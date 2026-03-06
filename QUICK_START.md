# Matjark - Quick Start Guide

## 🚀 Fast Setup (5 minutes)

### Prerequisites
- Node.js 18+ installed
- Git installed
- Visual Studio Code (optional but recommended)

### Step 1: Download Service Account Key

1. Go to https://console.firebase.google.com/project/matjark-7ebc7/settings/serviceaccounts/adminsdk
2. Click **"Generate new private key"**
3. Save the file as `serviceAccountKey.json` in `web-app/scripts/` folder

### Step 2: Start Everything

**Terminal 1 - Firebase Emulators:**
```bash
cd D:\matjark
npx firebase emulators:start --only firestore,auth
```

**Terminal 2 - Next.js App:**
```bash
cd D:\matjark\web-app
npm run dev
```

### Step 3: Create Admin Account

**Terminal 3:**
```bash
cd D:\matjark\web-app/scripts
node create-admin.js admin@example.com password123 "Admin Name"
```

### Step 4: Access the App

- **App**: http://localhost:3000
- **Login**: admin@example.com / password123
- **Admin Dashboard**: http://localhost:3000/admin

## 📝 Project Structure

```
matjark/
├── web-app/                    # Next.js Frontend
│   ├── src/
│   │   ├── app/               # Pages & routes
│   │   ├── components/        # React components
│   │   ├── hooks/             # Custom hooks (useAuth)
│   │   ├── lib/               # Firebase config
│   │   └── types/             # TypeScript types
│   ├── functions/             # Cloud Functions
│   ├── scripts/               # Utilities
│   ├── firestore.rules        # Security rules
│   ├── .env.local            # Environment variables
│   └── package.json          # Dependencies
├── firebase.json             # Firebase config
├── firestore.indexes.json    # Firestore indexes
└── README.md                # Full documentation
```

## 🛡️ Security Architecture

### Firestore Rules
- **Admin**: Full access to all data
- **Vendor**: Manage only their own products
- **User**: Read approved products only
- **Authentication**: Required for all operations

### Custom Claims
```typescript
{
  admin: true    // User is admin
  vendor: true   // User is verified vendor
}
```

## 🎯 Main Features

### User Authentication
- Email/Password login and registration
- Role-based access control (User/Vendor/Admin)
- Multiple user profiles supported

### Admin Dashboard
- User statistics
- Vendor approvals
- Product reviews
- Order management
- Return management

### Vendor Portal
- Product management
- Store settings
- Order tracking
- Customer ratings

### Customer Portal
- Browse products
- Place orders
- Track shipments
- Return products

## 📊 Database Schema

### Collections

**users** - User accounts
```json
{
  "uid": "user_id",
  "name": "John Doe",
  "email": "john@example.com",
  "role": "user|vendor|admin",
  "status": "active|pending|banned",
  "createdAt": "ISO 8601 date"
}
```

**vendors** - Store information
```json
{
  "uid": "vendor_uid",
  "storeName": "My Store",
  "approved": true,
  "createdAt": "ISO 8601 date"
}
```

**products** - Product listings
```json
{
  "productId": "prod_123",
  "name": "Product Name",
  "price": 99.99,
  "vendorId": "vendor_uid",
  "status": "pending|approved|rejected",
  "description": "...",
  "createdAt": "ISO 8601 date"
}
```

**orders** - Customer orders
```json
{
  "orderId": "ord_123",
  "userId": "user_uid",
  "items": [
    {
      "productId": "prod_123",
      "quantity": 2,
      "price": 99.99
    }
  ],
  "total": 199.98,
  "status": "processing|shipped|delivered|returned",
  "createdAt": "ISO 8601 date"
}
```

**returns** - Returns management
```json
{
  "returnId": "ret_123",
  "orderId": "ord_123",
  "reason": "Defective product",
  "status": "pending|approved|rejected"
}
```

## 🔌 API Endpoints

### Cloud Functions

**Approve Vendor**
```javascript
const approveVendor = firebase.functions().httpsCallable('approveVendor');
await approveVendor({ vendorId: 'vendor_uid' });
```

**Reject Vendor**
```javascript
const rejectVendor = firebase.functions().httpsCallable('rejectVendor');
await rejectVendor({ vendorId: 'vendor_uid' });
```

## 🧪 Testing

### Test User Types

1. **Admin Account** (created by you)
   - Full access to all features
   - Can approve vendors
   - Can manage users and products

2. **Regular User** (create via register)
   - Can browse products
   - Can place orders
   - Can manage own profile

3. **Vendor Account** (create via register)
   - Can manage products
   - Can see own orders
   - Pending admin approval

## 💾 Environment Setup

File: `web-app/.env.local`

```env
# Firebase configuration
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=matjark-7ebc7.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=matjark-7ebc7
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=matjark-7ebc7.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

## 🚢 Production Deployment

### Requirements
- Blaze Plan (pay-as-you-go) - required for Cloud Functions
- Custom domain (optional)

### Deployment Commands

```bash
# Login to Firebase
firebase login

# Build the app
npm run build

# Deploy Firestore rules
npm run deploy:rules

# Deploy Cloud Functions
npm run deploy:functions

# Deploy everything
npm run deploy
```

## 🐛 Troubleshooting

### Issue: "Port already in use"
```bash
# Kill existing processes
Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force
```

### Issue: "Firestore rules invalid"
- Check syntax in `web-app/firestore.rules`
- Ensure all functions are properly defined
- Test with emulator first

### Issue: "Cloud Functions deployment failed"
- Need Blaze Plan for production deployment
- Use emulators for local testing
- Check function syntax and dependencies

### Issue: "Authentication fails"
- Ensure emulators are running
- Check `.env.local` configuration
- Clear browser cookies and try again

## 📚 Useful Commands

```bash
# Development
npm run dev           # Start dev server
npm run emulators     # Start Firebase emulators
npm run build         # Build for production

# Admin
npm run admin:create  # Create admin account
firebase login        # Login to Firebase

# Deployment
npm run deploy:rules  # Deploy Firestore rules
npm run deploy:functions # Deploy Cloud Functions
npm run deploy        # Deploy everything
```

## 📖 Documentation Files

- [DEVELOPMENT_SETUP.md](./DEVELOPMENT_SETUP.md) - Detailed setup guide
- [README.md](./README.md) - Full project documentation
- [Firestore Rules](./firestore.rules) - Security rules definition

## 🤝 Next Steps

1. ✅ Start emulators and dev server
2. ✅ Create admin account
3. ✅ Log in and explore admin dashboard
4. ✅ Create test vendor account
5. ✅ Create products and test ordering flow
6. ✅ Review Firestore to understand data structure

## 🎓 Learning Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Next.js Guide](https://nextjs.org/docs)
- [Firestore Security Rules Best Practices](https://firebase.google.com/docs/firestore/security/rules-structure)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

## 📞 Support

If you encounter any issues:
1. Check the browser console (F12) for errors
2. Check terminal logs for Firebase errors
3. Ensure all prerequisites are installed
4. Restart the emulators and dev server
5. Check the documentation files for more details

---

**Happy developing! 🎉**