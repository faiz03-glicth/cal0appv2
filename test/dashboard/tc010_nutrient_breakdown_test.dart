// TC010 – UC010 View Nutrient Breakdown (pure model tests, no Firebase)
import 'package:flutter_test/flutter_test.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/models/foodlog_model.dart';

FoodLogModel _log({
  String id = 'log_1',
  String name = 'Test Food',
  int calories = 200,
  double protein = 10,
  double carbs = 30,
  double fat = 5,
  double fiber = 2,
  double sugar = 8,
  double sodium = 300,
}) =>
    FoodLogModel(
      foodLogID: id,
      userId: 'uid_001',
      foodLogName: name,
      calorieIntake: calories,
      foodLogDate: DateTime(2025, 1, 1),
      loggedAt: DateTime(2025, 1, 1),
      protein: protein,
      carbs: carbs,
      fats: fat,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
    );

void main() {
  // TC010_01 – Empty log list returns NutrientTotals.empty
  test('TC010_01: fromLogs([]) → returns empty totals with logCount 0', () {
    final totals = NutrientTotals.fromLogs([]);

    expect(totals.isEmpty, isTrue);
    expect(totals.logCount, equals(0));
    expect(totals.calories, equals(0));
    expect(totals.protein, equals(0.0));
  });

  // TC010_02 – Aggregation sums all logs correctly
  test('TC010_02: fromLogs with two entries → correctly sums nutrients', () {
    final logs = [
      _log(calories: 300, protein: 20, carbs: 40, fat: 10, sodium: 400),
      _log(
        id: 'log_2',
        calories: 200,
        protein: 15,
        carbs: 25,
        fat: 8,
        sodium: 250,
      ),
    ];

    final totals = NutrientTotals.fromLogs(logs);

    expect(totals.logCount, equals(2));
    expect(totals.calories, equals(500));
    expect(totals.protein, closeTo(35.0, 0.001));
    expect(totals.carbs, closeTo(65.0, 0.001));
    expect(totals.fat, closeTo(18.0, 0.001));
    expect(totals.sodium, closeTo(650.0, 0.001));
    expect(totals.isEmpty, isFalse);
  });

  // TC010_03 – netCarbs = carbs − fiber (clamped to 0)
  test('TC010_03: netCarbs = carbs - fiber, minimum 0', () {
    final log = _log(carbs: 20, fiber: 5);
    final totals = NutrientTotals.fromLogs([log]);

    expect(totals.netCarbs, closeTo(15.0, 0.001));
  });

  test('TC010_03b: fiber > carbs → netCarbs clamped to 0', () {
    final log = _log(carbs: 3, fiber: 10);
    final totals = NutrientTotals.fromLogs([log]);

    expect(totals.netCarbs, equals(0.0));
  });

  // TC010_04 – Single log: totals equal individual log values
  test('TC010_04: fromLogs with single log → totals match log values exactly', () {
    final log = _log(
      calories: 450,
      protein: 30,
      carbs: 55,
      fat: 12,
      fiber: 4,
      sugar: 15,
      sodium: 600,
    );

    final totals = NutrientTotals.fromLogs([log]);

    expect(totals.calories, equals(450));
    expect(totals.protein, closeTo(30.0, 0.001));
    expect(totals.carbs, closeTo(55.0, 0.001));
    expect(totals.fat, closeTo(12.0, 0.001));
    expect(totals.fiber, closeTo(4.0, 0.001));
    expect(totals.sugar, closeTo(15.0, 0.001));
    expect(totals.sodium, closeTo(600.0, 0.001));
    expect(totals.logCount, equals(1));
  });

  // TC010_05 – NutrientTotals.empty constant is truly empty
  test('TC010_05: NutrientTotals.empty → all fields are 0', () {
    const totals = NutrientTotals.empty;

    expect(totals.isEmpty, isTrue);
    expect(totals.calories, equals(0));
    expect(totals.protein, equals(0.0));
    expect(totals.carbs, equals(0.0));
    expect(totals.fat, equals(0.0));
    expect(totals.sodium, equals(0.0));
    expect(totals.logCount, equals(0));
  });
}
