# ProGuard rules for Matjark app
# Minimal rules to avoid dex issues

# Keep Flutter classes
-keep class io.flutter.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep app classes
-keep class com.example.matjark.** { *; }
# ============================
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-keepattributes *Annotation*

# ============================
# Keep view constructors for inflation
# ============================
-keepclasseswithmembers class * {
  public <init>(android.content.Context, android.util.AttributeSet);
}

# ============================
# Keep Parcelable classes
# ============================
-keep interface android.os.Parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# ============================
# Keep Serializable classes
# ============================
-keepclassmembers class * implements java.io.Serializable {
  static final long serialVersionUID;
  private static final java.io.ObjectStreamField[] serialPersistentFields;
  private void writeObject(java.io.ObjectOutputStream);
  private void readObject(java.io.ObjectInputStream);
  java.lang.Object writeReplace();
  java.lang.Object readResolve();
}

# ============================
# Remove unused classes
# ============================
-dontwarn androidx.annotation.**
-dontwarn com.google.**
-dontwarn kotlin.**

# ============================
# Preserve line numbers for crash reports
# ============================
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
