import 'package:cal0appv2/models/logging/foodlog_model.dart';

class NutrientTotals {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double sodium; // mg
  final int logCount;

  const NutrientTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.logCount = 0,
  });

  /// Zero state — shown when there are no food logs for the day.
  static const empty = NutrientTotals();

  bool get isEmpty => logCount == 0;

  /// Single O(n) pass over the log list.
  factory NutrientTotals.fromLogs(List<FoodLogModel> logs) {
    if (logs.isEmpty) return NutrientTotals.empty;

    int cal = 0;
    double pro = 0, carb = 0, fat = 0, sug = 0, sod = 0;

    for (final log in logs) {
      cal += log.calorieIntake;
      pro += log.protein;
      carb += log.carbs;
      fat += log.fats;
      sug += log.sugar;
      sod += log.sodium;
    }

    return NutrientTotals(
      calories: cal,
      protein: pro,
      carbs: carb,
      fat: fat,
      sugar: sug,
      sodium: sod,
      logCount: logs.length,
    );
  }

  /// Value equality — lets widgets skip rebuild when totals haven't changed.
  @override
  bool operator ==(Object other) =>
      other is NutrientTotals &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat &&
      other.sugar == sugar &&
      other.sodium == sodium &&
      other.logCount == logCount;

  @override
  int get hashCode =>
      Object.hash(calories, protein, carbs, fat, sugar, sodium, logCount);

  @override
  String toString() =>
      'NutrientTotals(cal:$calories pro:${protein.toStringAsFixed(1)} '
      'carb:${carbs.toStringAsFixed(1)} fat:${fat.toStringAsFixed(1)} '
      'sug:${sugar.toStringAsFixed(1)} sod:${sodium.toStringAsFixed(0)} '
      'logs:$logCount)';
}
