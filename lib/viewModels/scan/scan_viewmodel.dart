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
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'package:cal0appv2/models/whey/whey_supplement_model.dart';
import 'package:cal0appv2/repositories/whey_supplement_repository.dart';

class _IngredientRule {
  final String name; // display name
  final String category; // e.g. 'Amino Spiking Agent'
  final String explanation; // plain-English why this matters
  final List<String> aliases; // OCR variant spellings to match

  const _IngredientRule({
    required this.name,
    required this.category,
    required this.explanation,
    required this.aliases,
  });
}

const _ingredientDatabase = <_IngredientRule>[
  // ── Amino spiking agents ─────────────────────────────────────────────────
  _IngredientRule(
    name: 'Glycine',
    category: 'Amino Spiking Agent',
    explanation:
        'Cheap amino acid sometimes added to inflate protein content on lab tests. '
        'Does not provide the same muscle-building benefit as whey.',
    aliases: ['glycine'],
  ),
  _IngredientRule(
    name: 'Taurine',
    category: 'Amino Spiking Agent',
    explanation:
        'Free-form amino acid that registers as protein on Kjeldahl/Dumas tests '
        'but is not a complete protein source and does not contribute to MPS.',
    aliases: ['taurine'],
  ),
  _IngredientRule(
    name: 'Creatine Monohydrate',
    category: 'Performance Compound / Potential Spiking Agent',
    explanation:
        'Creatine contains nitrogen and can inflate total protein readings. '
        'It is a legitimate performance supplement, but its presence in a '
        '"protein powder" label may indicate label amino spiking.',
    aliases: [
      'creatine monohydrate',
      'creatine',
      'creatine hcl',
      'creatine ethyl',
    ],
  ),
  _IngredientRule(
    name: 'Beta-Alanine',
    category: 'Amino Spiking Agent',
    explanation:
        'Non-essential amino acid that contributes nitrogen to protein tests '
        'without being a quality protein source.',
    aliases: ['beta-alanine', 'beta alanine', 'β-alanine'],
  ),
  _IngredientRule(
    name: 'L-Glutamine',
    category: 'Amino Spiking Agent',
    explanation:
        'Free amino acid that is sometimes added in excess to boost nitrogen content. '
        'While it has some gut-health benefits, large amounts suggest spiking.',
    aliases: ['l-glutamine', 'glutamine', 'l glutamine'],
  ),
  _IngredientRule(
    name: 'Arginine',
    category: 'Amino Spiking Agent',
    explanation:
        'Free-form amino acid used to boost nitrogen scores. '
        'At high doses it is more indicative of spiking than a benefit.',
    aliases: ['arginine', 'l-arginine', 'l arginine', 'arginine akg'],
  ),
  _IngredientRule(
    name: 'Alanine',
    category: 'Amino Spiking Agent',
    explanation:
        'Cheap non-essential amino acid used to inflate protein readings.',
    aliases: ['alanine', 'l-alanine', 'l alanine'],
  ),
  _IngredientRule(
    name: 'Leucine',
    category: 'Amino Spiking Agent / BCAA',
    explanation:
        'While leucine is a branched-chain amino acid with real benefit, '
        'excessive free-form leucine on a label can indicate spiking. '
        'It is expected inside whey protein but suspicious as a standalone addition.',
    aliases: ['leucine', 'l-leucine', 'l leucine'],
  ),

  // ── Artificial sweeteners ────────────────────────────────────────────────
  _IngredientRule(
    name: 'Sucralose',
    category: 'Artificial Sweetener',
    explanation:
        'Zero-calorie chlorinated sugar. Common in protein powders. '
        'Some consumers prefer to avoid it.',
    aliases: ['sucralose', 'splenda'],
  ),
  _IngredientRule(
    name: 'Acesulfame Potassium',
    category: 'Artificial Sweetener',
    explanation:
        'Also listed as Ace-K or E950. Often used alongside sucralose. '
        'Some studies suggest possible gut microbiome effects.',
    aliases: [
      'acesulfame potassium',
      'acesulfame-k',
      'ace-k',
      'acesulfame k',
      'e950',
    ],
  ),
  _IngredientRule(
    name: 'Aspartame',
    category: 'Artificial Sweetener',
    explanation:
        'Common artificial sweetener. Should be avoided by people with PKU.',
    aliases: ['aspartame', 'nutrasweet', 'equal'],
  ),

  // ── Fillers & thickeners ─────────────────────────────────────────────────
  _IngredientRule(
    name: 'Maltodextrin',
    category: 'Filler / High GI Carbohydrate',
    explanation:
        'High-glycaemic carbohydrate often used as a filler or flavour carrier. '
        'Can contribute to blood sugar spikes.',
    aliases: ['maltodextrin'],
  ),
  _IngredientRule(
    name: 'Soy Lecithin',
    category: 'Emulsifier',
    explanation:
        'Common emulsifier. Possible concern for those with soy allergies '
        'or those wanting to limit phytoestrogen sources.',
    aliases: ['soy lecithin', 'soya lecithin'],
  ),
];

