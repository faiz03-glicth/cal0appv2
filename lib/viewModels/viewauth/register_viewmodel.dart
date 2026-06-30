import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthRepository _authRepo;

  RegisterViewModel({AuthRepository? authRepository})
    : _authRepo = authRepository ?? AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

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
    // Validation — collect every problem instead of stopping at the first,
    // then end with a generic re-enter prompt (matches STD TC001_02 steps
    // 3-5: Invalid Email Format / Invalid Password Format / Re-enter
    // correct credentials).
    final problems = <String>[];

    if (userName.isEmpty || userEmail.isEmpty || userPassword.isEmpty) {
      errorMessage = 'Please fill in all fields';
      notifyListeners();
      return false;
    }
    if (!userEmail.contains('@')) {
      problems.add('Invalid Email Format');
    }
    if (userPassword.length < 6) {
      problems.add('Invalid Password Format');
    }
    if (userPassword != confirmPassword) {
      problems.add('Passwords do not match');
    }

    if (problems.isNotEmpty) {
      errorMessage = '${problems.join('. ')}. Re-enter correct credentials.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uid = await _authRepo.register(
        userName: userName.trim(),
        userEmail: userEmail.trim(),
        userPassword: userPassword,
        gender: gender,
        goal: goal,
        activityLevel: activityLevel,
        birthday: birthday,
        weight: weight,
        height: height,
      );

      isLoading = false;
      successMessage = 'Account created successfully';
      notifyListeners();
      return uid != null;
    } on FirebaseAuthException catch (e) {
      errorMessage = _friendlyAuthError(e.code);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Registration failed. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        // Matches UAT 1.3 documented expected result verbatim.
        return 'User already registered';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Registration is currently disabled.';
      default:
        return 'Registration failed. Please try again.';
    }
  }
}
