import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/services/auth/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
    : _authService = authService ?? AuthService();

  // ── Auth state ────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// The currently signed-in user's uid, or null if signed out.
  String? get currentUid => _authService.currentUid;

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

  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);

  Future<String?> signIn(String email, String password) async {
    final user = await _authService.signIn(email, password);
    return user?.uid;
  }

  /// Signs the current user out and clears secure config keys.
  Future<void> signOut() => _authService.signOut();
}
