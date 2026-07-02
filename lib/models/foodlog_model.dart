import 'package:cloud_firestore/cloud_firestore.dart';

enum FoodLogSource { manual, scanned }

class FoodLogModel {
  String foodLogID;
  String userId;
  String foodLogName;
  int calorieIntake;
  DateTime foodLogDate;
  DateTime loggedAt;

  // ── Macros ─────────────────────────────────────────────────────────────
  double protein;
  double carbs;
  double fats;
  double fiber;
  double sugar;
  double addedSugar;
  double saturatedFat;
  double transFat;
  double unsaturatedFat;
  double omega3;
  double omega6;
  double cholesterol; // mg

  // ── Minerals ──────────────────────────────────────────────────────────
  double sodium; // mg
  double potassium; // mg
  double calcium; // mg
  double iron; // mg
  double magnesium; // mg
  double zinc; // mg
  double phosphorus; // mg
  double selenium; // µg

  // ── Vitamins ──────────────────────────────────────────────────────────
  double vitaminA; // µg RAE
  double vitaminB1; // mg (thiamine)
  double vitaminB2; // mg (riboflavin)
  double vitaminB3; // mg (niacin)
  double vitaminB6; // mg
  double vitaminB12; // µg
  double vitaminC; // mg
  double vitaminD; // µg
  double vitaminE; // mg
  double vitaminK; // µg
  double folate; // µg DFE

  // ── Supplement compounds ─────────────────────────────────────────────
  // Same fields exposed on the live scan confirm sheet, added here so
  // BOTH the scan flow and food history edit screens show the same set
  // of nutrient fields.
  double creatineMonohydrate; // g
  double bcaa; // g (total BCAAs)
  double leucine; // g
  double isoleucine; // g
  double valine; // g
  double glutamine; // g
  double taurine; // g

  // ── Other ──────────────────────────────────────────────────────────────
  double waterMl; // ml
  double caffeine; // mg

  // ── Ingredients ───────────────────────────────────────────────────────
  // Raw ingredient list text. This is what powers the Authentic /
  // Non-Authentic re-check when a history entry is edited — without it
  // stored, history edits have nothing to re-analyse.
  String ingredientText;

