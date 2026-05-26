import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/repositories/barcode_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/services/logging/activity_logger.dart';
import 'package:cal0appv2/models/logging/activity_log.dart';

enum BarcodeScanState { idle, scanning, found, notFound, failed, saving }

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

  BarcodeScanState _state = BarcodeScanState.idle;
  BarcodeFoodModel? _foundFood;
  String? _lastBarcode;
  String? _errorMessage;
  String? _successMessage;

  // Debounce
  String? _processingBarcode;
  DateTime? _lastScanTime;
  static const _debounce = Duration(seconds: 2);

  // ── Getters ───────────────────────────────────────────────────────────

  BarcodeScanState get state => _state;
  BarcodeFoodModel? get foundFood => _foundFood;
  String? get lastBarcode => _lastBarcode;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isIdle => _state == BarcodeScanState.idle;
  bool get isLooking => _state == BarcodeScanState.scanning;
  bool get isSaving => _state == BarcodeScanState.saving;
  bool get canScan => _state == BarcodeScanState.idle;

  // ── Barcode detected ──────────────────────────────────────────────────

  Future<void> onBarcodeDetected(String rawBarcode) async {
    // ADD THIS LINE
    debugPrint('🔍 Barcode detected: $rawBarcode');

    final now = DateTime.now();
    if (_processingBarcode == rawBarcode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _debounce) {
      debugPrint('⏭ Debounce skip: $rawBarcode');
      return;
    }
    if (!canScan) {
      debugPrint('⏭ Cannot scan, state: $_state');
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

    final result = await _barcodeRepo.lookup(rawBarcode);

    switch (result) {
      case BarcodeLookupSuccess(:final food):
        _foundFood = food;
        _setState(BarcodeScanState.found);

      case BarcodeLookupNotFound():
        _foundFood = null;
        _setState(BarcodeScanState.notFound);

      case BarcodeLookupError(:final message):
        _errorMessage = message;
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
    double? servingSize,
  }) async {
    if (uid.isEmpty) return false;

    _setState(BarcodeScanState.saving);
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
      _setState(BarcodeScanState.idle);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save: $e';
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
    _setState(BarcodeScanState.idle);
  }

  void _setState(BarcodeScanState state) {
    _state = state;
    notifyListeners();
  }
}
