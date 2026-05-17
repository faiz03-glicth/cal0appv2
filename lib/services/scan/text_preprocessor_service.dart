// lib/services/scan/text_preprocessor_service.dart

class TextPreprocessorService {
  /// Mirrors the preprocessing done during DistilBERT training.
  /// Cleans OCR noise before tokenization.
  static String preprocess(String rawText) {
    String text = rawText.toLowerCase();

    // Remove non-alphanumeric except commas, dots, hyphens, percent
    text = text.replaceAll(RegExp(r'[^a-z0-9\s,.\-%()/]'), ' ');

    // Collapse multiple whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Truncate to ~400 chars — model sees max 128 tokens anyway
    if (text.length > 400) text = text.substring(0, 400);

    return text;
  }

  /// Joins multi-line OCR output into a single ingredient string.
  static String joinLines(List<String> lines) {
    return lines.map((l) => l.trim()).where((l) => l.isNotEmpty).join(', ');
  }
}
