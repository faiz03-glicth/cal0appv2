import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/scan/scan_stage.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/scan/ai_service.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';
import 'package:cal0appv2/services/scan/nutrition_extractor_service.dart';
import 'package:cal0appv2/services/scan/image_preprocessor_service.dart';
import 'package:cal0appv2/services/scan/ocr_text_cleaner_service.dart';
import 'package:cal0appv2/services/scan/gemini_vision_service.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'package:cal0appv2/models/whey/whey_supplement_model.dart';
import 'package:cal0appv2/repositories/whey_supplement_repository.dart';
import 'package:cal0appv2/config/scan_thresholds.dart';

export 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart'
    show DetectedIngredient;

class _AcquiredScan {
  final List<File> imagesForGemini;
  final List<String> mergedLines;
  final CleanedOcrResult cleanedOcr;
  final bool lowOcrQuality;

  const _AcquiredScan({
    required this.imagesForGemini,
    required this.mergedLines,
    required this.cleanedOcr,
    required this.lowOcrQuality,
  });
}

class ScanViewModel extends ChangeNotifier {
  final ScanRepository _scanRepo;
  final FoodLogRepository _foodLogRepo;
  final WheySupplementRepository _wheyRepo = WheySupplementRepository();
  final AminoSpikingAI _aiService = AminoSpikingAI();
  final NutritionExtractorService _extractor = NutritionExtractorService();
  final ImagePreprocessorService _preprocessor = ImagePreprocessorService();
  final OcrTextCleanerService _cleaner = OcrTextCleanerService();
  final GeminiVisionService _gemini = GeminiVisionService();
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
          errorMessage: 'ONNX DistilBERT model failed to initialise',
        );
      }
      notifyListeners();
    });
  }

  // ── Observable state ──────────────────────────────────────────────────

  ScanStage currentStage = ScanStage.idle;

  bool isScanning = false;
  bool isAnalyzing = false;
  bool isSaving = false;

  String? scannedText;
  List<String> scannedLines = [];
  String? errorMessage;
  String? successMessage;

  File? scannedImageFile;
  File? preprocessedImageFile;

  ScanResultModel? extractedResult;
  CleanedOcrResult? cleanedOcr;
  PreprocessResult? preprocessResult;

  // AI verdict
  bool hasSuspiciousIngredients = false;
  double aiConfidence = 0.0;
  String aiLabel = ''; // 'Authentic' | 'Spiked' | 'Plant-Based'

  // Quality flags
  bool lowOcrQuality = false;
  bool lowAiConfidence = false;

  // Cleaner output
  double ocrConfidence = 0.0;
  List<String> uncertainWords = [];
  List<DetectedIngredient> detectedIngredients = [];
  bool geminiUsed = false;

  bool get showingOverlay =>
      isScanning &&
      currentStage != ScanStage.idle &&
      currentStage != ScanStage.done;

  String get verdictLabel {
    if (extractedResult == null) return '';
    final pct = '${(aiConfidence * 100).toStringAsFixed(0)}%';
    if (lowOcrQuality) return 'Scan quality too low — try retaking the photo';
    if (lowAiConfidence)
      return 'AI confidence low ($pct) — please verify manually';
    if (aiLabel == 'Plant-Based')
      return 'Plant-Based Protein ($pct confidence)';
    return hasSuspiciousIngredients
        ? 'Potential amino spiking detected ($pct confidence)'
        : 'No suspicious ingredients found ($pct confidence)';
  }

  // ── Public entry points ────────────────────────────────────────────────

  /// Single-photo scan pipeline.
  Future<void> scanImage(File imageFile) async {
    _reset(imageFile);
    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      _setStage(ScanStage.preparingImage);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      _setStage(ScanStage.enhancingQuality);
      final prepResult = await _preprocessor.preprocess(imageFile);
      preprocessResult = prepResult;
      preprocessedImageFile = prepResult.processedFile;

      _setStage(ScanStage.extractingText);
      var lines = await _scanRepo.scanLabelLines(prepResult.processedFile);
      if (lines.length < 4) {
        final origLines = await _scanRepo.scanLabelLines(imageFile);
        if (origLines.length > lines.length) lines = origLines;
      }

      final cleaned = _cleaner.clean(lines);
      final acquired = _AcquiredScan(
        imagesForGemini: [imageFile],
        mergedLines: lines,
        cleanedOcr: cleaned,
        lowOcrQuality: _isLowQuality(cleaned, lines),
      );

      await _runAnalysisPipeline(
        acquired: acquired,
        sw: sw,
        primaryImagePath: imageFile.path,
        slowThresholdMs: ScanThresholds.slowSingleScanMs,
        slowOpMessage: 'Enhanced scan pipeline > 9s',
        errorCode: 'SCAN_PIPELINE_ERROR',
      );
    } catch (e, st) {
      _handlePipelineError(e, st, 'SCAN_PIPELINE_ERROR');
    }

    _finishScan();
  }

  /// Multi-angle scan pipeline (3-5 photos), merged before analysis.
  ///
  /// Merge strategy:
  ///   • Each image is preprocessed + OCR'd independently, in parallel
  ///   • Lines are deduplicated (exact-match) — shared text counted once
  ///   • For nutrition values: highest-confidence non-zero value wins
  ///     (handled downstream by _applyGeminiResult / _mergeNutritionFromOcr)
  Future<void> scanMultipleImages(List<File> imageFiles) async {
    if (imageFiles.isEmpty) return;

    _reset(imageFiles.first);
    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      _setStage(ScanStage.preparingImage);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      _setStage(ScanStage.enhancingQuality);
      final prepResults = await Future.wait(
        imageFiles.map((f) => _preprocessor.preprocess(f)),
      );

      _setStage(ScanStage.extractingText);
      final ocrResults = await Future.wait(
        prepResults.map((pr) => _scanRepo.scanLabelLines(pr.processedFile)),
      );

      var mergedLines = _dedupeLines(ocrResults);

      // Fallback: if preprocessed yield was poor, also try originals.
      if (mergedLines.length < 6) {
        final origResults = await Future.wait(
          imageFiles.map((f) => _scanRepo.scanLabelLines(f)),
        );
        mergedLines = _dedupeLines([...ocrResults, ...origResults]);
      }

      final cleaned = _cleaner.clean(mergedLines);

      // Strictest quality gate: poor by both the cleaner AND every image's
      // own preprocessing quality score.
      final lowQuality =
          _isLowQuality(cleaned, mergedLines) &&
          prepResults.every(
            (p) => p.qualityScore < ScanThresholds.lowOcrQualityCutoff,
          );

      final acquired = _AcquiredScan(
        imagesForGemini: imageFiles,
        mergedLines: mergedLines,
        cleanedOcr: cleaned,
        lowOcrQuality: lowQuality,
      );

      await _runAnalysisPipeline(
        acquired: acquired,
        sw: sw,
        primaryImagePath: imageFiles.first.path,
        slowThresholdMs: ScanThresholds.slowMultiScanMs,
        slowOpMessage:
            'Multi-angle pipeline > 15s for ${imageFiles.length} images',
        errorCode: 'MULTI_SCAN_PIPELINE_ERROR',
      );
    } catch (e, st) {
      _handlePipelineError(e, st, 'MULTI_SCAN_PIPELINE_ERROR');
    }

    _finishScan();
  }

  // ── Shared pipeline (was duplicated across both public methods) ────────

  Future<void> _runAnalysisPipeline({
    required _AcquiredScan acquired,
    required Stopwatch sw,
    required String primaryImagePath,
    required int slowThresholdMs,
    required String slowOpMessage,
    required String errorCode,
  }) async {
    scannedLines = acquired.mergedLines;
    cleanedOcr = acquired.cleanedOcr;
    ocrConfidence = acquired.cleanedOcr.overallConfidence;
    uncertainWords = acquired.cleanedOcr.uncertainTokens;
    scannedText = acquired.cleanedOcr.fullText.isNotEmpty
        ? acquired.cleanedOcr.fullText
        : acquired.mergedLines.join('\n');
    lowOcrQuality = acquired.lowOcrQuality;

    ActivityLogger.instance.log(
      ActivityEventType.scanOcrCompleted,
      ocrExtractedText: scannedText,
      durationMs: sw.elapsedMilliseconds,
      scanImagePath: primaryImagePath,
      errorMessage: lowOcrQuality ? 'OCR quality gate failed' : null,
    );

    _setStage(ScanStage.analyzingIngredients);
    isAnalyzing = true;
    notifyListeners();

    // Nutrition extraction: baseline from OCR, refined by Gemini if available.
    extractedResult = _extractor.extract(acquired.mergedLines);
    if (cleanedOcr!.hasIngredients && extractedResult!.ingredientText.isEmpty) {
      extractedResult = extractedResult!.copyWith(
        ingredientText: cleanedOcr!.ingredientSection,
      );
    }
    if (cleanedOcr!.productName.isNotEmpty &&
        extractedResult!.productName.isEmpty) {
      extractedResult = extractedResult!.copyWith(
        productName: cleanedOcr!.productName,
      );
    }

    final geminiResult = await _gemini.extractNutrition(
      acquired.imagesForGemini,
    );
    if (geminiResult.hasData) {
      LogService.info('GeminiVision: succeeded — using Gemini values');
      extractedResult = _applyGeminiResult(extractedResult!, geminiResult);
      geminiUsed = true;
    } else {
      LogService.info('GeminiVision: unavailable — regex fallback');
      final rawOcrText = acquired.mergedLines.join('\n');
      extractedResult = _mergeNutritionFromOcr(
        extractedResult!,
        cleanedOcr!.nutritionSection,
        rawOcrText,
      );
      geminiUsed = false;
    }

    final textForDetection = _bestIngredientText(
      extracted: extractedResult!.ingredientText,
      cleaned: cleanedOcr!.ingredientSection,
      fullOcr: scannedText ?? '',
      allLines: acquired.mergedLines,
    );
    detectedIngredients = IngredientAuthenticityService.detectAll(
      textForDetection,
    );

    _setStage(ScanStage.generatingInsights);

    final ingredientText = extractedResult!.ingredientText.isNotEmpty
        ? extractedResult!.ingredientText
        : cleanedOcr!.ingredientSection.isNotEmpty
        ? cleanedOcr!.ingredientSection
        : scannedText ?? '';

    if (_aiService.isReady && ingredientText.isNotEmpty && !lowOcrQuality) {
      final aiSw = Stopwatch()..start();
      final result = await _aiService.analyzeIngredients(ingredientText);

      hasSuspiciousIngredients = result['isSpiked'] as bool;
      aiConfidence = result['confidence'] as double;
      aiLabel = result['label'] as String? ?? '';
      lowAiConfidence = aiConfidence < ScanThresholds.lowAiConfidenceCutoff;

      // Cross-check: if the model says "Spiked" but the rule-based detector
      // found no *confirmed* spiking agent by name, treat the verdict as
      // uncertain rather than confidently flagging the user.
      if (hasSuspiciousIngredients &&
          !IngredientAuthenticityService.hasConfirmedSpikingAgent(
            detectedIngredients,
          )) {
        lowAiConfidence = true;
      }

      ActivityLogger.instance.logScan(
        ocrText: scannedText!,
        label: aiLabel.isNotEmpty
            ? aiLabel
            : (hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN'),
        confidence: aiConfidence,
        imagePath: primaryImagePath,
        flagged: detectedIngredients.map((d) => d.name).toList(),
        ms: aiSw.elapsedMilliseconds,
      );
    } else {
      hasSuspiciousIngredients = false;
      aiConfidence = 0.0;
      aiLabel = '';
      if (lowOcrQuality) {
        ActivityLogger.instance.log(
          ActivityEventType.aiPredictionLowConfidence,
          ocrExtractedText: scannedText,
          errorMessage: 'AI skipped: OCR quality gate failed',
          scanImagePath: primaryImagePath,
        );
      }
    }

    if (sw.elapsedMilliseconds > slowThresholdMs) {
      ActivityLogger.instance.log(
        ActivityEventType.slowOperation,
        durationMs: sw.elapsedMilliseconds,
        errorMessage: slowOpMessage,
      );
    }
  }

  // ── Small helpers extracted for clarity ────────────────────────────────

  /// Deduplicates OCR lines across multiple images, preserving first-seen
  /// order (case-insensitive, whitespace-trimmed comparison).
  List<String> _dedupeLines(List<List<String>> allLines) {
    final seen = <String>{};
    final merged = <String>[];
    for (final lines in allLines) {
      for (final line in lines) {
        final key = line.trim().toLowerCase();
        if (key.isNotEmpty && seen.add(key)) {
          merged.add(line.trim());
        }
      }
    }
    return merged;
  }

  /// Single source of truth for the OCR-quality gate. Prefers the rich,
  /// multi-factor score from OcrTextCleanerService; falls back to the
  /// cruder ASCII-ratio check only if cleaning yielded nothing to score.
  bool _isLowQuality(CleanedOcrResult cleaned, List<String> rawLines) {
    if (cleaned.wordConfidence.isNotEmpty) {
      return cleaned.overallConfidence < ScanThresholds.lowOcrQualityCutoff;
    }
    return _assessOcrQualityFallback(rawLines) <
        ScanThresholds.lowOcrQualityCutoff;
  }

  /// Defensive fallback only — used when OcrTextCleanerService had nothing
  /// to score from (e.g. zero lines survived Stage 1 cleaning).
  double _assessOcrQualityFallback(List<String> lines) {
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
      if (ascii / t.length >= ScanThresholds.minReadableCharRatio) good++;
    }
    return good / lines.length;
  }

  void _handlePipelineError(Object e, StackTrace st, String errorCode) {
    errorMessage = 'Scan failed. Please try again with better lighting.';
    ActivityLogger.instance.log(
      ActivityEventType.scanFailed,
      errorCode: errorCode,
      errorMessage: e.toString(),
      stackTrace: st,
    );
  }

  void _finishScan() {
    _setStage(ScanStage.done);
    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  // ── Apply Gemini result to ScanResultModel ─────────────────────────────
  // Overwrites all fields Gemini found. Keeps existing values for anything
  // Gemini returned as 0 (meaning it wasn't found on the label).
  ScanResultModel _applyGeminiResult(
    ScanResultModel existing,
    GeminiNutritionResult gemini,
  ) {
    return existing.copyWith(
      productName: gemini.productName.isNotEmpty
          ? gemini.productName
          : existing.productName,
      calories: gemini.calories > 0 ? gemini.calories : existing.calories,
      protein: gemini.protein > 0 ? gemini.protein : existing.protein,
      carbs: gemini.carbs > 0 ? gemini.carbs : existing.carbs,
      fat: gemini.fat > 0 ? gemini.fat : existing.fat,
      sugar: gemini.sugar > 0 ? gemini.sugar : existing.sugar,
      sodium: gemini.sodium > 0 ? gemini.sodium : existing.sodium,
      servingSize: gemini.servingSize > 0
          ? gemini.servingSize
          : existing.servingSize,
      ingredientText: gemini.ingredientText.isNotEmpty
          ? gemini.ingredientText
          : existing.ingredientText,
    );
  }

  // ── Best ingredient text helper ────────────────────────────────────────
  String _bestIngredientText({
    required String extracted,
    required String cleaned,
    required String fullOcr,
    required List<String> allLines,
  }) {
    if (extracted.isNotEmpty) return extracted;
    if (cleaned.isNotEmpty) return cleaned;
    if (fullOcr.isNotEmpty) return fullOcr;
    return allLines.join(' ');
  }

  // ── OCR nutrition number parser (unchanged from original) ──────────────
  //
  // NOTE FOR FUTURE REFACTOR: this regex-based nutrition parser is domain
  // logic that arguably belongs in NutritionExtractorService rather than
  // the ViewModel — flagged here rather than moved in this pass, since it
  // touches parsing behaviour rather than pure structure and deserves its
  // own reviewed change.
  ScanResultModel _mergeNutritionFromOcr(
    ScanResultModel result,
    String nutritionSection,
    String fullText,
  ) {
    final src = nutritionSection.isNotEmpty ? nutritionSection : fullText;
    if (src.isEmpty) return result;

    final lower = _stripKj(src.toLowerCase());

    final int? calories = _parseNutritionValue(lower, _caloriePat);
    final double? protein = _parseNutritionDouble(lower, _proteinPat);
    final double? carbs = _parseNutritionDouble(lower, _carbPat);
    final double? fat = _parseNutritionDouble(lower, _fatPat);
    final double? sugar = _parseNutritionDouble(lower, _sugarPat);
    final double? sodium = _parseNutritionDouble(lower, _sodiumPat);
    final double? serving = _parseNutritionDouble(lower, _servingPat);

    if (calories == null &&
        protein == null &&
        carbs == null &&
        fat == null &&
        sugar == null &&
        sodium == null &&
        serving == null) {
      return result;
    }

    return result.copyWith(
      calories: calories ?? result.calories,
      protein: protein ?? result.protein,
      carbs: carbs ?? result.carbs,
      fat: fat ?? result.fat,
      sugar: sugar ?? result.sugar,
      sodium: sodium ?? result.sodium,
      servingSize: serving ?? result.servingSize,
    );
  }

  static String _stripKj(String text) =>
      text.replaceAll(RegExp(r'\(\d+\.?\d*\s*kj\)', caseSensitive: false), '');

  static final _caloriePat = RegExp(
    r'(?:energy|calorie|kcal|cal|tenaga)\D{0,40}(\d{1,4})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _proteinPat = RegExp(
    r'protein\D{0,40}(\d{1,3}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _carbPat = RegExp(
    r'(?:carbohydrate|carbs?|karbohidrat)\D{0,40}(\d{1,3}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _fatPat = RegExp(
    r'total fat\D{0,40}(\d{1,3}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sugarPat = RegExp(
    r'total sugar\D{0,40}(\d{1,3}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sodiumPat = RegExp(
    r'sodium\D{0,40}(\d{1,4}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _servingPat = RegExp(
    r'serving size\D{0,40}(\d{1,3}\.?\d{0,2})',
    caseSensitive: false,
    dotAll: true,
  );

  int? _parseNutritionValue(String text, RegExp pattern) {
    final match = pattern.firstMatch(_stripKj(text));
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  double? _parseNutritionDouble(String text, RegExp pattern) {
    final match = pattern.firstMatch(_stripKj(text));
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<bool> saveScanResult({
    required String uid,
    required ScanResultModel confirmed,
    String brandName = '',
    DateTime? targetDate,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final logDate = targetDate ?? DateTime.now();
      final analysisResult = _buildAnalysisResult();

      final log = FoodLogModel(
        foodLogID: _uuid.v4(),
        userId: uid,
        foodLogName: confirmed.productName.isEmpty
            ? 'Scanned Product'
            : confirmed.productName,
        calorieIntake: confirmed.calories,
        foodLogDate: logDate,
        loggedAt: DateTime.now(),
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
        scanAnalysisResult: analysisResult,
      );

      await _foodLogRepo.addFoodLog(uid, log);

      final wheyDoc = WheySupplementModel(
        id: log.foodLogID,
        userId: uid,
        brandName: brandName.trim(),
        productName: log.foodLogName,
        calories: log.calorieIntake,
        protein: log.protein ?? 0,
        carbs: log.carbs ?? 0,
        fat: log.fats ?? 0,
        sugar: log.sugar,
        sodium: log.sodium,
        servingSize: log.servingSize,
        servingUnit: log.servingUnit,
        aiVerdict: aiLabel.isNotEmpty ? aiLabel : 'Unknown',
        aiConfidence: aiConfidence,
        isSpiked: hasSuspiciousIngredients,
        flaggedIngredients: detectedIngredients.map((d) => d.name).toList(),
        ocrConfidence: ocrConfidence > 0 ? ocrConfidence : null,
        imagePath: scannedImageFile?.path,
        loggedAt: DateTime.now(),
      );
      await _wheyRepo.addSupplement(wheyDoc);

      ActivityLogger.instance.log(
        ActivityEventType.scanResultSaved,
        foodName: log.foodLogName,
        calories: log.calorieIntake,
        foodSource: 'scanned',
        aiPredictionLabel: analysisResult,
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

  String _buildAnalysisResult() {
    final pct = '${(aiConfidence * 100).toStringAsFixed(0)}%';
    switch (aiLabel) {
      case 'Spiked':
        return 'SPIKED ($pct)';
      case 'Plant-Based':
        return 'PLANT-BASED ($pct)';
      case 'Authentic':
        return 'AUTHENTIC ($pct)';
      default:
        return 'Unknown';
    }
  }

  void _setStage(ScanStage stage) {
    currentStage = stage;
    notifyListeners();
  }

  void _reset(File imageFile) {
    isScanning = true;
    isAnalyzing = false;
    isSaving = false;
    currentStage = ScanStage.idle;
    errorMessage = null;
    successMessage = null;
    scannedText = null;
    scannedLines = [];
    extractedResult = null;
    cleanedOcr = null;
    preprocessResult = null;
    preprocessedImageFile = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
    aiLabel = '';
    ocrConfidence = 0.0;
    uncertainWords = [];
    detectedIngredients = [];
    lowOcrQuality = false;
    lowAiConfidence = false;
    geminiUsed = false;
    scannedImageFile = imageFile;
    notifyListeners();
  }

  void clearScan() {
    scannedText = null;
    scannedLines = [];
    errorMessage = null;
    successMessage = null;
    extractedResult = null;
    cleanedOcr = null;
    preprocessResult = null;
    preprocessedImageFile = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
    aiLabel = '';
    ocrConfidence = 0.0;
    uncertainWords = [];
    detectedIngredients = [];
    lowOcrQuality = false;
    lowAiConfidence = false;
    geminiUsed = false;
    scannedImageFile = null;
    currentStage = ScanStage.idle;
    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanRepo.dispose();
    _aiService.dispose();
    super.dispose();
  }
}
