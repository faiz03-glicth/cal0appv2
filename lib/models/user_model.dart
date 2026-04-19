class UserModel {
  String _userId,
      _userName,
      _userEmail,
      _userPassword,
      _gender,
      _goal,
      _activityLevel;
  DateTime? _birthday;
  double? _weight, _height;

  UserModel({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPassword,
    required String gender,
    required String goal,
    required String activityLevel,
    required double weight,
    required double height,
    DateTime? birthday,
  }) : _userId = userId,
       _userName = userName,
       _userEmail = userEmail,
       _userPassword = userPassword,
       _gender = gender,
       _goal = goal,
       _activityLevel = activityLevel,
       _weight = weight,
       _height = height,
       _birthday = birthday;

  String get userId => _userId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPassword => _userPassword;
  String get gender => _gender;
  String get goal => _goal;
  String get activityLevel => _activityLevel;
  DateTime get birthday => _birthday!;
  double get weight => _weight!;
  double get height => _height!;

  set userId(String value) => _userId = value;
  set userName(String value) => _userName = value;
  set userEmail(String value) => _userEmail = value;
  set userPassword(String value) => _userPassword = value;
  set gender(String value) => _gender = value;
  set goal(String value) => _goal = value;
  set activityLevel(String value) => _activityLevel = value;
  set birthday(DateTime value) => _birthday = value;
  set weight(double value) => _weight = value;
  set height(double value) => _height = value;

  int? get age {
    if (birthday == null) return null;

    final today = DateTime.now();
    int calculatedAge = today.year - birthday.year;

    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      calculatedAge--;
    }

    return calculatedAge;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    userId: map['userId'],
    userName: map['userName'],
    userEmail: map['userEmail'],
    userPassword: map['userPassword'],
    gender: map['gender'],
    goal: map['goal'],
    activityLevel: map['activityLevel'],
    birthday: DateTime.parse(map['birthday']),
    weight: map['weight'],
    height: map['height'],
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'userPassword': userPassword,
    'gender': gender,
    'goal': goal,
    'activityLevel': activityLevel,
    'birthday': birthday?.toIso8601String(),
    'weight': weight,
    'height': height,
  };
}

//   UserModel({
//     required String userId,
//     required String userName,
//     required String userEmail,
//     required String userPassword,
//     required String gender,
//     required String goal,
//     required String activityLevel,
//     required DateTime birthday,
//     required double weight,
//     required double height,
//   }) : _userId = userId,
//        _userName = userName,
//        _userEmail = userEmail,
//        _userPassword = userPassword,
//        _gender = gender,
//        _goal = goal,
//        _activityLevel = activityLevel,
//        _birthday = birthday,
//        _weight = weight,
//        _height = height;

//   String get userId => _userId;
//   String get userName => _userName;
//   String get userEmail => _userEmail;
//   String get userPassword => _userPassword;
//   String get gender => _gender;
//   String get goal => _goal;
//   String get activityLevel => _activityLevel;
//   DateTime get birthday => _birthday!;
//   double get weight => _weight!;
//   double get height => _height!;

//   set userId(String value) => _userId = value;
//   set userName(String value) => _userName = value;
//   set userEmail(String value) => _userEmail = value;
//   set userPassword(String value) => _userPassword = value;
//   set gender(String value) => _gender = value;
//   set goal(String value) => _goal = value;
//   set activityLevel(String value) => _activityLevel = value;
//   set birthday(DateTime value) => _birthday = value;
//   set weight(double value) => _weight = value;
//   set height(double value) => _height = value;

//   factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
//     userId: map['userId'],
//     userName: map['userName'],
//     userEmail: map['userEmail'],
//     userPassword: map['userPassword'],
//     gender: map['gender'],
//     goal: map['goal'],
//     activityLevel: map['activityLevel'],
//     birthday: DateTime.parse(map['birthday']),
//     weight: map['weight'],
//     height: map['height'],
//   );

//   Map<String, dynamic> toMap() => {
//     'userId': userId,
//     'userName': _userName,
//     'userEmail': _userEmail,
//     'userPassword': _userPassword,
//     'gender': _gender,
//     'goal': _goal,
//     'activityLevel': _activityLevel,
//     'birthday': _birthday?.toIso8601String(),
//     'weight': _weight,
//     'height': _height,
//   };
// }
