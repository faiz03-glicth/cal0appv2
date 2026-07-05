

class ScanThresholds {
  ScanThresholds._(); // no instances — static constants only

  /// Below this, the AI verdict is shown as "low confidence" in the UI
  /// rather than a confident Authentic/Spiked/Plant-Based verdict.
  static const double lowAiConfidenceCutoff = 0.50;

  /// Below this, OCR quality is considered too poor to trust — the AI
  /// step is skipped entirely and the user is asked to retake the photo.
  /// Uses OcrTextCleanerService.overallConfidence (see note in
  /// ScanViewModel on why this replaces the old ad-hoc ASCII-ratio check).
  static const double lowOcrQualityCutoff = 0.35;

  /// Minimum ratio of alphanumeric characters in a line for it to count
  /// as "readable" text, used only as a fallback when cleanedOcr is
  /// unavailable (e.g. before Stage 1 cleaning has run).
  static const double minReadableCharRatio = 0.55;

  /// Pipelines exceeding this duration are logged as slow operations
  /// (single-image scan).
  static const int slowSingleScanMs = 9000;

  /// Pipelines exceeding this duration are logged as slow operations
  /// (multi-angle scan — allowed more time since it processes several images).
  static const int slowMultiScanMs = 15000;
}
