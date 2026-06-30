import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/report_model.dart';

class ReportService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference get _col => _db.collection('reports');

  // ── Create (user-side: submit a report) ─────────────────────────────────

  /// Persists a new report document to Firestore.
  /// Generates a reportId via uuid if one is not already set.
  Future<void> addReport(ReportModel report) async {
    final id = report.reportId.isEmpty ? _uuid.v4() : report.reportId;
    report.reportId = id;
    await _col.doc(id).set(report.toMap());
  }

  // ── Read (admin-side: view user report) ─────────────────────────────────

  /// All reports across all users, most recent first.
  /// Used by UC012 TC012_01 (admin "User Report" section).
  Future<List<ReportModel>> getAllReports({int limit = 100}) async {
    final snap = await _col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => ReportModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  /// Reports submitted by a single user (e.g. for a "my reports" view).
  Future<List<ReportModel>> getReportsForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs
        .map((d) => ReportModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<ReportModel?> getReport(String reportId) async {
    final doc = await _col.doc(reportId).get();
    return doc.exists
        ? ReportModel.fromMap(doc.data() as Map<String, dynamic>)
        : null;
  }

  // ── Update / Delete (admin-side: manage report) ─────────────────────────

  Future<void> updateReport(ReportModel report) =>
      _col.doc(report.reportId).update(report.toMap());

  Future<void> deleteReport(String reportId) => _col.doc(reportId).delete();
}
