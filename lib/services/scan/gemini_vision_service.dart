import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cal0appv2/services/logs/debuglog_services.dart';

// ── Result model ──────────────────────────────────────────────────────────

class GeminiNutritionResult {
  final String productName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double sodium;
  final double servingSize;
  final String servingUnit;
  final String ingredientText;
  final double creatineMonohydrate; // 0 if not present
  final bool isSuccess;
  final String? errorMessage;

  const GeminiNutritionResult({
    this.productName = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.servingSize = 0,
    this.servingUnit = 'g',
    this.ingredientText = '',
    this.creatineMonohydrate = 0,
    this.isSuccess = false,
    this.errorMessage,
  });

  static const empty = GeminiNutritionResult();

  bool get hasData => isSuccess && (calories > 0 || protein > 0);
}

// ── Service ───────────────────────────────────────────────────────────────

class GeminiVisionService {
  // Read API key from --dart-define at build time.
  // Run with: flutter run --dart-define=GEMINI_API_KEY=your_key
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const _model = 'gemini-1.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  // ── Public entry point ────────────────────────────────────────────────

  /// Send one or more label images and return structured nutrition data.
  /// Multiple images are sent in a single request so Gemini sees all angles.
  Future<GeminiNutritionResult> extractNutrition(List<File> images) async {
    if (_apiKey.isEmpty) {
      LogService.error('GeminiVision: GEMINI_API_KEY not set');
      return GeminiNutritionResult(
        isSuccess: false,
        errorMessage: 'Gemini API key not configured.',
      );
    }
    if (images.isEmpty) return GeminiNutritionResult.empty;

    final sw = Stopwatch()..start();
    LogService.info('GeminiVision: sending ${images.length} image(s)');

    try {
      // Build the request body
      final body = await _buildRequestBody(images);

      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      sw.stop();
      LogService.info(
        'GeminiVision: HTTP ${response.statusCode} in ${sw.elapsedMilliseconds}ms',
      );

      if (response.statusCode != 200) {
        LogService.error('GeminiVision: API error ${response.statusCode}');
        return GeminiNutritionResult(
          isSuccess: false,
          errorMessage: 'Gemini API error ${response.statusCode}',
        );
      }

      return _parseResponse(response.body);
    } catch (e, st) {
      LogService.error('GeminiVision: exception', e, st);
      return GeminiNutritionResult(
        isSuccess: false,
        errorMessage: 'Gemini request failed: $e',
      );
    }
  }

  // ── Build Gemini request body ─────────────────────────────────────────

  Future<Map<String, dynamic>> _buildRequestBody(List<File> images) async {
    // Build the parts list: images first, then the text prompt
    final parts = <Map<String, dynamic>>[];

    for (final file in images) {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _mimeType(file.path);
      parts.add({
        'inline_data': {'mime_type': mime, 'data': b64},
      });
    }

    parts.add({'text': _prompt});

    return {
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0.0, // deterministic — we want facts not creativity
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json',
      },
    };
  }

  // ── Prompt ────────────────────────────────────────────────────────────

  static const _prompt = '''
You are a nutrition label parser. Analyse the supplement/food label image(s) provided.

Extract the following information and return ONLY a valid JSON object.
Use the "Amount Per Serving" column, NOT the "Per 100g" column.
If a field is not found, use 0 for numbers or "" for strings.
Do not include any explanation or markdown — only the raw JSON.

Return this exact structure:
{
  "product_name": "name of the product",
  "serving_size": 30,
  "serving_unit": "g",
  "calories": 120,
  "protein_g": 17.7,
  "carbs_g": 9.0,
  "fat_g": 1.5,
  "sugar_g": 1.8,
  "sodium_mg": 59.43,
  "creatine_monohydrate_g": 1.6,
  "ingredients": "full comma-separated ingredient list as a single string"
}
''';

  // ── Parse Gemini response ─────────────────────────────────────────────

  GeminiNutritionResult _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

      // Navigate to the text content
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return GeminiNutritionResult(
          isSuccess: false,
          errorMessage: 'No candidates in Gemini response',
        );
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return GeminiNutritionResult(
          isSuccess: false,
          errorMessage: 'No parts in Gemini response content',
        );
      }

      final rawText = parts[0]['text'] as String? ?? '';
      LogService.info('GeminiVision: raw text: $rawText');

      // Strip markdown fences if Gemini wraps in ```json ... ```
      final jsonStr = _stripMarkdown(rawText);

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return GeminiNutritionResult(
        productName: _str(data, 'product_name'),
        calories: _int(data, 'calories'),
        protein: _dbl(data, 'protein_g'),
        carbs: _dbl(data, 'carbs_g'),
        fat: _dbl(data, 'fat_g'),
        sugar: _dbl(data, 'sugar_g'),
        sodium: _dbl(data, 'sodium_mg'),
        servingSize: _dbl(data, 'serving_size'),
        servingUnit: _str(data, 'serving_unit', fallback: 'g'),
        ingredientText: _str(data, 'ingredients'),
        creatineMonohydrate: _dbl(data, 'creatine_monohydrate_g'),
        isSuccess: true,
      );
    } catch (e) {
      LogService.error('GeminiVision: JSON parse error: $e');
      return GeminiNutritionResult(
        isSuccess: false,
        errorMessage: 'Failed to parse Gemini response: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static String _stripMarkdown(String text) {
    final t = text.trim();
    if (t.startsWith('```')) {
      return t
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    return t;
  }

  static String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ext == 'png' ? 'image/png' : 'image/jpeg';
  }

  static String _str(Map d, String k, {String fallback = ''}) =>
      (d[k] as String?)?.trim() ?? fallback;

  static int _int(Map d, String k) {
    final v = d[k];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _dbl(Map d, String k) {
    final v = d[k];
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
