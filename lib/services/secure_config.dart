import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfig {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyApiKey = 'kal_api_key';
  static const _keyBaseUrl = 'kal_base_url';

  // Call once at app startup in main.dart
  static Future<void> init() async {
    final existing = await _storage.read(key: _keyApiKey);

    // Only write to secure storage if not already stored
    if (existing == null) {
      final apiKey = dotenv.env['ACTIVATE_API_KEY'] ?? '';
      final baseUrl = dotenv.env['FOOD_API_URL'] ?? '';

      if (apiKey.isEmpty) {
        throw Exception('KAL_API_KEY not found in .env');
      }

      await _storage.write(key: _keyApiKey, value: apiKey);
      await _storage.write(key: _keyBaseUrl, value: baseUrl);
    }
  }

  static Future<String> get apiKey async =>
      await _storage.read(key: _keyApiKey) ?? '';

  static Future<String> get baseUrl async =>
      await _storage.read(key: _keyBaseUrl) ?? 'https://api.kalori-api.my';

  // Call when user logs out to wipe keys from device
  static Future<void> clear() async => await _storage.deleteAll();
}
