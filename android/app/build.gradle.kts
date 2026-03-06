plugins {
    id("com.android.application")
    id("kotlin-android")
    // apply Google services plugin at bottom instead of here
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.matjark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.matjark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for apps with > 65k methods
        multiDexEnabled = false  // Temporarily disable for bundle build
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Performance optimizations - temporarily disabled for bundle build
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // Performance: Split APK per ABI for smaller downloads
    splits {
        abi {
            isEnable = true  // Re-enable for APK builds
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true // Also generate a universal APK
        }
    }

    // Add the Google Services JSON file if necessary
    // googleServices { enableCrashlytics = true }
}

flutter {
    source = "../.."
}

// Firebase dependencies
dependencies {
    // Import the Firebase BoM to manage versions centrally
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

    // Add the Firebase products you need
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-messaging")
    // etc.
}

// Apply the Google Services plugin to enable Firebase tasks
apply(plugin = "com.google.gms.google-services")