  // ── Metadata ──────────────────────────────────────────────────────────
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
    // Macros — legacy required fields
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    // Extended macros
    this.fiber = 0,
    this.sugar = 0,
    this.addedSugar = 0,
    this.saturatedFat = 0,
    this.transFat = 0,
    this.unsaturatedFat = 0,
    this.omega3 = 0,
    this.omega6 = 0,
    this.cholesterol = 0,
    // Minerals
    this.sodium = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.zinc = 0,
    this.phosphorus = 0,
    this.selenium = 0,
    // Vitamins
    this.vitaminA = 0,
    this.vitaminB1 = 0,
    this.vitaminB2 = 0,
    this.vitaminB3 = 0,
    this.vitaminB6 = 0,
    this.vitaminB12 = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.vitaminE = 0,
    this.vitaminK = 0,
    this.folate = 0,
    // Supplement compounds
    this.creatineMonohydrate = 0,
    this.bcaa = 0,
    this.leucine = 0,
    this.isoleucine = 0,
    this.valine = 0,
    this.glutamine = 0,
    this.taurine = 0,
    // Other
    this.waterMl = 0,
    this.caffeine = 0,
    // Ingredients
    this.ingredientText = '',
    // Metadata
    this.source = FoodLogSource.manual,
    this.servingSize,
    this.servingUnit = 'g',
    this.imagePath,
    this.scanConfidence,
    this.scanAnalysisResult,
  });

  bool get isManual => source == FoodLogSource.manual;
  bool get isScanned => source == FoodLogSource.scanned;
  double get netCarbs => (carbs - fiber).clamp(0, double.infinity);

  // ── Helper: parse double safely ────────────────────────────────────────
  static double _d(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toDouble() ?? 0.0;

  // ── fromMap (backward compatible) ──────────────────────────────────────
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
    // Macros
    protein: _d(m, 'protein'),
    carbs: _d(m, 'carbs'),
    fats: _d(m, 'fats'),
    fiber: _d(m, 'fiber'),
    sugar: _d(m, 'sugar'),
    addedSugar: _d(m, 'addedSugar'),
    saturatedFat: _d(m, 'saturatedFat'),
    transFat: _d(m, 'transFat'),
    unsaturatedFat: _d(m, 'unsaturatedFat'),
    omega3: _d(m, 'omega3'),
    omega6: _d(m, 'omega6'),
    cholesterol: _d(m, 'cholesterol'),
    // Minerals
    sodium: _d(m, 'sodium'),
    potassium: _d(m, 'potassium'),
    calcium: _d(m, 'calcium'),
    iron: _d(m, 'iron'),
    magnesium: _d(m, 'magnesium'),
    zinc: _d(m, 'zinc'),
    phosphorus: _d(m, 'phosphorus'),
    selenium: _d(m, 'selenium'),
    // Vitamins
    vitaminA: _d(m, 'vitaminA'),
    vitaminB1: _d(m, 'vitaminB1'),
    vitaminB2: _d(m, 'vitaminB2'),
    vitaminB3: _d(m, 'vitaminB3'),
    vitaminB6: _d(m, 'vitaminB6'),
    vitaminB12: _d(m, 'vitaminB12'),
    vitaminC: _d(m, 'vitaminC'),
    vitaminD: _d(m, 'vitaminD'),
    vitaminE: _d(m, 'vitaminE'),
    vitaminK: _d(m, 'vitaminK'),
    folate: _d(m, 'folate'),
    // Supplement compounds
    creatineMonohydrate: _d(m, 'creatineMonohydrate'),
    bcaa: _d(m, 'bcaa'),
    leucine: _d(m, 'leucine'),
    isoleucine: _d(m, 'isoleucine'),
    valine: _d(m, 'valine'),
    glutamine: _d(m, 'glutamine'),
    taurine: _d(m, 'taurine'),
    // Other
    waterMl: _d(m, 'waterMl'),
    caffeine: _d(m, 'caffeine'),
    // Ingredients
    ingredientText: m['ingredientText'] ?? '',
    // Metadata
    source: m['source'] == 'scanned'
        ? FoodLogSource.scanned
        : FoodLogSource.manual,
    servingSize: (m['servingSize'] as num?)?.toDouble(),
    servingUnit: m['servingUnit'] ?? 'g',
    imagePath: m['imagePath'],
    scanConfidence: (m['scanConfidence'] as num?)?.toDouble(),
    scanAnalysisResult: m['scanAnalysisResult'],
  );

  // ── toMap ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'foodLogID': foodLogID,
    'userId': userId,
    'foodLogName': foodLogName,
    'calorieIntake': calorieIntake,
    'foodLogDate': Timestamp.fromDate(foodLogDate),
    'loggedAt': Timestamp.fromDate(loggedAt),
    // Macros
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'fiber': fiber,
    'sugar': sugar,
    'addedSugar': addedSugar,
    'saturatedFat': saturatedFat,
    'transFat': transFat,
    'unsaturatedFat': unsaturatedFat,
    'omega3': omega3,
    'omega6': omega6,
    'cholesterol': cholesterol,
    // Minerals
    'sodium': sodium,
    'potassium': potassium,
    'calcium': calcium,
    'iron': iron,
    'magnesium': magnesium,
    'zinc': zinc,
    'phosphorus': phosphorus,
    'selenium': selenium,
    // Vitamins
    'vitaminA': vitaminA,
    'vitaminB1': vitaminB1,
    'vitaminB2': vitaminB2,
    'vitaminB3': vitaminB3,
    'vitaminB6': vitaminB6,
    'vitaminB12': vitaminB12,
    'vitaminC': vitaminC,
    'vitaminD': vitaminD,
    'vitaminE': vitaminE,
    'vitaminK': vitaminK,
    'folate': folate,
    // Supplement compounds
    'creatineMonohydrate': creatineMonohydrate,
    'bcaa': bcaa,
    'leucine': leucine,
    'isoleucine': isoleucine,
    'valine': valine,
    'glutamine': glutamine,
    'taurine': taurine,
    // Other
    'waterMl': waterMl,
    'caffeine': caffeine,
    // Ingredients
    'ingredientText': ingredientText,
    // Metadata
    'source': source == FoodLogSource.scanned ? 'scanned' : 'manual',
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'imagePath': imagePath,
    'scanConfidence': scanConfidence,
    'scanAnalysisResult': scanAnalysisResult,
  };
}
