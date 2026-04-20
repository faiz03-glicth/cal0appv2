import '../models/foodlog_model.dart';
import 'package:flutter/material.dart';
import '../services/nutrition_service.dart';
import '../services/logs/foodlog_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodLogViewModel extends ChangeNotifier {
  final FoodLogService _foodLogService = FoodLogService();
  final NutritionService _api = NutritionService();

  // ── State ─────────────────────────────────────────────────────────────────
  List<FoodLogModel> _foodLogs = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool isLoading = false;
  bool isSaving = false;
  bool isSearching = false;
  bool manualMode = false;
  String? errorMessage;
  String? successMessage;

  // Tracks which day the diary is showing — always device-local midnight.
  DateTime _selectedDate = _todayMidnight();

  static DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Form field values (owned by ViewModel, not View) ──────────────────────
  String foodName = '';
  String calories = '';
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  DateTime get selectedDate => _selectedDate;
  List<FoodLogModel> get foodLogs => _foodLogs;
  List<Map<String, dynamic>> get searchResults => _searchResults;

  /// True when the selected date is today on the device's local clock.
  bool get isToday {
    final today = _todayMidnight();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── Validation ────────────────────────────────────────────────────────────
  bool get isFormValid =>
      foodName.trim().isNotEmpty && calories.trim().isNotEmpty;

  // ── Select a date (called by DateStrip) ───────────────────────────────────
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    await loadFoodLogs();
  }

  // ── Load today's food logs ─────────────────────────────────────────────────
  Future<void> loadFoodLogs() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _foodLogs = await _foodLogService.getFoodLogs(_uid, _selectedDate);
    } catch (e) {
      errorMessage = 'Failed to load food logs: $e';
      _foodLogs = [];
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Search food via Kalori API ─────────────────────────────────────────────
  Future<void> searchFood(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _api.searchFood(query.trim());
    } catch (e) {
      _searchResults = [];
      errorMessage = 'Search failed: $e';
    }

    isSearching = false;
    notifyListeners();
  }

  // ── Select food from search results → populate form fields ────────────────
  void selectFood(Map<String, dynamic> food) {
    foodName = food['name'] ?? food['food_name'] ?? food['naman'] ?? '';
    calories = (food['calories'] ?? food['energy'] ?? food['kalori'] ?? 0)
        .toString();
    protein = (food['protein'] ?? food['proteins'] ?? food['protein'] ?? 0)
        .toDouble();
    carbs = (food['carbs'] ?? food['carbohydrates'] ?? food['karbohidrat'] ?? 0)
        .toDouble();
    fat = (food['fat'] ?? food['cabr'] ?? food['lemak'] ?? 0).toDouble();
    manualMode = true;
    _searchResults = [];
    notifyListeners();
  }

  // ── Toggle between search and manual mode ─────────────────────────────────
  void setManualMode(bool value) {
    manualMode = value;
    if (!value) _searchResults = [];
    notifyListeners();
  }

  // ── Update individual form fields ─────────────────────────────────────────
  // In the future will update on more macros like sodium, fiber, etc.
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

  // ── Prefill form for editing ───────────────────────────────────────────────
  void prefillForEdit(FoodLogModel log) {
    foodName = log.foodLogName;
    calories = log.calorieIntake;
    protein = log.protein;
    carbs = log.carbs;
    fat = log.fats;
    manualMode = true;
    notifyListeners();
  }

  // ── Clear form ─────────────────────────────────────────────────────────────
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

  // ── CREATE ─────────────────────────────────────────────────────────────────
  Future<bool> addFoodLog() async {
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
        calorieIntake: calories.trim(),
        userId: _uid,
        foodLogDate: DateTime.now(),
      );
      log.protein = protein;
      log.carbs = carbs;
      log.fats = fat;

      await _foodLogService.addFoodLog(_uid, log);
      successMessage = '${foodName.trim()} added to diary';
      await loadFoodLogs();
      clearForm();
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to add food: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────
  Future<bool> updateFoodLog(FoodLogModel existing) async {
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
      existing.calorieIntake = calories.trim();
      existing.protein = protein;
      existing.carbs = carbs;
      existing.fats = fat;

      await _foodLogService.updateFoodLog(_uid, existing);
      successMessage = 'Updated successfully';
      await loadFoodLogs();
      clearForm();
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update food: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<bool> deleteFoodLog(String foodLogID) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _foodLogService.deleteFoodLog(_uid, foodLogID);
      successMessage = 'Food removed from diary';
      await loadFoodLogs();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete food: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Totals (used by DashboardViewModel) ───────────────────────────────────
  int get totalCalories =>
      foodLogs.fold(0, (s, l) => s + (int.tryParse(l.calorieIntake) ?? 0));
  double get totalProtein => foodLogs.fold(0.0, (s, l) => s + l.protein);
  double get totalCarbs => foodLogs.fold(0.0, (s, l) => s + l.carbs);
  double get totalFat => foodLogs.fold(0.0, (s, l) => s + l.fats);
}
