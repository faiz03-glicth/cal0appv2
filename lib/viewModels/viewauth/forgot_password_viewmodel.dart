import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/repositories/auth_repository.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthRepository _authRepo;

  ForgotPasswordViewModel({AuthRepository? authRepository})
    : _authRepo = authRepository ?? AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;
  bool emailSent = false;

  Future<bool> sendResetEmail(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      errorMessage = 'Please enter a valid email address';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _authRepo.sendPasswordResetEmail(email.trim());
      successMessage = 'Password reset link sent to $email. Check your inbox.';
      emailSent = true;
      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _friendlyError(e.code);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
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

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Failed to send reset email. Please try again.';
    }
  }
}
