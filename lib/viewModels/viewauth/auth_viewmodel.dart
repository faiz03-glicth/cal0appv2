import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepo;

  // Optional callbacks invoked on sign-out to let other VMs clear themselves.
  // Registered from main.dart after all providers are ready.
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

  /// Signs the user out. Returns true on success.
  /// On failure (e.g. no network), sets [errorMessage] and returns false —
  /// matches UAT 3.2 (Unsuccessful Logout, no internet connection).
  Future<bool> signOut() async {
    errorMessage = null;
    try {
      // Clear all dependent VMs before signing out
      for (final cb in _signOutCallbacks) {
        cb();
      }
      await _authRepo.signOut();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (_) {
      errorMessage = '503 Service Unavailable. Logout failed due to network issue';
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = '503 Service Unavailable. Logout failed due to network issue';
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
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      default:
        return 'Authentication error: $code';
    }
  }
}