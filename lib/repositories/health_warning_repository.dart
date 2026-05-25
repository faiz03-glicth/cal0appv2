import 'package:cal0appv2/models/health/health_condition.dart';
import 'package:cal0appv2/repositories/user_repository.dart';
import 'package:cal0appv2/services/health/health_warning_service.dart';

class HealthWarningRepository {
  final HealthWarningService _service;
  final UserRepository _userRepo;

  HealthWarningRepository({
    HealthWarningService? service,
    UserRepository? userRepo,
  }) : _service = service ?? HealthWarningService(),
       _userRepo = userRepo ?? UserRepository();

  /// Analyse [nutrition] against the health conditions stored for [uid].
  ///
  /// Returns an empty list when:
  ///   - the user has no health conditions declared, or
  ///   - no nutritional thresholds are exceeded.
  Future<List<HealthWarning>> analyseForUser(
    String uid,
    FoodNutritionSnapshot nutrition,
  ) async {
    if (uid.isEmpty) return [];
    final user = await _userRepo.getUser(uid);
    if (user == null || user.healthConditions.isEmpty) return [];
    return _service.analyse(nutrition, user.healthConditions);
  }

  /// Synchronous version — caller already has the condition list.
  /// Used by HealthWarningViewModel which caches conditions after loading.
  List<HealthWarning> analyseWithConditions(
    List<HealthCondition> conditions,
    FoodNutritionSnapshot nutrition,
  ) {
    if (conditions.isEmpty) return [];
    return _service.analyse(nutrition, conditions);
  }
}
