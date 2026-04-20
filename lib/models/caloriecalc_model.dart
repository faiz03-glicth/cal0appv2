class CalorieCalculatorModel {
  String _goal, _gender, _activityLevel;
  int _age;
  double _weight, _height;

  CalorieCalculatorModel({
    required String goal,
    required String gender,
    required String activityLevel,
    required int age,
    required double weight,
    required double height,
  }) : _goal = goal,
       _gender = gender,
       _activityLevel = activityLevel,
       _age = age,
       _weight = weight,
       _height = height;

  // Getters
  String get goals => _goal;
  String get genders => _gender;
  String get activityLevels => _activityLevel;
  int get ages => _age;
  double get weights => _weight;
  double get heights => _height;

  // Setters
  set goal(String value) => _goal = value;
  set gender(String value) => _gender = value;
  set activityLevel(String value) => _activityLevel = value;
  set age(int value) => _age = value;
  set weight(double value) => _weight = value;
  set height(double value) => _height = value;

  // Methods from domain model
  int calculateCalorieTarget(
    double weight,
    double height,
    int age,
    String gender,
  ) {
    // BMR using Mifflin-St Jeor formula
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Activity multiplier
    double activityMultiplier;
    switch (_activityLevel.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.2;
    }

    double tdee = bmr * activityMultiplier;

    // Goal adjustment
    switch (_goal.toLowerCase()) {
      case 'lose weight':
        return (tdee - 500).toInt();
      case 'gain weight':
        return (tdee + 500).toInt();
      case 'maintain':
        return tdee.toInt();
      default:
        return tdee.toInt();
    }
  }

  String getAllUserInfo() {
    return 'Goal: $_goal | Gender: $_gender | Age: $_age | '
        'Weight: $_weight kg | Height: $_height cm | Activity: $_activityLevel';
  }
}
