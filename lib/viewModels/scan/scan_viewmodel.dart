import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/scan/ai_service.dart';
import 'package:cal0appv2/services/scan/nutrition_extractor_service.dart';

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
    _aiService.initialize().then((_) => notifyListeners());
  }

  // ── State ─────────────────────────────────────────────────────────────────
  bool isScanning = false;
  bool isAnalyzing = false;
  bool isSaving = false;

  String? scannedText;
  List<String> scannedLines = [];
  String? errorMessage;
  String? successMessage;
  File? scannedImageFile;

  // OCR extraction result
  ScanResultModel? extractedResult;

  // AI verdict
  bool hasSuspiciousIngredients = false;
  double aiConfidence = 0.0;

  String get verdictLabel {
    if (extractedResult == null) return '';
    final pct = (aiConfidence * 100).toStringAsFixed(0);
    return hasSuspiciousIngredients
        ? 'Potential amino spiking detected ($pct% confidence)'
        : 'No suspicious ingredients found ($pct% confidence)';
  }

  // ── Scan ──────────────────────────────────────────────────────────────────

  Future<void> scanImage(File imageFile) async {
    isScanning = true;
    errorMessage = null;
    successMessage = null;
    scannedText = null;
    scannedLines = [];
    extractedResult = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
    scannedImageFile = imageFile;
    notifyListeners();

    try {
      // Step 1 — OCR
      scannedLines = await _scanRepo.scanLabelLines(imageFile);
      scannedText = scannedLines.join('\n');

      // Step 2 — Smart nutrition extraction
      extractedResult = _extractor.extract(scannedLines);

      isScanning = false;
      isAnalyzing = true;
      notifyListeners();

      // Step 3 — BERT amino spiking analysis
      if (_aiService.isReady && extractedResult!.ingredientText.isNotEmpty) {
        final result = await _aiService.analyzeIngredients(
          extractedResult!.ingredientText,
        );
        hasSuspiciousIngredients = result['isSpiked'] as bool;
        aiConfidence = result['confidence'] as double;
      }
    } catch (e) {
      errorMessage = 'Scan failed. Please try again with better lighting.';
    }

    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  // ── Save to scan history + optionally food log ────────────────────────────
  Future<bool> saveScanResult({
    required String uid,
    required ScanResultModel confirmed,
    required bool addToFoodLog, // kept for API compat, always true now
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
      successMessage = 'Saved to food log!';
    } catch (e) {
      errorMessage = 'Failed to save: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }

    isSaving = false;
    notifyListeners();
    return true;
  }

  void clearScan() {
    scannedText = null;
    scannedLines = [];
    errorMessage = null;
    successMessage = null;
    extractedResult = null;
    hasSuspiciousIngredients = false;
    aiConfidence = 0.0;
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
