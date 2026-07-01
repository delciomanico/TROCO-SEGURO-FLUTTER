# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Dio / OkHttp
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# local_auth / biometrics
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# mobile_scanner / ZXing / MLKit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**

# Firebase / FCM
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Gson (used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
