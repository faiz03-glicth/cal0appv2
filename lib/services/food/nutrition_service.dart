import 'dart:convert';
import '../auth/secure_config.dart';
import 'package:http/http.dart' as http;
import 'package:cal0appv2/services/users/nutrition_cache_service.dart';

class NutritionService {
  Future<Map<String, String>> _buildHeaders() async {
    final apiKey = await SecureConfig.apiKey;
    return {
      'X-API-Key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<String> _getBaseUrl() => SecureConfig.baseUrl;

  // ── Search — cache first, then network ───────────────────────────────────
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. Check cache first
    final cached = await NutritionCacheService.getSearch(query);
    if (cached != null) return cached; // ✅ instant from cache

    // 2. Cache miss — fetch from API
    try {
      final headers = await _buildHeaders();
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/api/v1/foods/search?q=${Uri.encodeComponent(query)}',
      );

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data['foods'] ?? data['results'] ?? [];
        final results = List<Map<String, dynamic>>.from(list);

        // 3. Save to cache for next time
        await NutritionCacheService.saveSearch(query, results);
        return results;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Get categories — cache first ──────────────────────────────────────────
  Future<List<String>> getCategories() async {
    // 1. Check cache
    final cached = await NutritionCacheService.getCategories();
    if (cached != null) return cached;

    // 2. Fetch from API
    try {
      final headers = await _buildHeaders();
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/v1/categories');

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data['categories'] ?? [];
        final categories = List<String>.from(
          list.map((c) => c['name']?.toString() ?? c.toString()),
        );

        // 3. Save to cache
        await NutritionCacheService.saveCategories(categories);
        return categories;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Get food by ID — no cache needed (rarely called) ─────────────────────
  Future<Map<String, dynamic>?> getFoodById(String id) async {
    try {
      final headers = await _buildHeaders();
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/v1/foods/$id');

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['data'] ?? data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Search halal ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchHalal(String query) async {
    if (query.trim().isEmpty) return [];

    final cached = await NutritionCacheService.getSearch('halal_$query');
    if (cached != null) return cached;

    try {
      final headers = await _buildHeaders();
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/api/v1/halal/search?q=${Uri.encodeComponent(query)}',
      );

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data['foods'] ?? [];
        final results = List<Map<String, dynamic>>.from(list);
        await NutritionCacheService.saveSearch('halal_$query', results);
        return results;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Get foods by category ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFoodsByCategory(
    String category, {
    int limit = 10,
    int offset = 0,
  }) async {
    final cacheKey = 'category_${category}_${limit}_$offset';
    final cached = await NutritionCacheService.getSearch(cacheKey);
    if (cached != null) return cached;

    try {
      final headers = await _buildHeaders();
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/api/v1/foods?category=${Uri.encodeComponent(category)}'
        '&limit=$limit&offset=$offset',
      );

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data['foods'] ?? [];
        final results = List<Map<String, dynamic>>.from(list);
        await NutritionCacheService.saveSearch(cacheKey, results);
        return results;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
