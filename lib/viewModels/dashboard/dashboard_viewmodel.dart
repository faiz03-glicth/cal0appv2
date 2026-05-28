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
  String _loadedUid = '';

  // ── Getters ────────────────────────────────────────────────────────────
  UserModel? get user => _user;
  int get calorieTarget => _tdeeModel?.calorieTargetInt ?? 2000;
  int get bmr => _tdeeModel?.bmrInt ?? 0;
  int get tdee => _tdeeModel?.tdeeInt ?? 0;
  double get activityMult => _tdeeModel?.getActivityMultiplier() ?? 1.2;
  String get tdeeFormula => 'Mifflin-St Jeor';

  Map<String, double> get macroTargets =>
      _tdeeModel?.calculateMacros() ??
      {'protein': 150.0, 'carbs': 250.0, 'fat': 65.0};

  // ── Load ───────────────────────────────────────────────────────────────

  Future<void> loadDashboard(String uid) async {
    if (uid.isEmpty) return;

    // Only skip reload if already have data AND same uid
    if (_loadedUid == uid && _user != null) return;

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

  /// Force re-fetch — called after profile update.
  Future<void> refreshDashboard(String uid) async {
    _loadedUid = '';
    await loadDashboard(uid);
  }

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

    // Correct age calculation — accounts for whether birthday has passed yet
    final now = DateTime.now();
    final birthday = _user!.birthday;
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--; // birthday hasn't occurred this year yet
    }
    age = age.clamp(10, 100); // safety clamp

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
