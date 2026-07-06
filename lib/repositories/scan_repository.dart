import 'dart:io';
import 'package:cal0appv2/models/scan/scan_stage.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/services/scan/ocr_service.dart';
import 'package:cal0appv2/services/scan/ai_service.dart';
import 'package:cal0appv2/services/scan/nutrition_extractor_service.dart';
import 'package:cal0appv2/services/scan/image_preprocessor_service.dart';
import 'package:cal0appv2/services/scan/ocr_text_cleaner_service.dart';
import 'package:cal0appv2/services/scan/gemini_vision_service.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'package:cal0appv2/services/config/scan_thresholds.dart';

// ── Record type — replaces what would otherwise be a new model class ──────

typedef ScanPipelineResult = ({
  bool wrongFormat,
  List<String> scannedLines,
  CleanedOcrResult cleanedOcr,
  double ocrConfidence,
  List<String> uncertainWords,
  String scannedText,
  bool lowOcrQuality,
  PreprocessResult? preprocessResult,
  File? preprocessedImageFile,
  ScanResultModel extractedResult,
  bool geminiUsed,
  List<DetectedIngredient> detectedIngredients,
  bool hasSuspiciousIngredients,
  double aiConfidence,
  String aiLabel,
  bool lowAiConfidence,
  String? pipelineErrorMessage,
});

class ScanRepository {
  final OcrService _ocrService;
  final ImagePreprocessorService _preprocessor;
  final OcrTextCleanerService _cleaner;
  final NutritionExtractorService _extractor;
  final GeminiVisionService _gemini;
  final AminoSpikingAI _aiService;

  ScanRepository({
    OcrService? ocrService,
    ImagePreprocessorService? preprocessor,
    OcrTextCleanerService? cleaner,
    NutritionExtractorService? extractor,
    GeminiVisionService? gemini,
    AminoSpikingAI? aiService,
  }) : _ocrService = ocrService ?? OcrService(),
       _preprocessor = preprocessor ?? ImagePreprocessorService(),
       _cleaner = cleaner ?? OcrTextCleanerService(),
       _extractor = extractor ?? NutritionExtractorService(),
       _gemini = gemini ?? GeminiVisionService(),
       _aiService = aiService ?? AminoSpikingAI();

  // ── AI model lifecycle ──────────────────────────────────────────────────

  bool get isAiReady => _aiService.isReady;

  Future<void> initializeAi() => _aiService.initialize();

  // ── Existing thin OCR wrappers — kept unchanged for compatibility ───────

  Future<String> scanLabel(File imageFile) =>
      _ocrService.extractText(imageFile);

  Future<List<String>> scanLabelLines(File imageFile) =>
      _ocrService.extractLines(imageFile);

  static const _allowedExtensions = ['.jpg', '.jpeg', '.png'];

  bool _hasValidImageExtension(File file) {
    final path = file.path.toLowerCase();
    return _allowedExtensions.any((ext) => path.endsWith(ext));
  }

  // ── Empty-result builder — avoids repeating every record field inline ──

  ScanPipelineResult _emptyResult({bool wrongFormat = false, String? error}) =>
      (
        wrongFormat: wrongFormat,
        scannedLines: const <String>[],
        cleanedOcr: CleanedOcrResult.empty,
        ocrConfidence: 0.0,
        uncertainWords: const <String>[],
        scannedText: '',
        lowOcrQuality: false,
        preprocessResult: null,
        preprocessedImageFile: null,
        extractedResult: ScanResultModel.empty,
        geminiUsed: false,
        detectedIngredients: const <DetectedIngredient>[],
        hasSuspiciousIngredients: false,
        aiConfidence: 0.0,
        aiLabel: '',
        lowAiConfidence: false,
        pipelineErrorMessage: error,
      );

  // ── Single-image pipeline ────────────────────────────────────────────────

  Future<ScanPipelineResult> analyzeSingleImage(
    File imageFile, {
    required void Function(ScanStage stage) onStageChange,
    required void Function(ScanResultModel partial) onNutritionExtracted,
  }) async {
    if (!_hasValidImageExtension(imageFile)) {
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'WRONG_FILE_FORMAT',
        errorMessage: 'Unsupported file format uploaded',
      );
      return _emptyResult(wrongFormat: true);
    }

    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      onStageChange(ScanStage.preparingImage);
      await Future<void>.microtask(() {});

      onStageChange(ScanStage.enhancingQuality);
      await Future<void>.microtask(() {});
      final prepResult = await _preprocessor.preprocess(imageFile);

