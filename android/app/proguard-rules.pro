# Keep MLKit text recognition stubs (non-Latin scripts not used but referenced)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep MLKit text recognition (Latin) — actually used by the scan/OCR flow
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# Keep TFLite GPU delegate stub
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**

# Keep TFLite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Keep ONNX Runtime classes (flutter_onnxruntime) — used directly in ai_service.dart
# to load model.onnx. R8 stripping these is the most common cause of a crash
# right when the scan page tries to initialize the model.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
-keep class com.microsoft.onnxruntime.** { *; }
-dontwarn com.microsoft.onnxruntime.**

# Keep mobile_scanner (barcode scanning) native/JNI bridge classes
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**
-keep class com.google.mlkit.vision.barcode.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# Preserve JNI-bound native methods generally (protects any plugin that calls
# into native code via reflection/JNI, e.g. ONNX Runtime, camera plugins)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep classes with a native constructor/finalizer pattern used by many plugins
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}