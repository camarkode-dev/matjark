const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Cloud Function example: calculate commission when an order status changes to delivered
exports.calculateCommission = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'delivered' && after.status === 'delivered') {
      const orderId = context.params.orderId;
      const commissionRate = 0.02; // 2%
      const amount = after.totalAmount || 0;
      const commission = amount * commissionRate;

      // write commission breakdown to a subcollection or another document
      await admin.firestore().collection('orders').doc(orderId).update({
        commissionAmount: commission,
        commissionCalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // adjust seller/supplier earnings documents if needed
      // ... additional logic here ...
    }
    return null;
  });

// Example: send notification when order is shipped
exports.notifyOrderShipped = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (before.status !== 'shipped' && after.status === 'shipped') {
      const tokens = []; // query FCM tokens for the customer (not shown)
      const payload = {
        notification: {
          title: 'Your order has shipped',
          body: `Order #${context.params.orderId} is on its way!`,
        },
      };
      if (tokens.length > 0) {
        await admin.messaging().sendToDevice(tokens, payload);
      }
    }
    return null;
  });
