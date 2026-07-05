import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cal0appv2/services/logs/debuglog_services.dart';

// ── Result model ──────────────────────────────────────────────────────────

class GeminiNutritionResult {
  // Identity
  final String productName;
  final String brandName;
  final double servingSize;
  final String servingUnit;
  final int servingsPerContainer;

  // Core macros
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  // Extended macros
  final double sugar;
  final double fiber;
  final double saturatedFat;
  final double transFat;
  final double unsaturatedFat;
  final double cholesterol; // mg
  final double sodium; // mg
  final double potassium; // mg

  // Supplement-specific
  final double creatineMonohydrate; // g
  final double bcaa; // g
  final double leucine; // g
  final double isoleucine; // g
  final double valine; // g
  final double glutamine; // g
  final double taurine; // g
  final double caffeine; // mg

  // Vitamins & minerals
  final double vitaminC; // mg
  final double vitaminD; // µg
  final double calcium; // mg
  final double iron; // mg
  final double magnesium; // mg
  final double zinc; // mg

  // Text
  final String ingredientText;

  // Status
  final bool isSuccess;
  final String? errorMessage;

  const GeminiNutritionResult({
    this.productName = '',
    this.brandName = '',
    this.servingSize = 0,
    this.servingUnit = 'g',
    this.servingsPerContainer = 0,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.fiber = 0,
    this.saturatedFat = 0,
    this.transFat = 0,
    this.unsaturatedFat = 0,
    this.cholesterol = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.creatineMonohydrate = 0,
    this.bcaa = 0,
    this.leucine = 0,
    this.isoleucine = 0,
    this.valine = 0,
    this.glutamine = 0,
    this.taurine = 0,
    this.caffeine = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.zinc = 0,
    this.ingredientText = '',
    this.isSuccess = false,
    this.errorMessage,
  });

  static const empty = GeminiNutritionResult();

  bool get hasData => isSuccess && (calories > 0 || protein > 0);
}

// ── Service ───────────────────────────────────────────────────────────────

