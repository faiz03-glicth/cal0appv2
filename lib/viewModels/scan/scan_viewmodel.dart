import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cal0appv2/repositories/scan_repository.dart';

class ScanViewModel extends ChangeNotifier {
  final ScanRepository _scanRepo;

  ScanViewModel({ScanRepository? scanRepository})
    : _scanRepo = scanRepository ?? ScanRepository();

  bool isScanning = false;
  String? scannedText;
  List<String> scannedLines = [];
  String? errorMessage;

  // Amino spiking suspects per your thesis (§1 background)
  static const _suspectIngredients = [
    'glycine',
    'taurine',
    'creatine',
    'arginine',
    'glutamine',
    'beta-alanine',
    'hydroxyproline',
  ];

  List<String> get flaggedIngredients => scannedLines
      .where(
        (line) =>
            _suspectIngredients.any((s) => line.toLowerCase().contains(s)),
      )
      .toList();

  bool get hasSuspiciousIngredients => flaggedIngredients.isNotEmpty;

  Future<void> scanImage(File imageFile) async {
    isScanning = true;
    errorMessage = null;
    scannedText = null;
    scannedLines = [];
    notifyListeners();

    try {
      scannedLines = await _scanRepo.scanLabelLines(imageFile);
      scannedText = scannedLines.join('\n');
    } catch (e) {
      errorMessage = 'Scan failed. Please try again with better lighting.';
    }

    isScanning = false;
    notifyListeners();
  }

  void clearScan() {
    scannedText = null;
    scannedLines = [];
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanRepo.dispose();
    super.dispose();
  }
}
