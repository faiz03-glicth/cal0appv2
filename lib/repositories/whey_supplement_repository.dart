// lib/repositories/whey_supplement_repository.dart
//
// Manages the dedicated `whey_supplements` Firestore collection.
//
// Collection path:  whey_supplements/{docId}
// Indexed fields:   userId, loggedAt, isSpiked, brandName
//
// Firestore rules (add to your rules file):
//   match /whey_supplements/{docId} {
//     allow read, write: if request.auth != null
//                        && request.auth.uid == resource.data.userId;
//     allow create: if request.auth != null
//                   && request.auth.uid == request.resource.data.userId;
//   }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/whey/whey_supplement_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class WheySupplementRepository {
  static const _collection = 'whey_supplements';

  final FirebaseFirestore _db;

  WheySupplementRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Save a new supplement scan. Returns the document ID on success.
  Future<String?> addSupplement(WheySupplementModel model) async {
    try {
      await _ref.doc(model.id).set(model.toJson());
      LogService.info(
        'WheyRepo: saved ${model.brandName} ${model.productName} (${model.id})',
      );
      return model.id;
    } catch (e, st) {
      LogService.error('WheyRepo: addSupplement failed', e, st);
      return null;
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// All supplements for a user, newest first.
  Future<List<WheySupplementModel>> getSupplementsForUser(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snap = await _ref
          .where('userId', isEqualTo: userId)
          .orderBy('loggedAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((d) => WheySupplementModel.fromJson(d.data()))
          .toList();
    } catch (e, st) {
      LogService.error('WheyRepo: getSupplementsForUser failed', e, st);
      return [];
    }
  }

  /// Stream supplements for a user — use in UI with StreamBuilder / watch.
  Stream<List<WheySupplementModel>> streamSupplementsForUser(
    String userId, {
    int limit = 50,
  }) {
    return _ref
        .where('userId', isEqualTo: userId)
        .orderBy('loggedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => WheySupplementModel.fromJson(d.data()))
              .toList(),
        );
  }

  /// Only spiked / suspicious supplements for a user.
  Future<List<WheySupplementModel>> getSpikedSupplements(String userId) async {
    try {
      final snap = await _ref
          .where('userId', isEqualTo: userId)
          .where('isSpiked', isEqualTo: true)
          .orderBy('loggedAt', descending: true)
          .get();

      return snap.docs
          .map((d) => WheySupplementModel.fromJson(d.data()))
          .toList();
    } catch (e, st) {
      LogService.error('WheyRepo: getSpikedSupplements failed', e, st);
      return [];
    }
  }

  /// Supplements by brand name (case-sensitive Firestore match).
  Future<List<WheySupplementModel>> getByBrand(
    String userId,
    String brandName,
  ) async {
    try {
      final snap = await _ref
          .where('userId', isEqualTo: userId)
          .where('brandName', isEqualTo: brandName)
          .orderBy('loggedAt', descending: true)
          .get();

      return snap.docs
          .map((d) => WheySupplementModel.fromJson(d.data()))
          .toList();
    } catch (e, st) {
      LogService.error('WheyRepo: getByBrand failed', e, st);
      return [];
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<bool> deleteSupplement(String docId) async {
    try {
      await _ref.doc(docId).delete();
      LogService.info('WheyRepo: deleted $docId');
      return true;
    } catch (e, st) {
      LogService.error('WheyRepo: deleteSupplement failed', e, st);
      return false;
    }
  }
}
