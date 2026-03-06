'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const runtimeConfig = functions.config();

const DEFAULT_ADMIN_EMAIL = 'ca.matjark@gmail.com';
const DEFAULT_ADMIN_PASSWORD =
  process.env.DEFAULT_ADMIN_PASSWORD ||
  (runtimeConfig.app && runtimeConfig.app.default_admin_password) ||
  '01090886364';
const BOOTSTRAP_KEY =
  process.env.BOOTSTRAP_KEY ||
  (runtimeConfig.app && runtimeConfig.app.bootstrap_key) ||
  '';
const EG_TAX_RATE =
  toNumber(process.env.EG_TAX_RATE) ||
  toNumber(runtimeConfig.app && runtimeConfig.app.eg_tax_rate) ||
  0.14;

const COMMISSION_RATE = 0.02;
const ROLES = new Set(['customer', 'seller', 'admin']);
const ORDER_FLOW = {
  pending: ['processing'],
  processing: ['shipped'],
  shipped: ['delivered'],
  delivered: ['returned'],
  returned: [],
};

function toBool(value) {
  return value === true;
}

function toNumber(value) {
  const n = Number(value || 0);
  return Number.isFinite(n) ? n : 0;
}

function round2(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function normalizeRole(role) {
  return ROLES.has(role) ? role : 'customer';
}

function normalizeStatus(role, status, isApproved) {
  if (role === 'admin') return 'approved';
  if (role === 'customer') return 'approved';
  if (status === 'suspended') return 'suspended';
  if (role === 'seller') return isApproved ? 'approved' : 'pending';
  return 'pending';
}

function normalizeEgyptPhone(phone) {
  const raw = String(phone || '').replace(/[^\d+]/g, '');
  if (!raw) return '';
  if (raw.startsWith('+20')) return raw;
  if (raw.startsWith('0020')) return `+${raw.substring(2)}`;
  if (raw.startsWith('20')) return `+${raw}`;
  if (raw.startsWith('01') && raw.length === 11) {
    return `+20${raw.substring(1)}`;
  }
  if (raw.startsWith('1') && raw.length === 10) {
    return `+20${raw}`;
  }
  return raw;
}

function isAdminCaller(context) {
  return !!(
    context &&
    context.auth &&
    context.auth.token &&
    (context.auth.token.admin === true || context.auth.token.role === 'admin')
  );
}

function statusMessage(status, orderId) {
  const map = {
    pending: 'Order created',
    processing: 'Order is being processed',
    shipped: 'Order shipped',
    delivered: 'Order delivered',
    returned: 'Order returned',
  };
  const title = map[status] || 'Order update';
  return {
    title,
    body: `Order #${orderId} status changed to ${status}.`,
  };
}

function isValidTransition(fromStatus, toStatus) {
  if (!fromStatus || !toStatus) return false;
  if (fromStatus === toStatus) return true;
  const allowed = ORDER_FLOW[fromStatus] || [];
  return allowed.includes(toStatus);
}

async function setUserClaims(uid, role, isApproved) {
  const userRecord = await admin.auth().getUser(uid);
  const currentClaims = userRecord.customClaims || {};
  const admin = role === 'admin';
  if (
    currentClaims.role === role &&
    currentClaims.isApproved === isApproved &&
    currentClaims.admin === admin
  ) {
    return;
  }
  await admin.auth().setCustomUserClaims(uid, {
    ...currentClaims,
    role,
    isApproved,
    admin,
  });
}

async function upsertUserProfile(uid, userRecord, role, isApproved) {
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  const status = normalizeStatus(role, null, isApproved);

  const payload = {
    uid,
    email: userRecord.email || null,
    name: userRecord.displayName || null,
    phone: userRecord.phoneNumber || null,
    role,
    status,
    isApproved,
    language: 'ar',
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!snap.exists) {
    payload.createdAt = FieldValue.serverTimestamp();
  }
  await ref.set(payload, { merge: true });
}

async function ensureDefaultAdminAccount(forcePasswordReset) {
  let userRecord;

  try {
    userRecord = await admin.auth().getUserByEmail(DEFAULT_ADMIN_EMAIL);
    if (forcePasswordReset) {
      await admin.auth().updateUser(userRecord.uid, {
        password: DEFAULT_ADMIN_PASSWORD,
        disabled: false,
      });
    }
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    userRecord = await admin.auth().createUser({
      email: DEFAULT_ADMIN_EMAIL,
      password: DEFAULT_ADMIN_PASSWORD,
      displayName: 'Matjark Admin',
      emailVerified: true,
      disabled: false,
    });
  }

  await upsertUserProfile(userRecord.uid, userRecord, 'admin', true);
  await setUserClaims(userRecord.uid, 'admin', true);
  return userRecord;
}

async function notifyUser(userId, type, referenceId, title, body) {
  const now = FieldValue.serverTimestamp();
  await Promise.all([
    db.collection('notifications').add({
      userId,
      type,
      referenceId,
      title,
      body,
      isRead: false,
      createdAt: now,
    }),
    db.collection('mail_queue').add({
      userId,
      type,
      referenceId,
      subject: title,
      body,
      state: 'queued',
      createdAt: now,
    }),
  ]);
}

async function getAdminIds() {
  const snap = await db.collection('users').where('role', '==', 'admin').get();
  return snap.docs.map((d) => d.id);
}

async function notifyAdmins(type, referenceId, title, body) {
  const adminIds = await getAdminIds();
  await Promise.all(adminIds.map((uid) => notifyUser(uid, type, referenceId, title, body)));
}

async function fanOutOrderStatusNotifications(orderData, orderId, status) {
  const message = statusMessage(status, orderId);
  const recipients = [orderData.customerId, orderData.sellerId].filter(Boolean);
  await Promise.all(
    recipients.map((uid) =>
      notifyUser(uid, 'order_status', orderId, message.title, message.body),
    ),
  );
  await notifyAdmins('order_status', orderId, message.title, `Order #${orderId} update for admin.`);
}

exports.seedDefaultAdmin = functions.https.onCall(async (data, context) => {
  const providedKey = data && typeof data.bootstrapKey === 'string' ? data.bootstrapKey : '';
  const adminCaller = isAdminCaller(context);
  const hasBootstrapKey = BOOTSTRAP_KEY && providedKey === BOOTSTRAP_KEY;

  if (!adminCaller && !hasBootstrapKey) {
    throw new functions.https.HttpsError('permission-denied', 'Admin role or bootstrap key required.');
  }

  const userRecord = await ensureDefaultAdminAccount(toBool(data && data.forcePasswordReset));
  return { uid: userRecord.uid, email: userRecord.email, role: 'admin' };
});

exports.ensureDefaultAdminDaily = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  await ensureDefaultAdminAccount(false);
  return null;
});

