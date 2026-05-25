import 'package:cal0appv2/models/health/health_condition.dart';

class HealthWarningService {
  /// Analyse [nutrition] against all [conditions] the user has declared.
  /// Returns warnings sorted by severity (high first).
  /// Returns an empty list if no risks are detected.
  List<HealthWarning> analyse(
    FoodNutritionSnapshot nutrition,
    List<HealthCondition> conditions,
  ) {
    final warnings = <HealthWarning>[];
    for (final condition in conditions) {
      final w = _check(condition, nutrition);
      if (w != null) warnings.add(w);
    }

    // Deduplicate by condition, keep highest risk if somehow duplicated
    final seen = <HealthCondition>{};
    final unique = <HealthWarning>[];
    // Sort high-risk first so the dialog shows the most critical warning first
    warnings.sort((a, b) {
      if (a.riskLevel == b.riskLevel) return 0;
      return a.riskLevel == RiskLevel.high ? -1 : 1;
    });
    for (final w in warnings) {
      if (seen.add(w.condition)) unique.add(w);
    }
    return unique;
  }

  // ── Per-condition rule checkers ────────────────────────────────────────

  HealthWarning? _check(HealthCondition condition, FoodNutritionSnapshot n) {
    switch (condition) {
      case HealthCondition.diabetes:
        return _checkDiabetes(n);
      case HealthCondition.hypertension:
        return _checkHypertension(n);
      case HealthCondition.heartDisease:
        return _checkHeartDisease(n);
      case HealthCondition.kidneyDisease:
        return _checkKidneyDisease(n);
      case HealthCondition.highCholesterol:
        return _checkCholesterol(n);
      case HealthCondition.obesity:
        return _checkObesity(n);
      case HealthCondition.celiacDisease:
        return _checkCeliac(n);
      case HealthCondition.lactoseIntolerance:
        return _checkLactose(n);
    }
  }

  // ── Diabetes ───────────────────────────────────────────────────────────

  HealthWarning? _checkDiabetes(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();

    // High-glycaemic food name patterns
    final highGlycaemicKeywords = [
      'syrup',
      'candy',
      'soda',
      'juice',
      'cake',
      'cookie',
      'donut',
      'chocolate',
      'ice cream',
      'milkshake',
      'sweet',
      'pudding',
      'jam',
      'honey',
      'sugar',
      'cola',
      'fanta',
      'sprite',
      'bubble tea',
    ];
    final starchKeywords = [
      'white rice',
      'nasi',
      'bread',
      'roti',
      'pasta',
      'noodle',
      'mee',
      'bihun',
      'mashed potato',
      'french fries',
      'chips',
    ];

    final nameIsHighGlycaemic = highGlycaemicKeywords.any(
      (k) => nameLower.contains(k),
    );
    final nameIsStarchy = starchKeywords.any((k) => nameLower.contains(k));

    // Numerical thresholds
    if (n.sugar > 15 || (n.sugar > 0 && nameIsHighGlycaemic)) {
      return HealthWarning(
        condition: HealthCondition.diabetes,
        riskLevel: RiskLevel.high,
        headline: 'High Sugar Content Detected',
        message:
            'This food contains high sugar (${_fmt(n.sugar)}g) that may '
            'cause a rapid spike in blood sugar levels. '
            'If you have diabetes, please consume in moderation or '
            'consider a lower-sugar alternative.',
        nutritionDetail:
            'Sugar: ${_fmt(n.sugar)}g  ·  Carbs: ${_fmt(n.carbs)}g',
      );
    }

    if (n.carbs > 45 || (n.carbs > 25 && nameIsStarchy)) {
      return HealthWarning(
        condition: HealthCondition.diabetes,
        riskLevel: RiskLevel.high,
        headline: 'High Carbohydrate / Starch Content',
        message:
            'This food is high in carbohydrates (${_fmt(n.carbs)}g) or '
            'refined starch, which can raise blood sugar levels. '
            'Watch your portion size and pair with protein or fibre '
            'to slow sugar absorption.',
        nutritionDetail:
            'Carbs: ${_fmt(n.carbs)}g  ·  Sugar: ${_fmt(n.sugar)}g',
      );
    }

    if (n.carbs > 25 || n.sugar > 8) {
      return HealthWarning(
        condition: HealthCondition.diabetes,
        riskLevel: RiskLevel.moderate,
        headline: 'Moderate Sugar / Carb Content',
        message:
            'This food has a moderate amount of carbohydrates '
            '(${_fmt(n.carbs)}g) or sugar (${_fmt(n.sugar)}g). '
            'It can be part of a balanced meal — just keep track '
            'of your total daily carb intake.',
        nutritionDetail:
            'Carbs: ${_fmt(n.carbs)}g  ·  Sugar: ${_fmt(n.sugar)}g',
      );
    }

    return null;
  }

