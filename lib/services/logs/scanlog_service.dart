import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/scanlog_model.dart';

class ScanLogService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference _col(String userId) =>
      _db.collection('users').doc(userId).collection('scanLogs');

  Future<void> saveScanLog(String userId, ScanLogModel log) async {
    final id = log.supplementId.isEmpty ? _uuid.v4() : log.supplementId;
    await _col(userId).doc(id).set({...log.toMap(), 'supplementId': id});
  }

  Future<List<ScanLogModel>> getScanLogs(String userId) async {
    final snap = await _col(
      userId,
    ).orderBy('scanTimestamp', descending: true).limit(50).get();
    return snap.docs
        .map((d) => ScanLogModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteScanLog(String userId, String supplementId) =>
      _col(userId).doc(supplementId).delete();
}
