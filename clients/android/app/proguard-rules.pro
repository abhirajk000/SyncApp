-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.compose.runtime.Composable <methods>;
}
-dontwarn okhttp3.**
-dontwarn okio.**
