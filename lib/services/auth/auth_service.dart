import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register — creates Auth user AND saves to Firestore
  Future<User?> register({
    required String userName,
    required String userEmail,
    required String userPassword,
    required String gender,
    required String goal,
    required String activityLevel,
    required DateTime birthday,
    required double weight,
    required double height,
  }) async {
    // Step 1 — create Firebase Auth user
    final result = await _auth.createUserWithEmailAndPassword(
      email: userEmail,
      password: userPassword,
    );

    final user = result.user;
    if (user == null) return null;

    // Step 2 — save user data to Firestore
    final userModel = UserModel(
      userId: user.uid,
      userName: userName,
      userEmail: userEmail,
      userPassword: '',
      gender: gender,
      goal: goal,
      activityLevel: activityLevel,
      birthday: birthday,
      weight: weight,
      height: height,
    );

    await _db.collection('users').doc(user.uid).set(userModel.toMap());

    return user;
  }

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<void> signOut() => _auth.signOut();
}
