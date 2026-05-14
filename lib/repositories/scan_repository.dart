import 'dart:io';
import 'package:cal0appv2/services/scan/ocr_service.dart';

class ScanRepository {
  final OcrService _ocrService;

  ScanRepository({OcrService? ocrService})
    : _ocrService = ocrService ?? OcrService();

  Future<String> scanLabel(File imageFile) =>
      _ocrService.extractText(imageFile);

  Future<List<String>> scanLabelLines(File imageFile) =>
      _ocrService.extractLines(imageFile);

  void dispose() => _ocrService.dispose();
}
