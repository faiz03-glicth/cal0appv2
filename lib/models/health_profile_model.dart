// lib/models/health_profile_model.dart

enum HealthCondition {
  diabetes,
  prediabetes,
  highBloodPressure,
  highCholesterol,
  heartDisease,
  kidneyDisease,
  celiacDisease,
  lactoseIntolerance,
  glutenIntolerance,
  nutAllergy,
  shellfishAllergy,
  soyAllergy,
  eggAllergy,
  obesity,
  gerd, // acid reflux
}

enum FoodRiskLevel { safe, low, moderate, high, critical }

class HealthProfileModel {
  final String userId;
  final List<HealthCondition> conditions;
  final List<String> customAllergies;
  final List<String> dietaryRestrictions;

  // Thresholds (daily limits)
  final int? maxDailySugarG;
  final int? maxDailyCarbsG;
  final int? maxDailySodiumMg;
  final int? maxDailyCalories;
  final int? maxDailyCholesterolMg;

  final bool enableSmartAlerts;
  final bool enableDailyInsights;
  final bool showAlternativeSuggestions;
  final DateTime? updatedAt;

  const HealthProfileModel({
    required this.userId,
    this.conditions = const [],
    this.customAllergies = const [],
    this.dietaryRestrictions = const [],
    this.maxDailySugarG,
    this.maxDailyCarbsG,
    this.maxDailySodiumMg,
    this.maxDailyCalories,
    this.maxDailyCholesterolMg,
    this.enableSmartAlerts = true,
    this.enableDailyInsights = true,
    this.showAlternativeSuggestions = true,
    this.updatedAt,
  });

  bool get hasDiabetes =>
      conditions.contains(HealthCondition.diabetes) ||
      conditions.contains(HealthCondition.prediabetes);

  bool get hasHypertension =>
      conditions.contains(HealthCondition.highBloodPressure);

  bool get hasHighCholesterol =>
      conditions.contains(HealthCondition.highCholesterol);

  bool get hasHeartCondition =>
      conditions.contains(HealthCondition.heartDisease) ||
      hasHypertension ||
      hasHighCholesterol;

  bool get hasKidneyDisease =>
      conditions.contains(HealthCondition.kidneyDisease);

  bool get hasAnyCondition =>
      conditions.isNotEmpty || customAllergies.isNotEmpty;

  // Effective sugar threshold (considers diabetes)
  int get effectiveSugarLimitG {
    if (maxDailySugarG != null) return maxDailySugarG!;
    if (hasDiabetes) return 25; // WHO recommendation for diabetics
    return 50; // General recommendation
  }

  // Effective sodium threshold
  int get effectiveSodiumLimitMg {
    if (maxDailySodiumMg != null) return maxDailySodiumMg!;
    if (hasHypertension || hasHeartCondition || hasKidneyDisease) return 1500;
    return 2300;
  }

  // Effective carbs threshold
  int get effectiveCarbsLimitG {
    if (maxDailyCarbsG != null) return maxDailyCarbsG!;
    if (hasDiabetes) return 130; // Low-carb for diabetics
    return 300;
  }

  HealthProfileModel copyWith({
    List<HealthCondition>? conditions,
    List<String>? customAllergies,
    List<String>? dietaryRestrictions,
    int? maxDailySugarG,
    int? maxDailyCarbsG,
    int? maxDailySodiumMg,
    int? maxDailyCalories,
    int? maxDailyCholesterolMg,
    bool? enableSmartAlerts,
    bool? enableDailyInsights,
    bool? showAlternativeSuggestions,
  }) => HealthProfileModel(
    userId: userId,
    conditions: conditions ?? this.conditions,
    customAllergies: customAllergies ?? this.customAllergies,
    dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
    maxDailySugarG: maxDailySugarG ?? this.maxDailySugarG,
    maxDailyCarbsG: maxDailyCarbsG ?? this.maxDailyCarbsG,
    maxDailySodiumMg: maxDailySodiumMg ?? this.maxDailySodiumMg,
    maxDailyCalories: maxDailyCalories ?? this.maxDailyCalories,
    maxDailyCholesterolMg: maxDailyCholesterolMg ?? this.maxDailyCholesterolMg,
    enableSmartAlerts: enableSmartAlerts ?? this.enableSmartAlerts,
    enableDailyInsights: enableDailyInsights ?? this.enableDailyInsights,
    showAlternativeSuggestions:
        showAlternativeSuggestions ?? this.showAlternativeSuggestions,
    updatedAt: DateTime.now(),
  );

