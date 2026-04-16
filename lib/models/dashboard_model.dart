class DashboardModel {
  String _analysisResult, _nutrientStatus, _userId, _foodLog, _scanLog;
  int _totalCalories;
  List<dynamic> _recentFoodLogs, _recentSupplements;

  DashboardModel({
    required String analysisResult,
    required String nutrientStatus,
    required String userId,
    required String foodLog,
    required String scanLog,
    required int totalCalories,
    required List<dynamic> recentFoodLogs,
    required List<dynamic> recentSupplements,
  }) : _analysisResult = analysisResult,
       _nutrientStatus = nutrientStatus,
       _userId = userId,
       _foodLog = foodLog,
       _scanLog = scanLog,
       _totalCalories = totalCalories,
       _recentFoodLogs = recentFoodLogs,
       _recentSupplements = recentSupplements;

  // Getters
  String get analysisResult => _analysisResult;
  String get nutrientStatus => _nutrientStatus;
  String get userId => _userId;
  String get foodLog => _foodLog;
  String get scanLog => _scanLog;
  int get totalCalories => _totalCalories;
  List<dynamic> get recentFoodLogs => _recentFoodLogs;
  List<dynamic> get recentSupplements => _recentSupplements;

  // Setters
  set analysisResult(String value) => _analysisResult = value;
  set nutrientStatus(String value) => _nutrientStatus = value;
  set userId(String value) => _userId = value;
  set foodLog(String value) => _foodLog = value;
  set scanLog(String value) => _scanLog = value;
  set totalCalories(int value) => _totalCalories = value;
  set recentFoodLogs(List<dynamic> value) => _recentFoodLogs = value;
  set recentSupplements(List<dynamic> value) => _recentSupplements = value;

  Map<String, dynamic> toMap() => {
    'analysisResult': _analysisResult,
    'nutrientStatus': _nutrientStatus,
    'userId': _userId,
    'foodLog': _foodLog,
    'scanLog': _scanLog,
    'totalCalories': _totalCalories,
    'recentFoodLogs': _recentFoodLogs,
    'recentSupplements': _recentSupplements,
  };
}
