
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/repositories/off_food_repository.dart';
import 'package:cal0appv2/services/cache/recent_food_cache.dart';

enum HistoryFilter { all, manual, scanned }

class FoodLogViewModel extends ChangeNotifier {
  final FoodLogRepository  _foodLogRepo;
  final OFFFoodRepository  _foodRepo;

  FoodLogViewModel({
    FoodLogRepository?  foodLogRepository,
    OFFFoodRepository?  foodRepository,
    // Keep old param name for injection compat
    @Deprecated('Use foodRepository') dynamic nutritionRepository,
  }) : _foodLogRepo = foodLogRepository ?? FoodLogRepository(),
       _foodRepo    = foodRepository    ?? OFFFoodRepository();

  // ── Internal state ─────────────────────────────────────────────────────
  List<FoodLogModel>    _foodLogs         = [];
  NutrientTotals        _totals           = NutrientTotals.empty;
  List<OFFFoodResult>   _searchResults    = [];
  List<RecentFoodEntry> _recentFoods      = [];
  bool                  _recentFoodsLoaded = false;

  // Search debounce
  Timer?  _debounce;
  String  _lastQuery = '';

  bool    isLoading    = false;
  bool    isSaving     = false;
  bool    isSearching  = false;
  bool    manualMode   = false;
  String? errorMessage;
  String? successMessage;

  DateTime _selectedDate = _midnight(DateTime.now());

  // Form fields
  String  foodName  = '';
  String  calories  = '';
  double  protein   = 0;
  double  carbs     = 0;
  double  fat       = 0;
  double  fiber     = 0;
  double  sugar     = 0;
  double  sodium    = 0;
  double  saturatedFat = 0;
  // Serving size for rescaling
  double  servingGrams = 100;

  // Currently selected OFFFoodResult (for serving-size rescaling)
  OFFFoodResult? _selectedFood;

  static DateTime _midnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _recomputeTotals() => _totals = NutrientTotals.fromLogs(_foodLogs);

  // ── Public getters ─────────────────────────────────────────────────────
  DateTime              get selectedDate   => _selectedDate;
  List<FoodLogModel>    get foodLogs        => _foodLogs;
  List<OFFFoodResult>   get searchResults   => _searchResults;
  List<RecentFoodEntry> get recentFoods     => _recentFoods;
  OFFFoodResult?        get selectedFood    => _selectedFood;
  bool                  get isToday         =>
      _selectedDate == _midnight(DateTime.now());
  bool get isFormValid =>
      foodName.trim().isNotEmpty && calories.trim().isNotEmpty;

  NutrientTotals get totals       => _totals;
  int            get totalCalories => _totals.calories;
  double         get totalProtein  => _totals.protein;
  double         get totalCarbs    => _totals.carbs;
  double         get totalFat      => _totals.fat;
  double         get totalSugar    => _totals.sugar;
  double         get totalSodium   => _totals.sodium;
  bool           get hasLogs       => !_totals.isEmpty;

  // ── Load / Date navigation ─────────────────────────────────────────────

