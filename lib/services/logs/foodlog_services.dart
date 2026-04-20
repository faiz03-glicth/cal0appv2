import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/foodlog_model.dart';

class FoodLogService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // collection path per user: users/{userId}/foodLogs/{foodLogId}
  CollectionReference _col(String userId) =>
      _db.collection('users').doc(userId).collection('foodLogs');

  // CREATE, UPDATE, DELETE operations
  Future<void> addFoodLog(String userId, FoodLogModel log) async {
    if (log.foodLogID.isEmpty) {
      log.foodLogID = _uuid.v4();
    }
    await _col(userId).doc(log.foodLogID).set(log.toMap());
  }

  // READ — today's logs ───────────────────────────────────────────────────
  Future<List<FoodLogModel>> getFoodLogs(String userId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _col(userId)
        .where('foodLogDate', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('foodLogDate', isLessThan: end.toIso8601String())
        .orderBy('foodLogDate', descending: false)
        .get();

    return snap.docs
        .map((d) => FoodLogModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateFoodLog(String userId, FoodLogModel log) => _db
      .collection('users')
      .doc(userId)
      .collection('foodLogs')
      .doc(log.foodLogID.toString())
      .update(log.toMap());

  Future<void> deleteFoodLog(String userId, String foodLogID) => _db
      .collection('users')
      .doc(userId)
      .collection('foodLogs')
      .doc(foodLogID.toString())
      .delete();
}
