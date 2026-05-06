import 'package:cal0appv2/services/food/nutrition_service.dart';

/// Single access point for all nutrition / food search operations.
/// ViewModels must never import NutritionService directly —
/// they call this repository only.
class NutritionRepository {
  final NutritionService _nutritionService;

  NutritionRepository({NutritionService? nutritionService})
    : _nutritionService = nutritionService ?? NutritionService();

  // ── Search ────────────────────────────────────────────────────────────────

  /// Searches for food items by name. Results are cache-first (24h TTL).
  /// Returns an empty list on network failure — never throws.
  Future<List<Map<String, dynamic>>> searchFood(String query) =>
      _nutritionService.searchFood(query);

  /// Searches within halal-certified food items only.
  Future<List<Map<String, dynamic>>> searchHalal(String query) =>
      _nutritionService.searchHalal(query);

  // ── Browse ────────────────────────────────────────────────────────────────

  /// Returns available food categories. Results are cached for 24 hours.
  Future<List<String>> getCategories() => _nutritionService.getCategories();

  /// Returns foods within a specific [category].
  /// Supports pagination via [limit] and [offset].
  Future<List<Map<String, dynamic>>> getFoodsByCategory(
    String category, {
    int limit = 10,
    int offset = 0,
  }) => _nutritionService.getFoodsByCategory(
    category,
    limit: limit,
    offset: offset,
  );

  // ── Detail ────────────────────────────────────────────────────────────────

  /// Fetches the full nutrition detail for a single food item by [id].
  /// Returns null if not found or on network failure.
  Future<Map<String, dynamic>?> getFoodById(String id) =>
      _nutritionService.getFoodById(id);
}
