# Matjark - Multi-Vendor Marketplace

A secure, scalable multi-vendor marketplace built with Next.js, Firebase, and Firestore.

## Features

- **Role-based Access Control**: User, Vendor, Admin roles with Firebase Custom Claims
- **Secure Firestore Rules**: Comprehensive security rules preventing unauthorized access
- **Admin Dashboard**: Manage users, vendors, products, and orders
- **Vendor Management**: Approve/reject vendor applications
- **Product Management**: Vendors can manage their own products
- **Order System**: Complete order lifecycle management
- **Return System**: Handle product returns

## Tech Stack

- **Frontend**: Next.js 14 with TypeScript
- **Backend**: Firebase (Authentication, Firestore, Cloud Functions)
- **Styling**: Tailwind CSS
- **Deployment**: Vercel

## Project Structure

```
web-app/
├── src/
│   ├── app/                 # Next.js app router
│   │   ├── admin/          # Admin dashboard pages
│   │   ├── auth/           # Authentication pages
│   │   └── ...
│   ├── components/         # Reusable components
│   ├── hooks/             # Custom React hooks
│   ├── lib/               # Firebase config and utilities
│   └── types/             # TypeScript type definitions
├── functions/             # Firebase Cloud Functions
├── scripts/               # Utility scripts
└── firestore.rules       # Firestore security rules
```

## Setup Instructions

### 1. Firebase Setup

1. Create a new Firebase project at https://console.firebase.google.com/
2. Enable Authentication with Email/Password provider
3. Enable Firestore Database
4. Create a service account key and download it as `serviceAccountKey.json` in the `scripts` folder

### 2. Environment Variables

Create a `.env.local` file in the `web-app` directory:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

### 3. Install Dependencies

```bash
cd web-app
npm install
cd ../functions
npm install
```

### 4. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 5. Deploy Cloud Functions

```bash
cd functions
firebase deploy --only functions
```

### 6. Add Admin User

Run the admin setup script:

```bash
cd scripts
node add-admin.js <admin-user-uid>
```

## Security Features

- **Custom Claims**: Admin and vendor roles stored in Firebase Auth tokens
- **Firestore Rules**: Granular permissions based on user roles
- **Server-side Validation**: Cloud Functions for sensitive operations
- **Input Validation**: Client and server-side validation

## Usage

### Starting the Development Server

```bash
cd web-app
npm run dev
```

### Building for Production

```bash
npm run build
npm start
```

## API Reference

### Cloud Functions

#### `approveVendor`
Approves a vendor application.

**Parameters:**
- `vendorId` (string): The UID of the vendor to approve

**Returns:** Success message

#### `rejectVendor`
Rejects a vendor application.

**Parameters:**
- `vendorId` (string): The UID of the vendor to reject

**Returns:** Success message

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.
