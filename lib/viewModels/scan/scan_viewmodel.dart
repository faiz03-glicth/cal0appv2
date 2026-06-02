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
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

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
  final AminoSpikingAI _aiService = AminoSpikingAI();
  final NutritionExtractorService _extractor = NutritionExtractorService();
  final ImagePreprocessorService _preprocessor = ImagePreprocessorService();
  final OcrTextCleanerService _cleaner = OcrTextCleanerService();
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

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFiles.first.path,
        errorMessage: lowOcrQuality
            ? 'Multi-angle OCR quality gate failed'
            : null,
      );

      // Stage 4: Analyse merged text
      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      notifyListeners();

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

      final textForDetection = _bestIngredientText(
        extracted: extractedResult!.ingredientText,
        cleaned: cleanedOcr!.ingredientSection,
        fullOcr: scannedText ?? '',
        allLines: scannedLines,
      );
      detectedIngredients = _detectIngredients(textForDetection);

      // Pass both the nutrition section AND the raw joined lines.
      // Raw lines preserve newlines between labels and values — critical for dotAll regex.
      final rawOcrText = scannedLines.join('\n');
      extractedResult = _mergeNutritionFromOcr(
        extractedResult!,
        cleanedOcr!.nutritionSection,
        rawOcrText,
      );

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

      ActivityLogger.instance.log(
        ActivityEventType.scanOcrCompleted,
        ocrExtractedText: scannedText,
        durationMs: sw.elapsedMilliseconds,
        scanImagePath: imageFile.path,
        errorMessage: lowOcrQuality ? 'OCR quality gate failed' : null,
      );

      // 4. Analyse ingredients
      _setStage(ScanStage.analyzingIngredients);
      isAnalyzing = true;
      notifyListeners();

      extractedResult = _extractor.extract(scannedLines);

      // Enrich with cleaner sections when extractor missed them
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

      // Rule-based ingredient detection — runs on ALL scans regardless of AI.
      // Uses the broadest available text so nothing is missed:
      // priority: extracted section → cleaner section → full OCR text
      final textForDetection = _bestIngredientText(
        extracted: extractedResult!.ingredientText,
        cleaned: cleanedOcr!.ingredientSection,
        fullOcr: scannedText ?? '',
        allLines: scannedLines,
      );
      detectedIngredients = _detectIngredients(textForDetection);

      // Direct number extraction from OCR — fills fields the existing extractor missed
      final rawOcrText = scannedLines.join('\n');
      extractedResult = _mergeNutritionFromOcr(
        extractedResult!,
        cleanedOcr!.nutritionSection,
        rawOcrText,
      );

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
    // Use nutrition section if available, fall back to full text
    final src = nutritionSection.isNotEmpty ? nutritionSection : fullText;
    if (src.isEmpty) return result;

    final lower = src.toLowerCase();

    int? calories = result.calories > 0
        ? null
        : _parseNutritionValue(lower, _caloriePat);
    double? protein = (result.protein > 0)
        ? null
        : _parseNutritionDouble(lower, _proteinPat);
    double? carbs = (result.carbs > 0)
        ? null
        : _parseNutritionDouble(lower, _carbPat);
    double? fat = (result.fat > 0)
        ? null
        : _parseNutritionDouble(lower, _fatPat);
    double? sugar = ((result.sugar ?? 0) > 0)
        ? null
        : _parseNutritionDouble(lower, _sugarPat);
    double? sodium = ((result.sodium ?? 0) > 0)
        ? null
        : _parseNutritionDouble(lower, _sodiumPat);
    double? serving = ((result.servingSize ?? 0) > 0)
        ? null
        : _parseNutritionDouble(lower, _servingPat);

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
  // dotAll: true makes . match newlines — critical for nutrition panels
  // where the value is often on the line BELOW the label.
  // Gap increased to 60 chars to handle "Amount Per Serving\nCalories\n120".
  static final _caloriePat = RegExp(
    r'(?:calorie|energy|kcal|cal|tenaga)[^\d]{0,60}(\d{1,4})',
    caseSensitive: false,
    dotAll: true,
  );
  static final _proteinPat = RegExp(
    r'protein[^\d]{0,60}(\d{1,3}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _carbPat = RegExp(
    r'(?:carbohydrate|carbs?|total carb|karbohidrat)[^\d]{0,60}(\d{1,3}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _fatPat = RegExp(
    r'(?:total fat|fat|lemak)[^\d]{0,60}(\d{1,3}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sugarPat = RegExp(
    r'(?:total sugars?|sugars?|gula)[^\d]{0,60}(\d{1,3}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sodiumPat = RegExp(
    r'(?:sodium|natrium)[^\d]{0,60}(\d{1,4}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _servingPat = RegExp(
    r'(?:serving size|saiz hidangan)[^\d]{0,60}(\d{1,3}(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );

  int? _parseNutritionValue(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  double? _parseNutritionDouble(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
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
