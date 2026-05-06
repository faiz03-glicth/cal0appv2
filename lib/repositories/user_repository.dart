import 'package:cal0appv2/models/user_model.dart';
import 'package:cal0appv2/services/users/user_service.dart';

/// Repository for user profile data.
class UserRepository {
  final UserService _userService;

  UserRepository({UserService? userService})
    : _userService = userService ?? UserService();

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetches a user profile from Firestore by uid.
  /// Returns null if the document does not exist.
  Future<UserModel?> getUser(String uid) => _userService.getUser(uid);

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Persists a new user document to Firestore.
  /// Called once after registration.
  Future<void> createUser(UserModel user) => _userService.createUser(user);

  /// Updates an existing user document in Firestore.
  Future<void> updateUser(UserModel user) => _userService.updateUser(user);

  /// Updates the user profile fields individually without requiring a full
  /// UserModel — useful for partial edits from the profile screen.
  Future<void> updateProfile({
    required String uid,
    required String userName,
    required String userEmail,
    required String gender,
    required String goal,
    required String activityLevel,
    required DateTime birthday,
    required double weight,
    required double height,
  }) async {
    final existing = await _userService.getUser(uid);
    if (existing == null) return;

    final updated = UserModel(
      userId: uid,
      userName: userName,
      userEmail: userEmail,
      // userPassword: '', // Password updates are handled separately via updatePassword()
      gender: gender,
      goal: goal,
      activityLevel: activityLevel,
      birthday: birthday,
      weight: weight,
      height: height,
    );

    await _userService.updateUser(updated);
  }

  // ── Auth-adjacent ─────────────────────────────────────────────────────────

  /// Updates the Firebase Auth password for the current user.
  /// Separate from profile updates since it hits Firebase Auth, not Firestore.
  Future<void> updatePassword(String uid, String newPassword) =>
      _userService.updatePassword(uid, newPassword);
}
