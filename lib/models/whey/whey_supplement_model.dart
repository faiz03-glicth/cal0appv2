// lib/models/whey/whey_supplement_model.dart
//
// Firestore collection: whey_supplements
// Document ID: auto-generated UUID
//
// Every whey scan that the user saves is also written here.
// This gives you a dedicated, query-friendly table of all supplement
// scans without having to filter the general food_logs collection.

class WheySupplementModel {
  final String id; // Firestore doc ID (UUID)
  final String userId;
  final String brandName; // e.g. "Optimum Nutrition"
  final String productName; // e.g. "Gold Standard 100% Whey"

  // Macros per serving
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? sugar;
  final double? sodium;
  final double? servingSize; // grams
  final String? servingUnit;

  // AI verdict
  final String aiVerdict; // 'Authentic' | 'Spiked' | 'Plant-Based' | 'Unknown'
  final double aiConfidence; // 0.0 – 1.0
  final bool isSpiked;

  // Detected ingredients from rule-based scan
  final List<String> flaggedIngredients;

  // Scan metadata
  final double? ocrConfidence;
  final String? imagePath;
  final DateTime loggedAt;

  const WheySupplementModel({
    required this.id,
    required this.userId,
    required this.brandName,
    required this.productName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar,
    this.sodium,
    this.servingSize,
    this.servingUnit,
    required this.aiVerdict,
    required this.aiConfidence,
    required this.isSpiked,
    this.flaggedIngredients = const [],
    this.ocrConfidence,
    this.imagePath,
    required this.loggedAt,
  });

  // ── Firestore serialisation ───────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'brandName': brandName,
    'productName': productName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    if (sugar != null) 'sugar': sugar,
    if (sodium != null) 'sodium': sodium,
    if (servingSize != null) 'servingSize': servingSize,
    if (servingUnit != null) 'servingUnit': servingUnit,
    'aiVerdict': aiVerdict,
    'aiConfidence': aiConfidence,
    'isSpiked': isSpiked,
    'flaggedIngredients': flaggedIngredients,
    if (ocrConfidence != null) 'ocrConfidence': ocrConfidence,
    if (imagePath != null) 'imagePath': imagePath,
    'loggedAt': loggedAt.toIso8601String(),
  };

  factory WheySupplementModel.fromJson(Map<String, dynamic> json) =>
      WheySupplementModel(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        brandName: json['brandName'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble(),
        sodium: (json['sodium'] as num?)?.toDouble(),
        servingSize: (json['servingSize'] as num?)?.toDouble(),
        servingUnit: json['servingUnit'] as String?,
        aiVerdict: json['aiVerdict'] as String? ?? 'Unknown',
        aiConfidence: (json['aiConfidence'] as num?)?.toDouble() ?? 0,
        isSpiked: json['isSpiked'] as bool? ?? false,
        flaggedIngredients:
            (json['flaggedIngredients'] as List<dynamic>?)?.cast<String>() ??
            [],
        ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
        imagePath: json['imagePath'] as String?,
        loggedAt: json['loggedAt'] != null
            ? DateTime.parse(json['loggedAt'] as String)
            : DateTime.now(),
      );
}
