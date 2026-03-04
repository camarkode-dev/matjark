# متجرك (Matjark)

Multi-vendor marketplace Flutter application built as a bilingual Arabic/English app.

### Overview

This repository contains the initial scaffold for the project described in the specification:
- Roles: Customer, Seller, Dropshipping Supplier, Admin
- Firebase backend (Authentication, Firestore, Storage, Functions)
- Full dropshipping workflow with supplier integration
- Commission management, order tracking, notifications
- Arabic (RTL) and English localization with instant language switch
- High‑performance design, lazy loading, and modular architecture

### Setup

1. **Prerequisites**
   - Flutter SDK (>=3.10)
   - Dart SDK (comes with Flutter)
   - Firebase CLI and FlutterFire CLI
   - An Android/iOS device or emulator

2. **Install dependencies**
   ```bash
   flutter pub get
   ```
   > 🔌 Internet connectivity is required to fetch packages.

3. **Configure Firebase**
   ```bash
   flutterfire configure
   ```
   This will generate `lib/firebase_options.dart` with project-specific options.

4. **Run the app**
   ```bash
   flutter run
   ```

### Structure

- `lib/` – main source code
  - `core/` constants, theme, helpers
  - `models/` data classes
  - `providers/` state managers (e.g. role, auth)
  - `services/` Firebase and network logic
  - `screens/` UI pages grouped by role
  - `widgets/` reusable components
- `assets/translations/` localization JSON files
- `firestore.rules` – example Firestore security rules for RBAC
- `functions/` – Cloud Functions sample (commission, notifications)
- `functions/package.json` – dependencies for functions


> 🚀 The foundation is in place; next steps involve implementing the detailed features outlined in the client requirements.

