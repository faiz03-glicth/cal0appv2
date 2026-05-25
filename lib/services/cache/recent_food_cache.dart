import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class RecentFoodEntry {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double sodium;
  final double? servingSize;
  final String servingUnit;
  final int lastUsedMs; // Unix ms timestamp

  const RecentFoodEntry({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.sodium = 0,
    this.servingSize,
    this.servingUnit = 'g',
    required this.lastUsedMs,
  });

  /// Used for deduplication: case-insensitive name match.
  String get key => name.toLowerCase().trim();

  factory RecentFoodEntry.fromJson(Map<String, dynamic> j) => RecentFoodEntry(
    name: j['name'] as String? ?? '',
    calories: (j['calories'] as num?)?.toInt() ?? 0,
    protein: (j['protein'] as num?)?.toDouble() ?? 0,
    carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
    fat: (j['fat'] as num?)?.toDouble() ?? 0,
    sugar: (j['sugar'] as num?)?.toDouble() ?? 0,
    sodium: (j['sodium'] as num?)?.toDouble() ?? 0,
    servingSize: (j['servingSize'] as num?)?.toDouble(),
    servingUnit: j['servingUnit'] as String? ?? 'g',
    lastUsedMs:
        (j['lastUsedMs'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'sodium': sodium,
    if (servingSize != null) 'servingSize': servingSize,
    'servingUnit': servingUnit,
    'lastUsedMs': lastUsedMs,
  };

  /// Returns a copy with an updated timestamp.
  RecentFoodEntry withNow() => RecentFoodEntry(
    name: name,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    sugar: sugar,
    sodium: sodium,
    servingSize: servingSize,
    servingUnit: servingUnit,
    lastUsedMs: DateTime.now().millisecondsSinceEpoch,
  );

  /// Build a search-result-style map for use with FoodLogViewModel.selectFood()
  Map<String, dynamic> toFoodMap() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'sodium': sodium,
    if (servingSize != null) 'servingSize': servingSize,
    'servingUnit': servingUnit,
  };
}

class RecentFoodCache {
  static const int maxItems = 5;
  static const String _prefsKey = 'c0_recent_foods_v1';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Read ───────────────────────────────────────────────────────────────

  /// Returns all cached entries sorted newest-first.
  static Future<List<RecentFoodEntry>> getAll() async {
    try {
      final prefs = await _instance;
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List;
      final entries = list
          .map((e) => RecentFoodEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      // Sort newest first
      entries.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
      return entries;
    } catch (e) {
      LogService.error('RecentFoodCache.getAll failed', e);
      return [];
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────

  /// Adds or updates [entry] in the cache.
  ///
  /// Deduplication: if a food with the same name (case-insensitive) already
  /// exists, it is replaced with an updated timestamp and moved to top.
  /// Eviction: if size would exceed MAX_ITEMS, the oldest entry is removed.
  static Future<void> add(RecentFoodEntry entry) async {
    try {
      final prefs = await _instance;
      var current = await getAll();

      // Remove existing entry with the same key (dedup + refresh)
      current.removeWhere((e) => e.key == entry.key);

      // Insert at front (newest)
      current.insert(0, entry.withNow());

      // Evict oldest if over limit
      if (current.length > maxItems) {
        current = current.sublist(0, maxItems);
      }

      await prefs.setString(
        _prefsKey,
        json.encode(current.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      LogService.error('RecentFoodCache.add failed', e);
    }
  }

  /// Removes a single entry by name key.
  static Future<void> remove(String name) async {
    try {
      final prefs = await _instance;
      final current = await getAll();
      final key = name.toLowerCase().trim();
      current.removeWhere((e) => e.key == key);
      await prefs.setString(
        _prefsKey,
        json.encode(current.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      LogService.error('RecentFoodCache.remove failed', e);
    }
  }

  /// Wipes the entire cache (called on sign-out).
  static Future<void> clear() async {
    try {
      final prefs = await _instance;
      await prefs.remove(_prefsKey);
    } catch (e) {
      LogService.error('RecentFoodCache.clear failed', e);
    }
  }

  // ── Sync search for filtering suggestions ─────────────────────────────

  /// Synchronous filter used for instant suggestion rendering.
  /// [cached] is the already-loaded list; [query] may be empty.
  static List<RecentFoodEntry> filter(
    List<RecentFoodEntry> cached,
    String query,
  ) {
    if (query.trim().isEmpty) return cached;
    final q = query.toLowerCase().trim();
    return cached.where((e) => e.name.toLowerCase().contains(q)).toList();
  }
}
