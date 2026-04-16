import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/services/auth/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email, password);
      isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        default:
          errorMessage = e.message ?? 'Login failed';
      }
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String userName,
    required String userEmail,
    required String userPassword,
    required String confirmPassword,
    required String gender,
    required String goal,
    required String activityLevel,
    required DateTime birthday,
    required double weight,
    required double height,
  }) async {
    // Validation
    if (userName.isEmpty || userEmail.isEmpty || userPassword.isEmpty) {
      errorMessage = 'Please fill in all fields';
      notifyListeners();
      return false;
    }
    if (!userEmail.contains('@')) {
      errorMessage = 'Invalid email format';
      notifyListeners();
      return false;
    }
    if (userPassword.length < 6) {
      errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }
    if (userPassword != confirmPassword) {
      errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(
        userName: userName,
        userEmail: userEmail,
        userPassword: userPassword,
        gender: gender,
        goal: goal,
        activityLevel: activityLevel,
        birthday: birthday,
        weight: weight,
        height: height,
      );
      successMessage = 'Account created successfully!';
      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        default:
          errorMessage = e.message ?? 'Registration failed';
      }
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
