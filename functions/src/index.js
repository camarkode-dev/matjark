import admin from "firebase-admin";
import cors from "cors";
import * as logger from "firebase-functions/logger";
import * as functionsV1 from "firebase-functions/v1";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const REGION = "us-central1";
const DEFAULT_CURRENCY = "EGP";
const TAX_RATE = 0.14;
const COMMISSION_RATE = 0.02;
const LOW_STOCK_THRESHOLD = 5;
const NOTIFICATION_RETENTION_DAYS = 30;
const MAX_LINE_ITEMS = 20;
const MAX_ADMIN_RECIPIENTS = 20;
const FREE_SHIPPING_THRESHOLD = 350;

const V2_RUNTIME_OPTIONS = Object.freeze({
  region: REGION,
  memory: "256MiB",
  cpu: 1,
  maxInstances: 10,
  minInstances: 0,
  concurrency: 80,
  timeoutSeconds: 60,
});

const SCHEDULE_RUNTIME_OPTIONS = Object.freeze({
  ...V2_RUNTIME_OPTIONS,
  maxInstances: 1,
  concurrency: 1,
});

const SHIPPING_BY_ZONE = Object.freeze({
  cairo: 29,
  giza: 29,
  alexandria: 35,
  delta: 39,
  upper_egypt: 49,
  sinai: 55,
  default: 39,
});

const ROLES = Object.freeze({
  ADMIN: "admin",
  SELLER: "seller",
  CUSTOMER: "customer",
});

const PAYMENT_STATUS_BY_PROVIDER = Object.freeze({
  cod: "pending_collection",
  bank_transfer: "awaiting_transfer",
  instapay: "awaiting_instapay_transfer",
  paymob_card: "pending_gateway_configuration",
  card: "pending_gateway_configuration",
  fawry: "awaiting_fawry_payment",
  apple_pay: "pending_gateway_configuration",
});

const PAYMENT_INSTRUCTIONS = Object.freeze({
  cod: {
    title: "Cash on delivery",
    body: "Pay in cash when the order arrives.",
  },
  instapay: {
    title: "InstaPay transfer",
    body: "Transfer to InstaPay number 01090886364 and keep the transfer reference.",
    accountName: "Matjark Demo",
    phoneNumber: "01090886364",
  },
  bank_transfer: {
    title: "Bank transfer",
    body: "Transfer to the demo bank account below and add the transfer reference after payment.",
    accountName: "Matjark Demo",
    bankName: "National Bank of Egypt",
    accountNumber: "1002003004",
    iban: "EG38001900050000001002003004",
  },
  fawry: {
    title: "Fawry payment",
    body: "Use the demo Fawry code below until the live merchant code is added.",
    serviceCode: "77889911",
    mobileNumber: "01000000001",
  },
  paymob_card: {
    title: "Card payment",
    body: "Pay securely with Visa or Mastercard.",
  },
  apple_pay: {
    title: "Apple Pay",
    body: "Available on supported Apple devices and browsers.",
  },
});

const ADMIN_EMAILS = new Set(
  parseCsv(process.env.MARKETPLACE_ADMIN_EMAILS).map((email) => email.toLowerCase()),
);
const ADMIN_UIDS = parseCsv(process.env.MARKETPLACE_ADMIN_UIDS);
const ALLOWED_ORIGINS = new Set([
  "https://matjark-7ebc7.web.app",
  "https://matjark-7ebc7.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5000",
  "http://localhost:8080",
  "http://localhost:8232",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:5000",
  "http://127.0.0.1:8080",
  "http://127.0.0.1:8232",
]);

setGlobalOptions(V2_RUNTIME_OPTIONS);

const corsMiddleware = cors({
  origin(origin, callback) {
    if (!origin || ALLOWED_ORIGINS.has(origin)) {
      callback(null, true);
      return;
    }
    callback(new Error("Origin is not allowed by CORS."));
  },
  methods: ["POST", "OPTIONS"],
  allowedHeaders: ["Authorization", "Content-Type"],
});

function parseCsv(value) {
  return String(value || "")
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
}

