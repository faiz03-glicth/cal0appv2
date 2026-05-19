import 'package:cloud_firestore/cloud_firestore.dart';

enum FoodLogSource { manual, scanned }

class FoodLogModel {
  String _foodLogName, _foodLogID, _userId;
  int _calorieIntake;
  double _protein, _carbs, _fats;

  DateTime _foodLogDate, _loggedAt;

  // ── Unified log metadata ──────────────────────────────────────────────────
  FoodLogSource _source;
  double? _servingSize;
  String _servingUnit;
  double _sugar, _sodium;

  // Scan-specific (null for manual entries)
  String? _imagePath;
  double? _scanConfidence;
  String? _scanAnalysisResult; // "CLEAN" | "SPIKED (92%)"

  FoodLogModel({
    required String foodLogID,
    required String userId,
    required String foodLogName,
    required int calorieIntake,
    required DateTime foodLogDate,
    DateTime? loggedAt,
    double protein = 0,
    double carbs = 0,
    double fats = 0,
    FoodLogSource source = FoodLogSource.manual,
    double? servingSize,
    String servingUnit = 'g',
    double sugar = 0,
    double sodium = 0,
    String? imagePath,
    double? scanConfidence,
    String? scanAnalysisResult,
  }) : _foodLogID = foodLogID,
       _userId = userId,
       _foodLogName = foodLogName,
       _calorieIntake = calorieIntake,
       _foodLogDate = DateTime(
         foodLogDate.year,
         foodLogDate.month,
         foodLogDate.day,
       ),
       _loggedAt = loggedAt ?? DateTime.now(),
       _protein = protein,
       _carbs = carbs,
       _fats = fats,
       _source = source,
       _servingSize = servingSize,
       _servingUnit = servingUnit,
       _sugar = sugar,
       _sodium = sodium,
       _imagePath = imagePath,
       _scanConfidence = scanConfidence,
       _scanAnalysisResult = scanAnalysisResult;

  // Getters
  String get foodLogID => _foodLogID;
  String get userId => _userId;
  String get foodLogName => _foodLogName;
  int get calorieIntake => _calorieIntake;
  DateTime get foodLogDate => _foodLogDate;
  DateTime get loggedAt => _loggedAt;
  double get protein => _protein;
  double get carbs => _carbs;
  double get fats => _fats;
  FoodLogSource get source => _source;
  double? get servingSize => _servingSize;
  String get servingUnit => _servingUnit;
  double get sugar => _sugar;
  double get sodium => _sodium;
  String? get imagePath => _imagePath;
  double? get scanConfidence => _scanConfidence;
  String? get scanAnalysisResult => _scanAnalysisResult;

  bool get isScanned => _source == FoodLogSource.scanned;
  bool get isManual => _source == FoodLogSource.manual;

  // Setters
  set foodLogID(String v) => _foodLogID = v;
  set userId(String v) => _userId = v;
  set foodLogName(String v) => _foodLogName = v;
  set calorieIntake(int v) => _calorieIntake = v;
  set foodLogDate(DateTime v) =>
      _foodLogDate = DateTime(v.year, v.month, v.day);
  set protein(double v) => _protein = v;
  set carbs(double v) => _carbs = v;
  set fats(double v) => _fats = v;

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  factory FoodLogModel.fromMap(Map<String, dynamic> map) => FoodLogModel(
    foodLogID: map['foodLogID'] ?? '',
    userId: map['userId'] ?? '',
    foodLogName: map['foodLogName'] ?? '',
    calorieIntake: (map['calorieIntake'] as num?)?.toInt() ?? 0,
    foodLogDate: _parseDate(map['foodLogDate']),
    loggedAt: _parseDate(map['loggedAt'] ?? map['foodLogDate']),
    protein: (map['protein'] as num?)?.toDouble() ?? 0,
    carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
    fats: (map['fats'] as num?)?.toDouble() ?? 0,
    source: map['source'] == 'scanned'
        ? FoodLogSource.scanned
        : FoodLogSource.manual,
    servingSize: (map['servingSize'] as num?)?.toDouble(),
    servingUnit: map['servingUnit'] ?? 'g',
    sugar: (map['sugar'] as num?)?.toDouble() ?? 0,
    sodium: (map['sodium'] as num?)?.toDouble() ?? 0,
    imagePath: map['imagePath'],
    scanConfidence: (map['scanConfidence'] as num?)?.toDouble(),
    scanAnalysisResult: map['scanAnalysisResult'],
  );

  Map<String, dynamic> toMap() => {
    'foodLogID': _foodLogID,
    'userId': _userId,
    'foodLogName': _foodLogName,
    'calorieIntake': _calorieIntake,
    'foodLogDate': Timestamp.fromDate(
      DateTime(_foodLogDate.year, _foodLogDate.month, _foodLogDate.day),
    ),
    'loggedAt': Timestamp.fromDate(_loggedAt),
    'protein': _protein,
    'carbs': _carbs,
    'fats': _fats,
    'source': _source == FoodLogSource.scanned ? 'scanned' : 'manual',
    'servingSize': _servingSize,
    'servingUnit': _servingUnit,
    'sugar': _sugar,
    'sodium': _sodium,
    'imagePath': _imagePath,
    'scanConfidence': _scanConfidence,
    'scanAnalysisResult': _scanAnalysisResult,
  };
}
