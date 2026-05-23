# ezctx ProGuard rules
# Без этих правил release-APK падает на старте с UnsatisfiedLinkError
# "Bad JNI version returned from JNI_OnLoad" — R8 переименовывает Java-классы,
# на которые нативный код ffmpeg-kit биндится через RegisterNatives.

# ─── ffmpeg-kit (форк antonkarpenko/ffmpeg-kit) ───
# Все классы плагина — JNI ищет их по полному имени.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.**

# ─── Flutter / JNI общее ───
# Любые методы, помеченные native — не переименовывать (биндинг по имени).
-keepclasseswithmembernames class * {
    native <methods>;
}

# Поля и методы с @Keep — не трогать.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}

# ─── flutter_secure_storage ───
# Использует Tink (Google) для шифрования — keep на всякий.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ─── super_clipboard / file_picker / path_provider ───
# Эти плагины написаны на чистом Kotlin/Dart без JNI-нативок,
# дополнительные rules не требуются.

# ─── Подавление шума ───
# Эти классы используются опционально и не всегда есть в classpath.
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn javax.annotation.**
