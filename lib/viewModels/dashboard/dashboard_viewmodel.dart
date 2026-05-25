import 'package:flutter/material.dart';
import 'package:cal0appv2/models/user_model.dart';
import 'package:cal0appv2/models/tdee_model.dart';
import 'package:cal0appv2/repositories/user_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final UserRepository _userRepo;

  DashboardViewModel({UserRepository? userRepository})
    : _userRepo = userRepository ?? UserRepository();

  // ── State ──────────────────────────────────────────────────────────────
  UserModel? _user;
  TDEEModel? _tdeeModel;
  bool isLoading = false;
  String? errorMessage;

  // The uid we loaded the user for — used to detect account switches.
  String _loadedUid = '';

  // ── Getters ────────────────────────────────────────────────────────────
  UserModel? get user => _user;

  int get calorieTarget => _tdeeModel?.calculateCalorieTarget().toInt() ?? 2000;
  int get bmr => _tdeeModel?.calculateBMR().toInt() ?? 0;
  int get tdee => _tdeeModel?.calculateTDEE().toInt() ?? 0;

  Map<String, double> get macroTargets =>
      _tdeeModel?.calculateMacros() ??
      {'protein': 150.0, 'carbs': 250.0, 'fat': 65.0};

  // ── Load ───────────────────────────────────────────────────────────────

  Future<void> loadDashboard(String uid) async {
    if (uid.isEmpty) return;

    // Skip Firestore if we already have data for this user
    if (_loadedUid == uid && _user != null) {
      return; // already loaded — TDEE targets are still valid
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _user = await _userRepo.getUser(uid);
      _loadedUid = uid;
      _buildTdeeModel();
    } catch (e) {
      errorMessage = 'Failed to load dashboard: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  /// Force re-fetch — called after the user updates their profile.
  Future<void> refreshDashboard(String uid) async {
    _loadedUid = ''; // invalidate cache
    await loadDashboard(uid);
  }

  /// Clears cached user on logout so the next login fetches fresh data.
  void clearForLogout() {
    _user = null;
    _tdeeModel = null;
    _loadedUid = '';
    errorMessage = null;
    notifyListeners();
  }

  // ── Private ────────────────────────────────────────────────────────────

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
}
