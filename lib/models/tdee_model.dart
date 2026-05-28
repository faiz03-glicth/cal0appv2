class TDEEModel {
  final String gender;
  final String activityLevel;
  final String goal;
  final int age;
  final double weight; // kg
  final double height; // cm

  TDEEModel({
    required this.gender,
    required this.activityLevel,
    required this.goal,
    required this.age,
    required this.weight,
    required this.height,
  });

  // ── BMR (Mifflin-St Jeor) ─────────────────────────────────────────────────

  double calculateBMR() {
    // Clamp inputs to physiologically plausible range
    final w = weight.clamp(30.0, 300.0);
    final h = height.clamp(100.0, 250.0);
    final a = age.clamp(10, 100);

    final base = (10.0 * w) + (6.25 * h) - (5.0 * a);
    return gender.toLowerCase() == 'male' ? base + 5.0 : base - 161.0;
  }

  // ── BMR (Harris-Benedict) — for reference / comparison ───────────────────

  double calculateBMRHarrisBenedict() {
    final w = weight.clamp(30.0, 300.0);
    final h = height.clamp(100.0, 250.0);
    final a = age.clamp(10, 100);

    if (gender.toLowerCase() == 'male') {
      return 88.362 + (13.397 * w) + (4.799 * h) - (5.677 * a);
    } else {
      return 447.593 + (9.247 * w) + (3.098 * h) - (4.330 * a);
    }
  }

  // ── Activity multiplier ───────────────────────────────────────────────────

  double getActivityMultiplier() {
    // Normalise: lower-case, collapse whitespace
    final level = activityLevel.toLowerCase().trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // Accept all reasonable variants from the dropdown + legacy strings
    if (level.contains('sedentary')) return 1.200;
    if (level.contains('extra') || level.contains('very very')) return 1.900;
    if (level.contains('very active') || level == 'very') return 1.725;
    if (level.contains('moderate') || level == 'moderately active')
      return 1.550;
    if (level.contains('light') || level == 'lightly active') return 1.375;
    if (level.contains('active')) return 1.550; // fallback for bare "active"

    // Default: sedentary
    return 1.200;
  }

  // ── TDEE ──────────────────────────────────────────────────────────────────

  double calculateTDEE() {
    return calculateBMR() * getActivityMultiplier();
  }

  // ── Calorie target with goal adjustment ──────────────────────────────────

  double calculateCalorieTarget() {
    double tdee = calculateTDEE();

    final g = goal.toLowerCase().trim();
    double adjusted;

    if (g.contains('lose') && g.contains('fast')) {
      adjusted = tdee - 1000;
    } else if (g.contains('lose')) {
      adjusted = tdee - 500;
    } else if (g.contains('gain') && g.contains('fast')) {
      adjusted = tdee + 500;
    } else if (g.contains('gain')) {
      adjusted = tdee + 300;
    } else {
      adjusted = tdee; // maintain
    }

    // Sanity floor: never recommend below safe minimums
    final minKcal = gender.toLowerCase() == 'male' ? 1500.0 : 1200.0;
    return adjusted.clamp(minKcal, 4500.0);
  }

  // ── Macro breakdown ───────────────────────────────────────────────────────

  /// Returns protein (g), carbs (g), fat (g) based on goal-appropriate split.
  Map<String, double> calculateMacros() {
    final cal = calculateCalorieTarget();
    final g = goal.toLowerCase();

    // Protein-forward splits for body composition goals
    double proteinPct, carbPct, fatPct;

    if (g.contains('lose')) {
      // Higher protein preserves muscle during deficit
      proteinPct = 0.35;
      fatPct = 0.30;
      carbPct = 0.35;
    } else if (g.contains('gain')) {
      // Slight carb emphasis for muscle glycogen
      proteinPct = 0.30;
      fatPct = 0.25;
      carbPct = 0.45;
    } else {
      // Maintenance: balanced
      proteinPct = 0.30;
      fatPct = 0.25;
      carbPct = 0.45;
    }

    return {
      'protein': (cal * proteinPct) / 4.0, // 4 kcal/g
      'carbs': (cal * carbPct) / 4.0,
      'fat': (cal * fatPct) / 9.0, // 9 kcal/g
    };
  }

  // ── Convenience int getter ────────────────────────────────────────────────

  int get calorieTargetInt => calculateCalorieTarget().round();
  int get bmrInt => calculateBMR().round();
  int get tdeeInt => calculateTDEE().round();

  // ── Debug summary ─────────────────────────────────────────────────────────

  String getSummary() {
    final bmr = calculateBMR();
    final tdee = calculateTDEE();
    final target = calculateCalorieTarget();
    final macros = calculateMacros();

    return '''
=== TDEE Summary (Mifflin-St Jeor) ===
Gender         : $gender
Age            : $age years
Weight         : $weight kg
Height         : $height cm
Activity Level : $activityLevel  (×${getActivityMultiplier().toStringAsFixed(3)})
Goal           : $goal

BMR            : ${bmr.toStringAsFixed(0)} kcal/day
TDEE           : ${tdee.toStringAsFixed(0)} kcal/day
Calorie Target : ${target.toStringAsFixed(0)} kcal/day

=== Macros ===
Protein : ${macros['protein']!.toStringAsFixed(1)} g/day
Carbs   : ${macros['carbs']!.toStringAsFixed(1)} g/day
Fat     : ${macros['fat']!.toStringAsFixed(1)} g/day
    ''';
  }
}
