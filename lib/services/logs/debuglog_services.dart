import 'package:flutter/foundation.dart';

class LogService {
  // A static list to hold logs in memory during the session
  static final List<String> _logs = [];

  static void info(String message) {
    final logEntry = "[${DateTime.now().toString().split(' ').last}] INFO: $message";
    _logs.add(logEntry);
    if (kDebugMode) print(logEntry);
  }

  static List<String> getLogs() => _logs;

  static void clear() => _logs.clear();
}