exports.onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  const isDefaultAdmin = (user.email || '').toLowerCase() === DEFAULT_ADMIN_EMAIL.toLowerCase();
  const role = isDefaultAdmin ? 'admin' : 'customer';
  const isApproved = true;
  await upsertUserProfile(user.uid, user, role, isApproved);
  await setUserClaims(user.uid, role, isApproved);
  return null;
});

exports.syncUserClaimsFromProfile = functions.firestore
  .document('users/{uid}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const data = change.after.data() || {};
    const role = normalizeRole(data.role);
    const status = (data.status || 'pending').toString();
    const isApproved = role === 'seller' ? status === 'approved' : true;

    await setUserClaims(context.params.uid, role, isApproved);
    return null;
  });

exports.setUserRoleAndApproval = functions.https.onCall(async (data, context) => {
  const adminCaller = isAdminCaller(context);
  if (!adminCaller) {
    throw new functions.https.HttpsError('permission-denied', 'Admin role required.');
  }

  const uid = data && typeof data.uid === 'string' ? data.uid.trim() : '';
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid is required.');

  const role = normalizeRole(data.role);
  const requestedStatus = (data.status || '').toString().trim();
  const requestedApproved = toBool(data.isApproved);
  const status = requestedStatus || normalizeStatus(role, null, requestedApproved);
  const isApproved = role === 'seller' ? status === 'approved' : true;

  await db.collection('users').doc(uid).set(
    {
      role,
      status,
      isApproved,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await setUserClaims(uid, role, isApproved);

  return { uid, role, status, isApproved };
});

exports.resetPasswordByPhoneOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token || !context.auth.token.phone_number) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Phone verification is required before resetting password.',
    );
  }

  const email = (data && data.email ? data.email : '').toString().trim().toLowerCase();
  const phone = normalizeEgyptPhone(data && data.phone);
  const newPassword = (data && data.newPassword ? data.newPassword : '').toString();
  const callerPhone = normalizeEgyptPhone(context.auth.token.phone_number);

  if (!email || !phone || !newPassword) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'email, phone, and newPassword are required.',
    );
  }
  if (newPassword.length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Password must be at least 6 characters.',
    );
  }
  if (phone !== callerPhone) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Verified phone number does not match the requested phone.',
    );
  }

  const users = await db.collection('users').where('email', '==', email).limit(3).get();
  const target = users.docs.find((doc) => normalizeEgyptPhone((doc.data() || {}).phone) === callerPhone);
  if (!target) {
    throw new functions.https.HttpsError(
      'not-found',
      'No account matches this email and phone number.',
    );
  }

  await admin.auth().updateUser(target.id, { password: newPassword });
  await target.ref.set(
    {
      updatedAt: FieldValue.serverTimestamp(),
      lastPasswordResetAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true, uid: target.id };
});

