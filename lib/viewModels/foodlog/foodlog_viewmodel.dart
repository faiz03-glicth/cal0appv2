import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/repositories/off_food_repository.dart';
import 'package:cal0appv2/services/cache/recent_food_cache.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';

enum HistoryFilter { all, manual, scanned }

class FoodLogViewModel extends ChangeNotifier {
  final FoodLogRepository _foodLogRepo;
  final OFFFoodRepository _foodRepo;

  FoodLogViewModel({
    FoodLogRepository? foodLogRepository,
    OFFFoodRepository? foodRepository,
    // Keep old param name for injection compat
    @Deprecated('Use foodRepository') dynamic nutritionRepository,
  }) : _foodLogRepo = foodLogRepository ?? FoodLogRepository(),
       _foodRepo = foodRepository ?? OFFFoodRepository();

  // ── Internal state ─────────────────────────────────────────────────────
  List<FoodLogModel> _foodLogs = [];
  NutrientTotals _totals = NutrientTotals.empty;
  List<OFFFoodResult> _searchResults = [];
  List<RecentFoodEntry> _recentFoods = [];
  bool _recentFoodsLoaded = false;

  // Search debounce
  Timer? _debounce;
  String _lastQuery = '';

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
  double fiber = 0;
  double sugar = 0;
  double sodium = 0;
  double saturatedFat = 0;
  // Serving size for rescaling
  double servingGrams = 100;

  // ── Supplements toggle ──────────────────────────────────────────────
  // OFF (default) = Normal Food Logging — no ingredient list, no
  // Authentic/Non-Authentic check, nothing extra saved.
  // ON = Whey Supplement — shows the ingredient list field and runs the
  // same nitrogen-compound check used by the live scan and food history,
  // via IngredientAuthenticityService.
  bool isSupplementMode = false;
  String ingredientText = '';
  double creatineMonohydrate = 0;
  double bcaa = 0;
  double leucine = 0;
  double isoleucine = 0;
  double valine = 0;
  double glutamine = 0;
  double taurine = 0;

  // Currently selected OFFFoodResult (for serving-size rescaling)
  OFFFoodResult? _selectedFood;

  static DateTime _midnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _recomputeTotals() => _totals = NutrientTotals.fromLogs(_foodLogs);

  // ── Public getters ─────────────────────────────────────────────────────
  DateTime get selectedDate => _selectedDate;
  List<FoodLogModel> get foodLogs => _foodLogs;
  List<OFFFoodResult> get searchResults => _searchResults;
  List<RecentFoodEntry> get recentFoods => _recentFoods;
  OFFFoodResult? get selectedFood => _selectedFood;
  bool get isToday => _selectedDate == _midnight(DateTime.now());
  bool get isFormValid =>
      foodName.trim().isNotEmpty && calories.trim().isNotEmpty;

  NutrientTotals get totals => _totals;
  int get totalCalories => _totals.calories;
  double get totalProtein => _totals.protein;
  double get totalCarbs => _totals.carbs;
  double get totalFat => _totals.fat;
  double get totalSugar => _totals.sugar;
  double get totalSodium => _totals.sodium;
  bool get hasLogs => !_totals.isEmpty;

  /// The current Authentic / Non-Authentic result for whatever ingredient
  /// text is in the form right now — null when Supplements mode is off,
  /// or there's no ingredient text yet to check.
  AuthenticityCheck? get supplementAuthenticityCheck {
    if (!isSupplementMode || ingredientText.trim().isEmpty) return null;
    return IngredientAuthenticityService.check(ingredientText);
  }

  // ── Load / Date navigation ─────────────────────────────────────────────

  Future<void> loadFoodLogs({required String uid}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _foodLogs = await _foodLogRepo.getFoodLogs(uid, _selectedDate);
      _recomputeTotals();
      // UAT 9.2 — empty result for the selected date is its own
      // documented case, distinct from a fetch failure.
      if (_foodLogs.isEmpty) {
        errorMessage = 'No data to shown';
      }
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
    _recentFoods = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
    notifyListeners();
  }

  Future<void> _refreshRecentFoods() async {
    _recentFoods = await RecentFoodCache.getAll();
    _recentFoodsLoaded = true;
  }

  List<RecentFoodEntry> filteredRecent(String query) =>
      RecentFoodCache.filter(_recentFoods, query);

  // ── Search (debounced, 400ms) ──────────────────────────────────────────

  void cancelSearch() {
    _debounce?.cancel();
    _debounce = null;
  }