class GeminiVisionService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-flash-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  // ── Public entry point ────────────────────────────────────────────────

  Future<GeminiNutritionResult> extractNutrition(List<File> images) async {
    if (_apiKey.isEmpty) {
      LogService.error('GeminiVision: GEMINI_API_KEY not set');
      return const GeminiNutritionResult(
        isSuccess: false,
        errorMessage: 'Gemini API key not configured.',
      );
    }
    if (images.isEmpty) return GeminiNutritionResult.empty;

    final sw = Stopwatch()..start();
    LogService.info('GeminiVision: sending ${images.length} image(s)');

    try {
      final body = await _buildRequestBody(images);
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

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

  // ── Build request body ────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildRequestBody(List<File> images) async {
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
        'temperature': 0.0,
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };
  }

  static const _prompt = r'''
You are an expert nutrition label OCR and parser for supplement products.
Analyse ALL label images provided (may be multiple angles of the same product).

RULES:
- Use "Amount Per Serving" values, NOT "Per 100g".
- For two-column tables (Per Serving | Per 100g), always take the FIRST number.
- If a value is not present on the label, return 0 for numbers or "" for strings.
- Return ONLY a valid JSON object — no explanation, no markdown fences.
- For supplement rows like "Creatine Monohydrate 3g" — read the number after the name.
- Units: protein/carbs/fat/fiber/sugar/saturated_fat/trans_fat/unsaturated_fat/creatine/bcaa/leucine/isoleucine/valine/glutamine/taurine are in GRAMS.
- Units: sodium/potassium/cholesterol/caffeine/vitamin_c/calcium/iron/magnesium/zinc are in MILLIGRAMS.
- Units: vitamin_d is in MICROGRAMS (µg).
- serving_size is in grams (the numeric value only, e.g. 30 for "30g").

Return exactly this JSON structure (include all keys even if value is 0 or ""):
{
  "product_name": "",
  "brand_name": "",
  "serving_size": 0,
  "serving_unit": "g",
  "servings_per_container": 0,
  "calories": 0,
  "protein_g": 0.0,
  "carbs_g": 0.0,
  "fat_g": 0.0,
  "sugar_g": 0.0,
  "fiber_g": 0.0,
  "saturated_fat_g": 0.0,
  "trans_fat_g": 0.0,
  "unsaturated_fat_g": 0.0,
  "cholesterol_mg": 0.0,
  "sodium_mg": 0.0,
  "potassium_mg": 0.0,
  "creatine_monohydrate_g": 0.0,
  "bcaa_g": 0.0,
  "leucine_g": 0.0,
  "isoleucine_g": 0.0,
  "valine_g": 0.0,
  "glutamine_g": 0.0,
  "taurine_g": 0.0,
  "caffeine_mg": 0.0,
  "vitamin_c_mg": 0.0,
  "vitamin_d_ug": 0.0,
  "calcium_mg": 0.0,
  "iron_mg": 0.0,
  "magnesium_mg": 0.0,
  "zinc_mg": 0.0,
  "ingredients": ""
}
''';

  // ── Parse Gemini response ─────────────────────────────────────────────

  GeminiNutritionResult _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return const GeminiNutritionResult(
          isSuccess: false,
          errorMessage: 'No candidates in Gemini response',
        );
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return const GeminiNutritionResult(
          isSuccess: false,
          errorMessage: 'No parts in Gemini response content',
        );
      }

      final rawText = parts[0]['text'] as String? ?? '';
      LogService.info('GeminiVision: raw response length=${rawText.length}');

      final jsonStr = _stripMarkdown(rawText);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final result = GeminiNutritionResult(
        productName: _str(data, 'product_name'),
        brandName: _str(data, 'brand_name'),
        servingSize: _dbl(data, 'serving_size'),
        servingUnit: _str(data, 'serving_unit', fallback: 'g'),
        servingsPerContainer: _int(data, 'servings_per_container'),
        calories: _int(data, 'calories'),
        protein: _dbl(data, 'protein_g'),
        carbs: _dbl(data, 'carbs_g'),
        fat: _dbl(data, 'fat_g'),
        sugar: _dbl(data, 'sugar_g'),
        fiber: _dbl(data, 'fiber_g'),
        saturatedFat: _dbl(data, 'saturated_fat_g'),
        transFat: _dbl(data, 'trans_fat_g'),
        unsaturatedFat: _dbl(data, 'unsaturated_fat_g'),
        cholesterol: _dbl(data, 'cholesterol_mg'),
        sodium: _dbl(data, 'sodium_mg'),
        potassium: _dbl(data, 'potassium_mg'),
        creatineMonohydrate: _dbl(data, 'creatine_monohydrate_g'),
        bcaa: _dbl(data, 'bcaa_g'),
        leucine: _dbl(data, 'leucine_g'),
        isoleucine: _dbl(data, 'isoleucine_g'),
        valine: _dbl(data, 'valine_g'),
        glutamine: _dbl(data, 'glutamine_g'),
        taurine: _dbl(data, 'taurine_g'),
        caffeine: _dbl(data, 'caffeine_mg'),
        vitaminC: _dbl(data, 'vitamin_c_mg'),
        vitaminD: _dbl(data, 'vitamin_d_ug'),
        calcium: _dbl(data, 'calcium_mg'),
        iron: _dbl(data, 'iron_mg'),
        magnesium: _dbl(data, 'magnesium_mg'),
        zinc: _dbl(data, 'zinc_mg'),
        ingredientText: _str(data, 'ingredients'),
        isSuccess: true,
      );

      LogService.info(
        'GeminiVision: parsed — '
        'cal=${result.calories} pro=${result.protein}g '
        'creatine=${result.creatineMonohydrate}g '
        'bcaa=${result.bcaa}g sodium=${result.sodium}mg',
      );

      return result;
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
