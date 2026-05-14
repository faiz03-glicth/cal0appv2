// lib/services/auth/secure_config.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfig {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyApiKey = 'kal_api_key';
  static const _keyBaseUrl = 'kal_base_url';

  // In-memory cache — set once during init, reused everywhere
  static String _cachedApiKey = '';
  static String _cachedBaseUrl = 'https://api.kalori-api.my';

  /// Called once in main.dart before runApp.
  /// Loads from .env in debug, reads from secure storage in release.
  static Future<void> init() async {
    final apiKey = dotenv.env['ACTIVATE_API_KEY'] ?? '';
    final baseUrl = dotenv.env['FOOD_API_URL'] ?? 'https://api.kalori-api.my';

    if (apiKey.isEmpty) {
      throw Exception('ACTIVATE_API_KEY not found in crypt.env');
    }

    if (kDebugMode) {
      // Always refresh from .env in debug (branch switching safe)
      await _storage.write(key: _keyApiKey, value: apiKey);
      await _storage.write(key: _keyBaseUrl, value: baseUrl);
    } else {
      // Release: write once, read back
      final existing = await _storage.read(key: _keyApiKey);
      if (existing == null) {
        await _storage.write(key: _keyApiKey, value: apiKey);
        await _storage.write(key: _keyBaseUrl, value: baseUrl);
      }
    }

    _cachedApiKey = await _storage.read(key: _keyApiKey) ?? '';
    _cachedBaseUrl =
        await _storage.read(key: _keyBaseUrl) ?? 'https://api.kalori-api.my';
  }

  static String get apiKey => _cachedApiKey;
  static String get baseUrl => _cachedBaseUrl;

  /// Called on sign-out to wipe device storage and clear cache
  static Future<void> clear() async {
    await _storage.deleteAll();
    _cachedApiKey = '';
    _cachedBaseUrl = 'https://api.kalori-api.my';
  }
}