exports.calculateOrderTotalsEgypt = functions.https.onCall(async (data) => {
  const items = Array.isArray(data && data.items) ? data.items : [];
  const discountCode = data && typeof data.discountCode === 'string' ? data.discountCode.trim() : '';
  const governorate = data && typeof data.governorate === 'string' ? data.governorate.trim().toLowerCase() : '';

  const shippingMap = {
    cairo: 55,
    giza: 55,
    alexandria: 65,
    delta: 70,
    upper_egypt: 85,
    sinai: 95,
    default: 75,
  };

  const subtotal = round2(
    items.reduce((sum, item) => {
      const qty = toNumber(item.quantity || 0);
      const unitPrice = toNumber(item.unitPrice || item.price || 0);
      return sum + qty * unitPrice;
    }, 0),
  );

  let discountAmount = 0;
  if (discountCode) {
    let codeSnap = await db.collection('coupons').doc(discountCode).get();
    if (!codeSnap.exists) {
      codeSnap = await db.collection('discount_codes').doc(discountCode).get();
    }
    if (codeSnap.exists) {
      const code = codeSnap.data() || {};
      if (code.isActive === true && subtotal >= toNumber(code.minOrder || 0)) {
        discountAmount =
          code.type === 'percent'
            ? round2((subtotal * toNumber(code.value || 0)) / 100)
            : round2(toNumber(code.value || 0));
      }
    }
  }
  discountAmount = Math.min(discountAmount, subtotal);

  const taxable = Math.max(subtotal - discountAmount, 0);
  const taxAmount = round2(taxable * EG_TAX_RATE);
  const shippingAmount = shippingMap[governorate] || shippingMap.default;
  const totalAmount = round2(taxable + taxAmount + shippingAmount);

  return {
    currency: 'EGP',
    subtotal,
    discountAmount,
    taxAmount,
    shippingAmount,
    totalAmount,
  };
});

exports.onSellerApplicationCreate = functions.firestore
  .document('seller_requests/{applicationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const applicationId = context.params.applicationId;
    const ownerName = data.merchant_name || data.ownerName || 'Unknown owner';
    const storeName = data.store_name || data.storeName || 'Unknown store';
    await notifyAdmins(
      'seller_registration',
      applicationId,
      'New seller registration',
      `${ownerName} submitted application for store "${storeName}".`,
    );
    return null;
  });

exports.onSellerStatusChanged = functions.firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.role !== 'seller' && after.role !== 'seller') return null;
    if (before.status === after.status && before.role === after.role) return null;

    const uid = context.params.uid;
    const role = normalizeRole(after.role);
    const status = (after.status || 'pending').toString();
    const isApproved = role === 'seller' ? status === 'approved' : true;
    await setUserClaims(uid, role, isApproved);

    if (status === 'approved') {
      await notifyUser(
        uid,
        'seller_approved',
        uid,
        'Seller account approved',
        'Your seller account is approved. You can now manage products and orders.',
      );
    } else if (status === 'suspended') {
      await notifyUser(
        uid,
        'seller_suspended',
        uid,
        'Seller account suspended',
        'Your seller account has been suspended by admin.',
      );
    }

    return null;
  });

exports.onOrderCreateAdminAlert = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const orderId = context.params.orderId;
    const customerId = data.customerId || null;
    const sellerId = data.sellerId || null;

    if (customerId) {
      await notifyUser(
        customerId,
        'new_order',
        orderId,
        'Order created',
        `Your order #${orderId} has been created successfully.`,
      );
    }
    if (sellerId) {
      await notifyUser(
        sellerId,
        'new_order',
        orderId,
        'New order received',
        `You received a new order #${orderId}.`,
      );
    }
    await notifyAdmins(
      'new_order',
      orderId,
      'New order created',
      `Order #${orderId} created by customer ${data.customerId || 'unknown'}.`,
    );
    return null;
  });

exports.onOrderCreateInitializeFinancials = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const total = toNumber(data.totalAmount || 0);
    const platformFee = round2(total * COMMISSION_RATE);
    const sellerRevenue = round2(total - platformFee);
    await snap.ref.set(
      {
        platform_fee: platformFee,
        seller_revenue: sellerRevenue,
        commission: platformFee,
        payment_status: data.payment_status || data.paymentStatus || 'pending',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return null;
  });

