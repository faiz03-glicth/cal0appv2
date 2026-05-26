import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/scan/ai_service.dart';
import 'package:cal0appv2/services/scan/nutrition_extractor_service.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

class ScanViewModel extends ChangeNotifier {
  final ScanRepository _scanRepo;
  final FoodLogRepository _foodLogRepo;
  final AminoSpikingAI _aiService = AminoSpikingAI();
  final NutritionExtractorService _extractor = NutritionExtractorService();
  final _uuid = const Uuid();

  ScanViewModel({
    ScanRepository? scanRepository,
    FoodLogRepository? foodLogRepository,
  }) : _scanRepo = scanRepository ?? ScanRepository(),
       _foodLogRepo = foodLogRepository ?? FoodLogRepository() {
    _aiService.initialize().then((_) {
      if (!_aiService.isReady) {
        ActivityLogger.instance.log(
          ActivityEventType.aiModelLoadFailed,
          errorMessage: 'TFLite DistilBERT model failed to initialise',
        );
      }
      notifyListeners();
    });
  }

  // ── State ────────────────────────────────────────────────────────────────
  bool isScanning = false;
  bool isAnalyzing = false;
  bool isSaving = false;

  String? scannedText;
  List<String> scannedLines = [];
  String? errorMessage;
  String? successMessage;
  File? scannedImageFile;

  ScanResultModel? extractedResult;
  bool hasSuspiciousIngredients = false;
  double aiConfidence = 0.0;

  /// True when OCR quality score < 0.40. AI inference is skipped.
  bool lowOcrQuality = false;

  /// True when AI confidence < 0.50. User is warned before saving.
  bool lowAiConfidence = false;

  String get verdictLabel {
    if (extractedResult == null) return '';
    final pct = '${(aiConfidence * 100).toStringAsFixed(0)}%';
    if (lowOcrQuality)
      return 'Scan quality too low — results may be inaccurate';
    if (lowAiConfidence)
      return 'AI confidence low ($pct) — please verify manually';
    return hasSuspiciousIngredients
        ? 'Potential amino spiking detected ($pct confidence)'
        : 'No suspicious ingredients found ($pct confidence)';
  }

  // ── Scan pipeline ────────────────────────────────────────────────────────

  Future<void> scanImage(File imageFile) async {
    _reset(imageFile);
    final timer = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      // Stage 1: OCR
      scannedLines = await _scanRepo.scanLabelLines(imageFile);
      scannedText = scannedLines.join('\n');
      final ocrMs = timer.elapsedMilliseconds;

      // Stage 2: quality gate
      final ocrQuality = _assessOcrQuality(scannedLines);
      lowOcrQuality = ocrQuality < 0.40;

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: ocrMs,
        scanImagePath: imageFile.path,
        errorMessage: lowOcrQuality
            ? 'OCR quality ${ocrQuality.toStringAsFixed(2)} < threshold 0.40'
            : null,
      );

      // Stage 3: nutrition extraction
      extractedResult = _extractor.extract(scannedLines);

      isScanning = false;
      isAnalyzing = true;
      notifyListeners();

      // Stage 4: AI inference (skipped if OCR quality too low)
      if (_aiService.isReady &&
          extractedResult!.ingredientText.isNotEmpty &&
          !lowOcrQuality) {
        final aiTimer = Stopwatch()..start();
        final result = await _aiService.analyzeIngredients(
          extractedResult!.ingredientText,
        );
        final aiMs = aiTimer.elapsedMilliseconds;

        hasSuspiciousIngredients = result['isSpiked'] as bool;
        aiConfidence = result['confidence'] as double;
        lowAiConfidence = aiConfidence < 0.50;

        ActivityLogger.instance.logScan(
          ocrText: scannedText!,
          label: hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN',
          confidence: aiConfidence,
          imagePath: imageFile.path,
          flagged: (result['flagged'] as List?)?.cast<String>() ?? [],
          ms: aiMs,
        );
      } else if (lowOcrQuality) {
        // Fallback: rule-based only
        hasSuspiciousIngredients = false;
        aiConfidence = 0.0;
        ActivityLogger.instance.log(
          ActivityEventType.aiPredictionLowConfidence,
          ocrExtractedText: scannedText,
          errorMessage: 'Skipped AI: OCR quality gate failed',
          scanImagePath: imageFile.path,
        );
      }

