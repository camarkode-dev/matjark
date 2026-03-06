# Flutter Performance Optimization Guide

## Build Optimizations

### Android Build Optimization
1. **Reduce APK Size:**
   ```bash
   flutter build apk --split-per-abi -v
   ```

2. **Enable R8 Minification in android/app/build.gradle:**
   ```gradle
   buildTypes {
       release {
           minifyEnabled true
           shrinkResources true
           proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
       }
   }
   ```

3. **Optimize Gradle:**
   ```gradle
   // In android/gradle.properties
   org.gradle.jvmargs=-Xmx2048m
   org.gradle.parallel=true
   org.gradle.caching=true
   ```

### Web Build Optimization
1. **Build with optimizations:**
   ```bash
   flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
   ```

2. **GZIP compression:** Enable in web server (nginx, Apache)

3. **Service Worker:** Already included in Flutter web apps

### iOS Build Optimization
1. **Enable Bitcode:**
   ```
   In Xcode: Build Settings → Enable Bitcode = YES
   ```

2. **Release Build:**
   ```bash
   flutter build ios --release
   ```

## Code-Level Optimizations

### 1. Use const Constructors
```dart
// ✅ GOOD
const SizedBox(height: 16);
const Icon(Icons.home);

// ❌ BAD
SizedBox(height: 16);
Icon(Icons.home);
```

### 2. Lazy Load Heavy Widgets
```dart
// Load heavy screens only when needed
const routes = {
  '/admin': (_) => const AdminDashboard(), // Lazy loaded
};
```

### 3. Cache Network Images
```dart
// Use CachedNetworkImage instead of Image.network
CachedNetworkImage(
  imageUrl: url,
  cacheKey: 'unique_key',
  maxHeightDiskCache: 200,
  maxWidthDiskCache: 200,
);
```

### 4. Optimize Rebuilds
```dart
// Use RepaintBoundary for complex widgets
RepaintBoundary(
  child: ExpensiveWidget(),
);

// Use const where possible
const SafeArea(
  child: SizedBox.expand(),
);
```

## Firestore Optimization

### 1. Add Indexes for Common Queries
- `products` → Filter by categoryId + isApproved
- `products` → Filter by sellerId + isApproved
- `products` → Filter by sellingPrice range

### 2. Use Pagination
```dart
// Already implemented in FirestoreService
// Load 15 products max per page
```

### 3. Enable Offline Persistence
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
);
```

## Platform-Specific Tips

### Android
- **ProGuard/R8:** Minifies code, reduces APK size by ~30%
- **Multidex:** Enable if you have > 65k methods
- **64-bit build:** Better performance on modern devices
- **Gradle build cache:** Speeds up subsequent builds

### Web
- **Tree shaking:** Removes unused code, reduces bundle by ~40%
- **Code splitting:** Automatically done by dart2js
- **Preload assets:** Use precacheImages() for critical images
- **Compress static files:** Use gzip on web server

### iOS
- **Bitcode:** Allows Apple to optimize for specific devices
- **iOS 14+:** Better performance and features
- **Crash reporting:** Use Crashlytics for monitoring

## Environment Variables for Build

Add this to pubspec.yaml section or use flutter run/build:
```bash
flutter run --dart-define=ENABLE_ANALYTICS=false
flutter run --dart-define=ENABLE_FIREBASE_ANALYTICS=false
```

## Monitoring Performance

### Use DevTools
```bash
flutter pub global activate devtools
devtools
# Or in Android Studio: Tools → Flutter → Open DevTools
```

### Key Metrics to Monitor
- **Frame rate:** Should stay at 60fps (120fps on high refresh rate)
- **Memory usage:** Watch for memory leaks
- **CPU usage:** High CPU indicates inefficient rendering
- **Startup time:** Target < 2 seconds

## Quick Checklist

- [ ] Use `const` constructors wherever possible
- [ ] Implement lazy loading for heavy screens
- [ ] Cache network images
- [ ] Enable ProGuard/R8 for Android
- [ ] Use image optimization (resize before upload)
- [ ] Implement pagination in lists
- [ ] Clear cached data on logout
- [ ] Use RepaintBoundary for expensive widgets
- [ ] Monitor app with Flutter DevTools
- [ ] Test on actual devices, not just emulator

## Expected Performance Improvements

After implementing these optimizations:
- **APK size:** Reduced by 30-40%
- **App startup:** 20-30% faster
- **List scrolling:** Smooth 60fps
- **Memory usage:** 15-25% reduction
- **Network requests:** Reduced by 40-50% with caching
