import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      final text = recognized.text;
      LogService.info('OCR extracted ${text.length} chars');
      return text;
    } catch (e) {
      LogService.error('OcrService.extractText failed: $e');
      return '';
    }
  }

  Future<List<String>> extractLines(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      return recognized.blocks
          .expand((b) => b.lines)
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      LogService.error('OcrService.extractLines failed: $e');
      return [];
    }
  }

  void dispose() => _recognizer.close();
}
