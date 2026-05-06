import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/services/logs/foodlog_services.dart';

/// Single access point for all food log operations.
/// ViewModels must never import FoodLogService, FirebaseFirestore,
/// or FirebaseAuth directly — they call this repository only.
class FoodLogRepository {
  final FoodLogService _foodLogService;

  FoodLogRepository({FoodLogService? foodLogService})
    : _foodLogService = foodLogService ?? FoodLogService();

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all food logs for [uid] on the given [date].
  /// Date is normalised to midnight so time component is ignored.
  Future<List<FoodLogModel>> getFoodLogs(String uid, DateTime date) =>
      _foodLogService.getFoodLogs(uid, date);

  // ── Create ────────────────────────────────────────────────────────────────

  /// Saves a new food log entry. A uuid is assigned if [log.foodLogID] is empty.
  Future<void> addFoodLog(String uid, FoodLogModel log) =>
      _foodLogService.addFoodLog(uid, log);

  // ── Update ────────────────────────────────────────────────────────────────

  /// Overwrites an existing food log document with the updated model.
  Future<void> updateFoodLog(String uid, FoodLogModel log) =>
      _foodLogService.updateFoodLog(uid, log);

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes a single food log by its [foodLogID].
  Future<void> deleteFoodLog(String uid, String foodLogID) =>
      _foodLogService.deleteFoodLog(uid, foodLogID);

  // ── Aggregates (computed locally — no extra Firestore reads) ──────────────

  /// Sums calories across a list of logs already in memory.
  /// Use this instead of re-fetching from Firestore for totals.
  int totalCalories(List<FoodLogModel> logs) =>
      logs.fold(0, (sum, log) => sum + log.calorieIntake);

  double totalProtein(List<FoodLogModel> logs) =>
      logs.fold(0.0, (sum, log) => sum + log.protein);

  double totalCarbs(List<FoodLogModel> logs) =>
      logs.fold(0.0, (sum, log) => sum + log.carbs);

  double totalFat(List<FoodLogModel> logs) =>
      logs.fold(0.0, (sum, log) => sum + log.fats);
}
