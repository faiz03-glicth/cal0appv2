import 'package:flutter/material.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/repositories/nutrition_repository.dart';

/// ViewModel for the food diary / food sheet.
/// No Firebase, no services — only repositories.
class FoodLogViewModel extends ChangeNotifier {
  final FoodLogRepository _foodLogRepo;
  final NutritionRepository _nutritionRepo;

  FoodLogViewModel({
    FoodLogRepository? foodLogRepository,
    NutritionRepository? nutritionRepository,
  }) : _foodLogRepo = foodLogRepository ?? FoodLogRepository(),
       _nutritionRepo = nutritionRepository ?? NutritionRepository();

  // ── State ─────────────────────────────────────────────────────────────────
  List<FoodLogModel> _foodLogs = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool isLoading = false;
  bool isSaving = false;
  bool isSearching = false;
  bool manualMode = false;
  String? errorMessage;
  String? successMessage;

  DateTime _selectedDate = _midnight(DateTime.now());
  static DateTime _midnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Form fields ───────────────────────────────────────────────────────────
  String foodName = '';
  String calories = '';
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  DateTime get selectedDate => _selectedDate;
  List<FoodLogModel> get foodLogs => _foodLogs;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isToday => _selectedDate == _midnight(DateTime.now());
  bool get isFormValid =>
      foodName.trim().isNotEmpty && calories.trim().isNotEmpty;

  // Totals — computed from in-memory list via repository helper (no Firestore)
  int get totalCalories => _foodLogRepo.totalCalories(_foodLogs);
  double get totalProtein => _foodLogRepo.totalProtein(_foodLogs);
  double get totalCarbs => _foodLogRepo.totalCarbs(_foodLogs);
  double get totalFat => _foodLogRepo.totalFat(_foodLogs);

  // ── Date selection ────────────────────────────────────────────────────────
  Future<void> selectDate(DateTime date) async {
    final newDate = _midnight(date);
    if (newDate == _selectedDate) return;
    _selectedDate = newDate;
    notifyListeners();
    await loadFoodLogs(uid: _currentUidOrThrow());
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> loadFoodLogs({required String uid}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _foodLogs = await _foodLogRepo.getFoodLogs(uid, _selectedDate);
    } catch (e) {
      errorMessage = 'Failed to load food logs: $e';
      _foodLogs = [];
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────────────────
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

  // ── Select from search results ────────────────────────────────────────────
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

  void setManualMode(bool value) {
    manualMode = value;
    if (!value) _searchResults = [];
    notifyListeners();
  }

  // ── Form field updaters ───────────────────────────────────────────────────
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

  // ── CREATE ────────────────────────────────────────────────────────────────
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
      final logDate = isToday
          ? DateTime.now()
          : DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              12,
            );

      final log = FoodLogModel(
        foodLogID: '',
        foodLogName: foodName.trim(),
        calorieIntake: int.tryParse(calories.trim()) ?? 0,
        userId: uid,
        foodLogDate: logDate,
      );
      log.protein = protein;
      log.carbs = carbs;
      log.fats = fat;

      await _foodLogRepo.addFoodLog(uid, log);

      // Mutate in memory — no Firestore re-fetch (Bug #18 fix)
      _foodLogs.add(log);
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

  // ── UPDATE ────────────────────────────────────────────────────────────────
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

      // Update in memory — no Firestore re-fetch (Bug #18 fix)
      final idx = _foodLogs.indexWhere(
        (l) => l.foodLogID == existing.foodLogID,
      );
      if (idx != -1) _foodLogs[idx] = existing;
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

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<bool> deleteFoodLog({
    required String uid,
    required String foodLogID,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _foodLogRepo.deleteFoodLog(uid, foodLogID);

      // Remove in memory — no Firestore re-fetch (Bug #18 fix)
      _foodLogs.removeWhere((l) => l.foodLogID == foodLogID);
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

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Guard used by selectDate — uid must be passed in from outside since
  /// ViewModels never read FirebaseAuth directly.
  /// Call loadFoodLogs(uid: ...) directly from Views/other VMs instead.
  String _currentUidOrThrow() {
    throw StateError(
      'selectDate requires uid — call loadFoodLogs(uid: uid) directly '
      'or pass uid into selectDate(date, uid: uid).',
    );
  }
}
