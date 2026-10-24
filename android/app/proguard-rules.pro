# R8 / ProGuard rules for release builds (isMinifyEnabled = true).
# The Flutter Gradle plugin already adds the rules the Flutter engine needs;
# these cover what it does not.

# Flutter embedding and plugin registrants are loaded reflectively.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# The Flutter engine references Play Core for deferred components; the app does
# not use them, so the classes are absent and that is fine.
-dontwarn com.google.android.play.core.**

# flutter_secure_storage encrypts with Tink. Tink ships consumer rules; these
# silence warnings about compile-time-only annotations it references.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

# Keep line numbers in crash reports (upload mapping.txt to the crash reporter).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
