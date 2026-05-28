import 'package:cal0appv2/models/foodlog_model.dart';

class NutrientTotals {
  // ── Macros ────────────────────────────────────────────────────────────────
  final int calories;
  final double protein; // g
  final double carbs; // g total
  final double netCarbs; // g (carbs - fiber)
  final double fiber; // g
  final double sugar; // g
  final double addedSugar; // g
  final double fat; // g total
  final double saturatedFat; // g
  final double transFat; // g
  final double unsatFat; // g (mono + poly)
  final double omega3; // g
  final double omega6; // g
  final double cholesterol; // mg

  // ── Minerals ──────────────────────────────────────────────────────────────
  final double sodium; // mg
  final double potassium; // mg
  final double calcium; // mg
  final double iron; // mg
  final double magnesium; // mg
  final double zinc; // mg
  final double phosphorus; // mg
  final double selenium; // µg

  // ── Vitamins ──────────────────────────────────────────────────────────────
  final double vitaminA; // µg RAE
  final double vitaminB1; // mg (thiamine)
  final double vitaminB2; // mg (riboflavin)
  final double vitaminB3; // mg (niacin)
  final double vitaminB6; // mg
  final double vitaminB12; // µg
  final double vitaminC; // mg
  final double vitaminD; // µg
  final double vitaminE; // mg
  final double vitaminK; // µg
  final double folate; // µg DFE

  // ── Other ─────────────────────────────────────────────────────────────────
  final double water; // ml
  final double caffeine; // mg
  final int logCount;

  const NutrientTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.netCarbs = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.addedSugar = 0,
    this.fat = 0,
    this.saturatedFat = 0,
    this.transFat = 0,
    this.unsatFat = 0,
    this.omega3 = 0,
    this.omega6 = 0,
    this.cholesterol = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.zinc = 0,
    this.phosphorus = 0,
    this.selenium = 0,
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
    this.water = 0,
    this.caffeine = 0,
    this.logCount = 0,
  });

  static const empty = NutrientTotals();
  bool get isEmpty => logCount == 0;

  // ── Aggregation ───────────────────────────────────────────────────────────

  factory NutrientTotals.fromLogs(List<FoodLogModel> logs) {
    if (logs.isEmpty) return NutrientTotals.empty;

    int cal = 0;
    double pro = 0, carb = 0, fib = 0, sug = 0, addSug = 0;
    double fat = 0, satF = 0, trnF = 0, unsF = 0, om3 = 0, om6 = 0, chol = 0;
    double sod = 0, pot = 0, calc = 0, irn = 0, mag = 0, znc = 0;
    double phos = 0, sel = 0;
    double vA = 0, vB1 = 0, vB2 = 0, vB3 = 0, vB6 = 0, vB12 = 0;
    double vC = 0, vD = 0, vE = 0, vK = 0, fol = 0;
    double wat = 0, caff = 0;

    for (final l in logs) {
      cal += l.calorieIntake;
      pro += l.protein;
      carb += l.carbs;
      fib += l.fiber;
      sug += l.sugar;
      addSug += l.addedSugar;
      fat += l.fats;
      satF += l.saturatedFat;
      trnF += l.transFat;
      unsF += l.unsaturatedFat;
      om3 += l.omega3;
      om6 += l.omega6;
      chol += l.cholesterol;
      sod += l.sodium;
      pot += l.potassium;
      calc += l.calcium;
      irn += l.iron;
      mag += l.magnesium;
      znc += l.zinc;
      phos += l.phosphorus;
      sel += l.selenium;
      vA += l.vitaminA;
      vB1 += l.vitaminB1;
      vB2 += l.vitaminB2;
      vB3 += l.vitaminB3;
      vB6 += l.vitaminB6;
      vB12 += l.vitaminB12;
      vC += l.vitaminC;
      vD += l.vitaminD;
      vE += l.vitaminE;
      vK += l.vitaminK;
      fol += l.folate;
      wat += l.waterMl;
      caff += l.caffeine;
    }

    return NutrientTotals(
      calories: cal,
      protein: pro,
      carbs: carb,
      netCarbs: (carb - fib).clamp(0, double.infinity),
      fiber: fib,
      sugar: sug,
      addedSugar: addSug,
      fat: fat,
      saturatedFat: satF,
      transFat: trnF,
      unsatFat: unsF,
      omega3: om3,
      omega6: om6,
      cholesterol: chol,
      sodium: sod,
      potassium: pot,
      calcium: calc,
      iron: irn,
      magnesium: mag,
      zinc: znc,
      phosphorus: phos,
      selenium: sel,
      vitaminA: vA,
      vitaminB1: vB1,
      vitaminB2: vB2,
      vitaminB3: vB3,
      vitaminB6: vB6,
      vitaminB12: vB12,
      vitaminC: vC,
      vitaminD: vD,
      vitaminE: vE,
      vitaminK: vK,
      folate: fol,
      water: wat,
      caffeine: caff,
      logCount: logs.length,
    );
  }

  // ── Value equality ────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      other is NutrientTotals &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fiber == fiber &&
      other.sugar == sugar &&
      other.fat == fat &&
      other.saturatedFat == saturatedFat &&
      other.sodium == sodium &&
      other.potassium == potassium &&
      other.calcium == calcium &&
      other.iron == iron &&
      other.vitaminC == vitaminC &&
      other.vitaminD == vitaminD &&
      other.logCount == logCount;

  @override
  int get hashCode => Object.hash(
    calories,
    protein,
    carbs,
    fiber,
    sugar,
    fat,
    saturatedFat,
    sodium,
    potassium,
    calcium,
    iron,
    vitaminC,
    vitaminD,
    logCount,
  );

  @override
  String toString() =>
      'NutrientTotals(cal:$calories pro:${protein.toStringAsFixed(1)} '
      'carb:${carbs.toStringAsFixed(1)} fat:${fat.toStringAsFixed(1)} '
      'sod:${sodium.toStringAsFixed(0)} logs:$logCount)';
}