  Future<void> loadFoodLogs({required String uid}) async {
    isLoading    = true;
    errorMessage = null;
    notifyListeners();
    try {
      _foodLogs = await _foodLogRepo.getFoodLogs(uid, _selectedDate);
      _recomputeTotals();
    } catch (e) {
      errorMessage = 'Failed to load food logs: $e';
      _foodLogs = [];
      _recomputeTotals();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> changeSelectedDate(DateTime date, {required String uid}) async {
    final nd = _midnight(date);
    if (nd == _selectedDate) return;
    _selectedDate = nd;
    notifyListeners();
    await loadFoodLogs(uid: uid);
  }

  // ── Recent foods ───────────────────────────────────────────────────────

  Future<void> loadRecentFoods() async {
    if (_recentFoodsLoaded) return;
    _recentFoods       = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
    notifyListeners();
  }

  Future<void> _refreshRecentFoods() async {
    _recentFoods       = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
  }

  List<RecentFoodEntry> filteredRecent(String query) =>
      RecentFoodCache.filter(_recentFoods, query);

  // ── Search (debounced, 400ms) ──────────────────────────────────────────

  void searchFood(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _searchResults = [];
      _lastQuery     = '';
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query.trim());
    });
  }

  Future<void> _doSearch(String query) async {
    if (query == _lastQuery) return;
    _lastQuery   = query;
    isSearching  = true;
    notifyListeners();
    try {
      _searchResults = await _foodRepo.searchFood(query);
    } catch (e) {
      _searchResults = [];
      errorMessage   = 'Search failed: $e';
    }
    isSearching = false;
    notifyListeners();
  }

  Future<void> forceRefreshSearch(String query) async {
    if (query.trim().isEmpty) return;
    _lastQuery  = '';
    isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _foodRepo.searchFood(query.trim(), forceRefresh: true);
    } catch (e) {
      _searchResults = [];
      errorMessage   = 'Search failed: $e';
    }
    isSearching = false;
    notifyListeners();
  }

  // ── Food selection (from OFF search result) ────────────────────────────

  void selectOFFFood(OFFFoodResult food) {
    _selectedFood = food;
    servingGrams  = food.servingSize > 0 ? food.servingSize : 100;
    _fillFromOFF(food, servingGrams);
  }

  /// Called when user changes the serving size slider/field in the UI.
  void updateServingSize(double grams) {
    if (_selectedFood == null || grams <= 0) return;
    servingGrams = grams;
    _fillFromOFF(_selectedFood!, grams);
  }

  void _fillFromOFF(OFFFoodResult food, double grams) {
    foodName     = food.displayName;
    calories     = food.caloriesForServing(grams).toString();
    protein      = food.proteinForServing(grams);
    carbs        = food.carbsForServing(grams);
    fat          = food.fatForServing(grams);
    fiber        = food.fiberForServing(grams);
    sugar        = food.sugarForServing(grams);
    sodium       = food.sodiumForServing(grams);
    saturatedFat = food.saturatedFatForServing(grams);
    manualMode   = true;
    _searchResults = [];
    notifyListeners();
  }

  // ── Food selection (legacy Map — used by barcode + scan paths) ─────────

  void selectFood(Map<String, dynamic> food) {
    foodName = food['name'] ?? food['food_name'] ?? food['naman'] ?? '';
    calories = (food['calories'] ?? food['energy'] ?? food['kalori'] ?? 0).toString();
    protein  = (food['protein']  ?? food['proteins'] ?? 0).toDouble();
    carbs    = (food['carbs']    ?? food['carbohydrates'] ?? food['karbohidrat'] ?? 0).toDouble();
    fat      = (food['fat']      ?? food['lemak'] ?? 0).toDouble();
    fiber    = (food['fiber']    ?? 0).toDouble();
    sugar    = (food['sugar']    ?? 0).toDouble();
    sodium   = (food['sodium']   ?? 0).toDouble();
    saturatedFat = (food['saturatedFat'] ?? 0).toDouble();
    servingGrams = (food['servingSize']  as num?)?.toDouble() ?? 100;
    manualMode   = true;
    _searchResults = [];
    notifyListeners();
  }

  void selectRecent(RecentFoodEntry entry) {
    foodName     = entry.name;
    calories     = entry.calories.toString();
    protein      = entry.protein;
    carbs        = entry.carbs;
    fat          = entry.fat;
    servingGrams = entry.servingSize ?? 100;
    manualMode   = true;
    _searchResults = [];
    notifyListeners();
  }

  // ── Form field updaters ────────────────────────────────────────────────

  void setManualMode(bool v)    { manualMode = v; if (!v) _searchResults = []; notifyListeners(); }
  void updateFoodName(String v) { foodName = v; notifyListeners(); }
  void updateCalories(String v) { calories = v; notifyListeners(); }
  void updateProtein(String v)  { protein  = double.tryParse(v) ?? 0; notifyListeners(); }
  void updateCarbs(String v)    { carbs    = double.tryParse(v) ?? 0; notifyListeners(); }
  void updateFat(String v)      { fat      = double.tryParse(v) ?? 0; notifyListeners(); }

  void prefillForEdit(FoodLogModel log) {
    foodName     = log.foodLogName;
    calories     = log.calorieIntake.toString();
    protein      = log.protein;
    carbs        = log.carbs;
    fat          = log.fats;
    fiber        = log.fiber;
    sugar        = log.sugar;
    sodium       = log.sodium;
    saturatedFat = log.saturatedFat;
    servingGrams = log.servingSize ?? 100;
    manualMode   = true;
    notifyListeners();
  }

  void clearForm() {
    foodName     = '';
    calories     = '';
    protein      = 0;
    carbs        = 0;
    fat          = 0;
    fiber        = 0;
    sugar        = 0;
    sodium       = 0;
    saturatedFat = 0;
    servingGrams = 100;
    manualMode   = false;
    _selectedFood  = null;
    _searchResults = [];
    errorMessage   = null;
    successMessage = null;
    notifyListeners();
  }

  // ── CREATE ─────────────────────────────────────────────────────────────

  Future<bool> addFoodLog({required String uid}) async {
    if (!isFormValid) { errorMessage = 'Food name and calories are required'; notifyListeners(); return false; }

    isSaving     = true;
    errorMessage = null;
    notifyListeners();

    try {
      final log = FoodLogModel(
        foodLogID    : '',
        foodLogName  : foodName.trim(),
        calorieIntake: int.tryParse(calories.trim()) ?? 0,
        userId       : uid,
        foodLogDate  : _selectedDate,
        loggedAt     : DateTime.now(),
        protein      : protein,
        carbs        : carbs,
        fats         : fat,
        fiber        : fiber,
        sugar        : sugar,
        sodium       : sodium,
        saturatedFat : saturatedFat,
        servingSize  : servingGrams,
      );

      await _foodLogRepo.addFoodLog(uid, log);
      _foodLogs.add(log);
      _recomputeTotals();

      await RecentFoodCache.add(RecentFoodEntry(
        name        : log.foodLogName,
        calories    : log.calorieIntake,
        protein     : log.protein,
        carbs       : log.carbs,
        fat         : log.fats,
        sugar       : log.sugar,
        sodium      : log.sodium,
        servingSize : log.servingSize,
        lastUsedMs  : DateTime.now().millisecondsSinceEpoch,
      ));
      await _refreshRecentFoods();

      successMessage = '${foodName.trim()} added to diary';
      clearForm();
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
    if (!isFormValid) { errorMessage = 'Food name and calories are required'; notifyListeners(); return false; }

    isSaving = true; errorMessage = null; notifyListeners();

    try {
      existing
        ..foodLogName   = foodName.trim()
        ..calorieIntake = int.tryParse(calories.trim()) ?? 0
        ..protein       = protein
        ..carbs         = carbs
        ..fats          = fat
        ..fiber         = fiber
        ..sugar         = sugar
        ..sodium        = sodium
        ..saturatedFat  = saturatedFat;

      await _foodLogRepo.updateFoodLog(uid, existing);
      final idx = _foodLogs.indexWhere((l) => l.foodLogID == existing.foodLogID);
      if (idx != -1) _foodLogs[idx] = existing;
      _recomputeTotals();

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
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      await _foodLogRepo.deleteFoodLog(uid, foodLogID);
      _foodLogs.removeWhere((l) => l.foodLogID == foodLogID);
      _recomputeTotals();
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

  // ── Logout ─────────────────────────────────────────────────────────────

  void clearForLogout() {
    _debounce?.cancel();
    _foodLogs          = [];
    _totals            = NutrientTotals.empty;
    _searchResults     = [];
    _recentFoods       = [];
    _recentFoodsLoaded = false;
    _selectedDate      = _midnight(DateTime.now());
    _selectedFood      = null;
    _lastQuery         = '';
    errorMessage       = null;
    successMessage     = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}