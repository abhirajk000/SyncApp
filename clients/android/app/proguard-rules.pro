-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# App code
-keep class com.syncbridge.android.** { *; }

# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# org.json (used by ApiClient)
-keepclassmembers class * {
    public <init>(org.json.JSONObject);
}

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.** {
    volatile <fields>;
}

# Compose
-keepclassmembers class * {
    @androidx.compose.runtime.Composable <methods>;
}

# ZXing QR scanner
-keep class com.journeyapps.barcodescanner.** { *; }
-keep class com.google.zxing.** { *; }

# ViewModels
-keep class * extends androidx.lifecycle.ViewModel {
    <init>(...);
}