      onStageChange(ScanStage.extractingText);
      await Future<void>.microtask(() {});
      var scannedLines = await scanLabelLines(prepResult.processedFile);
      if (scannedLines.length < 4) {
        final origLines = await scanLabelLines(imageFile);
        if (origLines.length > scannedLines.length) scannedLines = origLines;
      }

      final cleaned = _cleaner.clean(scannedLines);
      final ocrConfidence = cleaned.overallConfidence;
      final uncertainWords = cleaned.uncertainTokens;
      final scannedText = cleaned.fullText.isNotEmpty
          ? cleaned.fullText
          : scannedLines.join('\n');

      final lowOcrQuality =
          _assessOcrQuality(scannedLines) < ScanThresholds.lowOcrQualityCutoff;

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFile.path,
        errorMessage: lowOcrQuality ? 'OCR quality gate failed' : null,
      );

      onStageChange(ScanStage.analyzingIngredients);
      await Future<void>.microtask(() {});

      var extractedResult = _extractor.extract(scannedLines);
      if (cleaned.hasIngredients && extractedResult.ingredientText.isEmpty) {
        extractedResult = extractedResult.copyWith(
          ingredientText: cleaned.ingredientSection,
        );
      }
      if (cleaned.productName.isNotEmpty &&
          extractedResult.productName.isEmpty) {
        extractedResult = extractedResult.copyWith(
          productName: cleaned.productName,
        );
      }

      bool geminiUsed;
      final geminiResult = await _gemini.extractNutrition([imageFile]);
      if (geminiResult.hasData) {
        LogService.info('GeminiVision: succeeded — using Gemini values');
        extractedResult = _applyGeminiResult(extractedResult, geminiResult);
        geminiUsed = true;
      } else {
        LogService.info('GeminiVision: unavailable — regex fallback');
        final rawOcrText = scannedLines.join('\n');
        extractedResult = _mergeNutritionFromOcr(
          extractedResult,
          cleaned.nutritionSection,
          rawOcrText,
        );
        geminiUsed = false;
      }

      onNutritionExtracted(extractedResult);

      final textForDetection = _bestIngredientText(
        extracted: extractedResult.ingredientText,
        cleaned: cleaned.ingredientSection,
        fullOcr: scannedText,
        allLines: scannedLines,
      );
      final detectedIngredients = IngredientAuthenticityService.detectAll(
        textForDetection,
      );

      onStageChange(ScanStage.generatingInsights);
      await Future<void>.microtask(() {});

      final ingredientText = extractedResult.ingredientText.isNotEmpty
          ? extractedResult.ingredientText
          : cleaned.ingredientSection.isNotEmpty
          ? cleaned.ingredientSection
          : scannedText;

      bool hasSuspiciousIngredients = false;
      double aiConfidence = 0.0;
      String aiLabel = '';
      bool lowAiConfidence = false;

      if (_aiService.isReady && ingredientText.isNotEmpty && !lowOcrQuality) {
        final aiSw = Stopwatch()..start();
        final result = await _aiService.analyzeIngredients(ingredientText);

        hasSuspiciousIngredients = result['isSpiked'] as bool;
        aiConfidence = result['confidence'] as double;
        aiLabel = result['label'] as String? ?? '';
        lowAiConfidence = aiConfidence < ScanThresholds.lowAiConfidenceCutoff;

        if (hasSuspiciousIngredients &&
            !detectedIngredients.any((d) => d.isAmSpiking)) {
          lowAiConfidence = true;
        }

        ActivityLogger.instance.logScan(
          ocrText: scannedText,
          label: aiLabel.isNotEmpty
              ? aiLabel
              : (hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN'),
          confidence: aiConfidence,
          imagePath: imageFile.path,
          flagged: detectedIngredients.map((d) => d.name).toList(),
          ms: aiSw.elapsedMilliseconds,
        );
      } else if (lowOcrQuality) {
        ActivityLogger.instance.log(
          ActivityEventType.aiPredictionLowConfidence,
          ocrExtractedText: scannedText,
          errorMessage: 'AI skipped: OCR quality gate failed',
          scanImagePath: imageFile.path,
        );
      }

      if (sw.elapsedMilliseconds > ScanThresholds.slowSingleScanMs) {
        ActivityLogger.instance.log(
          ActivityEventType.slowOperation,
          durationMs: sw.elapsedMilliseconds,
          errorMessage: 'Enhanced scan pipeline > 9s',
        );
      }

      return (
        wrongFormat: false,
        scannedLines: scannedLines,
        cleanedOcr: cleaned,
        ocrConfidence: ocrConfidence,
        uncertainWords: uncertainWords,
        scannedText: scannedText,
        lowOcrQuality: lowOcrQuality,
        preprocessResult: prepResult,
        preprocessedImageFile: prepResult.processedFile,
        extractedResult: extractedResult,
        geminiUsed: geminiUsed,
        detectedIngredients: detectedIngredients,
        hasSuspiciousIngredients: hasSuspiciousIngredients,
        aiConfidence: aiConfidence,
        aiLabel: aiLabel,
        lowAiConfidence: lowAiConfidence,
        pipelineErrorMessage: null,
      );
    } catch (e, st) {
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'SCAN_PIPELINE_ERROR',
        errorMessage: e.toString(),
        stackTrace: st,
      );
      return _emptyResult(
        error: 'Scan failed. Please try again with better lighting.',
      );
    }
  }

  // ── Multi-angle pipeline ─────────────────────────────────────────────────

  Future<ScanPipelineResult> analyzeMultipleImages(
    List<File> imageFiles, {
    required void Function(ScanStage stage) onStageChange,
    required void Function(ScanResultModel partial) onNutritionExtracted,
  }) async {
    if (imageFiles.isEmpty) return _emptyResult(wrongFormat: true);

    if (imageFiles.any((f) => !_hasValidImageExtension(f))) {
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'WRONG_FILE_FORMAT',
        errorMessage: 'Unsupported file format uploaded',
      );
      return _emptyResult(wrongFormat: true);
    }

    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      onStageChange(ScanStage.preparingImage);
      await Future<void>.microtask(() {});

      onStageChange(ScanStage.enhancingQuality);
      await Future<void>.microtask(() {});
      final prepResults = await Future.wait(
        imageFiles.map((f) => _preprocessor.preprocess(f)),
      );

      onStageChange(ScanStage.extractingText);
      await Future<void>.microtask(() {});
      final ocrResults = await Future.wait(
        prepResults.map((pr) => scanLabelLines(pr.processedFile)),
      );

      final seen = <String>{};
      final mergedLines = <String>[];
      for (final lines in ocrResults) {
        for (final line in lines) {
          final key = line.trim().toLowerCase();
          if (key.isNotEmpty && seen.add(key)) mergedLines.add(line.trim());
        }
      }

      if (mergedLines.length < 6) {
        final origResults = await Future.wait(
          imageFiles.map((f) => scanLabelLines(f)),
        );
        for (final lines in origResults) {
          for (final line in lines) {
            final key = line.trim().toLowerCase();
            if (key.isNotEmpty && seen.add(key)) mergedLines.add(line.trim());
          }
        }
      }

      final cleaned = _cleaner.clean(mergedLines);

      final totalLines = ocrResults.fold(0, (a, b) => a + b.length);
      final ocrConfidence = totalLines > 0
          ? ocrResults.fold(
              0.0,
              (sum, lines) =>
                  sum + (cleaned.overallConfidence * lines.length / totalLines),
            )
          : cleaned.overallConfidence;
      final uncertainWords = cleaned.uncertainTokens;

      final scannedText = cleaned.fullText.isNotEmpty
          ? cleaned.fullText
          : mergedLines.join('\n');

      final lowOcrQuality =
          _assessOcrQuality(mergedLines) < ScanThresholds.lowOcrQualityCutoff &&
          prepResults.every(
            (p) => p.qualityScore < ScanThresholds.lowOcrQualityCutoff,
          );

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFiles.first.path,
        errorMessage: lowOcrQuality
            ? 'Multi-angle OCR quality gate failed'
            : null,
      );

      onStageChange(ScanStage.analyzingIngredients);
      await Future<void>.microtask(() {});

      var extractedResult = _extractor.extract(mergedLines);
      if (cleaned.hasIngredients && extractedResult.ingredientText.isEmpty) {
        extractedResult = extractedResult.copyWith(
          ingredientText: cleaned.ingredientSection,
        );
      }
      if (cleaned.productName.isNotEmpty &&
          extractedResult.productName.isEmpty) {
        extractedResult = extractedResult.copyWith(
          productName: cleaned.productName,
        );
      }

      bool geminiUsed;
      final geminiResult = await _gemini.extractNutrition(imageFiles);
      if (geminiResult.hasData) {
        LogService.info('GeminiVision: succeeded — using Gemini values');
        extractedResult = _applyGeminiResult(extractedResult, geminiResult);
        geminiUsed = true;
      } else {
        LogService.info('GeminiVision: unavailable — regex fallback');
        final rawOcrText = mergedLines.join('\n');
        extractedResult = _mergeNutritionFromOcr(
          extractedResult,
          cleaned.nutritionSection,
          rawOcrText,
        );
        geminiUsed = false;
      }

      onNutritionExtracted(extractedResult);

      final textForDetection = _bestIngredientText(
        extracted: extractedResult.ingredientText,
        cleaned: cleaned.ingredientSection,
        fullOcr: scannedText,
        allLines: mergedLines,
      );
      final detectedIngredients = IngredientAuthenticityService.detectAll(
        textForDetection,
      );

      onStageChange(ScanStage.generatingInsights);
      await Future<void>.microtask(() {});

      final ingredientText = extractedResult.ingredientText.isNotEmpty
          ? extractedResult.ingredientText
          : cleaned.ingredientSection.isNotEmpty
          ? cleaned.ingredientSection
          : scannedText;

      bool hasSuspiciousIngredients = false;
      double aiConfidence = 0.0;
      String aiLabel = '';
      bool lowAiConfidence = false;

      if (_aiService.isReady && ingredientText.isNotEmpty && !lowOcrQuality) {
        final aiSw = Stopwatch()..start();
        final result = await _aiService.analyzeIngredients(ingredientText);

        hasSuspiciousIngredients = result['isSpiked'] as bool;
        aiConfidence = result['confidence'] as double;
        aiLabel = result['label'] as String? ?? '';
        lowAiConfidence = aiConfidence < ScanThresholds.lowAiConfidenceCutoff;

        if (hasSuspiciousIngredients &&
            !detectedIngredients.any((d) => d.isAmSpiking)) {
          lowAiConfidence = true;
        }

        ActivityLogger.instance.logScan(
          ocrText: scannedText,
          label: aiLabel.isNotEmpty
              ? aiLabel
              : (hasSuspiciousIngredients ? 'SPIKED' : 'CLEAN'),
          confidence: aiConfidence,
          imagePath: imageFiles.first.path,
          flagged: detectedIngredients.map((d) => d.name).toList(),
          ms: aiSw.elapsedMilliseconds,
        );
      } else if (lowOcrQuality) {
        ActivityLogger.instance.log(
          ActivityEventType.aiPredictionLowConfidence,
          ocrExtractedText: scannedText,
          errorMessage: 'AI skipped: multi-angle OCR quality gate failed',
          scanImagePath: imageFiles.first.path,
        );
      }

      if (sw.elapsedMilliseconds > ScanThresholds.slowMultiScanMs) {
        ActivityLogger.instance.log(
          ActivityEventType.slowOperation,
          durationMs: sw.elapsedMilliseconds,
          errorMessage:
              'Multi-angle pipeline > 15s for ${imageFiles.length} images',
        );
      }

      return (
        wrongFormat: false,
        scannedLines: mergedLines,
        cleanedOcr: cleaned,
        ocrConfidence: ocrConfidence,
        uncertainWords: uncertainWords,
        scannedText: scannedText,
        lowOcrQuality: lowOcrQuality,
        preprocessResult: null,
        preprocessedImageFile: null,
        extractedResult: extractedResult,
        geminiUsed: geminiUsed,
        detectedIngredients: detectedIngredients,
        hasSuspiciousIngredients: hasSuspiciousIngredients,
        aiConfidence: aiConfidence,
        aiLabel: aiLabel,
        lowAiConfidence: lowAiConfidence,
        pipelineErrorMessage: null,
      );
    } catch (e, st) {
      ActivityLogger.instance.log(
        ActivityEventType.scanFailed,
        errorCode: 'MULTI_SCAN_PIPELINE_ERROR',
        errorMessage: e.toString(),
        stackTrace: st,
      );
      return _emptyResult(
        error: 'Scan failed. Please try again with better lighting.',
      );
    }
  }

  // ── Private helpers (moved verbatim from ScanViewModel) ─────────────────

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
      if (t.isNotEmpty &&
          ascii / t.length >= ScanThresholds.minReadableCharRatio) {
        good++;
      }
    }
    return good / lines.length;
  }

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

  void dispose() {
    _ocrService.dispose();
    _aiService.dispose();
  }
}
