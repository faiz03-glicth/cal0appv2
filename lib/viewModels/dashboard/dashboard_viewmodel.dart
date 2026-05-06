import 'package:flutter/material.dart';
import 'package:cal0appv2/models/user_model.dart';
import 'package:cal0appv2/models/tdee_model.dart';
import 'package:cal0appv2/models/dashboard_model.dart';
import 'package:cal0appv2/repositories/user_repository.dart';

/// DashboardViewModel — owns ONLY the user profile and derived TDEE targets.
/// Food log data lives in FoodLogViewModel (Bug #7 fix).
/// No Firebase, no services — only repositories (Bug #17 fix).
class DashboardViewModel extends ChangeNotifier {
  final UserRepository _userRepo;

  DashboardViewModel({UserRepository? userRepository})
    : _userRepo = userRepository ?? UserRepository();

  // ── State ─────────────────────────────────────────────────────────────────
  UserModel? _user;
  DashboardModel? _dashboard;
  TDEEModel? _tdeeModel; // Bug #8 fix — built once, not per getter
  bool isLoading = false;
  String? errorMessage;
  String _filter = 'daily';

  // ── Getters ───────────────────────────────────────────────────────────────
  UserModel? get user => _user;
  DashboardModel? get dashboard => _dashboard;
  String get filter => _filter;

  void setFilter(String value) {
    _filter = value;
    notifyListeners();
  }

  // ── TDEE getters — all read from single _tdeeModel instance (Bug #8 fix) ──

  int get calorieTarget => _tdeeModel?.calculateCalorieTarget().toInt() ?? 2000;
  int get bmr => _tdeeModel?.calculateBMR().toInt() ?? 0;
  int get tdee => _tdeeModel?.calculateTDEE().toInt() ?? 0;

  Map<String, double> get macroTargets =>
      _tdeeModel?.calculateMacros() ??
      {'protein': 150.0, 'carbs': 250.0, 'fat': 65.0};

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Loads the user profile and builds the TDEE model.
  /// Does NOT fetch food logs — FoodLogViewModel owns that (Bug #7 fix).
  /// Does NOT double-read Firestore on tab open (Bug #17 fix).
  Future<void> loadDashboard(String uid, {DateTime? date}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _user = await _userRepo.getUser(uid);
      _buildTdeeModel(); // Bug #8 fix — one instance built here

      _dashboard = DashboardModel(
        analysisResult: '',
        nutrientStatus: _getNutrientStatus(),
        userId: uid,
        foodLog: '',
        scanLog: '',
        totalCalories: 0, // totals come from FoodLogViewModel, not here
        recentFoodLogs: [],
        recentSupplements: [],
        selectedDate: date ?? DateTime.now(),
      );
    } catch (e) {
      errorMessage = 'Failed to load dashboard: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshDashboard(String uid) => loadDashboard(uid);

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Builds a single TDEEModel from the loaded user.
  /// Called once in loadDashboard — not on every getter access (Bug #8 fix).
  void _buildTdeeModel() {
    if (_user == null) {
      _tdeeModel = null;
      return;
    }
    final age = DateTime.now().year - _user!.birthday.year;
    _tdeeModel = TDEEModel(
      gender: _user!.gender,
      activityLevel: _user!.activityLevel,
      goal: _user!.goal,
      age: age,
      weight: _user!.weight,
      height: _user!.height,
    );
  }

  String _getNutrientStatus() {
    // Status is now based on calorieTarget since food totals
    // are owned by FoodLogViewModel
    if (_user == null) return 'No data';
    return 'On track';
  }
}
