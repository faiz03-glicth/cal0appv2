import 'package:cloud_firestore/cloud_firestore.dart';

class ScanLogModel {
  String supplementId,
      userId,
      supplementName,
      brandName,
      scannedIngredients,
      analysisResult,
      flaggedIngredients,
      imagePath,
      barcode,
      servingUnit;
  double protein, carbs, fat, sugar, sodium;
  int calories;
  double? servingSize;
  DateTime scanTimestamp;

  ScanLogModel({
    required this.supplementId,
    required this.userId,
    required this.supplementName,
    this.brandName = '',
    this.scannedIngredients = '',
    this.analysisResult = '',
    this.flaggedIngredients = '',
    this.imagePath = '',
    this.barcode = '',
    this.servingUnit = 'g',
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.calories = 0,
    this.servingSize,
    required this.scanTimestamp,
  });

  // Getters
  factory ScanLogModel.fromMap(Map<String, dynamic> m) => ScanLogModel(
    supplementId: m['supplementId'] ?? '',
    userId: m['userId'] ?? '',
    supplementName: m['supplementName'] ?? '',
    brandName: m['brandName'] ?? '',
    scannedIngredients: m['scannedIngredients'] ?? '',
    analysisResult: m['analysisResult'] ?? '',
    flaggedIngredients: m['flaggedIngredients'] ?? '',
    imagePath: m['imagePath'] ?? '',
    barcode: m['barcode'] ?? '',
    servingUnit: m['servingUnit'] ?? 'g',
    protein: (m['protein'] as num?)?.toDouble() ?? 0,
    carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
    fat: (m['fat'] as num?)?.toDouble() ?? 0,
    sugar: (m['sugar'] as num?)?.toDouble() ?? 0,
    sodium: (m['sodium'] as num?)?.toDouble() ?? 0,
    calories: (m['calories'] as num?)?.toInt() ?? 0,
    servingSize: (m['servingSize'] as num?)?.toDouble(),
    scanTimestamp: m['scanTimestamp'] is Timestamp
        ? (m['scanTimestamp'] as Timestamp).toDate()
        : DateTime.tryParse(m['scanTimestamp']?.toString() ?? '') ??
              DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'supplementId': supplementId,
    'userId': userId,
    'supplementName': supplementName,
    'brandName': brandName,
    'scannedIngredients': scannedIngredients,
    'analysisResult': analysisResult,
    'flaggedIngredients': flaggedIngredients,
    'imagePath': imagePath,
    'barcode': barcode,
    'servingUnit': servingUnit,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'sodium': sodium,
    'calories': calories,
    'servingSize': servingSize,
    'scanTimestamp': Timestamp.fromDate(scanTimestamp),
  };
}
