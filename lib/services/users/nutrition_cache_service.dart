import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionCacheService {
  static const Duration _cacheDuration = Duration(hours: 24);
  static const String _prefix = 'nutrition_cache_';

  // ── Save search results to cache ──────────────────────────────────────────
  static Future<void> saveSearch(
    String query,
    List<Map<String, dynamic>> results,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${query.toLowerCase().trim()}';

    final payload = json.encode({
      'results': results,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await prefs.setString(key, payload);
  }

  // ── Get cached search results ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>?> getSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${query.toLowerCase().trim()}';
    final raw = prefs.getString(key);

    if (raw == null) return null;

    try {
      final payload = json.decode(raw);
      final timestamp = payload['timestamp'] as int;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Expired — return null so fresh fetch happens
      if (DateTime.now().difference(savedAt) > _cacheDuration) {
        await prefs.remove(key);
        return null;
      }

      return List<Map<String, dynamic>>.from(payload['results']);
    } catch (e) {
      return null;
    }
  }

  // ── Save categories ───────────────────────────────────────────────────────
  static Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_prefix}categories', categories);
    await prefs.setInt(
      '${_prefix}categories_ts',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Get cached categories ─────────────────────────────────────────────────
  static Future<List<String>?> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('${_prefix}categories_ts');

    if (ts == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(savedAt) > _cacheDuration) {
      await prefs.remove('${_prefix}categories');
      return null;
    }

    return prefs.getStringList('${_prefix}categories');
  }

  // ── Clear all nutrition cache ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
