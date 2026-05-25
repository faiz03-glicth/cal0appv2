import 'package:flutter/material.dart';
import 'package:cal0appv2/models/health/health_condition.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/health_warning_repository.dart';
import 'package:cal0appv2/repositories/user_repository.dart';

class HealthWarningViewModel extends ChangeNotifier {
  final HealthWarningRepository _repo;
  final UserRepository _userRepo;

  HealthWarningViewModel({
    HealthWarningRepository? repo,
    UserRepository? userRepo,
  }) : _repo = repo ?? HealthWarningRepository(),
       _userRepo = userRepo ?? UserRepository();

  // ── Cached conditions ──────────────────────────────────────────────────

  List<HealthCondition> _conditions = [];
  bool _loaded = false;

  List<HealthCondition> get conditions => List.unmodifiable(_conditions);
  bool get hasConditions => _conditions.isNotEmpty;

  // ── Load once per session when user profile is known ──────────────────

  Future<void> loadConditions(String uid) async {
    if (uid.isEmpty) return;
    final user = await _userRepo.getUser(uid);
    _conditions = user?.healthConditions ?? [];
    _loaded = true;
    notifyListeners();
  }

  // ── Update conditions (called from UserViewModel after profile save) ───

  void updateConditions(List<HealthCondition> conditions) {
    _conditions = List.of(conditions);
    _loaded = true;
    notifyListeners();
  }

  // ── Main entry point used by food_sheet and scan_confirm_sheet ─────────

  /// Analyses [nutrition] against cached conditions.
  /// Returns [] if the user has no health conditions or no thresholds met.
  List<HealthWarning> analyzeFood(FoodNutritionSnapshot nutrition) {
    if (!_loaded || _conditions.isEmpty) return [];
    return _repo.analyseWithConditions(_conditions, nutrition);
  }

  /// Convenience overload that builds a snapshot from a FoodLogModel.
  List<HealthWarning> analyzeLog(FoodLogModel log) {
    return analyzeFood(
      FoodNutritionSnapshot(
        foodName: log.foodLogName,
        calories: log.calorieIntake,
        protein: log.protein,
        carbs: log.carbs,
        fat: log.fats,
        sugar: log.sugar,
        sodium: log.sodium,
      ),
    );
  }

  /// Convenience overload for inline nutrition values from a form.
  List<HealthWarning> analyzeValues({
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double sugar = 0,
    double sodium = 0,
  }) {
    return analyzeFood(
      FoodNutritionSnapshot(
        foodName: foodName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        sugar: sugar,
        sodium: sodium,
      ),
    );
  }
}
