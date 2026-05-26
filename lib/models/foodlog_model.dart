import 'package:cloud_firestore/cloud_firestore.dart';

enum FoodLogSource { manual, scanned }

class FoodLogModel {
  String foodLogID;
  String userId;
  String foodLogName;
  int calorieIntake;
  DateTime foodLogDate;
  DateTime loggedAt;
  double protein;
  double carbs;
  double fats;
  double sugar;
  double sodium;
  FoodLogSource source;
  double? servingSize;
  String servingUnit;
  String? imagePath;
  double? scanConfidence;
  String? scanAnalysisResult;

  FoodLogModel({
    required this.foodLogID,
    required this.userId,
    required this.foodLogName,
    required this.calorieIntake,
    required this.foodLogDate,
    required this.loggedAt,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.source = FoodLogSource.manual,
    this.servingSize,
    this.servingUnit = 'g',
    this.imagePath,
    this.scanConfidence,
    this.scanAnalysisResult,
  });

  bool get isManual => source == FoodLogSource.manual;
  bool get isScanned => source == FoodLogSource.scanned;

  factory FoodLogModel.fromMap(Map<String, dynamic> m) => FoodLogModel(
    foodLogID: m['foodLogID'] ?? '',
    userId: m['userId'] ?? '',
    foodLogName: m['foodLogName'] ?? '',
    calorieIntake: (m['calorieIntake'] as num?)?.toInt() ?? 0,
    foodLogDate: m['foodLogDate'] is Timestamp
        ? (m['foodLogDate'] as Timestamp).toDate()
        : DateTime.tryParse(m['foodLogDate']?.toString() ?? '') ??
              DateTime.now(),
    loggedAt: m['loggedAt'] is Timestamp
        ? (m['loggedAt'] as Timestamp).toDate()
        : DateTime.tryParse(m['loggedAt']?.toString() ?? '') ?? DateTime.now(),
    protein: (m['protein'] as num?)?.toDouble() ?? 0,
    carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
    fats: (m['fats'] as num?)?.toDouble() ?? 0,
    sugar: (m['sugar'] as num?)?.toDouble() ?? 0,
    sodium: (m['sodium'] as num?)?.toDouble() ?? 0,
    source: m['source'] == 'scanned'
        ? FoodLogSource.scanned
        : FoodLogSource.manual,
    servingSize: (m['servingSize'] as num?)?.toDouble(),
    servingUnit: m['servingUnit'] ?? 'g',
    imagePath: m['imagePath'],
    scanConfidence: (m['scanConfidence'] as num?)?.toDouble(),
    scanAnalysisResult: m['scanAnalysisResult'],
  );

  Map<String, dynamic> toMap() => {
    'foodLogID': foodLogID,
    'userId': userId,
    'foodLogName': foodLogName,
    'calorieIntake': calorieIntake,
    'foodLogDate': Timestamp.fromDate(foodLogDate),
    'loggedAt': Timestamp.fromDate(loggedAt),
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'sugar': sugar,
    'sodium': sodium,
    'source': source == FoodLogSource.scanned ? 'scanned' : 'manual',
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'imagePath': imagePath,
    'scanConfidence': scanConfidence,
    'scanAnalysisResult': scanAnalysisResult,
  };
}
