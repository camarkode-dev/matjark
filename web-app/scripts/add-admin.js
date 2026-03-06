const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json'); // Download from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://matjark-7ebc7.firebaseio.com' // Replace with your project ID
});

async function createAdminUser(email, password, name) {
  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });

    console.log('Successfully created new admin user:', userRecord.uid);

    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, { admin: true });

    // Create user document in Firestore
    const db = admin.firestore();
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      name: name,
      email: email,
      role: 'admin',
      status: 'active',
      createdAt: new Date(),
    });

    console.log(`Admin user created with UID: ${userRecord.uid}`);
    console.log(`Email: ${email}`);
    console.log(`Password: ${password}`);
    console.log('Please change the password after first login.');

  } catch (error) {
    console.error('Error creating admin user:', error);
  }
}

// Usage: node create-admin.js <email> <password> <name>
const email = process.argv[2];
const password = process.argv[3];
const name = process.argv[4];

if (!email || !password || !name) {
  console.log('Usage: node create-admin.js <email> <password> <name>');
  console.log('Example: node create-admin.js admin@matjark.com mypassword123 "Admin User"');
  process.exit(1);
}

createAdminUser(email, password, name);