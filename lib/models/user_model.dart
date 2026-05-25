import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/health/health_condition.dart';

class UserModel {
  String _userId, _userName, _userEmail, _gender, _goal, _activityLevel;
  DateTime? _birthday;
  double? _weight, _height;

  /// Health conditions the user has declared in their profile.
  List<HealthCondition> _healthConditions;

  UserModel({
    required String userId,
    required String userName,
    required String userEmail,
    required String gender,
    required String goal,
    required String activityLevel,
    required double weight,
    required double height,
    DateTime? birthday,
    List<HealthCondition>? healthConditions,
  }) : _userId = userId,
       _userName = userName,
       _userEmail = userEmail,
       _gender = gender,
       _goal = goal,
       _activityLevel = activityLevel,
       _weight = weight,
       _height = height,
       _birthday = birthday,
       _healthConditions = healthConditions ?? [];

  // ── Getters ───────────────────────────────────────────────────────────
  String get userId => _userId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get gender => _gender;
  String get goal => _goal;
  String get activityLevel => _activityLevel;
  DateTime get birthday => _birthday ?? DateTime(2000, 1, 1);
  double get weight => _weight ?? 70.0;
  double get height => _height ?? 170.0;
  List<HealthCondition> get healthConditions =>
      List.unmodifiable(_healthConditions);

  bool get hasHealthConditions => _healthConditions.isNotEmpty;

  // ── Setters ───────────────────────────────────────────────────────────
  set userId(String v) => _userId = v;
  set userName(String v) => _userName = v;
  set userEmail(String v) => _userEmail = v;
  set gender(String v) => _gender = v;
  set goal(String v) => _goal = v;
  set activityLevel(String v) => _activityLevel = v;
  set birthday(DateTime v) => _birthday = v;
  set weight(double v) => _weight = v;
  set height(double v) => _height = v;
  set healthConditions(List<HealthCondition> v) =>
      _healthConditions = List.of(v);

  // ── Age ───────────────────────────────────────────────────────────────
  int? get age {
    final today = DateTime.now();
    int calculatedAge = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  // ── Serialisation ──────────────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Parse healthConditions from stored list of string keys
    final rawConditions = map['healthConditions'];
    final conditions = <HealthCondition>[];
    if (rawConditions is List) {
      for (final item in rawConditions) {
        final cond = HealthCondition.fromKey(item.toString());
        if (cond != null) conditions.add(cond);
      }
    }

    return UserModel(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      gender: map['gender'] ?? 'male',
      goal: map['goal'] ?? 'maintain',
      activityLevel: map['activityLevel'] ?? 'sedentary',
      birthday: map['birthday'] != null
          ? (map['birthday'] is Timestamp
                ? (map['birthday'] as Timestamp).toDate()
                : DateTime.tryParse(map['birthday'].toString()) ??
                      DateTime(2000))
          : DateTime(2000),
      weight: (map['weight'] as num?)?.toDouble() ?? 70.0,
      height: (map['height'] as num?)?.toDouble() ?? 170.0,
      healthConditions: conditions,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'gender': gender,
    'goal': goal,
    'activityLevel': activityLevel,
    'birthday': birthday.toIso8601String(),
    'weight': weight,
    'height': height,
    // Store as list of string keys for easy Firestore querying
    'healthConditions': _healthConditions.map((c) => c.key).toList(),
  };
}
