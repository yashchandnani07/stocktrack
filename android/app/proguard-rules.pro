# ── Stripe (pre-existing) ────────────────────────────────────────────────────
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-keep class com.stripe.** { *; }

# ── Supabase / Ktor / OkHttp ─────────────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ── Kotlin coroutines ────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ── Kotlin serialization (used by Supabase) ──────────────────────────────────
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class **$$serializer {
    static **$$serializer INSTANCE;
}
-keep @kotlinx.serialization.Serializable class * { *; }

# ── Kotlin reflection (used by Supabase/Ktor internally) ────────────────────
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class ** {
    @kotlin.jvm.JvmStatic *;
    @kotlin.jvm.JvmField *;
}

# ── Ktor engine (CIO / Android) ──────────────────────────────────────────────
-keep class io.ktor.client.engine.** { *; }
-keep class io.ktor.client.plugins.** { *; }
-keep class io.ktor.serialization.** { *; }
-dontwarn io.ktor.client.engine.**

# ── Kotlinx serialization (extended rules for Supabase models) ───────────────
-keepclassmembers @kotlinx.serialization.Serializable class * {
    static ** Companion;
    static ** serializer(...);
    <fields>;
}
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# ── Prevent R8 from removing anonymous classes used by coroutines ────────────
-keep class kotlin.coroutines.** { *; }
-dontwarn kotlin.coroutines.**

# ── AndroidX / Lifecycle (used by Flutter embedding) ────────────────────────
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# ── PDF / Printing package ───────────────────────────────────────────────────
-keep class com.example.printing.** { *; }
-dontwarn com.example.printing.**

# ── File Picker ──────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# ── Flutter / General ────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Prevent stripping of classes used via reflection ────────────────────────
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception