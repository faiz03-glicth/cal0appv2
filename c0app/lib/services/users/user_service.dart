import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:c0app/models/user_model.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createUser(UserModel user) =>
      _db.collection('users').doc(user.userId).set(user.toMap());

  Future<UserModel?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  Future<void> updateUser(UserModel user) =>
      _db.collection('users').doc(user.userId).update(user.toMap());

  Future<void> updatePassword(String userId, String newPassword) =>
      _auth.currentUser!.updatePassword(newPassword);
}
