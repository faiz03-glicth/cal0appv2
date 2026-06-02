import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfig {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // No KaloriAPI key needed — OFF is free and open.
  // Keep getters as empty strings so any lingering references don't crash.
  static String get apiKey => '';
  static String get baseUrl => '';

  static Future<void> init() async {
    // Nothing to initialise for OpenFoodFacts.
    if (kDebugMode) {
      debugPrint('[SecureConfig] init — KaloriAPI removed, OFF needs no key');
    }
  }

  static Future<void> clear() async {
    await _storage.deleteAll();
  }
}
