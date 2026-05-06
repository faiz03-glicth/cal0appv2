import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache layer for nutrition API responses.
/// Fixed Bug #21 — SharedPreferences instance is now cached as a static
/// singleton instead of being opened on every single call.
class NutritionCacheService {
  static const Duration _cacheDuration = Duration(hours: 24);
  static const String _prefix = 'nutrition_cache_';

  // ── Singleton instance (Bug #21 fix) ──────────────────────────────────────
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Search cache ──────────────────────────────────────────────────────────

  static Future<void> saveSearch(
    String query,
    List<Map<String, dynamic>> results,
  ) async {
    final prefs = await _instance;
    final key = '$_prefix${query.toLowerCase().trim()}';

    final payload = json.encode({
      'results': results,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await prefs.setString(key, payload);
  }

  static Future<List<Map<String, dynamic>>?> getSearch(String query) async {
    final prefs = await _instance;
    final key = '$_prefix${query.toLowerCase().trim()}';
    final raw = prefs.getString(key);

    if (raw == null) return null;

    try {
      final payload = json.decode(raw);
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        payload['timestamp'] as int,
      );

      if (DateTime.now().difference(savedAt) > _cacheDuration) {
        await prefs.remove(key);
        return null;
      }

      return List<Map<String, dynamic>>.from(payload['results']);
    } catch (e) {
      return null;
    }
  }

  // ── Categories cache ──────────────────────────────────────────────────────

  static Future<void> saveCategories(List<String> categories) async {
    final prefs = await _instance;
    await prefs.setStringList('${_prefix}categories', categories);
    await prefs.setInt(
      '${_prefix}categories_ts',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<List<String>?> getCategories() async {
    final prefs = await _instance;
    final ts = prefs.getInt('${_prefix}categories_ts');

    if (ts == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(savedAt) > _cacheDuration) {
      await prefs.remove('${_prefix}categories');
      return null;
    }

    return prefs.getStringList('${_prefix}categories');
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await _instance;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
