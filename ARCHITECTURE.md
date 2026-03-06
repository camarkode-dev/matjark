# Matjark Architecture & System Design

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Browser    │  │   Browser    │  │   Browser    │       │
│  │   (Admin)    │  │   (Vendor)   │  │   (User)     │       │
│  └───────┬──────┘  └───────┬──────┘  └───────┬──────┘       │
│          │                 │                 │               │
│          └─────────────────┴─────────────────┘               │
│                     │                                        │
│              Next.js Frontend (Port 3000)                  │
│              ├─ Authentication System                       │
│              ├─ Admin Dashboard                             │
│              ├─ Vendor Portal                               │
│              └─ Customer Portal                             │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                         │
       ┌─────────────────┴──────────────────┐
       │                                    │
       ▼                                    ▼
┌──────────────────────┐        ┌──────────────────────┐
│ Firebase Auth        │        │ Firestore Database   │
│ (Port 9099)          │        │ (Port 9090)          │
│ ├─ Email/Password    │        │ Collections:         │
│ ├─ Custom Claims     │        │ ├─ users            │
│ │  - Admin           │        │ ├─ vendors          │
│ │  - Vendor          │        │ ├─ products         │
│ └─ ID Tokens         │        │ ├─ orders           │
│                      │        │ └─ returns          │
└──────────────────────┘        └──────────────────────┘
                                         │
                                         ▼
                        ┌──────────────────────────┐
                        │  Firestore Rules         │
                        │  (Security Layer)        │
                        │ ├─ Admin: Full Access    │
                        │ ├─ Vendor: Own Products  │
                        │ ├─ User: Read Only       │
                        │ └─ Auth Required         │
                        └──────────────────────────┘
       │
       ▼
┌──────────────────────┐
│ Cloud Functions      │
│ (Backend Logic)      │
│ ├─ approveVendor    │
│ └─ rejectVendor     │
└──────────────────────┘
```

## 🗄️ Database Schema

### Collections Overview

```
matjark-7ebc7 (Firestore Database)
├── users/                          [Collection]
│   ├── {uid}                       [Document]
│   │   ├── uid: string
│   │   ├── name: string
│   │   ├── email: string
│   │   ├── role: 'user'|'vendor'|'admin'
│   │   ├── status: 'active'|'pending'|'banned'
│   │   └── createdAt: timestamp
│   └── ...
│
├── vendors/                        [Collection]
│   ├── {vendorId}                  [Document]
│   │   ├── uid: string (references users/{uid})
│   │   ├── storeName: string
│   │   ├── approved: boolean
│   │   └── createdAt: timestamp
│   └── ...
│
├── products/                       [Collection]
│   ├── {productId}                 [Document]
│   │   ├── productId: string
│   │   ├── name: string
│   │   ├── description: string
│   │   ├── price: number
│   │   ├── vendorId: string (references vendors/{vendorId})
│   │   ├── status: 'pending'|'approved'|'rejected'
│   │   └── createdAt: timestamp
│   └── ...
│
├── orders/                         [Collection]
│   ├── {orderId}                   [Document]
│   │   ├── orderId: string
│   │   ├── userId: string (references users/{uid})
│   │   ├── items: [
│   │   │   {
│   │   │     productId: string,
│   │   │     quantity: number,
│   │   │     price: number
│   │   │   }
│   │   │ ]
│   │   ├── total: number
│   │   ├── status: 'processing'|'shipped'|'delivered'|'returned'
│   │   └── createdAt: timestamp
│   └── ...
│
└── returns/                        [Collection]
    ├── {returnId}                  [Document]
    │   ├── returnId: string
    │   ├── orderId: string (references orders/{orderId})
    │   ├── userId: string
    │   ├── reason: string
    │   ├── status: 'pending'|'approved'|'rejected'
    │   └── createdAt: timestamp
    └── ...
```

## 🔐 Security Model

### Role-Based Access Control (RBAC)

```
Roles:
├── Admin
│   ├── Full read/write access to all collections
│   ├── Approve/reject vendors
│   ├── Approve/reject products
│   ├── Manage returns
│   ├── Delete users
│   └── Delete products
│
├── Vendor
│   ├── Read own profile
│   ├── Create/update/delete own products
│   ├── Read approved vendor profile
│   └── View own orders
│
└── User
    ├── Read own profile
    ├── Read approved products
    ├── Create orders
    └── View own orders

Custom Claims (JWT):
├── admin: true        (Admin role)
└── vendor: true       (Vendor role)
```

### Firestore Security Rules Flow

```
Request → Auth Check → Role Check → Data Check → Allow/Deny

Examples:

1. User tries to read product:
   ✓ Request.auth != null                     → Authenticated
   → Check product.status == 'approved'       → Allowed
   
2. Vendor tries to update product:
   ✓ Request.auth != null                     → Authenticated
   ✓ User.role == 'vendor'                    → Is vendor
   ✓ product.vendorId == request.auth.uid     → Owner
   → Allow update
   
3. User tries to delete order:
   ✓ Request.auth != null                     → Authenticated
   → order.userId != request.auth.uid         → Not owner
   → Deny (unless admin)
```

## 🔄 Data Flow Diagrams

### User Registration Flow

```
User fills registration form
        ↓
Frontend validates input
        ↓
Creates Firebase Auth user (createUserWithEmailAndPassword)
        ↓
Creates Firestore user document
        ↓
If vendor:
  └─→ Creates vendors/{uid} document with approved=false
        ↓
Email confirmation (optional)
        ↓
Redirect to login
```

### Admin Approving Vendor Flow

```
Admin views pending vendors (Firestore query)
        ↓
Admin clicks "Approve"
        ↓
