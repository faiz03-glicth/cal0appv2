import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class OFFFoodCache {
  // ── Key prefixes ───────────────────────────────────────────────────────
  static const _bcPrefix = 'off_bc_';
  static const _sqPrefix = 'off_sq_';
  static const _bcKeysKey = 'off_bc_keys';
  static const _sqKeysKey = 'off_sq_keys';

  // ── TTLs ───────────────────────────────────────────────────────────────
  static const Duration _barcodeTTL = Duration(days: 30);
  static const Duration _searchTTL = Duration(hours: 24);

  // ── Max entries ────────────────────────────────────────────────────────
  static const int _maxBarcode = 200;
  static const int _maxSearch = 100;

  // ── Singleton prefs ────────────────────────────────────────────────────
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── BARCODE cache ──────────────────────────────────────────────────────

  static Future<OFFFoodResult?> getBarcode(String barcode) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString('$_bcPrefix$barcode');
      if (raw == null) return null;

      final result = OFFFoodResult.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
      if (DateTime.now().difference(result.cachedAt) > _barcodeTTL) {
        await prefs.remove('$_bcPrefix$barcode');
        return null;
      }
      return result;
    } catch (e) {
      LogService.error('OFFFoodCache.getBarcode', e);
      return null;
    }
  }

  static Future<void> saveBarcode(OFFFoodResult result) async {
    if (result.barcode.isEmpty) return;
    try {
      final prefs = await _p;
      final key = '$_bcPrefix${result.barcode}';
      await prefs.setString(key, json.encode(result.toJson()));
      await _trackKey(prefs, _bcKeysKey, key, _maxBarcode, _bcPrefix);
    } catch (e) {
      LogService.error('OFFFoodCache.saveBarcode', e);
    }
  }

  static Future<void> saveBarcodeNotFound(String barcode) async {
    await saveBarcode(OFFFoodResult.notFound(barcode));
  }

  // ── SEARCH cache ───────────────────────────────────────────────────────

  static String _sqKey(String query) =>
      '$_sqPrefix${query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_')}';

  static Future<List<OFFFoodResult>?> getSearch(String query) async {
    try {
      final prefs = await _p;
      final raw = prefs.getString(_sqKey(query));
      if (raw == null) return null;

      final payload = json.decode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        payload['ts'] as int? ?? 0,
      );
      if (DateTime.now().difference(savedAt) > _searchTTL) {
        await prefs.remove(_sqKey(query));
        return null;
      }

      final items = (payload['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OFFFoodResult.fromJson)
          .toList();
      return items;
    } catch (e) {
      LogService.error('OFFFoodCache.getSearch', e);
      return null;
    }
  }

  static Future<void> saveSearch(
    String query,
    List<OFFFoodResult> results,
  ) async {
    if (results.isEmpty) return;
    try {
      final prefs = await _p;
      final key = _sqKey(query);
      final payload = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'items': results.map((r) => r.toJson()).toList(),
      };
      await prefs.setString(key, json.encode(payload));
      await _trackKey(prefs, _sqKeysKey, key, _maxSearch, _sqPrefix);
    } catch (e) {
      LogService.error('OFFFoodCache.saveSearch', e);
    }
  }

  // ── Key tracking + LRU eviction ────────────────────────────────────────

  static Future<void> _trackKey(
    SharedPreferences prefs,
    String keysKey,
    String newKey,
    int maxCount,
    String prefix,
  ) async {
    final raw = prefs.getString(keysKey);
    final keys = raw != null
        ? List<String>.from(json.decode(raw) as List)
        : <String>[];

    keys.remove(newKey); // remove old occurrence
    keys.insert(0, newKey); // add to front (most recent)

    // Evict oldest if over limit
    while (keys.length > maxCount) {
      final evict = keys.removeLast();
      await prefs.remove(evict);
    }

    await prefs.setString(keysKey, json.encode(keys));
  }

  // ── Clear all ──────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    try {
      final prefs = await _p;
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.startsWith(_bcPrefix) ||
            k.startsWith(_sqPrefix) ||
            k == _bcKeysKey ||
            k == _sqKeysKey) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      LogService.error('OFFFoodCache.clearAll', e);
    }
  }

  // ── Stats (for debug view) ─────────────────────────────────────────────

  static Future<({int barcodes, int searches})> stats() async {
    final prefs = await _p;
    final bcRaw = prefs.getString(_bcKeysKey);
    final sqRaw = prefs.getString(_sqKeysKey);
    final bc = bcRaw != null ? (json.decode(bcRaw) as List).length : 0;
    final sq = sqRaw != null ? (json.decode(sqRaw) as List).length : 0;
    return (barcodes: bc, searches: sq);
  }
}
