class ReportModel {
  String _reportId, _userId, _reportDetails;
  DateTime _timestamp;

  ReportModel({
    required String reportId,
    required String userId,
    required String reportDetails,
    required DateTime timestamp,
  }) : _reportId = reportId,
       _userId = userId,
       _reportDetails = reportDetails,
       _timestamp = timestamp;

  // Getters
  String get reportId => _reportId;
  String get userId => _userId;
  String get reportDetails => _reportDetails;
  DateTime get timestamp => _timestamp;

  // Setters
  set reportId(String value) => _reportId = value;
  set userId(String value) => _userId = value;
  set reportDetails(String value) => _reportDetails = value;
  set timestamp(DateTime value) => _timestamp = value;

  factory ReportModel.fromMap(Map<String, dynamic> map) => ReportModel(
    reportId: map['reportId'],
    userId: map['userId'],
    reportDetails: map['reportDetails'],
    timestamp: DateTime.parse(map['timestamp']),
  );

  Map<String, dynamic> toMap() => {
    'reportId': _reportId,
    'userId': _userId,
    'reportDetails': _reportDetails,
    'timestamp': _timestamp.toIso8601String(),
  };
}
