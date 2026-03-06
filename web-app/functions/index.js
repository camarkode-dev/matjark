const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.approveVendor = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can approve vendors');
  }

  const { vendorId } = data;

  if (!vendorId) {
    throw new functions.https.HttpsError('invalid-argument', 'Vendor ID is required');
  }

  try {
    // Update vendor status
    await admin.firestore().collection('vendors').doc(vendorId).update({
      approved: true
    });

    // Update user status
    await admin.firestore().collection('users').doc(vendorId).update({
      status: 'active'
    });

    // Set custom claims for vendor
    await admin.auth().setCustomUserClaims(vendorId, { vendor: true });

    return { success: true, message: 'Vendor approved successfully' };
  } catch (error) {
    console.error('Error approving vendor:', error);
    throw new functions.https.HttpsError('internal', 'Failed to approve vendor');
  }
});

exports.rejectVendor = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can reject vendors');
  }

  const { vendorId } = data;

  if (!vendorId) {
    throw new functions.https.HttpsError('invalid-argument', 'Vendor ID is required');
  }

  try {
    // Update vendor status
    await admin.firestore().collection('vendors').doc(vendorId).update({
      approved: false
    });

    // Update user status
    await admin.firestore().collection('users').doc(vendorId).update({
      status: 'banned'
    });

    return { success: true, message: 'Vendor rejected successfully' };
  } catch (error) {
    console.error('Error rejecting vendor:', error);
    throw new functions.https.HttpsError('internal', 'Failed to reject vendor');
  }
});