function normalizeString(value) {
  return String(value || "").trim();
}

function normalizeLower(value) {
  return normalizeString(value).toLowerCase();
}

function normalizeRole(value) {
  return Object.values(ROLES).includes(value) ? value : ROLES.CUSTOMER;
}

function toMoney(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) / 100 : 0;
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : 0;
}

function monthBucket(date = new Date()) {
  return date.toISOString().slice(0, 7).replace("-", "");
}

function normalizeZone(value) {
  const zone = normalizeLower(value).replaceAll(" ", "_");
  return SHIPPING_BY_ZONE[zone] ? zone : "default";
}

function normalizePaymentMethod(value) {
  const raw = normalizeLower(value);
  if (raw === "banktransfer") return "bank_transfer";
  if (raw === "applepay") return "apple_pay";
  return raw;
}

function resolveVendorId(data) {
  return normalizeString(data.vendorId || data.sellerId);
}

function resolveUnitPrice(data) {
  return toMoney(data.sellingPrice ?? data.price ?? 0);
}

function resolveImageUrl(data) {
  if (Array.isArray(data.images) && data.images.length > 0) {
    return normalizeString(data.images[0]);
  }
  return normalizeString(data.imageUrl);
}

function isProductPurchasable(product) {
  return product.isActive !== false;
}

function safeErrorMessage(error) {
  return normalizeString(error?.message) || "Unexpected server error.";
}

function assertAuthenticated(auth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
}

function assertAdmin(auth) {
  assertAuthenticated(auth);
  const role = auth?.token?.admin === true
    ? ROLES.ADMIN
    : normalizeRole(auth?.token?.role);
  if (role !== ROLES.ADMIN) {
    throw new HttpsError("permission-denied", "Admin role required.");
  }
}

function normalizeQuoteLines(rawLines) {
  const items = Array.isArray(rawLines) ? rawLines : [];
  if (items.length === 0 || items.length > MAX_LINE_ITEMS) {
    throw new HttpsError(
      "invalid-argument",
      `Checkout must contain between 1 and ${MAX_LINE_ITEMS} items.`,
    );
  }

  const merged = new Map();
  for (const item of items) {
    const productId = normalizeString(item?.productId || item?.id);
    const quantity = toPositiveInt(item?.quantity);
    if (!productId || quantity < 1 || quantity > 99) {
      throw new HttpsError(
        "invalid-argument",
        "Each checkout line must include a valid productId and quantity.",
      );
    }
    merged.set(productId, (merged.get(productId) || 0) + quantity);
  }

  return Array.from(merged.entries()).map(([productId, quantity]) => ({
    productId,
    quantity,
  }));
}

function normalizeShippingAddress(data) {
  const shippingAddress =
    data && typeof data.shippingAddress === "object" ? data.shippingAddress : {};

  const address = {
    fullName: normalizeString(shippingAddress.fullName),
    phone: normalizeString(shippingAddress.phone),
    line1: normalizeString(shippingAddress.line1),
    city: normalizeString(shippingAddress.city),
    notes: normalizeString(shippingAddress.notes),
  };

  if (!address.fullName || !address.phone || !address.line1 || !address.city) {
    throw new HttpsError(
      "invalid-argument",
      "Shipping address requires fullName, phone, line1, and city.",
    );
  }

  return address;
}

function normalizePaymentDetails(data) {
  const paymentDetails =
    data && typeof data.paymentDetails === "object" ? data.paymentDetails : {};

  return {
    senderName: normalizeString(paymentDetails.senderName),
    senderPhone: normalizeString(paymentDetails.senderPhone),
    referenceNumber: normalizeString(paymentDetails.referenceNumber),
    receiptUrl: normalizeString(paymentDetails.receiptUrl),
    notes: normalizeString(paymentDetails.notes),
  };
}

function paymentInstructionsForProvider(provider) {
  return PAYMENT_INSTRUCTIONS[provider] || PAYMENT_INSTRUCTIONS.paymob_card;
}

