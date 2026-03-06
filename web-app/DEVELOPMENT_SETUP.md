# Matjark Development Setup Guide

## Current Status

✅ **Emulators Running** on custom ports:
- Firestore: `http://localhost:9090`
- Auth: `http://localhost:9099`
- Emulator UI: `http://localhost:9093` (if enabled)

✅ **Next.js Development Server** running on:
- Application: `http://localhost:3000`

## Step 1: Download Service Account Key

Firebase Cloud Functions require a service account key for local testing.

1. Go to [Firebase Console](https://console.firebase.google.com/project/matjark-7ebc7/settings/serviceaccounts/adminsdk)
2. Click the **Generate new private key** button
3. A JSON file will be downloaded
4. Rename it to `serviceAccountKey.json`
5. Move it to: `web-app/scripts/serviceAccountKey.json`

**⚠️ IMPORTANT**: This file contains sensitive credentials. Never commit it to version control.

## Step 2: Create Your First Admin User

Once you have the service account key, run:

```bash
cd D:\matjark\web-app\scripts
node create-admin.js admin@matjark.com password123 "Admin User"
```

This will create an admin account in the Firestore emulator with:
- **Email**: admin@matjark.com
- **Password**: password123
- **Role**: admin

## Step 3: Test the Application

### Access the Application
- **Main URL**: `http://localhost:3000`
- **Firestore Console**: `http://localhost:9093` (if UI is enabled)

### Test User Flows

#### 1. Admin Login
```
Email: admin@matjark.com
Password: password123
```

#### 2. Create a Regular User Account
- Go to `http://localhost:3000/auth/register`
- Select "User" role
- Complete registration

#### 3. Create a Vendor Account
- Go to `http://localhost:3000/auth/register`
- Enter vendor store name
- Select "Vendor" role
- Register

## Step 4: Testing Admin Dashboard

After logging in as admin:
1. Navigate to `http://localhost:3000/admin`
2. View dashboard statistics:
   - Total users
   - Total vendors
   - Total products
   - Total orders
3. Approve/Reject pending vendors

## Firebase Emulator URLs

### Firestore Emulator
- **URL**: `http://localhost:9090`
- **Console UI**: `http://localhost:9093`

### Auth Emulator
- **URL**: `http://localhost:9099`
- **Console UI**: `http://localhost:9093`

## Environment Variables

The application is configured to use emulators in development mode. Configuration file: `web-app/.env.local`

```env
NEXT_PUBLIC_FIREBASE_API_KEY=demo_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=matjark-7ebc7.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=matjark-7ebc7
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=matjark-7ebc7.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abcdef123456
```

## Firestore Structure

The emulator will create the following collections:

### Collections

#### `users`
```json
{
  "uid": "user_id",
  "name": "User Name",
  "email": "user@example.com",
  "role": "user|vendor|admin",
  "status": "active|pending|banned",
  "createdAt": "2026-03-05T00:00:00Z"
}
```

#### `vendors`
```json
{
  "uid": "vendor_id",
  "storeName": "Store Name",
  "approved": true|false,
  "createdAt": "2026-03-05T00:00:00Z"
}
```

#### `products`
```json
{
  "productId": "product_id",
  "name": "Product Name",
  "description": "Description",
  "price": 100,
  "vendorId": "vendor_id",
  "status": "pending|approved|rejected",
  "createdAt": "2026-03-05T00:00:00Z"
}
```

#### `orders`
```json
{
  "orderId": "order_id",
  "userId": "user_id",
  "items": [
    {
      "productId": "product_id",
      "quantity": 1,
      "price": 100
    }
  ],
  "total": 100,
  "status": "processing|shipped|delivered|returned",
  "createdAt": "2026-03-05T00:00:00Z"
}
```

#### `returns`
```json
{
  "returnId": "return_id",
  "orderId": "order_id",
  "reason": "Defective",
  "status": "pending|approved|rejected"
}
```

## Security Features

### Firestore Rules
All collections are protected by Firestore Security Rules defined in `web-app/firestore.rules`:

- **Users**: Can read/update own data, admins can read all
- **Vendors**: Vendors can read/update their own, admins control
- **Products**: Approved products visible to all, vendors edit their own
- **Orders**: Users see own orders, vendors see their orders, admins see all
- **Returns**: Users manage own returns, admins control approvals

### Cloud Functions
Cloud Functions for sensitive operations:
- `approveVendor` - Admin approval of vendors
- `rejectVendor` - Admin rejection of vendors

## Common Issues & Solutions

### Port Already in Use

If you see "Port X is not open", ports may be occupied:

```bash
# Kill all node processes
Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force

# Then restart emulators
cd D:\matjark
npx firebase emulators:start --only firestore,auth
```

### Service Account Key Errors

If you see errors related to service account key:
1. Ensure the file is at `web-app/scripts/serviceAccountKey.json`
2. The file should be valid JSON from Firebase Console
3. Never share this file

### Emulator UI Not Showing Data

If the Firebase Emulator UI doesn't display data:
1. Ensure the app is connected to emulators
2. Check that emulators are still running
3. The UI updates may lag - refresh the browser

## Production Deployment

### Requirements
- **Blaze Plan**: Required for Cloud Functions in production
- **Service Account**: Generate from Firebase Console

### Deployment Steps

```bash
# 1. Build the Next.js app
cd D:\matjark\web-app
npm run build

# 2. Deploy Firestore Rules
cd D:\matjark
npx firebase deploy --only firestore:rules

# 3. Deploy Cloud Functions
npx firebase deploy --only functions

# 4. Deploy Hosting
npx firebase deploy --only hosting
```

## References

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Next.js Documentation](https://nextjs.org/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/start)

## Support

For issues or questions:
1. Check the browser console for errors (F12)
2. Check the terminal/emulator logs
3. Ensure all services are running
4. Try restarting the emulators and dev server