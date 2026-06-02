// lib/services/logging/activity_logger.dart
//
// Singleton logging service. Called throughout the app, never awaited.
//
// Design:
//   - All writes are fire-and-forget — never block the UI.
//   - In-memory buffer catches events when Firestore is unreachable.
//   - Flushes buffered events on the next successful write.
//   - Session ID (UUID v4) groups all events from one app launch.
//   - OCR text is truncated at 1000 chars; error messages at 500 chars.
//   - Called from: ScanViewModel, FoodLogViewModel, Wrapper (auth).
//   - NOT called from views or repositories.
//
// Firestore path: app_logs/{uid}/events/{logId}

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class ActivityLogger {
  ActivityLogger._();
  static final ActivityLogger instance = ActivityLogger._();

  final _uuid = const Uuid();
  final _db = FirebaseFirestore.instance;

  String? _uid;
  String? _sessionId;
  String? _appVersion;
  String _platform = 'unknown';

  /// Events buffered while offline (or before first successful write).
  /// Flushed on next write attempt.
  final List<ActivityLog> _buffer = [];
  bool _flushing = false;

  // ── Initialise once per sign-in ──────────────────────────────────────────

  void init({required String uid, String appVersion = '1.0.0'}) {
    _uid = uid;
    _sessionId = _uuid.v4();
    _appVersion = appVersion;
    _platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : Platform.isMacOS
        ? 'macos'
        : 'other';
    if (kDebugMode) {
      debugPrint(
        '[AL] init uid=${uid.substring(0, 6)}… sess=${_sessionId!.substring(0, 8)}',
      );
    }
    log(ActivityEventType.sessionStart);
  }

  void clearSession() {
    _uid = null;
    _sessionId = null;
  }

  // ── Primary log call ─────────────────────────────────────────────────────

  void log(
    ActivityEventType type, {
    String? ocrExtractedText,
    String? aiPredictionLabel,
    double? aiConfidence,
    String? scanImagePath,
    List<String>? flaggedIngredients,
    String? foodName,
    int? calories,
    String? foodSource,
    String? errorCode,
    String? errorMessage,
    StackTrace? stackTrace,
    int? durationMs,
    String? searchQuery,
    int? searchResultCount,
  }) {
    if (_uid == null) return; // not initialised — silent skip

    _enqueue(
      ActivityLog(
        logId: _uuid.v4(),
        uid: _uid!,
        eventType: type,
        timestamp: DateTime.now().toUtc(),
        sessionId: _sessionId,
        appVersion: _appVersion,
        platform: _platform,
        ocrExtractedText: ocrExtractedText != null
            ? _cut(ocrExtractedText, 1000)
            : null,
        aiPredictionLabel: aiPredictionLabel,
        aiConfidence: aiConfidence,
        scanImagePath: scanImagePath,
        flaggedIngredients: flaggedIngredients,
        foodName: foodName,
        calories: calories,
        foodSource: foodSource,
        errorCode: errorCode,
        errorMessage: errorMessage != null ? _cut(errorMessage, 500) : null,
        stackTraceSnippet: stackTrace != null
            ? _cut(stackTrace.toString(), 500)
            : null,
        durationMs: durationMs,
        searchQuery: searchQuery,
        searchResultCount: searchResultCount,
      ),
    );
  }

  // ── Convenience helpers ──────────────────────────────────────────────────

  void logError(String code, dynamic err, [StackTrace? st]) => log(
    ActivityEventType.unexpectedError,
    errorCode: code,
    errorMessage: err.toString(),
    stackTrace: st,
  );

  /// Called after each scan completes. Chooses success vs low-confidence
  /// event type based on the threshold defined in ScanViewModel.
  void logScan({
    required String ocrText,
    required String label,
    required double confidence,
    required String? imagePath,
    required List<String> flagged,
    required int ms,
  }) => log(
    confidence < 0.5
        ? ActivityEventType.aiPredictionLowConfidence
        : ActivityEventType.aiPredictionSuccess,
    ocrExtractedText: ocrText,
    aiPredictionLabel: label,
    aiConfidence: confidence,
    scanImagePath: imagePath,
    flaggedIngredients: flagged,
    durationMs: ms,
  );

  void logFoodAdded(String name, int cal, String src) => log(
    ActivityEventType.foodLogAdded,
    foodName: name,
    calories: cal,
    foodSource: src,
  );

  void logSearch(String q, int results) => log(
    ActivityEventType.foodSearched,
    searchQuery: q,
    searchResultCount: results,
  );

  // ── Write pipeline ───────────────────────────────────────────────────────

  void _enqueue(ActivityLog e) {
    if (kDebugMode) debugPrint('[AL] ${e.eventType.key}');
    _buffer.add(e);
    _flush();
  }

  Future<void> _flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;

    while (_buffer.isNotEmpty) {
      final e = _buffer.first;
      try {
        await _db
            .collection('app_logs')
            .doc(e.uid)
            .collection('events')
            .doc(e.logId)
            .set(e.toMap());
        _buffer.removeAt(0);
      } catch (err) {
        // Write failed — offline or denied. Stop and retry on next log() call.
        LogService.error('[AL] write failed, ${_buffer.length} buffered', err);
        break;
      }
    }

    _flushing = false;
  }

  String _cut(String s, int n) => s.length > n ? '${s.substring(0, n)}…' : s;
}
