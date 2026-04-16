class TDEEModel {
  String _gender, _activityLevel, _goal;
  int _age;
  double _weight, _height;

  TDEEModel({
    required String gender,
    required String activityLevel,
    required String goal,
    required int age,
    required double weight,
    required double height,
  }) : _gender = gender,
       _activityLevel = activityLevel,
       _goal = goal,
       _age = age,
       _weight = weight,
       _height = height;

  // Getters
  String get gender => _gender;
  String get activityLevel => _activityLevel;
  String get goal => _goal;
  int get age => _age;
  double get weight => _weight;
  double get height => _height;

  // Setters
  set gender(String value) => _gender = value;
  set activityLevel(String value) => _activityLevel = value;
  set goal(String value) => _goal = value;
  set age(int value) => _age = value;
  set weight(double value) => _weight = value;
  set height(double value) => _height = value;

  // Step 1 — BMR (Mifflin-St Jeor)
  double calculateBMR() {
    if (_gender.toLowerCase() == 'male') {
      return (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    } else {
      return (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;
    }
  }

  // Step 2 — Activity multiplier
  double getActivityMultiplier() {
    switch (_activityLevel.toLowerCase()) {
      case 'sedentary':
        return 1.2; // little or no exercise
      case 'lightly active':
        return 1.375; // light exercise 1-3 days/week
      case 'moderately active':
        return 1.55; // moderate exercise 3-5 days/week
      case 'very active':
        return 1.725; // hard exercise 6-7 days/week
      case 'extra active':
        return 1.9; // very hard exercise or physical job
      default:
        return 1.2;
    }
  }

  // Step 3 — TDEE
  double calculateTDEE() {
    return calculateBMR() * getActivityMultiplier();
  }

  // Step 4 — Calorie target based on goal
  double calculateCalorieTarget() {
    double tdee = calculateTDEE();
    switch (_goal.toLowerCase()) {
      case 'lose weight':
        return tdee - 500; // ~0.5kg/week loss
      case 'lose weight fast':
        return tdee - 1000; // ~1kg/week loss
      case 'maintain':
        return tdee;
      case 'gain weight':
        return tdee + 300; // lean bulk
      case 'gain weight fast':
        return tdee + 500; // aggressive bulk
      default:
        return tdee;
    }
  }

  // Macros breakdown based on calorie target
  Map<String, double> calculateMacros() {
    double calories = calculateCalorieTarget();
    return {
      'protein': (calories * 0.30) / 4, // 30% of calories, 4 cal/g
      'carbs': (calories * 0.45) / 4, // 45% of calories, 4 cal/g
      'fats': (calories * 0.25) / 9, // 25% of calories, 9 cal/g
    };
  }

  // Full summary
  String getSummary() {
    double bmr = calculateBMR();
    double tdee = calculateTDEE();
    double target = calculateCalorieTarget();
    Map<String, double> macros = calculateMacros();

    return '''
=== TDEE Summary ===
Gender        : $_gender
Age           : $_age years
Weight        : $_weight kg
Height        : $_height cm
Activity Level: $_activityLevel
Goal          : $_goal

BMR           : ${bmr.toStringAsFixed(0)} kcal/day
TDEE          : ${tdee.toStringAsFixed(0)} kcal/day
Calorie Target: ${target.toStringAsFixed(0)} kcal/day

=== Macros ===
Protein : ${macros['protein']!.toStringAsFixed(1)} g/day
Carbs   : ${macros['carbs']!.toStringAsFixed(1)} g/day
Fats    : ${macros['fats']!.toStringAsFixed(1)} g/day
    ''';
  }
}
