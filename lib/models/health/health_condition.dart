enum HealthCondition {
  diabetes,
  hypertension,
  heartDisease,
  kidneyDisease,
  highCholesterol,
  obesity,
  celiacDisease,
  lactoseIntolerance;

  /// Human-readable display name shown in the profile UI.
  String get displayName {
    switch (this) {
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.hypertension:
        return 'Hypertension (High Blood Pressure)';
      case HealthCondition.heartDisease:
        return 'Heart Disease';
      case HealthCondition.kidneyDisease:
        return 'Kidney Disease';
      case HealthCondition.highCholesterol:
        return 'High Cholesterol';
      case HealthCondition.obesity:
        return 'Obesity / Weight Management';
      case HealthCondition.celiacDisease:
        return 'Celiac Disease (Gluten Intolerance)';
      case HealthCondition.lactoseIntolerance:
        return 'Lactose Intolerance';
    }
  }

  /// Short label for chips and badges.
  String get shortLabel {
    switch (this) {
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.hypertension:
        return 'Hypertension';
      case HealthCondition.heartDisease:
        return 'Heart Disease';
      case HealthCondition.kidneyDisease:
        return 'Kidney Disease';
      case HealthCondition.highCholesterol:
        return 'High Cholesterol';
      case HealthCondition.obesity:
        return 'Obesity';
      case HealthCondition.celiacDisease:
        return 'Celiac / Gluten';
      case HealthCondition.lactoseIntolerance:
        return 'Lactose';
    }
  }

  /// Firestore-safe string key.
  String get key => name; // e.g. "diabetes", "hypertension"

  static HealthCondition? fromKey(String key) {
    for (final c in HealthCondition.values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

// ── Risk level ─────────────────────────────────────────────────────────────

enum RiskLevel {
  none,
  moderate,
  high;

  bool get shouldWarn => this != RiskLevel.none;
}

// ── A single actionable warning ────────────────────────────────────────────

class HealthWarning {
  /// Which condition triggered this warning.
  final HealthCondition condition;

  /// How severe the risk is.
  final RiskLevel riskLevel;

  /// Short headline shown at the top of the warning card.
  final String headline;

  /// Full explanation shown in the dialog body.
  final String message;

  /// Nutritional reason (e.g. "Sugar: 28g per serving").
  final String? nutritionDetail;

  const HealthWarning({
    required this.condition,
    required this.riskLevel,
    required this.headline,
    required this.message,
    this.nutritionDetail,
  });
}

// ── Nutrition snapshot passed to the rule engine ───────────────────────────
//
// This is intentionally separate from FoodLogModel so the service layer
// has no dependency on the log model.

class FoodNutritionSnapshot {
  final String foodName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double sodium; // mg

  const FoodNutritionSnapshot({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.sodium = 0,
  });
}
