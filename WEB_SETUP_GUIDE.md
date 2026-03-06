# Web Platform Setup Guide

## Google Sign-In Configuration for Web

The Flutter web app requires a Google OAuth 2.0 Client ID for Google Sign-In to work properly.

### Steps to Set Up:

#### 1. Get Your Google Client ID
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services** > **Credentials**
4. Create a new OAuth 2.0 Client ID (Web application type) if you don't have one
5. Copy the Client ID (it will look like: `xxxxxxxxxxxx.apps.googleusercontent.com`)

#### 2. Update web/index.html

Replace `YOUR_GOOGLE_WEB_CLIENT_ID` in `web/index.html` with your actual Client ID:

```html
<meta name="google-signin-client_id" content="YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com">
```

Example:
```html
<meta name="google-signin-client_id" content="123456789.apps.googleusercontent.com">
```

#### 3. Configure Authorized JavaScript Origins (Important!)

In Google Cloud Console:
1. Go to **APIs & Services** > **Credentials**
2. Click on your OAuth 2.0 Client ID
3. Add your development URLs to **Authorized JavaScript origins**:
   - `http://localhost:8080` (for local development)
   - `http://localhost` (alternative)
   - `http://127.0.0.1:8080`
   - Your production domain when deploying

#### 4. Configure Authorized Redirect URIs

Add to **Authorized redirect URIs**:
- `http://localhost:8080/` (for local development)
- Your production URL when deploying

#### 5. Update Firestore Rules

The current Firestore rules require users to be signed in. Make sure to:
1. Sign in with a valid Google account
2. Ensure the signed-in user has an `isApproved: true` status in their profile

### Testing Locally

Run the web app with:

```bash
flutter run -d chrome
```

Or with a specific port:

```bash
flutter run -d chrome --web-port=8080
```

### Firestore Permission Errors

If you see `[cloud_firestore/permission-denied]` errors:
1. Make sure you're **signed in** to the app
2. Check that your user document exists in Firestore with the correct permissions
3. Verify Firestore rules allow authenticated access

### Environment Variables (Optional)

For better security in production, you can use environment variables:

```bash
# For local development
flutter run -d chrome --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
```

Or for release build:

```bash
flutter build web --release --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
```
