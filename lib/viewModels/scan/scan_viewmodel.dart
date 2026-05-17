// lib/viewModels/scan/scan_viewmodel.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';
import 'package:cal0appv2/services/scan/amino_spike_detector_service.dart';

class ScanViewModel extends ChangeNotifier {
  final ScanRepository _scanRepo;
  final AminoSpikeDetectorService _detector = AminoSpikeDetectorService();

  ScanViewModel({ScanRepository? scanRepository})
    : _scanRepo = scanRepository ?? ScanRepository() {
    _detector.init(); // load model on VM creation
  }

  bool isScanning = false;
  bool isAnalyzing = false;
  String? scannedText;
  List<String> scannedLines = [];
  String? errorMessage;

  // ── Detection results ──────────────────────────────────────────────────────
  DetectionResult? detectionResult;

  List<String> get flaggedIngredients =>
      detectionResult?.flaggedIngredients ?? [];

  bool get hasSuspiciousIngredients => detectionResult?.isSpiked ?? false;

  double get confidence => detectionResult?.confidence ?? 0.0;

  String get verdictLabel {
    if (detectionResult == null) return '';
    if (detectionResult!.isSpiked) {
      return 'Potential amino spiking detected (${(confidence * 100).toStringAsFixed(0)}% confidence)';
    }
    return 'No suspicious ingredients found (${(confidence * 100).toStringAsFixed(0)}% confidence)';
  }

  Future<void> scanImage(File imageFile) async {
    isScanning = true;
    errorMessage = null;
    scannedText = null;
    scannedLines = [];
    detectionResult = null;
    notifyListeners();

    try {
      // Step 1 — OCR
      scannedLines = await _scanRepo.scanLabelLines(imageFile);
      scannedText = scannedLines.join('\n');

      // Step 2 — BERT analysis
      isScanning = false;
      isAnalyzing = true;
      notifyListeners();

      detectionResult = await _detector.analyze(scannedLines);
    } catch (e) {
      errorMessage = 'Scan failed. Please try again with better lighting.';
    }

    isScanning = false;
    isAnalyzing = false;
    notifyListeners();
  }

  void clearScan() {
    scannedText = null;
    scannedLines = [];
    errorMessage = null;
    detectionResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanRepo.dispose();
    _detector.dispose();
    super.dispose();
  }
}