// ── IngredientDetection result ────────────────────────────────────────────────

class DetectedIngredient {
  final String name;
  final String category;
  final String explanation;
  final bool isAmSpiking; // true = amino spiking agent

  const DetectedIngredient({
    required this.name,
    required this.category,
    required this.explanation,
    required this.isAmSpiking,
  });
}

// ── ScanViewModel ─────────────────────────────────────────────────────────────

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

  // ── Observable state ──────────────────────────────────────────────────────

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

  /// Rule-based detected ingredients with explanations.
  /// Populated regardless of AI model status.
  List<DetectedIngredient> detectedIngredients = [];

  /// True when Gemini Vision successfully extracted the nutrition values.
  /// False means the regex fallback was used instead.
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

  // ── File format validation ──────────────────────────────────────────────
  //
  // ImagePicker's gallery/camera flows normally only surface image files,
  // but this guard is the explicit, documented check the UAT exercises
  // (uploading a .pdf or other non-image file). Matches UAT 7.3/8.3.
  static const _allowedExtensions = ['.jpg', '.jpeg', '.png'];

  bool _hasValidImageExtension(File file) {
    final path = file.path.toLowerCase();
    return _allowedExtensions.any((ext) => path.endsWith(ext));
  }

  // ── Scan pipeline ─────────────────────────────────────────────────────────

  // ── Multi-angle scan pipeline ─────────────────────────────────────────────
  //
  // Processes 3–5 photos in parallel, merges their OCR output, deduplicates
  // lines, then runs the full analysis on the combined text.
  // This gives the AI model the most complete ingredient + nutrition picture.
  //
  // Merge strategy:
  //   • Each image is preprocessed + OCR'd independently
  //   • Lines are deduplicated (exact-match) — shared text only counted once
  //   • For nutrition values: highest-confidence non-zero value wins
  //   • ocrConfidence = average across all images (more images → more stable)

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

    // Use first image as the "primary" for the reset (imagePath logging etc.)
    _reset(imageFiles.first);
    final sw = Stopwatch()..start();
    ActivityLogger.instance.log(ActivityEventType.scanInitiated);

    try {
      // Stage 1 + 2: Prepare & enhance all images in parallel
      _setStage(ScanStage.preparingImage);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      _setStage(ScanStage.enhancingQuality);

      final prepResults = await Future.wait(
        imageFiles.map((f) => _preprocessor.preprocess(f)),
      );

      // Stage 3: OCR all preprocessed images in parallel
      _setStage(ScanStage.extractingText);

      final ocrResults = await Future.wait(
        prepResults.map((pr) => _scanRepo.scanLabelLines(pr.processedFile)),
      );

      // Merge: collect all lines, deduplicate while preserving order
      final seen = <String>{};
      final mergedLines = <String>[];
      for (final lines in ocrResults) {
        for (final line in lines) {
          final key = line.trim().toLowerCase();
          if (key.isNotEmpty && seen.add(key)) {
            mergedLines.add(line.trim());
          }
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
            if (key.isNotEmpty && seen.add(key)) {
              mergedLines.add(line.trim());
            }
          }
        }
      }

      scannedLines = mergedLines;

      // Clean the merged text
      final cleaned = _cleaner.clean(mergedLines);
      cleanedOcr = cleaned;

      // ocrConfidence = average over images weighted by their line count
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

      // Use strictest quality gate across all images
      lowOcrQuality =
          _assessOcrQuality(mergedLines) < 0.35 &&
          prepResults.every((p) => p.qualityScore < 0.35);
      if (lowOcrQuality) {
        // Matches UAT 7.4 documented expected result verbatim.
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

      // Stage 4: Extract nutrition values
      // Strategy: Gemini Vision first (accurate, handles any layout).
      // Falls back to regex if API key not set or request fails.
      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      notifyListeners();

      // Extractor for ingredient text / product name baseline
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

      // Gemini Vision: sends raw images so it sees the actual table layout
      final geminiResult = await _gemini.extractNutrition(imageFiles);
      if (geminiResult.hasData) {
        LogService.info('GeminiVision: succeeded — using Gemini values');
        extractedResult = _applyGeminiResult(extractedResult!, geminiResult);
        geminiUsed = true;
      } else {
        // Fallback: regex on OCR text
        LogService.info('GeminiVision: unavailable — regex fallback');
        final rawOcrText = scannedLines.join('\n');
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
        allLines: scannedLines,
      );
      detectedIngredients = _detectIngredients(textForDetection);
      // Stage 5: AI on merged ingredient text
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
      // 1. Prepare
      _setStage(ScanStage.preparingImage);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // 2. Enhance
      _setStage(ScanStage.enhancingQuality);
      final prepResult = await _preprocessor.preprocess(imageFile);
      preprocessResult = prepResult;
      preprocessedImageFile = prepResult.processedFile;

      // 3. Extract text
      _setStage(ScanStage.extractingText);
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
        // Matches UAT 7.4 documented expected result verbatim.
        errorMessage = 'Unreadable file, please upload picture with clear';
      }

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFile.path,
        errorMessage: lowOcrQuality ? 'OCR quality gate failed' : null,
      );

      // 4. Extract nutrition values
      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      notifyListeners();

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

      // Gemini Vision: sends the raw image for accurate nutrition extraction
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

      final textForDetection = _bestIngredientText(
        extracted: extractedResult!.ingredientText,
        cleaned: cleanedOcr!.ingredientSection,
        fullOcr: scannedText ?? '',
        allLines: scannedLines,
      );
      detectedIngredients = _detectIngredients(textForDetection);
      // 5. Generate insights (AI)
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
        lowAiConfidence = aiConfidence < 0.50;

        // If AI says spiked but rule-based found no spiking agents, flag as uncertain
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

  // ── Apply Gemini result to ScanResultModel ───────────────────────────────
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

  // ── Best ingredient text helper ──────────────────────────────────────────
  // Returns the richest available text for ingredient detection.
  // Falls back to the full OCR text when sections weren't isolated.
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

  // ── OCR nutrition number parser ───────────────────────────────────────────
  // Extracts calories, protein, carbs, fat, sugar, sodium, serving size
  // directly from raw OCR text using flexible regex patterns.
  // Overwrites zero/null fields in [result] only — never downgrades a value.
  ScanResultModel _mergeNutritionFromOcr(
    ScanResultModel result,
    String nutritionSection,
    String fullText,
  ) {
    // Use nutrition section if available, fall back to full text.
    // Always ALWAYS parse — overwrite even non-zero fields from the extractor
    // because the extractor may have grabbed the wrong column on two-column labels.
    final src = nutritionSection.isNotEmpty ? nutritionSection : fullText;
    if (src.isEmpty) return result;

    // Lowercase + strip kJ parentheticals before matching
    final lower = _stripKj(src.toLowerCase());

    // Always parse fresh from OCR — don't skip fields that already have values.
    // The two-column bug means existing values may be from the wrong column.
    final int? calories = _parseNutritionValue(lower, _caloriePat);
    final double? protein = _parseNutritionDouble(lower, _proteinPat);
    final double? carbs = _parseNutritionDouble(lower, _carbPat);
    final double? fat = _parseNutritionDouble(lower, _fatPat);
    final double? sugar = _parseNutritionDouble(lower, _sugarPat);
    final double? sodium = _parseNutritionDouble(lower, _sodiumPat);
    final double? serving = _parseNutritionDouble(lower, _servingPat);

    // Only copyWith if we found something new
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

  // Patterns that match "label ... number unit" flexibly:
  //   "calories 120", "energy: 120 kcal", "cal 120 per serving" etc.
  // ── Nutrition label parser ────────────────────────────────────────────────
  //
  // Two-column label problem:
  //   Many supplement labels print "Per Serving | Per 100g" side by side.
  //   OCR reads left-to-right and produces lines like "Protein 17.7g 59g".
  //   The first number after the label keyword is ALWAYS the per-serving value.
  //
  // kJ parenthetical problem:
  //   "Energy 120 (502kJ)" — strip the (NNNkJ) block first so the regex
  //   doesn't skip past 120 looking for a digit after the parenthetical.
  //
  // Strategy: strip kJ blocks, then find the keyword, then grab the FIRST
  // number that follows it (within 60 chars, dotAll for next-line layouts).
  // The per-serving column is always printed before the per-100g column.

  static String _stripKj(String text) =>
      text.replaceAll(RegExp(r'\(\d+\.?\d*\s*kj\)', caseSensitive: false), '');

  // Patterns anchor to the label keyword then grab the FIRST number following.
  // dotAll: true handles values on the next line.
  // The \D{0,40} gap stops at 40 non-digit chars so we don't skip columns.
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
  // Creatine Monohydrate — treated as a nutrition value row on this label
  static final _creatinePat = RegExp(
    r'creatine monohydrate\D{0,40}(\d{1,3}\.?\d{0,2})',
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

  // ── Rule-based ingredient detection ──────────────────────────────────────

  List<DetectedIngredient> _detectIngredients(String ingredientText) {
    if (ingredientText.isEmpty) return [];
    final lower = ingredientText.toLowerCase();
    final found = <DetectedIngredient>[];

    for (final rule in _ingredientDatabase) {
      for (final alias in rule.aliases) {
        if (lower.contains(alias)) {
          found.add(
            DetectedIngredient(
              name: rule.name,
              category: rule.category,
              explanation: rule.explanation,
              isAmSpiking: rule.category.contains('Amino Spiking'),
            ),
          );
          break; // only add each rule once
        }
      }
    }
    return found;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

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

      // ── Also write to dedicated whey_supplements collection ──────────────
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