exports.onReturnCreateAdminAlert = functions.firestore
  .document('returns/{returnId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const returnId = context.params.returnId;
    const customerId = data.customerId || null;
    const sellerId = data.sellerId || data.supplierId || null;
    const orderId = data.orderId || 'unknown';

    await notifyAdmins(
      'new_return',
      returnId,
      'New return request',
      `Return #${returnId} created for order ${orderId}.`,
    );

    if (sellerId) {
      await notifyUser(
        sellerId,
        'return_requested',
        returnId,
        'New return request',
        `A customer submitted return #${returnId} for order #${orderId}.`,
      );
    }

    if (customerId) {
      await notifyUser(
        customerId,
        'return_requested',
        returnId,
        'Return request submitted',
        `Your return request #${returnId} for order #${orderId} is pending seller review.`,
      );
    }

    return null;
  });

exports.onReturnStatusChanged = functions.firestore
  .document('returns/{returnId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const fromStatus = String(before.status || '');
    const toStatus = String(after.status || '');
    if (fromStatus === toStatus) return null;

    const returnId = context.params.returnId;
    const orderId = after.orderId || 'unknown';
    const customerId = after.customerId || null;
    const sellerId = after.sellerId || after.supplierId || null;

    await notifyAdmins(
      'return_status',
      returnId,
      'Return status updated',
      `Return #${returnId} for order #${orderId} changed from ${fromStatus} to ${toStatus}.`,
    );

    if (customerId) {
      if (toStatus === 'seller_approved' || toStatus === 'admin_approved') {
        await notifyUser(
          customerId,
          'return_approved',
          returnId,
          'Return approved',
          `Your return #${returnId} for order #${orderId} has been approved.`,
        );
      } else if (toStatus === 'seller_rejected' || toStatus === 'admin_rejected') {
        await notifyUser(
          customerId,
          'return_rejected',
          returnId,
          'Return rejected',
          `Your return #${returnId} for order #${orderId} has been rejected.`,
        );
      } else {
        await notifyUser(
          customerId,
          'return_status',
          returnId,
          'Return status updated',
          `Your return #${returnId} is now ${toStatus}.`,
        );
      }
    }

    if (sellerId && (toStatus === 'admin_approved' || toStatus === 'admin_rejected')) {
      await notifyUser(
        sellerId,
        'return_admin_override',
        returnId,
        'Return override by admin',
        `Admin changed return #${returnId} for order #${orderId} to ${toStatus}.`,
      );
    }

    return null;
  });