      // Stage 5: slow pipeline alert (> 5s)
      final totalMs = timer.elapsedMilliseconds;
      if (totalMs > 5000) {
        ActivityLogger.instance.log(
          ActivityEventType.slowOperation,
          durationMs: totalMs,
          errorMessage: 'Scan pipeline exceeded 5000ms',
        );
      }
    } catch (e, st) {
      errorMessage = 'Scan failed. Please try again with better lighting.';
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'SCAN_PIPELINE_ERROR',
        errorMessage: e.toString(),
        stackTrace: st,
      );
    }

    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<bool> saveScanResult({
    required String uid,
    required ScanResultModel confirmed,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final log = FoodLogModel(
        foodLogID: _uuid.v4(),
        userId: uid,
        foodLogName: confirmed.productName.isEmpty
            ? 'Scanned Product'
            : confirmed.productName,
        calorieIntake: confirmed.calories,
        foodLogDate: now,
        loggedAt: now,
        protein: confirmed.protein,
        carbs: confirmed.carbs,
        fats: confirmed.fat,
        source: FoodLogSource.scanned,
        servingSize: confirmed.servingSize,
        servingUnit: confirmed.servingUnit,
        sugar: confirmed.sugar,
        sodium: confirmed.sodium,
        imagePath: scannedImageFile?.path,
        scanConfidence: confirmed.extractionConfidence,
        scanAnalysisResult: hasSuspiciousIngredients
            ? 'SPIKED (${(aiConfidence * 100).toStringAsFixed(0)}%)'
            : 'CLEAN (${(aiConfidence * 100).toStringAsFixed(0)}%)',
      );

      await _foodLogRepo.addFoodLog(uid, log);

      ActivityLogger.instance.log(
        ActivityEventType.scanResultSaved,
        foodName: log.foodLogName,
        calories: log.calorieIntake,
        foodSource: 'scanned',
        aiPredictionLabel: log.scanAnalysisResult,
        aiConfidence: aiConfidence,
      );

      successMessage = 'Saved to food log!';
    } catch (e, st) {
      errorMessage = 'Failed to save: $e';
      ActivityLogger.instance.logError('SCAN_SAVE_ERROR', e, st);
      isSaving = false;
      notifyListeners();
      return false;
    }

    isSaving = false;
    notifyListeners();
    return true;
  }

  // ── OCR quality assessment ────────────────────────────────────────────────
  // Scores 0.0 (garbage) to 1.0 (clean label scan).
  // A "good" line is ≥ 60% ASCII alphanumerics.

  double _assessOcrQuality(List<String> lines) {
    if (lines.isEmpty) return 0.0;
    int good = 0;
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final ascii = t.runes
          .where(
            (c) =>
                (c >= 65 && c <= 90) ||
                (c >= 97 && c <= 122) ||
                (c >= 48 && c <= 57),
          )
          .length;
      if (t.isNotEmpty && ascii / t.length >= 0.60) good++;
    }
    return good / lines.length;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _reset(File imageFile) {
    isScanning = true;
    isAnalyzing = false;
    isSaving = false;
    errorMessage = null;
    successMessage = null;
    scannedText = null;
    scannedLines = [];
    extractedResult = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
    lowOcrQuality = false;
    lowAiConfidence = false;
    scannedImageFile = imageFile;
    notifyListeners();
  }

  void clearScan() {
    scannedText = null;
    scannedLines = [];
    errorMessage = null;
    successMessage = null;
    extractedResult = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
    lowOcrQuality = false;
    lowAiConfidence = false;
    scannedImageFile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanRepo.dispose();
    _aiService.dispose();
    super.dispose();
  }
}
