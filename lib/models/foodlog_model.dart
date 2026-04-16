class FoodLogModel {
  String _foodLogName, _calorieIntake;
  DateTime _foodLogDate;
  int _foodLogID;

  FoodLogModel({
    required int foodLogID,
    required String foodLogName,
    required String calorieIntake,
    required DateTime foodLogDate,
  }) : _foodLogID = foodLogID,
       _foodLogName = foodLogName,
       _calorieIntake = calorieIntake,
       _foodLogDate = foodLogDate;

  // Getters
  int get foodLogID => _foodLogID;
  String get foodLogName => _foodLogName;
  String get calorieIntake => _calorieIntake;
  DateTime get foodLogDate => _foodLogDate;

  // Setters
  set foodLogID(int value) => _foodLogID = value;
  set foodLogName(String value) => _foodLogName = value;
  set calorieIntake(String value) => _calorieIntake = value;
  set foodLogDate(DateTime value) => _foodLogDate = value;

  factory FoodLogModel.fromMap(Map<String, dynamic> map) => FoodLogModel(
    foodLogID: map['foodLogID'],
    foodLogName: map['foodLogName'],
    calorieIntake: map['calorieIntake'],
    foodLogDate: DateTime.parse(map['foodLogDate']),
  );

  Map<String, dynamic> toMap() => {
    'foodLogID': _foodLogID,
    'foodLogName': _foodLogName,
    'calorieIntake': _calorieIntake,
    'foodLogDate': _foodLogDate.toIso8601String(),
  };
}