exports.handleOrderStateAndCommission = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const fromStatus = String(before.status || '');
    const toStatus = String(after.status || '');
    const orderId = context.params.orderId;

    if (fromStatus === toStatus) return null;
    if (!isValidTransition(fromStatus, toStatus)) {
      await change.after.ref.set(
        {
          status: fromStatus,
          workflowError: `Invalid transition: ${fromStatus} -> ${toStatus}`,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return null;
    }

    const updates = { updatedAt: FieldValue.serverTimestamp() };
    if (toStatus === 'shipped' && !after.shippedAt) updates.shippedAt = FieldValue.serverTimestamp();
    if (toStatus === 'delivered' && !after.deliveredAt) updates.deliveredAt = FieldValue.serverTimestamp();
    if (toStatus === 'returned' && !after.returnedAt) updates.returnedAt = FieldValue.serverTimestamp();

    const batch = db.batch();
    batch.set(change.after.ref, updates, { merge: true });

    if (toStatus === 'delivered' && !after.commissionCalculatedAt) {
      const totalAmount = toNumber(after.totalAmount || 0);
      const commission = round2(totalAmount * COMMISSION_RATE);
      const sellerEarnings = round2(totalAmount - commission);

      batch.set(
        change.after.ref,
        {
          commission,
          commissionRate: COMMISSION_RATE,
          sellerEarnings,
          commissionCalculatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      batch.set(
        db.collection('commissions').doc(orderId),
        {
          orderId,
          sellerId: after.sellerId || null,
          totalAmount,
          commission,
          sellerEarnings,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (after.sellerId) {
        batch.set(
          db.collection('seller_reports').doc(after.sellerId),
          {
            earnings: FieldValue.increment(sellerEarnings),
            totalCommissionDeducted: FieldValue.increment(commission),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        batch.set(
          db.collection('users').doc(after.sellerId),
          {
            earnings: FieldValue.increment(sellerEarnings),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      batch.set(
        db.collection('admin_reports').doc('global'),
        {
          totalCommission: FieldValue.increment(commission),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    await batch.commit();
    await fanOutOrderStatusNotifications(after, orderId, toStatus);
    return null;
  });

async function ensureAuthUser({ email, password, displayName, phoneNumber }) {
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {
      displayName: displayName || userRecord.displayName || null,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: displayName || null,
      phoneNumber: phoneNumber || undefined,
      emailVerified: true,
      disabled: false,
    });
  }
  return userRecord;
}

function demoNowMinusDays(days) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return admin.firestore.Timestamp.fromDate(date);
}

async function buildAuthContextFromRequest(req) {
  const authHeader = req.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return {};
  }
  const token = authHeader.substring('Bearer '.length).trim();
  if (!token) {
    return {};
  }
  const decoded = await admin.auth().verifyIdToken(token);
  return { auth: { uid: decoded.uid, token: decoded } };
}

async function seedDemoMarketplaceDataCore(data, context) {
  const providedKey = data && typeof data.bootstrapKey === 'string' ? data.bootstrapKey : '';
  const adminCaller = isAdminCaller(context);
  const hasBootstrapKey = BOOTSTRAP_KEY && providedKey === BOOTSTRAP_KEY;
  if (!adminCaller && !hasBootstrapKey) {
    throw new functions.https.HttpsError('permission-denied', 'Admin role or bootstrap key required.');
  }

  const users = [
    {
      key: 'admin',
      email: DEFAULT_ADMIN_EMAIL,
      password: DEFAULT_ADMIN_PASSWORD,
      displayName: 'Matjark Admin',
      role: 'admin',
      status: 'approved',
      isApproved: true,
    },
    {
      key: 'sellerApproved1',
      email: 'seller1.demo@matjark.app',
      password: 'Seller@123',
      displayName: 'Cairo Gadgets',
      role: 'seller',
      status: 'approved',
      isApproved: true,
    },
    {
      key: 'sellerApproved2',
      email: 'seller2.demo@matjark.app',
      password: 'Seller@123',
      displayName: 'Nile Home',
      role: 'seller',
      status: 'approved',
      isApproved: true,
    },
    {
      key: 'sellerPending',
      email: 'seller.pending@matjark.app',
      password: 'Seller@123',
      displayName: 'Pending Store',
      role: 'seller',
      status: 'pending',
      isApproved: false,
    },
    {
      key: 'customer1',
      email: 'customer1.demo@matjark.app',
      password: 'Customer@123',
      displayName: 'Customer One',
      role: 'customer',
      status: 'approved',
      isApproved: true,
    },
    {
      key: 'customer2',
      email: 'customer2.demo@matjark.app',
      password: 'Customer@123',
      displayName: 'Customer Two',
      role: 'customer',
      status: 'approved',
      isApproved: true,
    },
  ];

  const userIdByKey = {};
  for (const u of users) {
    const authUser = await ensureAuthUser({
      email: u.email,
      password: u.password,
      displayName: u.displayName,
    });
    userIdByKey[u.key] = authUser.uid;
    await db.collection('users').doc(authUser.uid).set(
      {
        uid: authUser.uid,
        email: u.email,
        name: u.displayName,
        role: u.role,
        status: u.status,
        isApproved: u.isApproved,
        language: 'ar',
        themeMode: 'light',
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await setUserClaims(authUser.uid, u.role, u.isApproved);
  }

  const categories = [
    { id: 'demo_cat_electronics', nameAr: 'إلكترونيات', nameEn: 'Electronics' },
    { id: 'demo_cat_home', nameAr: 'منزل ومطبخ', nameEn: 'Home & Kitchen' },
    { id: 'demo_cat_fashion', nameAr: 'أزياء', nameEn: 'Fashion' },
    { id: 'demo_cat_beauty', nameAr: 'جمال', nameEn: 'Beauty' },
    { id: 'demo_cat_sports', nameAr: 'رياضة', nameEn: 'Sports' },
  ];

  for (const category of categories) {
    await db.collection('categories').doc(category.id).set(
      {
        ...category,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  const products = [
    {
      id: 'demo_prod_earbuds',
      titleAr: 'سماعات لاسلكية',
      titleEn: 'Wireless Earbuds',
      descriptionAr: 'سماعات بلوتوث بعزل ضوضاء ممتاز.',
      descriptionEn: 'Bluetooth earbuds with strong noise isolation.',
      categoryId: 'demo_cat_electronics',
      sellerKey: 'sellerApproved1',
      stock: 55,
      rating: 4.6,
      salesCount: 140,
      costPrice: 950,
      sellingPrice: 799,
      image: 'https://images.unsplash.com/photo-1583394838336-acd977736f90',
    },
    {
      id: 'demo_prod_blender',
      titleAr: 'خلاط ذكي',
      titleEn: 'Smart Blender',
      descriptionAr: 'خلاط قوي مع برامج متعددة.',
      descriptionEn: 'High-power blender with smart presets.',
      categoryId: 'demo_cat_home',
      sellerKey: 'sellerApproved2',
      stock: 28,
      rating: 4.4,
      salesCount: 72,
      costPrice: 2300,
      sellingPrice: 1899,
      image: 'https://images.unsplash.com/photo-1570222094114-d054a817e56b',
    },
    {
      id: 'demo_prod_tshirt',
      titleAr: 'تيشيرت قطني',
      titleEn: 'Cotton T-Shirt',
      descriptionAr: 'تيشيرت مريح وخامة ممتازة.',
      descriptionEn: 'Comfortable premium cotton t-shirt.',
      categoryId: 'demo_cat_fashion',
      sellerKey: 'sellerApproved2',
      stock: 120,
      rating: 4.2,
      salesCount: 220,
      costPrice: 300,
      sellingPrice: 249,
      image: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab',
    },
    {
      id: 'demo_prod_serum',
      titleAr: 'سيروم فيتامين سي',
      titleEn: 'Vitamin C Serum',
      descriptionAr: 'سيروم للعناية اليومية بالبشرة.',
      descriptionEn: 'Daily skincare vitamin C serum.',
      categoryId: 'demo_cat_beauty',
      sellerKey: 'sellerApproved1',
      stock: 64,
      rating: 4.8,
      salesCount: 190,
      costPrice: 520,
      sellingPrice: 429,
      image: 'https://images.unsplash.com/photo-1611080541599-8c6dbde6ed28',
    },
    {
      id: 'demo_prod_dumbbells',
      titleAr: 'دامبلز 20 كجم',
      titleEn: '20kg Dumbbells',
      descriptionAr: 'مجموعة دامبلز للتدريب المنزلي.',
      descriptionEn: 'Home workout dumbbell set.',
      categoryId: 'demo_cat_sports',
      sellerKey: 'sellerApproved1',
      stock: 16,
      rating: 4.5,
      salesCount: 88,
      costPrice: 1700,
      sellingPrice: 1499,
      image: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438',
    },
  ];

  for (let index = 0; index < products.length; index += 1) {
    const p = products[index];
    const sellerId = userIdByKey[p.sellerKey];
    const hasDiscount = p.costPrice > p.sellingPrice;
    await db.collection('products').doc(p.id).set(
      {
        titleAr: p.titleAr,
        titleEn: p.titleEn,
        descriptionAr: p.descriptionAr,
        descriptionEn: p.descriptionEn,
        categoryId: p.categoryId,
        sellerId,
        supplierId: null,
        stock: p.stock,
        rating: p.rating,
        salesCount: p.salesCount,
        costPrice: p.costPrice,
        sellingPrice: p.sellingPrice,
        commissionAmount: round2(p.sellingPrice * COMMISSION_RATE),
        hasDiscount,
        images: [p.image],
        isApproved: true,
        createdAt: demoNowMinusDays(index + 1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  const orderTemplates = [
    {
      id: 'demo_order_1',
      customerKey: 'customer1',
      sellerKey: 'sellerApproved1',
      productId: 'demo_prod_earbuds',
      quantity: 1,
      status: 'delivered',
    },
    {
      id: 'demo_order_2',
      customerKey: 'customer2',
      sellerKey: 'sellerApproved2',
      productId: 'demo_prod_tshirt',
      quantity: 2,
      status: 'shipped',
    },
    {
      id: 'demo_order_3',
      customerKey: 'customer1',
      sellerKey: 'sellerApproved2',
      productId: 'demo_prod_blender',
      quantity: 1,
      status: 'processing',
    },
  ];

  for (const [index, orderTemplate] of orderTemplates.entries()) {
    const product = products.find((p) => p.id === orderTemplate.productId);
    if (!product) continue;
    const subtotal = product.sellingPrice * orderTemplate.quantity;
    const shippingAmount = 60;
    const taxAmount = round2(subtotal * EG_TAX_RATE);
    const totalAmount = round2(subtotal + taxAmount + shippingAmount);
    const commission = orderTemplate.status === 'delivered' ? round2(totalAmount * COMMISSION_RATE) : 0;

    await db.collection('orders').doc(orderTemplate.id).set(
      {
        customerId: userIdByKey[orderTemplate.customerKey],
        sellerId: userIdByKey[orderTemplate.sellerKey],
        supplierId: null,
        status: orderTemplate.status,
        currency: 'EGP',
        items: [
          {
            productId: product.id,
            titleAr: product.titleAr,
            titleEn: product.titleEn,
            categoryId: product.categoryId,
            quantity: orderTemplate.quantity,
            unitPrice: product.sellingPrice,
            sellerId: userIdByKey[orderTemplate.sellerKey],
          },
        ],
        subtotalAmount: subtotal,
        discountAmount: 0,
        taxAmount,
        shippingAmount,
        totalAmount,
        commission,
        commissionRate: COMMISSION_RATE,
        sellerEarnings: orderTemplate.status === 'delivered' ? round2(totalAmount - commission) : 0,
        commissionCalculatedAt: orderTemplate.status === 'delivered' ? FieldValue.serverTimestamp() : null,
        paymentMethod: 'cod',
        paymentStatus: 'initiated',
        paymentProvider: 'cod',
        address: 'Cairo',
        createdAt: demoNowMinusDays(index + 2),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (orderTemplate.status === 'delivered') {
      await db.collection('commissions').doc(orderTemplate.id).set(
        {
          orderId: orderTemplate.id,
          sellerId: userIdByKey[orderTemplate.sellerKey],
          totalAmount,
          commission,
          sellerEarnings: round2(totalAmount - commission),
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  }

  await db.collection('discount_codes').doc('DEMO10').set(
    {
      code: 'DEMO10',
      type: 'percent',
      value: 10,
      minOrder: 200,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db.collection('discount_codes').doc('WELCOME50').set(
    {
      code: 'WELCOME50',
      type: 'fixed',
      value: 50,
      minOrder: 300,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection('coupons').doc('DEMO10').set(
    {
      code: 'DEMO10',
      type: 'percent',
      value: 10,
      minOrder: 200,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db.collection('coupons').doc('WELCOME50').set(
    {
      code: 'WELCOME50',
      type: 'fixed',
      value: 50,
      minOrder: 300,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection('offers').doc('demo_offer_summer').set(
    {
      titleAr: 'عرض الصيف',
      titleEn: 'Summer Offer',
      descriptionAr: 'خصومات مميزة لفترة محدودة.',
      descriptionEn: 'Special discounts for a limited time.',
      discountPercent: 15,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await notifyUser(
    userIdByKey.admin,
    'seed_complete',
    'demo_seed',
    'Demo marketplace data ready',
    'Demo users, products, orders, coupons, and offers have been seeded.',
  );

  return {
    ok: true,
    users: users.length,
    categories: categories.length,
    products: products.length,
    orders: orderTemplates.length,
    discountCodes: 2,
    coupons: 2,
    offers: 1,
  };
}

exports.seedDemoMarketplaceData = functions.https.onCall(async (data, context) =>
  seedDemoMarketplaceDataCore(data, context),
);

exports.seedDemoMarketplaceDataHttp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed.' });
    return;
  }

  try {
    const context = await buildAuthContextFromRequest(req);
    const data = req.body && typeof req.body === 'object' ? req.body : {};
    const result = await seedDemoMarketplaceDataCore(data, context);
    res.status(200).json(result);
  } catch (error) {
    const code = error && error.code ? error.code : 'internal';
    const message = error && error.message ? error.message : 'Unknown error.';
    const status = code === 'permission-denied' ? 403 : 500;
    res.status(status).json({ error: message, code });
  }
});

exports.onOfferCreatedNotifyUsers = functions.firestore
  .document('offers/{offerId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const offerId = context.params.offerId;
    const title = data.titleEn || data.titleAr || 'New promotion';
    const body = 'A new promotion is now available.';
    const users = await db.collection('users').where('status', '==', 'approved').limit(500).get();
    await Promise.all(
      users.docs.map((u) =>
        notifyUser(u.id, 'promotion', offerId, title.toString(), body),
      ),
    );
    return null;
  });

function readPaymentConfig(key, fallback = '') {
  return (
    process.env[`PAYMENTS_${key.toUpperCase()}`] ||
    (runtimeConfig.payments && runtimeConfig.payments[key]) ||
    fallback
  );
}

function paymentMode() {
  return String(readPaymentConfig('mode', 'sandbox')).toLowerCase();
}

function amountToCents(amount) {
  return Math.max(0, Math.round(toNumber(amount) * 100));
}

function integrationIdForProvider(provider) {
  const map = {
    paymob_card: readPaymentConfig('paymob_integration_id_card'),
    apple_pay: readPaymentConfig('paymob_integration_id_apple_pay'),
    fawry: readPaymentConfig('paymob_integration_id_fawry'),
    instapay: readPaymentConfig('paymob_integration_id_instapay'),
  };
  return map[provider] || readPaymentConfig('paymob_integration_id_default');
}

function iframeIdForProvider(provider) {
  const map = {
    paymob_card: readPaymentConfig('paymob_iframe_id_card'),
    apple_pay: readPaymentConfig('paymob_iframe_id_apple_pay'),
    fawry: readPaymentConfig('paymob_iframe_id_fawry'),
    instapay: readPaymentConfig('paymob_iframe_id_instapay'),
  };
  return map[provider] || readPaymentConfig('paymob_iframe_id_default');
}

async function fetchJson(url, options) {
  const res = await fetch(url, options);
  const text = await res.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {
    payload = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`Gateway request failed (${res.status}): ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function buildBillingData(customerId) {
  const userSnap = await db.collection('users').doc(customerId).get();
  const user = userSnap.exists ? userSnap.data() : {};
  const email = user && user.email ? String(user.email) : 'customer@matjark.app';
  const phone = user && user.phone ? String(user.phone) : '+201000000000';
  const fullName = user && user.name ? String(user.name) : 'Matjark Customer';
  const [firstName, ...rest] = fullName.split(' ');
  const lastName = rest.join(' ') || 'Customer';
  return {
    apartment: 'NA',
    email,
    floor: 'NA',
    first_name: firstName || 'Matjark',
    street: 'NA',
    building: 'NA',
    phone_number: phone,
    shipping_method: 'NA',
    postal_code: 'NA',
    city: 'Cairo',
    country: 'EG',
    last_name: lastName,
    state: 'Cairo',
  };
}

async function createPaymobPaymentIntent({
  provider,
  orderId,
  customerId,
  amount,
  currency,
}) {
  const apiKey = readPaymentConfig('paymob_api_key');
  const integrationId = integrationIdForProvider(provider);
  const iframeId = iframeIdForProvider(provider);

  if (!apiKey || !integrationId || !iframeId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Missing Paymob configuration for production mode.',
    );
  }

  const authResponse = await fetchJson('https://accept.paymob.com/api/auth/tokens', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ api_key: apiKey }),
  });
  const authToken = authResponse.token;
  if (!authToken) {
    throw new Error('Paymob auth token missing.');
  }

  const amountCents = amountToCents(amount);
  const orderResponse = await fetchJson('https://accept.paymob.com/api/ecommerce/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      auth_token: authToken,
      delivery_needed: false,
      amount_cents: amountCents,
      currency: currency || 'EGP',
      merchant_order_id: orderId,
      items: [],
    }),
  });
  const paymobOrderId = orderResponse.id;
  if (!paymobOrderId) {
    throw new Error('Paymob order creation failed.');
  }

  const paymentKeyResponse = await fetchJson(
    'https://accept.paymob.com/api/acceptance/payment_keys',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        auth_token: authToken,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: paymobOrderId,
        billing_data: await buildBillingData(customerId),
        currency: currency || 'EGP',
        integration_id: Number(integrationId),
      }),
    },
  );
  const paymentToken = paymentKeyResponse.token;
  if (!paymentToken) {
    throw new Error('Paymob payment key creation failed.');
  }

  const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${paymentToken}`;
  const referenceId = `intent_${provider}_${paymobOrderId}_${Date.now()}`;
  return {
    referenceId,
    status: 'requires_action',
    message: 'Payment intent created with Paymob.',
    metadata: {
      mode: 'production',
      provider,
      checkoutUrl,
      paymobOrderId,
      iframeId,
      paymentToken,
    },
  };
}

exports.createPaymentIntentEgypt = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }
  const provider = (data && data.provider ? data.provider : '').toString();
  const orderId = (data && data.orderId ? data.orderId : '').toString();
  const customerId = (data && data.customerId ? data.customerId : '').toString();
  const amount = toNumber(data && data.amount);

  if (!provider || !orderId || !customerId || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'provider, orderId, customerId, amount are required.');
  }
  const currency = (data && data.currency ? data.currency : 'EGP').toString();
  const mode = paymentMode();

  let intent;
  if (mode === 'production') {
    if (['paymob_card', 'apple_pay', 'fawry', 'instapay'].includes(provider)) {
      intent = await createPaymobPaymentIntent({
        provider,
        orderId,
        customerId,
        amount,
        currency,
      });
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Unsupported provider for production mode: ${provider}`,
      );
    }
  } else {
    const referenceId = `intent_${provider}_${Date.now()}_${orderId}`;
    intent = {
      referenceId,
      status: 'initiated',
      message: 'Payment intent created in sandbox mode.',
      metadata: {
        provider,
        mode: 'sandbox',
        checkoutUrl: `https://sandbox.matjark.app/pay/${referenceId}`,
      },
    };
  }

  await db.collection('payment_intents').doc(intent.referenceId).set({
    referenceId: intent.referenceId,
    provider,
    orderId,
    customerId,
    amount,
    currency,
    status: intent.status,
    message: intent.message,
    metadata: intent.metadata,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return intent;
});
