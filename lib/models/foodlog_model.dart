class FoodLogModel {
  String _foodLogName, _calorieIntake, _foodLogID, _userId;
  double _protein, _carbs, _fats;

  DateTime _foodLogDate, _loggedAt;

  FoodLogModel({
    required String foodLogID,
    required String userId,
    required String foodLogName,
    required String calorieIntake,
    required DateTime foodLogDate,
    DateTime? loggedAt,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
  }) : _foodLogID = foodLogID,
       _userId = userId,
       _foodLogName = foodLogName,
       _calorieIntake = calorieIntake,
       _foodLogDate = foodLogDate,
       _loggedAt = loggedAt ?? foodLogDate,
       _protein = protein,
       _carbs = carbs,
       _fats = fats;

  // Getters
  String get foodLogID => _foodLogID;
  String get userId => _userId;
  String get foodLogName => _foodLogName;
  String get calorieIntake => _calorieIntake;
  DateTime get foodLogDate => _foodLogDate;
  DateTime get loggedAt => _loggedAt;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fats => _fats;

  // Setters
  set foodLogID(String value) => _foodLogID = value;
  set userId(String value) => _userId = value;
  set foodLogName(String value) => _foodLogName = value;
  set calorieIntake(String value) => _calorieIntake = value;
  set foodLogDate(DateTime value) => _foodLogDate = value;
  set protein(double value) => _protein = value;
  set carbs(double value) => _carbs = value;
  set fats(double value) => _fats = value;

  factory FoodLogModel.fromMap(Map<String, dynamic> map) => FoodLogModel(
    foodLogID: map['foodLogID'],
    userId: map['userId'],
    foodLogName: map['foodLogName'],
    calorieIntake: map['calorieIntake'],
    foodLogDate: DateTime.parse(map['foodLogDate']),
    loggedAt: map['loggedAt'] != null
        ? DateTime.parse(map['loggedAt'])
        : DateTime.parse(map['foodLogDate']),
    protein: map['protein']?.toDouble() ?? 0,
    carbs: map['carbs']?.toDouble() ?? 0,
    fats: map['fats']?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'foodLogID': _foodLogID,
    'userId': _userId,
    'foodLogName': _foodLogName,
    'calorieIntake': _calorieIntake,
    'foodLogDate': _foodLogDate.toIso8601String(),
    'loggedAt': _loggedAt.toIso8601String(),
    'protein': _protein,
    'carbs': _carbs,
    'fats': _fats,
  };
}
