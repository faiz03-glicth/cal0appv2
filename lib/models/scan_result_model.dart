// lib/models/scan_result_model.dart
//
// Expanded from 9 to 30 nutritional fields so that Gemini's full extraction
// is preserved end-to-end all the way to the confirm sheet and food log.
// All new fields default to 0 / null so existing code is unaffected.

class ScanResultModel {
  // ── Identity ─────────────────────────────────────────────────────────────
  final String productName;
  final String brandName;
  final double? servingSize;
  final String servingUnit;
  final int? servingsPerContainer;

  // ── Core macros (always shown) ────────────────────────────────────────────
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  // ── Extended macros ───────────────────────────────────────────────────────
  final double sugar;
  final double fiber;
  final double saturatedFat;
  final double transFat;
  final double unsaturatedFat;
  final double cholesterol; // mg
  final double sodium; // mg
  final double potassium; // mg

  // ── Supplement-specific rows ──────────────────────────────────────────────
  // These appear on whey/creatine labels and are the ones Gemini was already
  // trying to extract but had nowhere to store.
  final double creatineMonohydrate; // g
  final double bcaa; // g  (total BCAAs)
  final double leucine; // g
  final double isoleucine; // g
  final double valine; // g
  final double glutamine; // g
  final double taurine; // g
  final double caffeine; // mg
  final double vitaminC; // mg
  final double vitaminD; // µg
  final double calcium; // mg
  final double iron; // mg
  final double magnesium; // mg
  final double zinc; // mg

  // ── Meta ──────────────────────────────────────────────────────────────────
  final String ingredientText;
  final bool isSupplementDetected;
  final double extractionConfidence; // 0.0–1.0

  const ScanResultModel({
    required this.productName,
    this.brandName = '',
    this.servingSize,
    this.servingUnit = 'g',
    this.servingsPerContainer,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.fiber = 0,
    this.saturatedFat = 0,
    this.transFat = 0,
    this.unsaturatedFat = 0,
    this.cholesterol = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.creatineMonohydrate = 0,
    this.bcaa = 0,
    this.leucine = 0,
    this.isoleucine = 0,
    this.valine = 0,
    this.glutamine = 0,
    this.taurine = 0,
    this.caffeine = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.zinc = 0,
    this.ingredientText = '',
    this.isSupplementDetected = false,
    this.extractionConfidence = 0.0,
  });

  static const empty = ScanResultModel(
    productName: '',
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );

  bool get hasUsefulData => calories > 0 || protein > 0 || carbs > 0 || fat > 0;

  // How many optional fields were successfully extracted (used for confidence)
  int get filledOptionalFields => [
    sugar,
    fiber,
    saturatedFat,
    transFat,
    cholesterol,
    sodium,
    potassium,
    creatineMonohydrate,
    bcaa,
    leucine,
    isoleucine,
    valine,
    glutamine,
    taurine,
    caffeine,
    vitaminC,
    vitaminD,
    calcium,
    iron,
    magnesium,
    zinc,
  ].where((v) => v > 0).length;

  ScanResultModel copyWith({
    String? productName,
    String? brandName,
    double? servingSize,
    String? servingUnit,
    int? servingsPerContainer,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? sugar,
    double? fiber,
    double? saturatedFat,
    double? transFat,
    double? unsaturatedFat,
    double? cholesterol,
    double? sodium,
    double? potassium,
    double? creatineMonohydrate,
    double? bcaa,
    double? leucine,
    double? isoleucine,
    double? valine,
    double? glutamine,
    double? taurine,
    double? caffeine,
    double? vitaminC,
    double? vitaminD,
    double? calcium,
    double? iron,
    double? magnesium,
    double? zinc,
    String? ingredientText,
    bool? isSupplementDetected,
    double? extractionConfidence,
  }) => ScanResultModel(
    productName: productName ?? this.productName,
    brandName: brandName ?? this.brandName,
    servingSize: servingSize ?? this.servingSize,
    servingUnit: servingUnit ?? this.servingUnit,
    servingsPerContainer: servingsPerContainer ?? this.servingsPerContainer,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    sugar: sugar ?? this.sugar,
    fiber: fiber ?? this.fiber,
    saturatedFat: saturatedFat ?? this.saturatedFat,
    transFat: transFat ?? this.transFat,
    unsaturatedFat: unsaturatedFat ?? this.unsaturatedFat,
    cholesterol: cholesterol ?? this.cholesterol,
    sodium: sodium ?? this.sodium,
    potassium: potassium ?? this.potassium,
    creatineMonohydrate: creatineMonohydrate ?? this.creatineMonohydrate,
    bcaa: bcaa ?? this.bcaa,
    leucine: leucine ?? this.leucine,
    isoleucine: isoleucine ?? this.isoleucine,
    valine: valine ?? this.valine,
    glutamine: glutamine ?? this.glutamine,
    taurine: taurine ?? this.taurine,
    caffeine: caffeine ?? this.caffeine,
    vitaminC: vitaminC ?? this.vitaminC,
    vitaminD: vitaminD ?? this.vitaminD,
    calcium: calcium ?? this.calcium,
    iron: iron ?? this.iron,
    magnesium: magnesium ?? this.magnesium,
    zinc: zinc ?? this.zinc,
    ingredientText: ingredientText ?? this.ingredientText,
    isSupplementDetected: isSupplementDetected ?? this.isSupplementDetected,
    extractionConfidence: extractionConfidence ?? this.extractionConfidence,
  );

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'brandName': brandName,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'servingsPerContainer': servingsPerContainer,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'fiber': fiber,
    'saturatedFat': saturatedFat,
    'transFat': transFat,
    'unsaturatedFat': unsaturatedFat,
    'cholesterol': cholesterol,
    'sodium': sodium,
    'potassium': potassium,
    'creatineMonohydrate': creatineMonohydrate,
    'bcaa': bcaa,
    'leucine': leucine,
    'isoleucine': isoleucine,
    'valine': valine,
    'glutamine': glutamine,
    'taurine': taurine,
    'caffeine': caffeine,
    'vitaminC': vitaminC,
    'vitaminD': vitaminD,
    'calcium': calcium,
    'iron': iron,
    'magnesium': magnesium,
    'zinc': zinc,
    'ingredientText': ingredientText,
    'isSupplementDetected': isSupplementDetected,
    'extractionConfidence': extractionConfidence,
  };
}