  factory HealthProfileModel.fromMap(Map<String, dynamic> map) =>
      HealthProfileModel(
        userId: map['userId'] ?? '',
        conditions: (map['conditions'] as List<dynamic>? ?? [])
            .map(
              (c) => HealthCondition.values.firstWhere(
                (e) => e.name == c,
                orElse: () => HealthCondition.diabetes,
              ),
            )
            .toList(),
        customAllergies: List<String>.from(map['customAllergies'] ?? []),
        dietaryRestrictions: List<String>.from(
          map['dietaryRestrictions'] ?? [],
        ),
        maxDailySugarG: map['maxDailySugarG'],
        maxDailyCarbsG: map['maxDailyCarbsG'],
        maxDailySodiumMg: map['maxDailySodiumMg'],
        maxDailyCalories: map['maxDailyCalories'],
        maxDailyCholesterolMg: map['maxDailyCholesterolMg'],
        enableSmartAlerts: map['enableSmartAlerts'] ?? true,
        enableDailyInsights: map['enableDailyInsights'] ?? true,
        showAlternativeSuggestions: map['showAlternativeSuggestions'] ?? true,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'])
            : null,
      );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'conditions': conditions.map((c) => c.name).toList(),
    'customAllergies': customAllergies,
    'dietaryRestrictions': dietaryRestrictions,
    'maxDailySugarG': maxDailySugarG,
    'maxDailyCarbsG': maxDailyCarbsG,
    'maxDailySodiumMg': maxDailySodiumMg,
    'maxDailyCalories': maxDailyCalories,
    'maxDailyCholesterolMg': maxDailyCholesterolMg,
    'enableSmartAlerts': enableSmartAlerts,
    'enableDailyInsights': enableDailyInsights,
    'showAlternativeSuggestions': showAlternativeSuggestions,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static String conditionDisplayName(HealthCondition c) {
    switch (c) {
      case HealthCondition.diabetes:
        return 'Diabetes (Type 1 or 2)';
      case HealthCondition.prediabetes:
        return 'Prediabetes';
      case HealthCondition.highBloodPressure:
        return 'High Blood Pressure';
      case HealthCondition.highCholesterol:
        return 'High Cholesterol';
      case HealthCondition.heartDisease:
        return 'Heart Disease';
      case HealthCondition.kidneyDisease:
        return 'Kidney Disease';
      case HealthCondition.celiacDisease:
        return 'Celiac Disease';
      case HealthCondition.lactoseIntolerance:
        return 'Lactose Intolerance';
      case HealthCondition.glutenIntolerance:
        return 'Gluten Intolerance';
      case HealthCondition.nutAllergy:
        return 'Nut Allergy';
      case HealthCondition.shellfishAllergy:
        return 'Shellfish Allergy';
      case HealthCondition.soyAllergy:
        return 'Soy Allergy';
      case HealthCondition.eggAllergy:
        return 'Egg Allergy';
      case HealthCondition.obesity:
        return 'Obesity / Weight Management';
      case HealthCondition.gerd:
        return 'Acid Reflux (GERD)';
    }
  }
}

class FoodRiskAssessment {
  final FoodRiskLevel riskLevel;
  final List<String> riskReasons;
  final List<String> flaggedIngredients;
  final List<String> healthySuggestions;
  final String? primaryWarning;
  final String? actionAdvice;
  final Map<String, double> nutrientRiskScores; // nutrient -> 0.0-1.0

  const FoodRiskAssessment({
    required this.riskLevel,
    this.riskReasons = const [],
    this.flaggedIngredients = const [],
    this.healthySuggestions = const [],
    this.primaryWarning,
    this.actionAdvice,
    this.nutrientRiskScores = const {},
  });

  bool get isSafe =>
      riskLevel == FoodRiskLevel.safe || riskLevel == FoodRiskLevel.low;
  bool get needsWarning =>
      riskLevel == FoodRiskLevel.moderate || riskLevel == FoodRiskLevel.high;
  bool get isCritical => riskLevel == FoodRiskLevel.critical;

  static const FoodRiskAssessment safe = FoodRiskAssessment(
    riskLevel: FoodRiskLevel.safe,
  );
}
