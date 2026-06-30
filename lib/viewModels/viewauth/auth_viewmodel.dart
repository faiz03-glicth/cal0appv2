import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepo;

  final List<VoidCallback> _signOutCallbacks = [];

  AuthViewModel({AuthRepository? authRepository})
    : _authRepo = authRepository ?? AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  String? get currentUid => _authRepo.currentUid;
  bool get isSignedIn => _authRepo.isSignedIn;
  Stream<User?> get authStateChanges => _authRepo.authStateChanges;

  /// Register a callback to run on sign-out (e.g. vm.clearForLogout).
  void addSignOutCallback(VoidCallback cb) => _signOutCallbacks.add(cb);

  Future<bool> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uid = await _authRepo.signIn(email, password);
      isLoading = false;
      notifyListeners();
      return uid != null;
    } on FirebaseAuthException catch (e) {
      errorMessage = _friendlyAuthError(e.code);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Sign in failed. Please try again.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    // Clear all dependent VMs before signing out
    for (final cb in _signOutCallbacks) {
      cb();
    }
    await _authRepo.signOut();
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        // Matches STD TC002_02 (Login with invalid inputs) documented
        // expected result verbatim.
        return 'User are not registered';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      default:
        return 'Authentication error: $code';
    }
  }
}