Cloud Function: approveVendor triggered
        ↓
Updates vendors/{uid}.approved = true
        ↓
Updates users/{uid}.status = 'active'
        ↓
Sets Firebase Auth custom claim: vendor=true
        ↓
Vendor receives notification
        ↓
Vendor can now create products
```

### Customer Ordering Flow

```
Customer selects products
        ↓
Creates order in Firestore
        ↓
Frontend submits to Firestore:
  └─→ orders/{orderId}
  └─→ items, total, status='processing'
        ↓
Vendor sees order notification
        ↓
Vendor updates status: 'shipped'
        ↓
Customer sees status update (real-time)
        ↓
Customer marks as 'delivered'
        ↓
Option to request return
```

### Return Management Flow

```
Customer requests return
        ↓
Creates returns/{returnId} document
        ↓
Vendor sees return request
        ↓
Vendor reviews reason
        ↓
Vendor approves/rejects
        ↓
If approved:
  └─→ Updates order.status = 'returned'
  └─→ Process refund
        ↓
Customer notified of result
```

## 📱 Frontend Component Hierarchy

```
App/
├── AuthProvider (Context)
│   ├── useAuth hook
│   ├── user state
│   ├── userData state
│   └── loading state
│
├── Root Layout
│   ├── Navigation
│   ├── Routes
│   └── Footer
│
├── Public Routes
│   ├── /                    (Home)
│   ├── /auth/login         (Login)
│   └── /auth/register      (Registration)
│
├── Protected Routes (Authenticated)
│   ├── /dashboard          (User Dashboard)
│   ├── /admin              (Admin Dashboard)
│   │   ├── Statistics      (Users, Vendors, Products, Orders)
│   │   ├── Vendors         (Approve/Reject)
│   │   ├── Products        (Review/Approve)
│   │   ├── Orders          (Manage)
│   │   └── Returns         (Manage)
│   │
│   └── /vendor             (Vendor Portal)
│       ├── Store           (Store Settings)
│       ├── Products        (Create/Edit)
│       ├── Orders          (View/Update)
│       └── Analytics       (Sales, Stats)
│
└── Error Handling
    ├── 404 Not Found
    ├── 403 Forbidden
    └── 500 Server Error
```

## 🔗 API Endpoints (Cloud Functions)

```
GET /                          ✓ Public (Firestore read)
POST /users                    ✓ Auth required (Firestore write)
GET /users/{uid}               ✓ Auth required (self/admin)
PUT /users/{uid}               ✓ Auth required (self/admin)

GET /vendors                   ✓ Auth required (admin/vendor)
POST /vendors/{uid}/approve    ✓ Admin only (Cloud Function)
POST /vendors/{uid}/reject     ✓ Admin only (Cloud Function)

GET /products                  ✓ Public (approved only)
POST /products                 ✓ Vendor required
PUT /products/{id}             ✓ Vendor (own only)
DELETE /products/{id}          ✓ Admin only

GET /orders                    ✓ Auth required (own/vendor/admin)
POST /orders                   ✓ User required
PUT /orders/{id}               ✓ Auth required (participant only)

GET /returns                   ✓ Auth required
POST /returns                  ✓ User required
PUT /returns/{id}              ✓ Auth required (participant only)
```

## 📊 Scalability Considerations

### For 100,000+ Users

#### Database Optimization
- ✅ Collections properly indexed
- ✅ Document structure normalized
- ✅ No nested subcollections (flat structure)
- ✅ Composite indexes for complex queries

#### Performance
- ✅ Firestore auto-scales
- ✅ Read/write operations optimized
- ✅ Pagination for large result sets
- ✅ Real-time listeners only where needed

#### Security
- ✅ Row-level security implemented
- ✅ Rate limiting via Cloud Functions
- ✅ Input validation on all operations
- ✅ No direct client-side database access

#### Deployment
- ✅ CDN for static assets (Hosting)
- ✅ Cloud Functions auto-scale
- ✅ Firestore handles concurrent users
- ✅ Firebase Admin SDK for bulk operations

### Capacity Planning

```
Current Limit    →    Action Required
─────────────────    ─────────────────────────────
1,000 users         Monitor usage
10,000 users        Consider database optimization
50,000 users        Consider Cloud Functions scaling
100,000+ users      Evaluate Realtime Database option
                    Consider separate database for analytics
```

## 🚀 Deployment Architecture

### Development
```
Local Machine
├── Next.js Dev Server (localhost:3000)
├── Firebase Emulators (localhost:9090, 9099)
└── Local Firestore data
```

### Production
```
Firebase Hosting
├── Next.js Static Build
├── CDN Distribution (Google CDN)
└── SSL/TLS Encryption

Firebase Authentication
├── Email/Password auth
├── Custom claims
└── ID token verification

Firestore Database
├── Multi-region replication
├── Automatic backups
└── Point-in-time recovery

Cloud Functions
├── Auto-scaling instances
├── 3rd party integrations
└── Background job processing
```

## 🔄 Update & Monitoring

### Key Metrics to Monitor

```
Authentication
├── Login success rate
├── Registration completion rate
└── Account lockouts

Database
├── Read/write operations/sec
├── Data size growth
└── Query performance

Vendors
├── Active vendors count
├── Average products per vendor
└── Vendor approval time

Orders
├── Daily order count
├── Average order value
└── Return rate

System Health
├── Error rate
├── API response time
├── Uptime percentage
```

## 📖 References

- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Scalability Guide](https://firebase.google.com/docs/firestore/best-practices#scale)
- [Authentication Guide](https://firebase.google.com/docs/auth)
- [Cloud Functions](https://firebase.google.com/docs/functions)