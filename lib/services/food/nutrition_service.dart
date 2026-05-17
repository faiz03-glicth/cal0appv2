import 'dart:convert';
import '../auth/secure_config.dart';
import 'package:http/http.dart' as http;
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/users/nutrition_cache_service.dart';

class NutritionService {
  Map<String, String> _buildHeaders() {
    final key = SecureConfig.apiKey;
    LogService.info(
      'NutritionService: apiKey is ${key.isEmpty ? "EMPTY" : "set (${key.length} chars)"}',
    );
    LogService.info('NutritionService: baseUrl = ${SecureConfig.baseUrl}');
    return {
      'X-API-Key': SecureConfig.apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  String get _baseUrl => SecureConfig.baseUrl;
  // Future<String> _getBaseUrl() => SecureConfig.baseUrl;
  // ── Search — cache first, then network ───────────────────────────────────
  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];

    LogService.info('searchFood: query="$query"');

    final cached = await NutritionCacheService.getSearch(query);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/v1/foods/search?q=${Uri.encodeComponent(query)}',
      );
      LogService.info('searchFood: GET $uri');
      final res = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      LogService.info('searchFood: status=${res.statusCode}');
      LogService.info(
        'searchFood: body preview=${res.body.substring(0, res.body.length.clamp(0, 300))}',
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = List<Map<String, dynamic>>.from(
          data['data'] ?? data['foods'] ?? data['results'] ?? [],
        );
        LogService.info('searchFood: parsed ${results.length} results');
        await NutritionCacheService.saveSearch(query, results);
        return results;
      }
      LogService.error(
        'searchFood: non-200 status ${res.statusCode}',
        res.body,
      );
      return [];
    } catch (e, stack) {
      LogService.error('searchFood: exception', e, stack);
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    final cached = await NutritionCacheService.getCategories();
    if (cached != null) return cached;

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/categories');
      final res = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] ?? data['categories'] ?? [];
        final categories = List<String>.from(
          list.map((c) => c['name']?.toString() ?? c.toString()),
        );
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
      final uri = Uri.parse('$_baseUrl/api/v1/foods/$id');
      final res = await http
          .get(uri, headers: _buildHeaders())
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
      final uri = Uri.parse(
        '$_baseUrl/api/v1/halal/search?q=${Uri.encodeComponent(query)}',
      );
      final res = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = List<Map<String, dynamic>>.from(
          data['data'] ?? data['foods'] ?? [],
        );
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
      final uri = Uri.parse(
        '$_baseUrl/api/v1/foods?category=${Uri.encodeComponent(category)}'
        '&limit=$limit&offset=$offset',
      );
      final res = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = List<Map<String, dynamic>>.from(
          data['data'] ?? data['foods'] ?? [],
        );
        await NutritionCacheService.saveSearch(cacheKey, results);
        return results;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
