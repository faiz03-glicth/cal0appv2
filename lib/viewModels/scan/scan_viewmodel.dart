import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/scan/scan_stage.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/scan/ai_service.dart';
import 'package:cal0appv2/services/scan/nutrition_extractor_service.dart';
import 'package:cal0appv2/services/scan/image_preprocessor_service.dart';
import 'package:cal0appv2/services/scan/ocr_text_cleaner_service.dart';
import 'package:cal0appv2/services/scan/gemini_vision_service.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'package:cal0appv2/models/whey/whey_supplement_model.dart';
import 'package:cal0appv2/repositories/whey_supplement_repository.dart';

// Re-exported so existing imports of `DetectedIngredient` from this file
// (e.g. whey_verdict_card.dart) keep working unchanged. The database and
// detection logic itself now live in one place:
// services/scan/ingredient_authenticity_service.dart — see that file for
// the single source of truth used by both the live scan flow and food
// history.
export 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart'
    show DetectedIngredient;

// ── Authenticity verdict enum ─────────────────────────────────────────────
// Consumed by WheyVerdictCard for clear, unambiguous UI feedback. This is
// the ML-driven verdict (can be authentic/spiked/plantBased/lowConf/
// unknown, with a confidence score) — distinct from the deterministic
// rule-based NitrogenCheckVerdict in IngredientAuthenticityService, which
// only ever says authentic or non-authentic.

enum AuthenticityVerdict {
  authentic, // AI says Authentic, confidence ≥ 50%
  spiked, // AI says Spiked, confidence ≥ 50%
  plantBased, // AI says Plant-Based
  lowConf, // AI ran but confidence < 50%
  unknown, // AI didn't run (low OCR quality or no ingredient text)
}