  void searchFood(String query) {
    _debounce?.cancel();
    _debounce = null;

    if (query.trim().isEmpty) {
      _searchResults = [];
      _lastQuery = '';
      notifyListeners(); // safe here — empty query is synchronous, not mid-build
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query.trim());
    });
  }

  Future<void> _doSearch(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;
    isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _foodRepo.searchFood(query);
    } catch (e) {
      _searchResults = [];
      errorMessage = 'Search failed: $e';
    }
    isSearching = false;
    notifyListeners();
  }

  Future<void> forceRefreshSearch(String query) async {
    if (query.trim().isEmpty) return;
    _lastQuery = '';
    isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _foodRepo.searchFood(
        query.trim(),
        forceRefresh: true,
      );
    } catch (e) {
      _searchResults = [];
      errorMessage = 'Search failed: $e';
    }
    isSearching = false;
    notifyListeners();
  }

  // ── Food selection (from OFF search result) ────────────────────────────

  void selectOFFFood(OFFFoodResult food) {
    _selectedFood = food;
    servingGrams = food.servingSize > 0 ? food.servingSize : 100;
    _fillFromOFF(food, servingGrams);
  }

  /// Called when user changes the serving size slider/field in the UI.
  void updateServingSize(double grams) {
    if (_selectedFood == null || grams <= 0) return;
    servingGrams = grams;
    _fillFromOFF(_selectedFood!, grams);
  }

  void _fillFromOFF(OFFFoodResult food, double grams) {
    foodName = food.displayName;
    calories = food.caloriesForServing(grams).toString();
    protein = food.proteinForServing(grams);
    carbs = food.carbsForServing(grams);
    fat = food.fatForServing(grams);
    fiber = food.fiberForServing(grams);
    sugar = food.sugarForServing(grams);
    sodium = food.sodiumForServing(grams);
    saturatedFat = food.saturatedFatForServing(grams);
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  // ── Food selection (legacy Map — used by barcode + scan paths) ─────────

  void selectFood(Map<String, dynamic> food) {
    foodName = food['name'] ?? food['food_name'] ?? food['naman'] ?? '';
    calories = (food['calories'] ?? food['energy'] ?? food['kalori'] ?? 0)
        .toString();
    protein = (food['protein'] ?? food['proteins'] ?? 0).toDouble();
    carbs = (food['carbs'] ?? food['carbohydrates'] ?? food['karbohidrat'] ?? 0)
        .toDouble();
    fat = (food['fat'] ?? food['lemak'] ?? 0).toDouble();
    fiber = (food['fiber'] ?? 0).toDouble();
    sugar = (food['sugar'] ?? 0).toDouble();
    sodium = (food['sodium'] ?? 0).toDouble();
    saturatedFat = (food['saturatedFat'] ?? 0).toDouble();
    servingGrams = (food['servingSize'] as num?)?.toDouble() ?? 100;
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  void selectRecent(RecentFoodEntry entry) {
    foodName = entry.name;
    calories = entry.calories.toString();
    protein = entry.protein;
    carbs = entry.carbs;
    fat = entry.fat;
    servingGrams = entry.servingSize ?? 100;
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  // ── Form field updaters ────────────────────────────────────────────────

  void setManualMode(bool v) {
    manualMode = v;
    if (!v) _searchResults = [];
    notifyListeners();
  }

  /// Toggles between Normal Food Logging (off) and Whey Supplement mode
  /// (on). Turning Supplements on reveals the ingredient list field and
  /// the Authentic / Non-Authentic check; turning it off hides them and
  /// the check is skipped entirely — nothing supplement-related gets
  /// evaluated or saved for a normal food log.
  void setSupplementMode(bool v) {
    isSupplementMode = v;
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

  void updateIngredientText(String v) {
    ingredientText = v;
    notifyListeners();
  }

  void updateCreatineMonohydrate(String v) {
    creatineMonohydrate = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateBcaa(String v) {
    bcaa = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateLeucine(String v) {
    leucine = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateIsoleucine(String v) {
    isoleucine = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateValine(String v) {
    valine = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateGlutamine(String v) {
    glutamine = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void updateTaurine(String v) {
    taurine = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void prefillForEdit(FoodLogModel log) {
    foodName = log.foodLogName;
    calories = log.calorieIntake.toString();
    protein = log.protein;
    carbs = log.carbs;
    fat = log.fats;
    fiber = log.fiber;
    sugar = log.sugar;
    sodium = log.sodium;
    saturatedFat = log.saturatedFat;
    servingGrams = log.servingSize ?? 100;
    manualMode = true;

    // Restore Supplements state from the saved log so re-opening an
    // existing whey entry for edit shows the toggle already on with its
    // ingredients and compounds intact.
    ingredientText = log.ingredientText;
    creatineMonohydrate = log.creatineMonohydrate;
    bcaa = log.bcaa;
    leucine = log.leucine;
    isoleucine = log.isoleucine;
    valine = log.valine;
    glutamine = log.glutamine;
    taurine = log.taurine;
    isSupplementMode =
        log.ingredientText.trim().isNotEmpty ||
        log.creatineMonohydrate > 0 ||
        log.bcaa > 0 ||
        log.leucine > 0 ||
        log.isoleucine > 0 ||
        log.valine > 0 ||
        log.glutamine > 0 ||
        log.taurine > 0;

    notifyListeners();
  }

  void clearForm() {
    foodName = '';
    calories = '';
    protein = 0;
    carbs = 0;
    fat = 0;
    fiber = 0;
    sugar = 0;
    sodium = 0;
    saturatedFat = 0;
    servingGrams = 100;
    manualMode = false;
    _selectedFood = null;
    _searchResults = [];
    errorMessage = null;
    successMessage = null;
    isSupplementMode = false;
    ingredientText = '';
    creatineMonohydrate = 0;
    bcaa = 0;
    leucine = 0;
    isoleucine = 0;
    valine = 0;
    glutamine = 0;
    taurine = 0;
    notifyListeners();
  }

  // ── Supplements save helpers ─────────────────────────────────────────
  // Only ever populated when isSupplementMode is on — a Normal Food Log
  // never carries ingredient text, supplement compounds, or an
  // Authentic/Non-Authentic result.

  String get _savedIngredientText =>
      isSupplementMode ? ingredientText.trim() : '';
  double get _savedCreatine => isSupplementMode ? creatineMonohydrate : 0;
  double get _savedBcaa => isSupplementMode ? bcaa : 0;
  double get _savedLeucine => isSupplementMode ? leucine : 0;
  double get _savedIsoleucine => isSupplementMode ? isoleucine : 0;
  double get _savedValine => isSupplementMode ? valine : 0;
  double get _savedGlutamine => isSupplementMode ? glutamine : 0;
  double get _savedTaurine => isSupplementMode ? taurine : 0;

  String? _buildSupplementAnalysisResult() {
    if (!isSupplementMode || ingredientText.trim().isEmpty) return null;
    final check = IngredientAuthenticityService.check(ingredientText);
    return check.isNonAuthentic ? 'NON-AUTHENTIC' : 'AUTHENTIC';
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
        fiber: fiber,
        sugar: sugar,
        sodium: sodium,
        saturatedFat: saturatedFat,
        servingSize: servingGrams,
        ingredientText: _savedIngredientText,
        creatineMonohydrate: _savedCreatine,
        bcaa: _savedBcaa,
        leucine: _savedLeucine,
        isoleucine: _savedIsoleucine,
        valine: _savedValine,
        glutamine: _savedGlutamine,
        taurine: _savedTaurine,
        scanAnalysisResult: _buildSupplementAnalysisResult(),
      );

      await _foodLogRepo.addFoodLog(uid, log);
      _foodLogs.add(log);
      _recomputeTotals();

      await RecentFoodCache.add(
        RecentFoodEntry(
          name: log.foodLogName,
          calories: log.calorieIntake,
          protein: log.protein,
          carbs: log.carbs,
          fat: log.fats,
          sugar: log.sugar,
          sodium: log.sodium,
          servingSize: log.servingSize,
          lastUsedMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
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
    if (!isFormValid) {
      errorMessage = 'Food name and calories are required';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      existing
        ..foodLogName = foodName.trim()
        ..calorieIntake = int.tryParse(calories.trim()) ?? 0
        ..protein = protein
        ..carbs = carbs
        ..fats = fat
        ..fiber = fiber
        ..sugar = sugar
        ..sodium = sodium
        ..saturatedFat = saturatedFat
        ..ingredientText = _savedIngredientText
        ..creatineMonohydrate = _savedCreatine
        ..bcaa = _savedBcaa
        ..leucine = _savedLeucine
        ..isoleucine = _savedIsoleucine
        ..valine = _savedValine
        ..glutamine = _savedGlutamine
        ..taurine = _savedTaurine
        ..scanAnalysisResult = _buildSupplementAnalysisResult();

      await _foodLogRepo.updateFoodLog(uid, existing);
      final idx = _foodLogs.indexWhere(
        (l) => l.foodLogID == existing.foodLogID,
      );
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
    isLoading = true;
    errorMessage = null;
    notifyListeners();
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
    _foodLogs = [];
    _totals = NutrientTotals.empty;
    _searchResults = [];
    _recentFoods = [];
    _recentFoodsLoaded = false;
    _selectedDate = _midnight(DateTime.now());
    _selectedFood = null;
    _lastQuery = '';
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
