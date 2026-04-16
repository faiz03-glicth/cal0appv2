import 'package:flutter/material.dart';
import '/models/user_model.dart';
import 'package:cal0appv2/services/users/user_service.dart';

class UserViewModel extends ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _user;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  UserModel? get user => _user;

  Future<void> loadUser(String userId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.getUser(userId);
    } catch (e) {
      errorMessage = 'Failed to load user: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String userId,
    required String userName,
    required String userEmail,
    required String gender,
    required String goal,
    required String activityLevel,
    required DateTime birthday,
    required double weight,
    required double height,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (!_isValidEmail(userEmail)) {
        errorMessage = 'Invalid email format';
        isLoading = false;
        notifyListeners();
        return;
      }

      _user!
        ..userName = userName
        ..userEmail = userEmail
        ..gender = gender
        ..goal = goal
        ..activityLevel = activityLevel
        ..birthday = birthday
        ..weight = weight
        ..height = height;

      await _userService.updateUser(_user!);
      successMessage = 'Profile updated successfully';
    } catch (e) {
      errorMessage = 'Failed to update profile: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> updatePassword(String userId, String newPassword) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (!_isValidPassword(newPassword)) {
        errorMessage = 'Password must be at least 6 characters';
        isLoading = false;
        notifyListeners();
        return;
      }
      await _userService.updatePassword(userId, newPassword);
      successMessage = 'Password updated successfully';
    } catch (e) {
      errorMessage = 'Failed to update password: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  bool _isValidPassword(String password) => password.length >= 6;

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
