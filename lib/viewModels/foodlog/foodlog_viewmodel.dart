import 'package:flutter/material.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/repositories/nutrition_repository.dart';
import 'package:cal0appv2/services/cache/recent_food_cache.dart';

enum HistoryFilter { all, manual, scanned }

class FoodLogViewModel extends ChangeNotifier {
  final FoodLogRepository _foodLogRepo;
  final NutritionRepository _nutritionRepo;

  FoodLogViewModel({
    FoodLogRepository? foodLogRepository,
    NutritionRepository? nutritionRepository,
  }) : _foodLogRepo = foodLogRepository ?? FoodLogRepository(),
       _nutritionRepo = nutritionRepository ?? NutritionRepository();

  // ── Internal state ─────────────────────────────────────────────────────
  List<FoodLogModel> _foodLogs = [];
  NutrientTotals _totals = NutrientTotals.empty; // ← single cached computation
  List<Map<String, dynamic>> _searchResults = [];
  List<RecentFoodEntry> _recentFoods = [];
  bool _recentFoodsLoaded = false;

  bool isLoading = false;
  bool isSaving = false;
  bool isSearching = false;
  bool manualMode = false;
  String? errorMessage;
  String? successMessage;

  DateTime _selectedDate = _midnight(DateTime.now());

  // Form fields
  String foodName = '';
  String calories = '';
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  static DateTime _midnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Recompute totals after any list mutation ───────────────────────────
  void _recomputeTotals() {
    _totals = NutrientTotals.fromLogs(_foodLogs);
  }

  // ── Public getters ─────────────────────────────────────────────────────
  DateTime get selectedDate => _selectedDate;
  List<FoodLogModel> get foodLogs => _foodLogs;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<RecentFoodEntry> get recentFoods => _recentFoods;
  bool get isToday => _selectedDate == _midnight(DateTime.now());
  bool get isFormValid =>
      foodName.trim().isNotEmpty && calories.trim().isNotEmpty;

  // Totals — all read from _totals (single O(n) pass already done)
  NutrientTotals get totals => _totals;
  int get totalCalories => _totals.calories;
  double get totalProtein => _totals.protein;
  double get totalCarbs => _totals.carbs;
  double get totalFat => _totals.fat;
  double get totalSugar => _totals.sugar;
  double get totalSodium => _totals.sodium;
  bool get hasLogs => !_totals.isEmpty;

  // ── Load ───────────────────────────────────────────────────────────────

  Future<void> loadFoodLogs({required String uid}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _foodLogs = await _foodLogRepo.getFoodLogs(uid, _selectedDate);
      _recomputeTotals(); // ← always recalculate from fresh data
    } catch (e) {
      errorMessage = 'Failed to load food logs: $e';
      _foodLogs = [];
      _recomputeTotals();
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Date navigation ────────────────────────────────────────────────────

  Future<void> changeSelectedDate(DateTime date, {required String uid}) async {
    final newDate = _midnight(date);
    if (newDate == _selectedDate) return;
    _selectedDate = newDate;
    notifyListeners();
    await loadFoodLogs(uid: uid);
  }

  // ── Recent foods ───────────────────────────────────────────────────────

  /// Loaded lazily — only when the food sheet opens.
  Future<void> loadRecentFoods() async {
    if (_recentFoodsLoaded) return; // already loaded this session
    _recentFoods = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
    notifyListeners();
  }

  /// Force reload — called after a successful save to surface the new item.
  Future<void> _refreshRecentFoods() async {
    _recentFoods = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
    // Don't notifyListeners here — caller will do it
  }

  List<RecentFoodEntry> filteredRecent(String query) =>
      RecentFoodCache.filter(_recentFoods, query);

  // ── Search ─────────────────────────────────────────────────────────────

  Future<void> searchFood(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _nutritionRepo.searchFood(query.trim());
    } catch (e) {
      _searchResults = [];
      errorMessage = 'Search failed: $e';
    }
    isSearching = false;
    notifyListeners();
  }

  // ── Form fill helpers ──────────────────────────────────────────────────

