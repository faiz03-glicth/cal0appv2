import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/foodlog_model.dart';

class FoodLogService {
  final _db = FirebaseFirestore.instance;

  Future<List<FoodLogModel>> getFoodLogs(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('foodLogs')
        .orderBy('foodLogDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FoodLogModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> addFoodLog(String userId, FoodLogModel log) => _db
      .collection('users')
      .doc(userId)
      .collection('foodLogs')
      .doc(log.foodLogID.toString())
      .set(log.toMap());

  Future<void> deleteFoodLog(String userId, String foodLogID) => _db
      .collection('users')
      .doc(userId)
      .collection('foodLogs')
      .doc(foodLogID.toString())
      .delete();

  Future<void> updateFoodLog(String userId, FoodLogModel log) => _db
      .collection('users')
      .doc(userId)
      .collection('foodLogs')
      .doc(log.foodLogID.toString())
      .update(log.toMap());
}
