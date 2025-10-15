# WorkVPN ProGuard Rules
# Production code obfuscation and optimization

# Keep Application class
-keep class com.workvpn.android.WorkVPNApplication { *; }

# Keep VPN Service
-keep class com.workvpn.android.vpn.** { *; }

# Keep Models (for serialization)
-keep class com.workvpn.android.model.** { *; }

# Keep BCrypt and Spring Security
-keep class org.springframework.security.crypto.** { *; }
-dontwarn org.springframework.security.crypto.**

# Keep OkHttp for certificate pinning
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Keep Jetpack Compose
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# Keep DataStore
-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# Keep Kotlin Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep debug logging for errors and warnings
-assumenosideeffects class android.util.Log {
    public static *** e(...);
    public static *** w(...);
}

# Keep ViewModels
-keep class * extends androidx.lifecycle.ViewModel {
    <init>();
}
-keep class * extends androidx.lifecycle.AndroidViewModel {
    <init>(android.app.Application);
}

# Keep AuthManager
-keep class com.workvpn.android.auth.AuthManager { *; }

# Keep Repository classes
-keep class com.workvpn.android.repository.** { *; }

# Keep NetworkExtension components
-keep class com.workvpn.android.util.NetworkMonitor { *; }
-keep class com.workvpn.android.util.ConnectionRetryManager { *; }
-keep class com.workvpn.android.util.KillSwitch { *; }
-keep class com.workvpn.android.util.CertificatePinnerManager { *; }

# Keep OVPN Parser
-keep class com.workvpn.android.util.OVPNParser { *; }

# Optimization: Remove unused resources
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep annotations
-keepattributes *Annotation*

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Crashlytics (if added later)
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Remove debug-only code
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static void checkParameterIsNotNull(...);
    public static void checkNotNullParameter(...);
    public static void checkExpressionValueIsNotNull(...);
    public static void checkNotNullExpressionValue(...);
}
