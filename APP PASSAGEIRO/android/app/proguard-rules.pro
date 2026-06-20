# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio / OkHttp
-keep class com.squareup.okhttp3.** { *; }
-keep interface com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# local_auth / biometric
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# mobile_scanner / zxing / mlkit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }
