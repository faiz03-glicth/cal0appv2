import '../../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:cal0appv2/models/tdee_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/models/dashboard_model.dart';
import 'package:cal0appv2/services/users/user_service.dart';
import 'package:cal0appv2/services/logs/foodlog_services.dart';

class DashboardViewModel extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;
  final FoodLogService _foodLogService = FoodLogService();
  final UserService _userService = UserService();

  DashboardModel? _dashboard;
  List<FoodLogModel> _foodLogs = [];
  UserModel? _user;
  bool isLoading = false;
  String? errorMessage;
  String _filter = 'daily'; // daily, monthly, yearly

  DashboardModel? get dashboard => _dashboard;
  List<FoodLogModel> get foodLogs => _foodLogs;
  UserModel? get user => _user;
  String get filter => _filter;

  // int get totalCalories =>
  //     _foodLogs.fold(0, (sum, log) => sum + int.tryParse(log.calorieIntake)!);

  //add safe getter to show empty list if food logs are not loaded yet
  int get totalCalories =>
      _foodLogs.fold(0, (s, l) => s + (int.tryParse(l.calorieIntake) ?? 0));

  double get totalProtein => _foodLogs.fold(0.0, (s, l) => s + l.protein);
  double get totalCarbs => _foodLogs.fold(0.0, (s, l) => s + l.carbs);
  double get totalFats => _foodLogs.fold(0.0, (s, l) => s + l.fats);

  int get calorieTarget {
    if (_user == null) return 2000;
    final birthYear = _user!.birthday.year;
    // final birthYear = _user!.birthday.year ?? (DateTime.now().year - 20);
    final age = DateTime.now().year - birthYear;
    final tdee = TDEEModel(
      gender: _user!.gender,
      activityLevel: _user!.activityLevel,
      goal: _user!.goal,
      age: age,
      weight: _user!.weight,
      height: _user!.height,
    );
    return tdee.calculateCalorieTarget().toInt();
  }

  int get bmr {
    if (_user == null) return 0;
    final age = DateTime.now().year - (_user!.birthday.year);
    final tdee = TDEEModel(
      gender: _user!.gender,
      activityLevel: _user!.activityLevel,
      goal: _user!.goal,
      age: age,
      weight: _user!.weight,
      height: _user!.height,
    );
    return tdee.calculateBMR().toInt();
  }

  int get tdee {
    if (_user == null) return 0;
    final age = DateTime.now().year - (_user!.birthday.year);
    final model = TDEEModel(
      gender: _user!.gender,
      activityLevel: _user!.activityLevel,
      goal: _user!.goal,
      age: age,
      weight: _user!.weight,
      height: _user!.height,
    );
    return model.calculateTDEE().toInt();
  }

  void setFilter(String value) {
    _filter = value;
    notifyListeners();
  }

  // ── Macro targets from TDEE macros() ─────────────────────────────────────
  Map<String, double> get macroTargets {
    if (_user == null) return {'protein': 150, 'carbs': 250, 'fat': 65};
    final age = DateTime.now().year - (_user!.birthday.year);
    final model = TDEEModel(
      gender: _user!.gender,
      activityLevel: _user!.activityLevel,
      goal: _user!.goal,
      age: age,
      weight: _user!.weight,
      height: _user!.height,
    );
    return model.calculateMacros();
  }

  Future<void> loadDashboard(String userId, {DateTime? date}) async {
    if (date != null) {
      _selectedDate = date;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.getUser(userId);
      _foodLogs = await _foodLogService.getFoodLogs(userId, _selectedDate);
    } catch (e) {
      errorMessage = e.toString();
      _foodLogs = [];
      isLoading = false;
      notifyListeners();
      return;
    }
    _dashboard = DashboardModel(
      analysisResult: '',
      nutrientStatus: _getNutrientStatus(),
      userId: userId,
      foodLog: '',
      scanLog: '',
      totalCalories: totalCalories,
      recentFoodLogs: _foodLogs.take(5).toList(),
      recentSupplements: [],
      selectedDate: _selectedDate,
    );
    isLoading = false;
    notifyListeners();
  }

  String _getNutrientStatus() {
    if (totalCalories == 0) return 'No data';
    if (totalCalories < 1200) return 'Under target';
    if (totalCalories > 3000) return 'Over target';
    return 'On track';
  }

  Future<void> refreshDashboard(String userId) => loadDashboard(userId);

  // ── CRUD operations ──────────────────────────────────────────────────────
  Future<void> addFoodLog(FoodLogModel log) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _foodLogService.addFoodLog(uid, log);
    await loadDashboard(uid); // refresh
  }

  Future<void> updateFoodLog(FoodLogModel log) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _foodLogService.updateFoodLog(uid, log);
    await loadDashboard(uid);
  }

  Future<void> deleteFoodLog(String foodLogID) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _foodLogService.deleteFoodLog(uid, foodLogID);
    await loadDashboard(uid);
  }
}
