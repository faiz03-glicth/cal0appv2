import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/off_food_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';
import 'dart:io';

enum BarcodeScanState { idle, scanning, found, notFound, failed, saving }

class BarcodeViewModel extends ChangeNotifier {
  final OFFFoodRepository _foodRepo;
  final FoodLogRepository _foodLogRepo;
  final _uuid = const Uuid();

  BarcodeViewModel({
    OFFFoodRepository? foodRepository,
    FoodLogRepository? foodLogRepository,
    // Legacy injection name — ignored, kept for DI compat
    @Deprecated('Use foodRepository') dynamic barcodeRepository,
  }) : _foodRepo = foodRepository ?? OFFFoodRepository(),
       _foodLogRepo = foodLogRepository ?? FoodLogRepository();

  // ── State ────────────────────────────────────────────────────────────

  BarcodeScanState _state = BarcodeScanState.idle;
  OFFFoodResult? _foundFood;
  String? _lastBarcode;
  String? _errorMessage;
  String? _successMessage;

  String? _processingBarcode;
  DateTime? _lastScanTime;
  static const _debounce = Duration(milliseconds: 1500);

  // ── Getters ───────────────────────────────────────────────────────────

  BarcodeScanState get state => _state;
  OFFFoodResult? get foundFood => _foundFood;
  String? get lastBarcode => _lastBarcode;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isIdle => _state == BarcodeScanState.idle;
  bool get isLooking => _state == BarcodeScanState.scanning;
  bool get isSaving => _state == BarcodeScanState.saving;
  bool get canScan => _state == BarcodeScanState.idle;

  // ── Barcode detected ──────────────────────────────────────────────────

  Future<void> onBarcodeDetected(String rawBarcode) async {
    debugPrint(
      '🔍 BarcodeViewModel.onBarcodeDetected: $rawBarcode  state=$_state',
    );

    if (!canScan) {
      debugPrint('⏭ VM not ready — state: $_state');
      return;
    }

    final now = DateTime.now();
    if (_processingBarcode == rawBarcode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _debounce) {
      debugPrint('⏭ Debounce skip for $rawBarcode');
      return;
    }

    _processingBarcode = rawBarcode;
    _lastScanTime = now;
    _lastBarcode = rawBarcode;
    _errorMessage = null;
    _successMessage = null;
    _setState(BarcodeScanState.scanning);

    ActivityLogger.instance.log(
      ActivityEventType.scanInitiated,
      errorMessage: 'barcode=$rawBarcode',
    );

    final result = await _foodRepo.lookupBarcode(rawBarcode);

    switch (result) {
      case FoodLookupSuccess(:final food):
        _foundFood = food;
        _setState(BarcodeScanState.found);

      case FoodLookupNotFound():
        _foundFood = null;
        _setState(BarcodeScanState.notFound);

      case FoodLookupError(:final message):
        _errorMessage = message;
        debugPrint('❌ Barcode lookup error: $message');
        _setState(BarcodeScanState.failed);
    }
  }

  // ── Gallery upload (UAT 8.2 / 8.3) ──────────────────────────────────────
  //
  // Decodes a barcode from a static image file instead of the live camera,
  // via mobile_scanner's MobileScannerController.analyzeImage(path).
  // Supported on Android/iOS only (package limitation).

  static const _allowedImageExtensions = ['.jpg', '.jpeg', '.png'];

  bool _hasValidImageExtension(File file) {
    final path = file.path.toLowerCase();
    return _allowedImageExtensions.any((ext) => path.endsWith(ext));
  }

  Future<void> onImageUploaded(File imageFile) async {
    if (!canScan) return;

    _errorMessage = null;
    _successMessage = null;

    // UAT 8.3 — reject non-image files before attempting to decode.
    if (!_hasValidImageExtension(imageFile)) {
      _errorMessage = 'Wrong Format File, please re-upload new file';
      _setState(BarcodeScanState.failed);
      return;
    }

    _setState(BarcodeScanState.scanning);
    ActivityLogger.instance.log(
      ActivityEventType.scanInitiated,
      errorMessage: 'barcode_upload=${imageFile.path}',
    );

    try {
      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(imageFile.path);
      await controller.dispose();

      final rawBarcode = capture?.barcodes.firstOrNull?.rawValue;

      if (rawBarcode == null) {
        // UAT 8.4 — image decoded but no barcode found, or the file
        // itself is unreadable/unclear.
        _errorMessage = 'Unreadable file, please upload picture with clear';
        _setState(BarcodeScanState.failed);
        return;
      }

      _lastBarcode = rawBarcode;
      final result = await _foodRepo.lookupBarcode(rawBarcode);

      switch (result) {
        case FoodLookupSuccess(:final food):
          _foundFood = food;
          _setState(BarcodeScanState.found);

        case FoodLookupNotFound():
          _foundFood = null;
          _setState(BarcodeScanState.notFound);

        case FoodLookupError(:final message):
          _errorMessage = message;
          _setState(BarcodeScanState.failed);
      }
    } catch (e) {
      debugPrint('❌ Image barcode analysis error: $e');
      _errorMessage = 'Unreadable file, please upload picture with clear';
      _setState(BarcodeScanState.failed);
    }
  }

  // ── Save to food log ──────────────────────────────────────────────────

  Future<bool> saveToFoodLog({
    required String uid,
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double sugar = 0,
    double sodium = 0,
    double saturatedFat = 0,
    double? servingSize,
    DateTime? targetDate,
  }) async {
    if (uid.isEmpty) return false;
    _setState(BarcodeScanState.saving);
    _errorMessage = null;

    try {
      final logDate = targetDate ?? DateTime.now();
      final log = FoodLogModel(
        foodLogID: _uuid.v4(),
        userId: uid,
        foodLogName: foodName.trim().isEmpty
            ? (_foundFood?.displayName ?? 'Scanned Product')
            : foodName.trim(),
        calorieIntake: calories,
        foodLogDate: logDate,
        loggedAt: DateTime.now(),
        protein: protein,
        carbs: carbs,
        fats: fat,
        sugar: sugar,
        sodium: sodium,
        saturatedFat: saturatedFat,
        source: FoodLogSource.scanned,
        servingSize: servingSize,
        servingUnit: _foundFood?.servingUnit ?? 'g',
        scanAnalysisResult: 'BARCODE: ${_lastBarcode ?? ""}',
      );

      await _foodLogRepo.addFoodLog(uid, log);

      ActivityLogger.instance.log(
        ActivityEventType.scanResultSaved,
        foodName: log.foodLogName,
        calories: log.calorieIntake,
        foodSource: 'barcode',
      );

      _successMessage = '${log.foodLogName} added to diary';
      _setState(BarcodeScanState.idle);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save: $e';
      debugPrint('❌ Save error: $e');
      ActivityLogger.instance.logError('BARCODE_SAVE_ERROR', e);
      _setState(BarcodeScanState.failed);
      return false;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────

  void reset() {
    _foundFood = null;
    _lastBarcode = null;
    _errorMessage = null;
    _successMessage = null;
    _processingBarcode = null;
    _lastScanTime = null;
    _setState(BarcodeScanState.idle);
  }

  void _setState(BarcodeScanState state) {
    _state = state;
    debugPrint('🔄 BarcodeViewModel state → $state');
    notifyListeners();
  }
}