  // ── Hypertension ───────────────────────────────────────────────────────

  HealthWarning? _checkHypertension(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    final saltyKeywords = [
      'salted',
      'salty',
      'pickle',
      'soy sauce',
      'kicap',
      'anchovies',
      'ikan bilis',
      'processed',
      'instant noodle',
      'maggi',
      'canned',
      'preserved',
      'bacon',
      'sausage',
      'ham',
    ];
    final isSaltyFood = saltyKeywords.any((k) => nameLower.contains(k));

    if (n.sodium > 800 || (n.sodium > 400 && isSaltyFood)) {
      return HealthWarning(
        condition: HealthCondition.hypertension,
        riskLevel: RiskLevel.high,
        headline: 'Very High Sodium Content',
        message:
            'This food contains ${_fmtInt(n.sodium)}mg of sodium — '
            'well above the safe limit for a single serving if you have '
            'high blood pressure. High sodium intake can raise blood pressure '
            'significantly. Consider a low-sodium alternative or reduce '
            'portion size.',
        nutritionDetail:
            'Sodium: ${_fmtInt(n.sodium)}mg  (daily limit ≈ 1500–2000mg)',
      );
    }

    if (n.sodium > 400) {
      return HealthWarning(
        condition: HealthCondition.hypertension,
        riskLevel: RiskLevel.moderate,
        headline: 'Elevated Sodium Content',
        message:
            'This food contains ${_fmtInt(n.sodium)}mg of sodium. '
            'For someone managing blood pressure, keep an eye on total '
            'daily sodium. Try to balance this with low-sodium meals '
            'throughout the day.',
        nutritionDetail: 'Sodium: ${_fmtInt(n.sodium)}mg',
      );
    }

    return null;
  }

  // ── Heart Disease ──────────────────────────────────────────────────────

  HealthWarning? _checkHeartDisease(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    final unhealthyFatKeywords = [
      'fried',
      'deep fried',
      'goreng',
      'butter',
      'margarine',
      'lard',
      'ghee',
      'full cream',
      'fatty',
      'creamy',
    ];
    final isHighFatFood = unhealthyFatKeywords.any(
      (k) => nameLower.contains(k),
    );

    if (n.fat > 20 || (n.fat > 10 && isHighFatFood)) {
      return HealthWarning(
        condition: HealthCondition.heartDisease,
        riskLevel: RiskLevel.high,
        headline: 'High Fat Content',
        message:
            'This food is high in fat (${_fmt(n.fat)}g), which may '
            'contribute to plaque build-up in arteries over time. '
            'For heart health, choose foods with unsaturated fats '
            'and limit saturated or trans fats.',
        nutritionDetail:
            'Fat: ${_fmt(n.fat)}g  ·  Sodium: ${_fmtInt(n.sodium)}mg',
      );
    }

    if (n.fat > 12 || n.sodium > 500) {
      return HealthWarning(
        condition: HealthCondition.heartDisease,
        riskLevel: RiskLevel.moderate,
        headline: 'Moderate Fat or Sodium Content',
        message:
            'This food has a moderate fat or sodium level. '
            'Regular consumption of high-fat, high-sodium foods '
            'can strain the cardiovascular system. '
            'Balance with heart-healthy options like vegetables, '
            'legumes, and lean protein.',
        nutritionDetail:
            'Fat: ${_fmt(n.fat)}g  ·  Sodium: ${_fmtInt(n.sodium)}mg',
      );
    }

    return null;
  }

