import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/services/auth/auth_service.dart';

/// Single access point for all authentication operations.
/// ViewModels must never import firebase_auth or AuthService directly —
/// they call this repository only.
class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
    : _authService = authService ?? AuthService();

  // ── Auth state ────────────────────────────────────────────────────────────

  /// Stream of auth state changes. Listen in AuthViewModel to react to
  /// sign-in / sign-out events automatically.
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// The currently signed-in user's uid, or null if signed out.
  String? get currentUid => _authService.currentUid;

  /// True when a user is signed in.
  bool get isSignedIn => currentUid != null;

  // ── Operations ────────────────────────────────────────────────────────────

  /// Registers a new user and saves their profile to Firestore.
  /// Throws [FirebaseAuthException] on failure — caller should handle.
  Future<String?> register({
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
    final user = await _authService.register(
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
    return user?.uid;
  }

  /// Signs in with email and password.
  /// Returns the uid on success, null on failure.
  Future<String?> signIn(String email, String password) async {
    final user = await _authService.signIn(email, password);
    return user?.uid;
  }

  /// Signs the current user out and clears secure config keys.
  Future<void> signOut() => _authService.signOut();
}
