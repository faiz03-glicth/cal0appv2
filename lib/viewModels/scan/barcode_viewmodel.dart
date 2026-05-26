import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/models/logging/foodlog_model.dart';
import 'package:cal0appv2/repositories/barcode_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/food/open_food_facts_service.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

/// Follows exact same pattern as ScanViewModel and FoodLogViewModel
enum BarcodeState {
  idle, // Awaiting scan
  looking, // Network/cache lookup in progress
  found, // Product found — show confirm sheet
  notFound, // Product not in database — show manual entry
  failed, // Network error
  saving, // Writing to Firestore
}

class BarcodeViewModel extends ChangeNotifier {
  final BarcodeRepository _barcodeRepo;
  final FoodLogRepository _foodLogRepo;
  final _uuid = const Uuid();

  BarcodeViewModel({
    BarcodeRepository? barcodeRepository,
    FoodLogRepository? foodLogRepository,
  }) : _barcodeRepo = barcodeRepository ?? BarcodeRepository(),
       _foodLogRepo = foodLogRepository ?? FoodLogRepository();

  // ── State ────────────────────────────────────────────────────────────

  BarcodeState _state = BarcodeState.idle;
  BarcodeFoodModel? _foundFood;
  String? _lastBarcode;
  String? _errorMessage;
  String? _successMessage;

  // Debounce — prevents processing same barcode twice in quick succession
  String? _processingBarcode;
  DateTime? _lastScanTime;
  static const _debounce = Duration(seconds: 2);

  // ── Getters ───────────────────────────────────────────────────────────

  BarcodeState get state => _state;
  BarcodeFoodModel? get foundFood => _foundFood;
  String? get lastBarcode => _lastBarcode;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isIdle => _state == BarcodeState.idle;
  bool get isLooking => _state == BarcodeState.looking;
  bool get isSaving => _state == BarcodeState.saving;
  bool get canScan => _state == BarcodeState.idle;

  // ── Barcode detected from scanner ─────────────────────────────────────

  Future<void> onBarcodeDetected(String rawBarcode) async {
    // Debounce: skip if same barcode scanned again too quickly
    final now = DateTime.now();
    if (_processingBarcode == rawBarcode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _debounce) {
      return;
    }
    if (!canScan) return;

    _processingBarcode = rawBarcode;
    _lastScanTime = now;
    _lastBarcode = rawBarcode;
    _errorMessage = null;
    _successMessage = null;
    _setState(BarcodeState.looking);

    ActivityLogger.instance.log(
      ActivityEventType.scanInitiated,
      errorMessage: 'barcode=$rawBarcode',
    );

    final result = await _barcodeRepo.lookup(rawBarcode);

    switch (result) {
      case BarcodeFound(:final food):
        _foundFood = food;
        _setState(BarcodeState.found);

      case BarcodeNotFound():
        _foundFood = null;
        _setState(BarcodeState.notFound);

      case BarcodeLookupFailed(:final message):
        _errorMessage = message;
        _setState(BarcodeState.failed);
    }
  }

  // ── Save to food log ──────────────────────────────────────────────────

  /// Called from BarcodeResultSheet after user confirms/edits values
  /// Mirrors ScanViewModel.saveScanResult() pattern
  Future<bool> saveToFoodLog({
    required String uid,
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double sugar = 0,
    double sodium = 0,
    double? servingSize,
  }) async {
    if (uid.isEmpty) return false;

    _setState(BarcodeState.saving);
    _errorMessage = null;

    try {
      final log = FoodLogModel(
        foodLogID: _uuid.v4(),
        userId: uid,
        foodLogName: foodName.trim().isEmpty
            ? (_foundFood?.displayName ?? 'Scanned Product')
            : foodName.trim(),
        calorieIntake: calories,
        foodLogDate: DateTime.now(),
        loggedAt: DateTime.now(),
        protein: protein,
        carbs: carbs,
        fats: fat,
        sugar: sugar,
        sodium: sodium,
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
      _setState(BarcodeState.idle);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save: $e';
      ActivityLogger.instance.logError('BARCODE_SAVE_ERROR', e);
      _setState(BarcodeState.failed);
      return false;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────

  /// Called when user dismisses the result sheet or wants to scan again
  void reset() {
    _foundFood = null;
    _lastBarcode = null;
    _errorMessage = null;
    _successMessage = null;
    _processingBarcode = null;
    _setState(BarcodeState.idle);
  }

  void _setState(BarcodeState state) {
    _state = state;
    notifyListeners();
  }
}
