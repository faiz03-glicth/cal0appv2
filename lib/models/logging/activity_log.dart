enum ActivityEventType {
  // ── Auth ──────────────────────────────────────────────────────────
  userLogin,
  userLogout,
  userRegistered,
  sessionStart,

  // ── Food logging ──────────────────────────────────────────────────
  foodLogAdded,
  foodLogEdited,
  foodLogDeleted,
  foodSearched,
  recentFoodUsed,

  // ── OCR / Scan pipeline ───────────────────────────────────────────
  scanInitiated,
  scanOcrCompleted,
  scanAiAnalysed,
  scanResultSaved,
  scanFailed,

  // ── AI model ──────────────────────────────────────────────────────
  aiPredictionSuccess,
  aiPredictionLowConfidence,
  aiPredictionFailed,
  aiModelLoadFailed,

  // ── Feature use ───────────────────────────────────────────────────
  dashboardViewed,
  historyViewed,
  profileUpdated,
  healthConditionsUpdated,
  healthWarningShown,
  healthWarningIgnored,

  // ── Errors ────────────────────────────────────────────────────────
  apiCallFailed,
  firebaseError,
  appCrash,
  unexpectedError,

  // ── Performance ───────────────────────────────────────────────────
  slowOperation,
}

extension ActivityEventTypeX on ActivityEventType {
  String get key => name;
  static ActivityEventType fromKey(String k) =>
      ActivityEventType.values.firstWhere(
        (e) => e.name == k,
        orElse: () => ActivityEventType.unexpectedError,
      );
}

class ActivityLog {
  final String logId;
  final String uid;
  final ActivityEventType eventType;
  final DateTime timestamp;

  // Context
  final String? sessionId;
  final String? appVersion;
  final String? platform; // android / ios / other

  // Scan debug (OCR + AI)
  final String? ocrExtractedText; // ingredient section only, max 1000 chars
  final String? aiPredictionLabel; // 'SPIKED' | 'CLEAN'
  final double? aiConfidence; // 0.0–1.0
  final String? scanImagePath; // Firebase Storage path
  final List<String>? flaggedIngredients;

  // Food log
  final String? foodName;
  final int? calories;
  final String? foodSource; // 'manual' | 'scanned' | 'search'

  // Error
  final String? errorCode;
  final String? errorMessage; // max 500 chars
  final String? stackTraceSnippet; // max 500 chars

  // Performance
  final int? durationMs;

  // Search
  final String? searchQuery;
  final int? searchResultCount;

  const ActivityLog({
    required this.logId,
    required this.uid,
    required this.eventType,
    required this.timestamp,
    this.sessionId,
    this.appVersion,
    this.platform,
    this.ocrExtractedText,
    this.aiPredictionLabel,
    this.aiConfidence,
    this.scanImagePath,
    this.flaggedIngredients,
    this.foodName,
    this.calories,
    this.foodSource,
    this.errorCode,
    this.errorMessage,
    this.stackTraceSnippet,
    this.durationMs,
    this.searchQuery,
    this.searchResultCount,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'logId': logId,
      'uid': uid,
      'eventType': eventType.key,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
    void a(String k, dynamic v) {
      if (v != null) m[k] = v;
    }

    a('sessionId', sessionId);
    a('appVersion', appVersion);
    a('platform', platform);
    a('ocrExtractedText', ocrExtractedText);
    a('aiPredictionLabel', aiPredictionLabel);
    a('aiConfidence', aiConfidence);
    a('scanImagePath', scanImagePath);
    a('flaggedIngredients', flaggedIngredients);
    a('foodName', foodName);
    a('calories', calories);
    a('foodSource', foodSource);
    a('errorCode', errorCode);
    a('errorMessage', errorMessage);
    a('stackTraceSnippet', stackTraceSnippet);
    a('durationMs', durationMs);
    a('searchQuery', searchQuery);
    a('searchResultCount', searchResultCount);
    return m;
  }

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
    logId: m['logId'] ?? '',
    uid: m['uid'] ?? '',
    eventType: ActivityEventTypeX.fromKey(m['eventType'] ?? ''),
    timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
    sessionId: m['sessionId'],
    appVersion: m['appVersion'],
    platform: m['platform'],
    ocrExtractedText: m['ocrExtractedText'],
    aiPredictionLabel: m['aiPredictionLabel'],
    aiConfidence: (m['aiConfidence'] as num?)?.toDouble(),
    scanImagePath: m['scanImagePath'],
    flaggedIngredients: m['flaggedIngredients'] != null
        ? List<String>.from(m['flaggedIngredients'])
        : null,
    foodName: m['foodName'],
    calories: (m['calories'] as num?)?.toInt(),
    foodSource: m['foodSource'],
    errorCode: m['errorCode'],
    errorMessage: m['errorMessage'],
    stackTraceSnippet: m['stackTraceSnippet'],
    durationMs: (m['durationMs'] as num?)?.toInt(),
    searchQuery: m['searchQuery'],
    searchResultCount: (m['searchResultCount'] as num?)?.toInt(),
  );
}
