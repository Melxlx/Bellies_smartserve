# R8 / Proguard rules for Bellies SmartServe

# ML Kit Text Recognition optional language packs
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