  // ── Kidney Disease ─────────────────────────────────────────────────────

  HealthWarning? _checkKidneyDisease(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    final highPotassiumKeywords = [
      'banana',
      'pisang',
      'potato',
      'kentang',
      'tomato',
      'tomato sauce',
      'avocado',
      'spinach',
      'bayam',
      'orange',
      'dried fruit',
      'dates',
    ];
    final isHighPotassium = highPotassiumKeywords.any(
      (k) => nameLower.contains(k),
    );

    if (n.protein > 25 || n.sodium > 600) {
      return HealthWarning(
        condition: HealthCondition.kidneyDisease,
        riskLevel: RiskLevel.high,
        headline: 'High Protein or Sodium — Kidney Concern',
        message:
            'This food is high in protein (${_fmt(n.protein)}g) or '
            'sodium (${_fmtInt(n.sodium)}mg). Excess protein and sodium '
            'make the kidneys work harder, which may worsen kidney function. '
            'Stick to your prescribed protein limits and choose '
            'low-sodium options.',
        nutritionDetail:
            'Protein: ${_fmt(n.protein)}g  ·  Sodium: ${_fmtInt(n.sodium)}mg',
      );
    }

    if (isHighPotassium) {
      return HealthWarning(
        condition: HealthCondition.kidneyDisease,
        riskLevel: RiskLevel.moderate,
        headline: 'Potentially High Potassium Food',
        message:
            'This food may be high in potassium. Damaged kidneys may '
            'not filter potassium properly, which can affect heart rhythm. '
            'Please check with your dietitian about your daily '
            'potassium limit.',
        nutritionDetail: null,
      );
    }

    if (n.protein > 15) {
      return HealthWarning(
        condition: HealthCondition.kidneyDisease,
        riskLevel: RiskLevel.moderate,
        headline: 'Moderate Protein Content',
        message:
            'This food contains ${_fmt(n.protein)}g of protein. '
            'Moderate protein intake is important for kidney health. '
            'Ensure this fits within your daily protein allowance.',
        nutritionDetail: 'Protein: ${_fmt(n.protein)}g',
      );
    }

    return null;
  }

  // ── High Cholesterol ───────────────────────────────────────────────────

  HealthWarning? _checkCholesterol(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    final highCholKeywords = [
      'egg yolk',
      'kuning telur',
      'organ meat',
      'offal',
      'liver',
      'hati',
      'butter',
      'mentega',
      'full cream',
      'cheese',
      'keju',
      'fried',
      'goreng',
      'cream',
      'lard',
    ];
    final isCholesterolRich = highCholKeywords.any(
      (k) => nameLower.contains(k),
    );

    if (n.fat > 18 || isCholesterolRich) {
      return HealthWarning(
        condition: HealthCondition.highCholesterol,
        riskLevel: isCholesterolRich ? RiskLevel.high : RiskLevel.moderate,
        headline: isCholesterolRich
            ? 'Cholesterol-Rich Food Detected'
            : 'High Fat — Cholesterol Concern',
        message: isCholesterolRich
            ? 'This food is known to be high in dietary cholesterol or '
                  'saturated fat, which can raise LDL ("bad") cholesterol. '
                  'Limit frequency and portion size, especially if your '
                  'cholesterol is already elevated.'
            : 'This food is high in fat (${_fmt(n.fat)}g) which may '
                  'contribute to higher cholesterol levels over time. '
                  'Prefer foods with healthy unsaturated fats.',
        nutritionDetail: 'Fat: ${_fmt(n.fat)}g',
      );
    }

    return null;
  }

  // ── Obesity ────────────────────────────────────────────────────────────

