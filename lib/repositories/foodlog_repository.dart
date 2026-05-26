// lib/repositories/foodlog_repository.dart
import 'package:cal0appv2/models/logging/foodlog_model.dart';
import 'package:cal0appv2/services/logs/foodlog_services.dart';

class FoodLogRepository {
  final FoodLogService _foodLogService;

  FoodLogRepository({FoodLogService? foodLogService})
    : _foodLogService = foodLogService ?? FoodLogService();

  Future<List<FoodLogModel>> getFoodLogs(String uid, DateTime date) =>
      _foodLogService.getFoodLogs(uid, date);

  /// All logs for the unified history view
  Future<List<FoodLogModel>> getAllFoodLogs(String uid, {int limit = 100}) =>
      _foodLogService.getAllFoodLogs(uid, limit: limit);

  Future<void> addFoodLog(String uid, FoodLogModel log) =>
      _foodLogService.addFoodLog(uid, log);

  Future<void> updateFoodLog(String uid, FoodLogModel log) =>
      _foodLogService.updateFoodLog(uid, log);

  Future<void> deleteFoodLog(String uid, String foodLogID) =>
      _foodLogService.deleteFoodLog(uid, foodLogID);

  int totalCalories(List<FoodLogModel> logs) =>
      logs.fold(0, (s, l) => s + l.calorieIntake);

  double totalProtein(List<FoodLogModel> logs) =>
      logs.fold(0.0, (s, l) => s + l.protein);

  double totalCarbs(List<FoodLogModel> logs) =>
      logs.fold(0.0, (s, l) => s + l.carbs);

  double totalFat(List<FoodLogModel> logs) =>
      logs.fold(0.0, (s, l) => s + l.fats);
}