// ── ScanViewModel ─────────────────────────────────────────────────────────

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
  String aiLabel = '';

  // Quality flags
  bool lowOcrQuality = false;
  bool lowAiConfidence = false;

  // Cleaner output
  double ocrConfidence = 0.0;
  List<String> uncertainWords = [];

  List<DetectedIngredient> detectedIngredients = [];
  bool geminiUsed = false;

  // Set to true once the user manually edits the ingredient list and the
  // verdict is recomputed from that edit via `updateIngredientsAndReanalyze`.
  // The verdict card uses this to switch to a plain Authentic / Non-Authentic
  // presentation instead of the full ML-confidence wording.
  bool ingredientManuallyEdited = false;

  // The last deterministic rule-based check, kept around for anything that
  // wants the raw AuthenticityCheck object (e.g. AuthenticityVerdictCard)
  // rather than the individual fields above.
  AuthenticityCheck? lastAuthenticityCheck;

  // ── Derived verdict (FIX #3) ──────────────────────────────────────────
  // A single source of truth for the verdict UI — replaces scattered string
  // comparisons spread across widgets.

  AuthenticityVerdict get authenticityVerdict {
    if (lowOcrQuality || aiLabel.isEmpty) return AuthenticityVerdict.unknown;
    if (lowAiConfidence) return AuthenticityVerdict.lowConf;
    switch (aiLabel) {
      case 'Spiked':
        return AuthenticityVerdict.spiked;
      case 'Plant-Based':
        return AuthenticityVerdict.plantBased;
      case 'Authentic':
        return AuthenticityVerdict.authentic;
      default:
        return AuthenticityVerdict.unknown;
    }
  }

  bool get showingOverlay =>
      isScanning &&
      currentStage != ScanStage.idle &&
      currentStage != ScanStage.done;

  String get verdictLabel {
    if (extractedResult == null) return '';

    if (ingredientManuallyEdited) {
      return hasSuspiciousIngredients
          ? 'Non-Authentic — suspicious nitrogen compound found in edited ingredients'
          : 'Authentic — no suspicious nitrogen compound found in edited ingredients';
    }

    final pct = '${(aiConfidence * 100).toStringAsFixed(0)}%';
    if (lowOcrQuality) return 'Scan quality too low — try retaking the photo';
    if (lowAiConfidence) {
      return 'AI confidence low ($pct) — please verify manually';
    }
    if (aiLabel == 'Plant-Based') {
      return 'Plant-Based Protein ($pct confidence)';
    }
    return hasSuspiciousIngredients
        ? 'Potential amino spiking detected ($pct confidence)'
        : 'No suspicious ingredients found ($pct confidence)';
  }

  // ── File format guard ─────────────────────────────────────────────────

  static const _allowedExtensions = ['.jpg', '.jpeg', '.png'];

  bool _hasValidImageExtension(File file) {
    final path = file.path.toLowerCase();
    return _allowedExtensions.any((ext) => path.endsWith(ext));
  }

  // ── Manual re-analysis after the user edits ANY field ───────────────────
  //
  // Called from the confirm sheet (via AuthenticityReanalysisMixin)
  // whenever the user edits ingredients or any nutrient field. Delegates
  // entirely to IngredientAuthenticityService — the same deterministic,
  // rule-based nitrogen-compound scan used by food history — so both
  // screens behave identically.

  void updateIngredientsAndReanalyze(String editedText) {
    final check = IngredientAuthenticityService.check(editedText);

    ingredientManuallyEdited = true;
    lastAuthenticityCheck = check;

    if (extractedResult != null) {
      extractedResult = extractedResult!.copyWith(
        ingredientText: check.ingredientText,
      );
    }

    detectedIngredients = check.allDetected;
    hasSuspiciousIngredients = check.isNonAuthentic;
    aiLabel = check.isNonAuthentic ? 'Spiked' : 'Authentic';
    // Rule-based checks are deterministic, so we treat this as full
    // confidence rather than routing through the ML confidence gate.
    aiConfidence = 1.0;
    lowAiConfidence = false;
    lowOcrQuality = false;
    errorMessage = null;

    notifyListeners();
  }

  // ── Multi-angle scan pipeline ─────────────────────────────────────────
  //
  // FIX #1 — preprocessing is now off-thread (compute() inside
  // ImagePreprocessorService). Additional await-points between stages
  // let the Flutter scheduler repaint the overlay between steps.

  Future<void> scanMultipleImages(List<File> imageFiles) async {
    if (imageFiles.isEmpty) return;

    if (imageFiles.any((f) => !_hasValidImageExtension(f))) {
      _reset(imageFiles.first);
      errorMessage = 'Wrong format file';
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'WRONG_FILE_FORMAT',
        errorMessage: 'Unsupported file format uploaded',
      );
      _setStage(ScanStage.done);
      isScanning = false;
      notifyListeners();
      return;
    }

    _reset(imageFiles.first);
    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      // Stage 1 – Prepare
      _setStage(ScanStage.preparingImage);
      await Future<void>.microtask(() {}); // yield to repaint overlay

      // Stage 2 – Enhance (runs off-thread per image via compute())
      _setStage(ScanStage.enhancingQuality);
      await Future<void>.microtask(() {});

      final prepResults = await Future.wait(
        imageFiles.map((f) => _preprocessor.preprocess(f)),
      );

      // Stage 3 – OCR (google_mlkit runs its own thread pool)
      _setStage(ScanStage.extractingText);
      await Future<void>.microtask(() {});

      final ocrResults = await Future.wait(
        prepResults.map((pr) => _scanRepo.scanLabelLines(pr.processedFile)),
      );

      // Merge + deduplicate OCR lines
      final seen = <String>{};
      final mergedLines = <String>[];
      for (final lines in ocrResults) {
        for (final line in lines) {
          final key = line.trim().toLowerCase();
          if (key.isNotEmpty && seen.add(key)) mergedLines.add(line.trim());
        }
      }

      // Fallback: if preprocessed yield was poor, also try originals
      if (mergedLines.length < 6) {
        final origResults = await Future.wait(
          imageFiles.map((f) => _scanRepo.scanLabelLines(f)),
        );
        for (final lines in origResults) {
          for (final line in lines) {
            final key = line.trim().toLowerCase();
            if (key.isNotEmpty && seen.add(key)) mergedLines.add(line.trim());
          }
        }
      }

      scannedLines = mergedLines;

      final cleaned = _cleaner.clean(mergedLines);
      cleanedOcr = cleaned;

      final totalLines = ocrResults.fold(0, (a, b) => a + b.length);
      ocrConfidence = totalLines > 0
          ? ocrResults.fold(
              0.0,
              (sum, lines) =>
                  sum + (cleaned.overallConfidence * lines.length / totalLines),
            )
          : cleaned.overallConfidence;
      uncertainWords = cleaned.uncertainTokens;

      scannedText = cleaned.fullText.isNotEmpty
          ? cleaned.fullText
          : mergedLines.join('\n');

      lowOcrQuality =
          _assessOcrQuality(mergedLines) < 0.35 &&
          prepResults.every((p) => p.qualityScore < 0.35);
      if (lowOcrQuality) {
        errorMessage = 'Unreadable file, please upload picture with clear';
      }

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFiles.first.path,
        errorMessage: lowOcrQuality
            ? 'Multi-angle OCR quality gate failed'
            : null,
      );

      // Stage 4 – Extract nutrition
      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      await Future<void>.microtask(() {}); // yield before heavy work

      extractedResult = _extractor.extract(mergedLines);
      if (cleanedOcr!.hasIngredients &&
          extractedResult!.ingredientText.isEmpty) {
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

      final geminiResult = await _gemini.extractNutrition(imageFiles);
      if (geminiResult.hasData) {
        LogService.info('GeminiVision: succeeded — using Gemini values');
        extractedResult = _applyGeminiResult(extractedResult!, geminiResult);
        geminiUsed = true;
      } else {
        LogService.info('GeminiVision: unavailable — regex fallback');
        final rawOcrText = scannedLines.join('\n');
        extractedResult = _mergeNutritionFromOcr(
          extractedResult!,
          cleanedOcr!.nutritionSection,
          rawOcrText,
        );
        geminiUsed = false;
      }

      // FIX #2 — notify after extractedResult is set so confirm sheet can fill
      notifyListeners();

      final textForDetection = _bestIngredientText(
        extracted: extractedResult!.ingredientText,
        cleaned: cleanedOcr!.ingredientSection,
        fullOcr: scannedText ?? '',
        allLines: scannedLines,
      );
      detectedIngredients = IngredientAuthenticityService.detectAll(
        textForDetection,
      );

      // Stage 5 – AI inference
      _setStage(ScanStage.generatingInsights);
      await Future<void>.microtask(() {});

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
        lowAiConfidence = aiConfidence < 0.50;

        if (hasSuspiciousIngredients &&
            !detectedIngredients.any((d) => d.isAmSpiking)) {
          lowAiConfidence = true;
        }

        ActivityLogger.instance.logScan(
          ocrText: scannedText!,
          label: aiLabel.isNotEmpty
              ? aiLabel
              : (hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN'),
          confidence: aiConfidence,
          imagePath: imageFiles.first.path,
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
            errorMessage: 'AI skipped: multi-angle OCR quality gate failed',
            scanImagePath: imageFiles.first.path,
          );
        }
      }

      if (sw.elapsedMilliseconds > 15000) {
        ActivityLogger.instance.log(
          ActivityEventType.slowOperation,
          durationMs: sw.elapsedMilliseconds,
          errorMessage:
              'Multi-angle pipeline > 15s for ${imageFiles.length} images',
        );
      }
    } catch (e, st) {
      errorMessage = 'Scan failed. Please try again with better lighting.';
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'MULTI_SCAN_PIPELINE_ERROR',
        errorMessage: e.toString(),
        stackTrace: st,
      );
    }

    _setStage(ScanStage.done);
    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  // ── Single-image scan pipeline ────────────────────────────────────────

  Future<void> scanImage(File imageFile) async {
    if (!_hasValidImageExtension(imageFile)) {
      _reset(imageFile);
      errorMessage = 'Wrong format file';
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'WRONG_FILE_FORMAT',
        errorMessage: 'Unsupported file format uploaded',
      );
      _setStage(ScanStage.done);
      isScanning = false;
      notifyListeners();
      return;
    }

    _reset(imageFile);
    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      _setStage(ScanStage.preparingImage);
      await Future<void>.microtask(() {});

      _setStage(ScanStage.enhancingQuality);
      await Future<void>.microtask(() {});
      // FIX #1 — preprocessing now runs off-thread inside compute()
      final prepResult = await _preprocessor.preprocess(imageFile);
      preprocessResult = prepResult;
      preprocessedImageFile = prepResult.processedFile;

      _setStage(ScanStage.extractingText);
      await Future<void>.microtask(() {});
      scannedLines = await _scanRepo.scanLabelLines(prepResult.processedFile);
      if (scannedLines.length < 4) {
        final origLines = await _scanRepo.scanLabelLines(imageFile);
        if (origLines.length > scannedLines.length) scannedLines = origLines;
      }

      final cleaned = _cleaner.clean(scannedLines);
      cleanedOcr = cleaned;
      ocrConfidence = cleaned.overallConfidence;
      uncertainWords = cleaned.uncertainTokens;
      scannedText = cleaned.fullText.isNotEmpty
          ? cleaned.fullText
          : scannedLines.join('\n');

      lowOcrQuality = _assessOcrQuality(scannedLines) < 0.35;
      if (lowOcrQuality) {
        errorMessage = 'Unreadable file, please upload picture with clear';
      }

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFile.path,
        errorMessage: lowOcrQuality ? 'OCR quality gate failed' : null,
      );

      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      await Future<void>.microtask(() {});

      extractedResult = _extractor.extract(scannedLines);
      if (cleanedOcr!.hasIngredients &&
          extractedResult!.ingredientText.isEmpty) {
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

      final geminiResult = await _gemini.extractNutrition([imageFile]);
      if (geminiResult.hasData) {
        LogService.info('GeminiVision: succeeded — using Gemini values');
        extractedResult = _applyGeminiResult(extractedResult!, geminiResult);
        geminiUsed = true;
      } else {
        LogService.info('GeminiVision: unavailable — regex fallback');
        final rawOcrText = scannedLines.join('\n');
        extractedResult = _mergeNutritionFromOcr(
          extractedResult!,
          cleanedOcr!.nutritionSection,
          rawOcrText,
        );
        geminiUsed = false;
      }

      // FIX #2 — notify immediately so confirm sheet sees real data
      notifyListeners();

      final textForDetection = _bestIngredientText(
        extracted: extractedResult!.ingredientText,
        cleaned: cleanedOcr!.ingredientSection,
        fullOcr: scannedText ?? '',
        allLines: scannedLines,
      );
      detectedIngredients = IngredientAuthenticityService.detectAll(
        textForDetection,
      );

      _setStage(ScanStage.generatingInsights);
      await Future<void>.microtask(() {});

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
        lowAiConfidence = aiConfidence < 0.50;

        if (hasSuspiciousIngredients &&
            !detectedIngredients.any((d) => d.isAmSpiking)) {
          lowAiConfidence = true;
        }

        ActivityLogger.instance.logScan(
          ocrText: scannedText!,
          label: aiLabel.isNotEmpty
              ? aiLabel
              : (hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN'),
          confidence: aiConfidence,
          imagePath: imageFile.path,
          flagged: detectedIngredients.map((d) => d.name).toList(),
          ms: aiSw.elapsedMilliseconds,
        );
      } else if (lowOcrQuality) {
        hasSuspiciousIngredients = false;
        aiConfidence = 0.0;
        aiLabel = '';
        ActivityLogger.instance.log(
          ActivityEventType.aiPredictionLowConfidence,
          ocrExtractedText: scannedText,
          errorMessage: 'AI skipped: OCR quality gate failed',
          scanImagePath: imageFile.path,
        );
      } else {
        hasSuspiciousIngredients = false;
        aiConfidence = 0.0;
        aiLabel = '';
      }

      if (sw.elapsedMilliseconds > 9000) {
        ActivityLogger.instance.log(
          ActivityEventType.slowOperation,
          durationMs: sw.elapsedMilliseconds,
          errorMessage: 'Enhanced scan pipeline > 9s',
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

    _setStage(ScanStage.done);
    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────

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
    final clean = _stripKj(text);
    final match = pattern.firstMatch(clean);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  double? _parseNutritionDouble(String text, RegExp pattern) {
    final clean = _stripKj(text);
    final match = pattern.firstMatch(clean);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  // ── Save ──────────────────────────────────────────────────────────────

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
        // Supplement compounds + ingredient text carried over so the
        // history edit screen has the same fields, and can re-run the
        // same Authentic / Non-Authentic check later.
        creatineMonohydrate: confirmed.creatineMonohydrate,
        bcaa: confirmed.bcaa,
        leucine: confirmed.leucine,
        isoleucine: confirmed.isoleucine,
        valine: confirmed.valine,
        glutamine: confirmed.glutamine,
        taurine: confirmed.taurine,
        ingredientText: confirmed.ingredientText,
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
        protein: log.protein,
        carbs: log.carbs,
        fat: log.fats,
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
    if (ingredientManuallyEdited) {
      return hasSuspiciousIngredients ? 'NON-AUTHENTIC' : 'AUTHENTIC';
    }
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
      if (t.isNotEmpty && ascii / t.length >= 0.55) good++;
    }
    return good / lines.length;
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
    ingredientManuallyEdited = false;
    lastAuthenticityCheck = null;
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
    ingredientManuallyEdited = false;
    lastAuthenticityCheck = null;
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