  HealthWarning? _checkObesity(FoodNutritionSnapshot n) {
    if (n.calories > 600) {
      return HealthWarning(
        condition: HealthCondition.obesity,
        riskLevel: RiskLevel.high,
        headline: 'Very High Calorie Food',
        message:
            'This item contains ${n.calories} kcal — a large portion '
            'of a typical daily calorie budget. High-calorie foods '
            'eaten frequently can make weight management harder. '
            'Consider a smaller portion or a lighter alternative.',
        nutritionDetail:
            '${n.calories} kcal  ·  Fat: ${_fmt(n.fat)}g  ·  Carbs: ${_fmt(n.carbs)}g',
      );
    }

    if (n.calories > 400 || n.fat > 18) {
      return HealthWarning(
        condition: HealthCondition.obesity,
        riskLevel: RiskLevel.moderate,
        headline: 'Calorie-Dense Food',
        message:
            'This food is moderately calorie-dense (${n.calories} kcal). '
            'It can fit into your day, but be mindful of portion size '
            'and how it balances with your other meals.',
        nutritionDetail: '${n.calories} kcal  ·  Fat: ${_fmt(n.fat)}g',
      );
    }

    return null;
  }

  // ── Celiac Disease ─────────────────────────────────────────────────────

  HealthWarning? _checkCeliac(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    // Clear gluten sources
    final highGlutenKeywords = [
      'bread',
      'roti',
      'wheat',
      'gandum',
      'flour',
      'tepung',
      'pasta',
      'noodle',
      'mee',
      'spaghetti',
      'pizza',
      'cake',
      'cookie',
      'biscuit',
      'cracker',
      'cereal',
      'oat',
      'barley',
      'rye',
      'croissant',
      'muffin',
      'pancake',
      'waffle',
    ];
    // Potentially hidden gluten
    final hiddenGlutenKeywords = [
      'soy sauce',
      'kicap',
      'gravy',
      'sauce',
      'seasoning',
      'marinade',
      'malt',
      'beer',
      'breaded',
      'battered',
    ];

    final isObviousGluten = highGlutenKeywords.any(
      (k) => nameLower.contains(k),
    );
    final isHiddenGluten = hiddenGlutenKeywords.any(
      (k) => nameLower.contains(k),
    );

    if (isObviousGluten) {
      return HealthWarning(
        condition: HealthCondition.celiacDisease,
        riskLevel: RiskLevel.high,
        headline: 'Contains Gluten',
        message:
            'This food likely contains gluten (wheat, barley, or rye). '
            'For people with celiac disease, even small amounts of '
            'gluten can damage the small intestine. '
            'Please choose a certified gluten-free alternative.',
        nutritionDetail: null,
      );
    }

    if (isHiddenGluten) {
      return HealthWarning(
        condition: HealthCondition.celiacDisease,
        riskLevel: RiskLevel.moderate,
        headline: 'May Contain Hidden Gluten',
        message:
            'This food may contain hidden gluten in sauces, '
            'seasonings, or additives. Always check the ingredient '
            'label for wheat, barley, rye, or malt before consuming.',
        nutritionDetail: null,
      );
    }

    return null;
  }

  // ── Lactose Intolerance ────────────────────────────────────────────────

  HealthWarning? _checkLactose(FoodNutritionSnapshot n) {
    final nameLower = n.foodName.toLowerCase();
    final highLactoseKeywords = [
      'milk',
      'susu',
      'cheese',
      'keju',
      'butter',
      'mentega',
      'ice cream',
      'aiskrim',
      'yogurt',
      'yoghurt',
      'cream',
      'milkshake',
      'lassi',
      'whey',
      'custard',
      'pudding',
      'full cream',
      'half cream',
    ];
    final lowLactoseKeywords = [
      'lactose-free',
      'lactose free',
      'dairy-free',
      'oat milk',
      'almond milk',
      'soy milk',
      'susu soya',
      'coconut milk',
    ];

    final isHighLactose = highLactoseKeywords.any((k) => nameLower.contains(k));
    final isLactoseFree = lowLactoseKeywords.any((k) => nameLower.contains(k));

    if (isHighLactose && !isLactoseFree) {
      return HealthWarning(
        condition: HealthCondition.lactoseIntolerance,
        riskLevel: RiskLevel.moderate,
        headline: 'Contains Dairy / Lactose',
        message:
            'This food appears to contain dairy which has lactose. '
            'If you are lactose intolerant, consuming this may cause '
            'bloating, cramps, or discomfort. '
            'Consider a lactose-free or plant-based alternative.',
        nutritionDetail: null,
      );
    }

    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _fmt(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
  String _fmtInt(double v) => v.toInt().toString();
}