function calculateShipping(subtotal, zone) {
  if (subtotal >= FREE_SHIPPING_THRESHOLD) {
    return 0;
  }
  return SHIPPING_BY_ZONE[zone] || SHIPPING_BY_ZONE.default;
}

async function setUserClaims(uid, role, sellerApproved) {
  const userRecord = await admin.auth().getUser(uid);
  const currentClaims = userRecord.customClaims || {};
  const nextClaims = {
    ...currentClaims,
    role,
    admin: role === ROLES.ADMIN,
    sellerApproved: role === ROLES.SELLER ? sellerApproved === true : false,
  };

  if (
    currentClaims.role === nextClaims.role &&
    currentClaims.admin === nextClaims.admin &&
    currentClaims.sellerApproved === nextClaims.sellerApproved
  ) {
    return;
  }

  await admin.auth().setCustomUserClaims(uid, nextClaims);
}

async function upsertUserDocument(userRecord, role, sellerApproved) {
  const userRef = db.collection("users").doc(userRecord.uid);
  const existing = await userRef.get();
  const payload = {
    uid: userRecord.uid,
    email: userRecord.email || "",
    name: userRecord.displayName || "",
    phone: userRecord.phoneNumber || "",
    role,
    status: role === ROLES.CUSTOMER ? "approved" : "pending",
    isApproved: role === ROLES.CUSTOMER,
    sellerApproved,
    sellerRequestStatus: sellerApproved ? "approved" : "none",
    language: "ar",
    themeMode: "light",
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (!existing.exists) {
    payload.createdAt = FieldValue.serverTimestamp();
  }

  await userRef.set(payload, { merge: true });
}

async function getAdminUserIds() {
  if (ADMIN_UIDS.length > 0) {
    return ADMIN_UIDS.slice(0, MAX_ADMIN_RECIPIENTS);
  }

  const snapshot = await db
    .collection("users")
    .where("role", "==", ROLES.ADMIN)
    .limit(MAX_ADMIN_RECIPIENTS)
    .get();

  return snapshot.docs.map((doc) => doc.id);
}

async function createNotifications(userIds, payload) {
  if (!Array.isArray(userIds) || userIds.length === 0) {
    return;
  }

  const batch = db.batch();
  for (const userId of userIds.slice(0, MAX_ADMIN_RECIPIENTS)) {
    batch.set(db.collection("notifications").doc(), {
      userId,
      type: payload.type,
      title: payload.title,
      body: payload.body,
      resourceType: payload.resourceType || null,
      resourceId: payload.resourceId || null,
      isRead: false,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

async function notifyAdmins(payload) {
  const adminUserIds = await getAdminUserIds();
  if (adminUserIds.length === 0) {
    logger.info("No admin recipients configured.", payload);
    return;
  }
  await createNotifications(adminUserIds, payload);
}

async function loadCoupon(couponCode) {
  const code = normalizeString(couponCode).toUpperCase();
  if (!code) {
    return null;
  }

  let snapshot = await db.collection("coupons").doc(code).get();
  if (!snapshot.exists) {
    snapshot = await db.collection("discount_codes").doc(code).get();
  }

  return snapshot.exists ? snapshot.data() : null;
}

async function loadProductsForLines(lines) {
  const refs = lines.map((line) => db.collection("products").doc(line.productId));
  const snapshots = refs.length > 0 ? await db.getAll(...refs) : [];
  const productsById = new Map();

  for (const snapshot of snapshots) {
    if (!snapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        `Product ${snapshot.id} does not exist.`,
      );
    }
    productsById.set(snapshot.id, snapshot.data());
  }

  return productsById;
}

function buildQuoteFromProducts({ lines, productsById, shippingZone, coupon }) {
  const normalizedZone = normalizeZone(shippingZone);
  const items = [];
  let subtotal = 0;
  let vendorId = "";

  for (const line of lines) {
    const product = productsById.get(line.productId);
    if (!product) {
      throw new HttpsError("failed-precondition", `Product ${line.productId} does not exist.`);
    }
    if (!isProductPurchasable(product)) {
      throw new HttpsError("failed-precondition", `Product ${line.productId} is unavailable.`);
    }
    if (toPositiveInt(product.stock) < line.quantity) {
      throw new HttpsError("failed-precondition", `Insufficient stock for ${line.productId}.`);
    }

    const currentVendorId = resolveVendorId(product);
    if (!currentVendorId) {
      throw new HttpsError(
        "failed-precondition",
        `Product ${line.productId} is missing vendor ownership.`,
      );
    }
    if (vendorId && vendorId !== currentVendorId) {
      throw new HttpsError(
        "failed-precondition",
        "Checkout currently supports one vendor per order. Split the cart by vendor first.",
      );
    }
    vendorId = currentVendorId;

    const unitPrice = resolveUnitPrice(product);
    const lineTotal = toMoney(unitPrice * line.quantity);
    subtotal = toMoney(subtotal + lineTotal);

    items.push({
      productId: line.productId,
      titleAr: normalizeString(product.titleAr),
      titleEn: normalizeString(product.titleEn || product.name),
      quantity: line.quantity,
      unitPrice,
      lineTotal,
      sellerId: currentVendorId,
      vendorId: currentVendorId,
      categoryId: normalizeString(product.categoryId),
      imageUrl: resolveImageUrl(product),
    });
  }

  let discountAmount = 0;
  const couponCode = normalizeString(coupon?.code);
  if (coupon && coupon.isActive === true) {
    const minOrder = toMoney(coupon.minOrder || 0);
    if (subtotal >= minOrder) {
      if (normalizeLower(coupon.type) === "percent") {
        discountAmount = toMoney((subtotal * toMoney(coupon.value || 0)) / 100);
      } else {
        discountAmount = toMoney(coupon.value || 0);
      }
    }
  }

  discountAmount = Math.min(discountAmount, subtotal);
  const taxableSubtotal = toMoney(Math.max(subtotal - discountAmount, 0));
  const shippingAmount = toMoney(calculateShipping(subtotal, normalizedZone));
  const taxAmount = toMoney(taxableSubtotal * TAX_RATE);
  const totalAmount = toMoney(taxableSubtotal + taxAmount + shippingAmount);

  return {
    currency: DEFAULT_CURRENCY,
    sellerId: vendorId,
    vendorId,
    items,
    itemCount: items.length,
    subtotal,
    discountAmount,
    taxAmount,
    shippingAmount,
    totalAmount,
    couponCode: couponCode || null,
    governorate: normalizedZone,
    taxRate: TAX_RATE,
    commissionRate: COMMISSION_RATE,
  };
}

async function buildCheckoutQuote(data) {
  const lines = normalizeQuoteLines((data?.lines || data?.items) || []);
  const coupon = await loadCoupon(data?.couponCode);
  const productsById = await loadProductsForLines(lines);
  return buildQuoteFromProducts({
    lines,
    productsById,
    shippingZone: data?.shippingZone || data?.governorate,
    coupon,
  });
}

function runCors(req, res) {
  return new Promise((resolve, reject) => {
    corsMiddleware(req, res, (error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

async function verifyHttpAuth(req) {
  const header = normalizeString(req.headers.authorization);
  if (!header.startsWith("Bearer ")) {
    throw new HttpsError("unauthenticated", "Missing bearer token.");
  }
  const token = header.substring("Bearer ".length).trim();
  return admin.auth().verifyIdToken(token);
}

async function createServerPaymentIntent({ auth, data }) {
  assertAuthenticated(auth);

  const orderId = normalizeString(data?.orderId);
  const provider = normalizePaymentMethod(data?.provider || data?.paymentMethod);
  const amount = toMoney(data?.amount);
  const currency = normalizeString(data?.currency || DEFAULT_CURRENCY) || DEFAULT_CURRENCY;

  if (!orderId || !provider || amount <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "orderId, provider, and amount are required.",
    );
  }

  const orderRef = db.collection("orders").doc(orderId);
  const paymentRef = db.collection("payments").doc();
  const referenceId = `pay_${Date.now()}_${orderId}`;
  const providerStatus = PAYMENT_STATUS_BY_PROVIDER[provider] || "pending_gateway_configuration";
  const paymentInstructions = paymentInstructionsForProvider(provider);
  const requiresManualReview = provider === "bank_transfer" || provider === "instapay" || provider === "fawry";
  const message = provider === "cod"
    ? "Cash on delivery selected."
    : paymentInstructions.body;

  await db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const order = orderSnapshot.data();
    if (order.customerId !== auth.uid) {
      throw new HttpsError("permission-denied", "This order does not belong to the caller.");
    }

    const orderTotal = toMoney(order.totalAmount);
    if (amount !== orderTotal) {
      throw new HttpsError("failed-precondition", "Amount must match the server order total.");
    }

    const paymentRecord = {
      referenceId,
      orderId,
      customerId: auth.uid,
      amount: orderTotal,
      currency,
      provider,
      status: providerStatus,
      requiresManualReview,
      message,
      metadata: {
        orderId,
        provider,
        mode: "server_v2",
        checkoutUrl: "",
        ...paymentInstructions,
      },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    transaction.set(paymentRef, paymentRecord);
    transaction.set(
      orderRef,
      {
        paymentReferenceId: referenceId,
        paymentIntentId: paymentRef.id,
        paymentProvider: provider,
        paymentStatus: providerStatus,
        payment_status: providerStatus,
        paymentMessage: message,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return {
    ok: true,
    referenceId,
    paymentId: paymentRef.id,
    status: providerStatus,
    provider,
    requiresManualReview,
    message,
    metadata: {
      orderId,
      provider,
      mode: "server_v2",
      checkoutUrl: "",
      ...paymentInstructions,
    },
  };
}

export const onUserCreate = functionsV1
  .region(REGION)
  .runWith({
    memory: "256MB",
    timeoutSeconds: 60,
    maxInstances: 10,
  })
  .auth.user()
  .onCreate(async (user) => {
    const role =
      user.email && ADMIN_EMAILS.has(user.email.toLowerCase())
        ? ROLES.ADMIN
        : ROLES.CUSTOMER;

    await Promise.all([
      upsertUserDocument(user, role, false),
      setUserClaims(user.uid, role, false),
    ]);
  });

export const syncUserClaimsFromProfileV2 = onDocumentUpdated(
  {
    ...V2_RUNTIME_OPTIONS,
    document: "users/{uid}",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const uid = normalizeString(event.params.uid);
    if (!uid) {
      return;
    }

    const nextRole = normalizeRole(after.role);
    const nextSellerApproved =
      after.sellerApproved === true ||
      after.isApproved === true ||
      after.status === "approved";
    const previousRole = normalizeRole(before.role);
    const previousSellerApproved =
      before.sellerApproved === true ||
      before.isApproved === true ||
      before.status === "approved";

    if (
      nextRole === previousRole &&
      nextSellerApproved === previousSellerApproved
    ) {
      return;
    }

    await setUserClaims(uid, nextRole, nextRole === ROLES.SELLER && nextSellerApproved);
  },
);

export const setUserRole = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAdmin(request.auth);

  const uid = normalizeString(request.data?.uid);
  const nextRole = normalizeRole(request.data?.role);
  const sellerApproved =
    nextRole === ROLES.SELLER && request.data?.sellerApproved === true;

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  const authUser = await admin.auth().getUser(uid);
  await Promise.all([
    upsertUserDocument(authUser, nextRole, sellerApproved),
    setUserClaims(uid, nextRole, sellerApproved),
  ]);

  return {
    ok: true,
    uid,
    role: nextRole,
    sellerApproved,
  };
});

export const calculateCheckoutQuote = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAuthenticated(request.auth);
  return buildCheckoutQuote(request.data || {});
});

export const calculateOrderTotals = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAuthenticated(request.auth);
  return buildCheckoutQuote(request.data || {});
});

export const calculateOrderTotalsEgypt = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAuthenticated(request.auth);
  return buildCheckoutQuote(request.data || {});
});

export const calculateOrderTotalsEgyptHttp = onRequest(
  V2_RUNTIME_OPTIONS,
  async (req, res) => {
    try {
      await runCors(req, res);
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed." });
        return;
      }

      await verifyHttpAuth(req);
      const quote = await buildCheckoutQuote(req.body || {});
      res.status(200).json(quote);
    } catch (error) {
      const status = error instanceof HttpsError ? error.httpErrorCode.status : 500;
      res.status(status).json({ error: safeErrorMessage(error) });
    }
  },
);

export const placeMarketplaceOrder = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAuthenticated(request.auth);

  const customerId = request.auth.uid;
  const paymentMethod = normalizePaymentMethod(request.data?.paymentMethod);
  const shippingAddress = normalizeShippingAddress(request.data || {});
  const paymentDetails = normalizePaymentDetails(request.data || {});
  const requestedLines = normalizeQuoteLines((request.data?.lines || request.data?.items) || []);
  const coupon = await loadCoupon(request.data?.couponCode);

  if (!paymentMethod) {
    throw new HttpsError("invalid-argument", "paymentMethod is required.");
  }

  const orderRef = db.collection("orders").doc();

  const result = await db.runTransaction(async (transaction) => {
    const refs = requestedLines.map((line) => db.collection("products").doc(line.productId));
    const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
    const productsById = new Map();

    for (const snapshot of snapshots) {
      if (!snapshot.exists) {
        throw new HttpsError("failed-precondition", `Product ${snapshot.id} does not exist.`);
      }
      productsById.set(snapshot.id, snapshot.data());
    }

    const quote = buildQuoteFromProducts({
      lines: requestedLines,
      productsById,
      shippingZone: request.data?.shippingZone || request.data?.governorate,
      coupon,
    });

    const platformFee = toMoney(quote.totalAmount * COMMISSION_RATE);
    const sellerRevenue = toMoney(quote.totalAmount - platformFee);
    const initialPaymentStatus =
      PAYMENT_STATUS_BY_PROVIDER[paymentMethod] || "pending_gateway_configuration";

    for (const line of requestedLines) {
      const productRef = db.collection("products").doc(line.productId);
      const product = productsById.get(line.productId);
      transaction.update(productRef, {
        stock: toPositiveInt(product.stock) - line.quantity,
        salesCount: FieldValue.increment(line.quantity),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    transaction.set(orderRef, {
      customerId,
      customerName: shippingAddress.fullName,
      vendorId: quote.vendorId,
      sellerId: quote.sellerId,
      items: quote.items,
      status: "pending",
      statusHistory: [
        {
          status: "pending",
          source: "placeMarketplaceOrder",
          at: new Date().toISOString(),
        },
      ],
      paymentMethod,
      paymentDetails,
      paymentStatus: initialPaymentStatus,
      payment_status: initialPaymentStatus,
      currency: quote.currency,
      subtotalAmount: quote.subtotal,
      discountAmount: quote.discountAmount,
      taxAmount: quote.taxAmount,
      shippingAmount: quote.shippingAmount,
      totalAmount: quote.totalAmount,
      platform_fee: platformFee,
      seller_revenue: sellerRevenue,
      commission: platformFee,
      commissionRate: COMMISSION_RATE,
      sellerSettlementStatus: "pending",
      couponCode: quote.couponCode,
      address: shippingAddress,
      governorate: quote.governorate,
      pricingSource: "server-v2",
      createdMonth: monthBucket(),
      financialsVersion: 2,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      ...quote,
      platformFee,
      sellerRevenue,
      paymentStatus: initialPaymentStatus,
    };
  });

  const cartBatch = db.batch();
  for (const line of requestedLines) {
    cartBatch.delete(db.collection("carts").doc(customerId).collection("items").doc(line.productId));
  }
  await cartBatch.commit();

  await notifyAdmins({
    type: "order.created",
    title: "New order placed",
    body: `Order ${orderRef.id} was placed successfully.`,
    resourceType: "order",
    resourceId: orderRef.id,
  });

  return {
    ok: true,
    orderId: orderRef.id,
    totalAmount: result.totalAmount,
    subtotalAmount: result.subtotal,
    discountAmount: result.discountAmount,
    taxAmount: result.taxAmount,
    shippingAmount: result.shippingAmount,
    currency: result.currency,
    paymentStatus: result.paymentStatus,
    platformFee: result.platformFee,
    sellerRevenue: result.sellerRevenue,
  };
});

export const createPaymentIntent = onCall(V2_RUNTIME_OPTIONS, async (request) =>
  createServerPaymentIntent(request),
);

export const createPaymentIntentEgypt = onCall(V2_RUNTIME_OPTIONS, async (request) =>
  createServerPaymentIntent(request),
);

export const createProduct = onCall(V2_RUNTIME_OPTIONS, async (request) => {
  assertAuthenticated(request.auth);
  const role = normalizeRole(request.auth?.token?.role);
  const sellerApproved = request.auth?.token?.sellerApproved === true;

  if (!(request.auth?.token?.admin === true) && !(role === ROLES.SELLER && sellerApproved)) {
    throw new HttpsError("permission-denied", "Approved vendor role required.");
  }

  const name = normalizeString(request.data?.titleEn || request.data?.name);
  const price = toMoney(request.data?.sellingPrice || request.data?.price);
  const stock = toPositiveInt(request.data?.stock);

  if (!name || price <= 0 || stock < 0) {
    throw new HttpsError("invalid-argument", "titleEn, sellingPrice, and stock are required.");
  }

  const productRef = db.collection("products").doc();
  await productRef.set({
    ...request.data,
    sellerId: normalizeString(request.data?.sellerId || request.auth.uid),
    vendorId: normalizeString(request.data?.vendorId || request.data?.sellerId || request.auth.uid),
    nameLower: name.toLowerCase(),
    searchKeywords: name.toLowerCase().split(/\s+/).filter(Boolean),
    isApproved: true,
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, productId: productRef.id };
});

export const onSellerApplicationCreatedV2 = onDocumentCreated(
  {
    ...V2_RUNTIME_OPTIONS,
    document: "seller_requests/{requestId}",
  },
  async (event) => {
    const data = event.data?.data() || {};
    await notifyAdmins({
      type: "seller.application",
      title: "New seller application",
      body: `${normalizeString(data.store_name || data.storeName || "A seller")} is waiting for review.`,
      resourceType: "seller_request",
      resourceId: event.params.requestId,
    });
  },
);

export const dailyAdminMaintenanceV2 = onSchedule(
  {
    ...SCHEDULE_RUNTIME_OPTIONS,
    schedule: "every day 03:00",
    timeZone: "Etc/UTC",
  },
  async () => {
    const notificationCutoff = Timestamp.fromMillis(
      Date.now() - NOTIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );

    const [pendingSellerRequests, lowStockProducts, staleNotifications] = await Promise.all([
      db.collection("seller_requests").where("status", "==", "pending").count().get(),
      db.collection("products").where("stock", "<=", LOW_STOCK_THRESHOLD).count().get(),
      db.collection("notifications").where("createdAt", "<", notificationCutoff).limit(100).get(),
    ]);

    if (!staleNotifications.empty) {
      const cleanupBatch = db.batch();
      staleNotifications.docs.forEach((doc) => cleanupBatch.delete(doc.ref));
      await cleanupBatch.commit();
    }

    const pendingSellerCount = pendingSellerRequests.data().count;
    const lowStockCount = lowStockProducts.data().count;
    const deletedNotifications = staleNotifications.size;

    if (pendingSellerCount > 0 || lowStockCount > 0 || deletedNotifications > 0) {
      await notifyAdmins({
        type: "admin.daily-check",
        title: "Marketplace daily check",
        body: `Pending seller requests: ${pendingSellerCount}, low-stock products: ${lowStockCount}, cleaned notifications: ${deletedNotifications}.`,
        resourceType: "system",
        resourceId: monthBucket(),
      });
    }

    logger.info("dailyAdminMaintenanceV2 completed.", {
      pendingSellerCount,
      lowStockCount,
      deletedNotifications,
    });
  },
);
