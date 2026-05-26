import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class BarcodeCacheService {
  static const String _prefix = 'barcode_cache_v1_';
  static const Duration _ttl = Duration(days: 30); // Barcodes rarely change
  static const int _maxEntries = 200;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static String _key(String barcode) => '$_prefix$barcode';

  /// Returns cached result or null if expired/missing
  static Future<BarcodeFoodModel?> get(String barcode) async {
    try {
      final prefs = await _instance;
      final raw = prefs.getString(_key(barcode));
      if (raw == null) return null;

      final model = BarcodeFoodModel.fromJson(json.decode(raw));
      if (DateTime.now().difference(model.cachedAt) > _ttl) {
        await prefs.remove(_key(barcode)); // Evict stale
        return null;
      }
      return model;
    } catch (e) {
      LogService.error('BarcodeCacheService.get failed', e);
      return null;
    }
  }

  static Future<void> save(BarcodeFoodModel model) async {
    try {
      final prefs = await _instance;
      await prefs.setString(_key(model.barcode), json.encode(model.toJson()));
      await _evictIfNeeded(prefs);
    } catch (e) {
      LogService.error('BarcodeCacheService.save failed', e);
    }
  }

  /// Cache a "not found" barcode so we don't re-query repeatedly
  static Future<void> saveNotFound(String barcode) async {
    final placeholder = BarcodeFoodModel(
      barcode: barcode,
      productName: '',
      isVerified: false,
      cachedAt: DateTime.now(),
    );
    await save(placeholder);
  }

  static Future<bool> isNotFound(String barcode) async {
    final cached = await get(barcode);
    return cached != null && cached.productName.isEmpty;
  }

  static Future<void> _evictIfNeeded(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    if (keys.length <= _maxEntries) return;

    // Remove oldest 20 entries
    final entries = <String, DateTime>{};
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw != null) {
        try {
          final m = BarcodeFoodModel.fromJson(json.decode(raw));
          entries[key] = m.cachedAt;
        } catch (_) {}
      }
    }
    final sorted = entries.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in sorted.take(20)) {
      await prefs.remove(entry.key);
    }
  }

  static Future<void> clear() async {
    final prefs = await _instance;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
