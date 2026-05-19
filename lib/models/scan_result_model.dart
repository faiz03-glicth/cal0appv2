
class ScanResultModel {
  final String productName;
  final double? servingSize;
  final String servingUnit;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double sodium;
  final String ingredientText;
  final bool isSupplementDetected;
  final double extractionConfidence; // 0.0–1.0

  const ScanResultModel({
    required this.productName,
    this.servingSize,
    this.servingUnit = 'g',
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.sodium = 0,
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
    extractionConfidence: 0.0,
  );

  bool get hasUsefulData => calories > 0 || protein > 0 || carbs > 0 || fat > 0;

  ScanResultModel copyWith({
    String? productName,
    double? servingSize,
    String? servingUnit,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? sugar,
    double? sodium,
    String? ingredientText,
    bool? isSupplementDetected,
    double? extractionConfidence,
  }) => ScanResultModel(
    productName: productName ?? this.productName,
    servingSize: servingSize ?? this.servingSize,
    servingUnit: servingUnit ?? this.servingUnit,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    sugar: sugar ?? this.sugar,
    sodium: sodium ?? this.sodium,
    ingredientText: ingredientText ?? this.ingredientText,
    isSupplementDetected: isSupplementDetected ?? this.isSupplementDetected,
    extractionConfidence: extractionConfidence ?? this.extractionConfidence,
  );

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'sodium': sodium,
    'ingredientText': ingredientText,
    'isSupplementDetected': isSupplementDetected,
    'extractionConfidence': extractionConfidence,
  };
}