  void selectFood(Map<String, dynamic> food) {
    foodName = food['name'] ?? food['food_name'] ?? food['naman'] ?? '';
    calories = (food['calories'] ?? food['energy'] ?? food['kalori'] ?? 0)
        .toString();
    protein = (food['protein'] ?? food['proteins'] ?? 0).toDouble();
    carbs = (food['carbs'] ?? food['carbohydrates'] ?? food['karbohidrat'] ?? 0)
        .toDouble();
    fat = (food['fat'] ?? food['lemak'] ?? 0).toDouble();
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  /// Fill form from a RecentFoodEntry (one-tap reuse).
  void selectRecent(RecentFoodEntry entry) {
    foodName = entry.name;
    calories = entry.calories.toString();
    protein = entry.protein;
    carbs = entry.carbs;
    fat = entry.fat;
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  void setManualMode(bool value) {
    manualMode = value;
    if (!value) _searchResults = [];
    notifyListeners();
  }

  void updateFoodName(String v) {
    foodName = v;
    notifyListeners();
  }

  void updateCalories(String v) {
    calories = v;
    notifyListeners();
  }

  void updateProtein(String v) {
    protein = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateCarbs(String v) {
    carbs = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateFat(String v) {
    fat = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void prefillForEdit(FoodLogModel log) {
    foodName = log.foodLogName;
    calories = log.calorieIntake.toString();
    protein = log.protein;
    carbs = log.carbs;
    fat = log.fats;
    manualMode = true;
    notifyListeners();
  }

  void clearForm() {
    foodName = '';
    calories = '';
    protein = 0;
    carbs = 0;
    fat = 0;
    manualMode = false;
    _searchResults = [];
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  // ── CREATE ─────────────────────────────────────────────────────────────

  Future<bool> addFoodLog({required String uid}) async {
    if (!isFormValid) {
      errorMessage = 'Food name and calories are required';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final log = FoodLogModel(
        foodLogID: '',
        foodLogName: foodName.trim(),
        calorieIntake: int.tryParse(calories.trim()) ?? 0,
        userId: uid,
        foodLogDate: _selectedDate,
        loggedAt: DateTime.now(),
        protein: protein,
        carbs: carbs,
        fats: fat,
      );

      await _foodLogRepo.addFoodLog(uid, log);

      // Optimistic update — no re-fetch needed
      _foodLogs.add(log);
      _recomputeTotals();

      // Cache this food for quick reuse
      await RecentFoodCache.add(
        RecentFoodEntry(
          name: log.foodLogName,
          calories: log.calorieIntake,
          protein: log.protein,
          carbs: log.carbs,
          fat: log.fats,
          lastUsedMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _refreshRecentFoods();

      successMessage = '${foodName.trim()} added to diary';
      clearForm(); // calls notifyListeners
    } catch (e) {
      errorMessage = 'Failed to add food: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }

    isSaving = false;
    notifyListeners();
    return true;
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────

  Future<bool> updateFoodLog({
    required String uid,
    required FoodLogModel existing,
  }) async {
    if (!isFormValid) {
      errorMessage = 'Food name and calories are required';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      existing.foodLogName = foodName.trim();
      existing.calorieIntake = int.tryParse(calories.trim()) ?? 0;
      existing.protein = protein;
      existing.carbs = carbs;
      existing.fats = fat;

      await _foodLogRepo.updateFoodLog(uid, existing);

      final idx = _foodLogs.indexWhere(
        (l) => l.foodLogID == existing.foodLogID,
      );
      if (idx != -1) _foodLogs[idx] = existing;
      _recomputeTotals();

      // Update cache entry with new values
      await RecentFoodCache.add(
        RecentFoodEntry(
          name: existing.foodLogName,
          calories: existing.calorieIntake,
          protein: existing.protein,
          carbs: existing.carbs,
          fat: existing.fats,
          lastUsedMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _refreshRecentFoods();

      successMessage = 'Updated successfully';
      clearForm();
    } catch (e) {
      errorMessage = 'Failed to update food: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }

    isSaving = false;
    notifyListeners();
    return true;
  }

  // ── DELETE ─────────────────────────────────────────────────────────────

  Future<bool> deleteFoodLog({
    required String uid,
    required String foodLogID,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _foodLogRepo.deleteFoodLog(uid, foodLogID);
      _foodLogs.removeWhere((l) => l.foodLogID == foodLogID);
      _recomputeTotals(); // recalculate after removal
      successMessage = 'Food removed from diary';
    } catch (e) {
      errorMessage = 'Failed to delete food: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }

    isLoading = false;
    notifyListeners();
    return true;
  }

  // ── Logout / reset ─────────────────────────────────────────────────────

  /// Called from auth sign-out to wipe all in-memory state.
  /// Does NOT clear the cache — cache is per-device and survives logout
  /// intentionally (same physical user different account is edge case).
  void clearForLogout() {
    _foodLogs = [];
    _totals = NutrientTotals.empty;
    _searchResults = [];
    _recentFoods = [];
    _recentFoodsLoaded = false;
    _selectedDate = _midnight(DateTime.now());
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
