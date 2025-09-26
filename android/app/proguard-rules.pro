# =================================================================================
# REGRAS DE PROGUARD/R8 PARA APLICATIVO FLUTTER - VERSÃO ROBUSTA
# =================================================================================

# --- REGRAS GENÉRICAS PARA FLUTTER ---
# Mantém as classes principais da engine do Flutter para evitar quebras.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.embedding.engine.plugins.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# --- REGRAS PARA FIREBASE (Essencial para Auth, Firestore, etc.) ---
# Mantém todas as classes do Firebase e serviços do Google Play.
# A ofuscação aqui pode quebrar a autenticação e a comunicação com os serviços.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepnames class com.google.android.gms.common.api.internal.IStatusCallback
-keep class com.google.android.gms.common.api.Status { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- REGRAS PARA REDE (OkHttp/Okio) - MUITO IMPORTANTE! ---
# A maioria dos pacotes de rede (http, dio, firebase) usa OkHttp por baixo dos panos.
# A ofuscação dessas classes é uma causa comum de falhas de rede em modo Release.
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn org.conscrypt.**
-dontwarn okhttp3.**
-dontwarn okio.**

# --- REGRAS PARA SERIALIZAÇÃO (GSON / Jackson) ---
# Mantém anotações usadas por bibliotecas de serialização JSON como GSON e Jackson,
# que podem ser usadas por plugins de forma transitiva.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.fasterxml.jackson.annotation.JsonProperty <fields>;
}
-keep @androidx.annotation.Keep class *
-keep class com.google.gson.examples.android.model.** { *; }

# --- REGRAS ADICIONAIS DE COMPATIBILIDADE ---
# Mantém classes de exceção públicas.
-keep public class * extends java.lang.Exception

# Mantém a classe Unsafe, usada por algumas bibliotecas de baixo nível.
-keep class sun.misc.Unsafe { *; }

# Fim das regras.
