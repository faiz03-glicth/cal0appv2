import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class NutritionExtractorService {
  // ── Supplement keyword detection ──────────────────────────────────────────
  static const _supplementKeywords = [
    'whey',
    'protein',
    'isolate',
    'concentrate',
    'hydrolyzed',
    'mass gainer',
    'creatine',
    'bcaa',
    'amino',
    'pre-workout',
    'pre workout',
    'casein',
    'collagen',
    'serving size',
    'servings per',
    'supplement facts',
    'nutrition facts',
  ];

  ScanResultModel extract(List<String> ocrLines) {
    final fullText = ocrLines.join('\n');
    final lower = fullText.toLowerCase();

    LogService.info('NutritionExtractor: processing ${ocrLines.length} lines');

    // Detect if this is a supplement/nutrition label
    final isSupplementDetected = _supplementKeywords.any(
      (kw) => lower.contains(kw),
    );

    // Extract each field
    final productName = _extractProductName(ocrLines, lower);
    final serving = _extractServing(fullText, lower);
    final calories = _extractCalories(fullText, lower);
    final protein = _extractMacro(fullText, lower, _proteinPatterns);
    final carbs = _extractMacro(fullText, lower, _carbPatterns);
    final fat = _extractMacro(fullText, lower, _fatPatterns);
    final sugar = _extractMacro(fullText, lower, _sugarPatterns);
    final sodium = _extractMacro(fullText, lower, _sodiumPatterns);
    final ingredients = _extractIngredients(fullText, lower);

    // Confidence: how many fields did we successfully extract?
    final fieldsFound = [
      calories > 0,
      protein > 0,
      carbs > 0,
      fat > 0,
      productName.isNotEmpty,
      serving.$1 != null,
    ].where((f) => f).length;
    final confidence = fieldsFound / 6.0;

    final result = ScanResultModel(
      productName: productName,
      servingSize: serving.$1,
      servingUnit: serving.$2,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      sodium: sodium,
      ingredientText: ingredients,
      isSupplementDetected: isSupplementDetected,
      extractionConfidence: confidence,
    );

    LogService.info(
      'NutritionExtractor: confidence=${confidence.toStringAsFixed(2)} '
      'kcal=$calories pro=${protein}g carbs=${carbs}g fat=${fat}g '
      'supplement=$isSupplementDetected',
    );

    return result;
  }

  // ── Product name ──────────────────────────────────────────────────────────

  String _extractProductName(List<String> lines, String lower) {
    // Strategy 1: line before "supplement facts" or "nutrition facts"
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l.contains('supplement facts') || l.contains('nutrition facts')) {
        if (i > 0 && lines[i - 1].trim().length > 3) {
          return lines[i - 1].trim();
        }
      }
    }

    // Strategy 2: known supplement brand keywords on a line
    final brandPattern = RegExp(
      r'(optimum nutrition|dymatize|musclepharm|bsn|myprotein|'
      r'gold standard|iso100|serious mass|nitrotech|'
      r'whey protein|mass gainer|pre.?workout)',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (brandPattern.hasMatch(line)) return line.trim();
    }

    // Strategy 3: first non-empty line that isn't a number
    for (final line in lines) {
      final t = line.trim();
      if (t.length > 5 && !RegExp(r'^\d').hasMatch(t)) return t;
    }

    return '';
  }

  // ── Serving size ──────────────────────────────────────────────────────────

  (double?, String) _extractServing(String text, String lower) {
    // e.g. "Serving Size: 32g", "Serving Size 1 scoop (32g)", "30.4 g"
    final patterns = [
      RegExp(
        r'serving\s*size[:\s]+(\d+\.?\d*)\s*(g|ml|oz|scoop|tbsp|tsp)',
        caseSensitive: false,
      ),
      RegExp(r'(\d+\.?\d*)\s*(g|ml|oz)\s*per\s*serving', caseSensitive: false),
      RegExp(r'serving[:\s]+(\d+\.?\d*)\s*(g|ml)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        return (double.tryParse(m.group(1)!), m.group(2) ?? 'g');
      }
    }
    return (null, 'g');
  }

  // ── Calories ──────────────────────────────────────────────────────────────

  int _extractCalories(String text, String lower) {
    final patterns = [
      // "Calories 120", "Calories: 120", "Cal 120"
      RegExp(r'calories?[:\s]+(\d+)', caseSensitive: false),
      // "Energy 502kJ / 120kcal"
      RegExp(r'(\d+)\s*kcal', caseSensitive: false),
      // "120 Cal" standalone
      RegExp(r'^(\d{2,4})\s*cal', caseSensitive: false, multiLine: true),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final val = int.tryParse(m.group(1)!);
        if (val != null && val > 0 && val < 5000) return val;
      }
    }
    return 0;
  }

  // ── Generic macro extractor ───────────────────────────────────────────────

  double _extractMacro(String text, String lower, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final val = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        if (val != null && val >= 0 && val < 1000) return val;
      }
    }
    return 0.0;
  }

  // ── Pattern lists per macro ───────────────────────────────────────────────

  final _proteinPatterns = [
    RegExp(r'protein[:\s]+(\d+\.?\d*)\s*g', caseSensitive: false),
    RegExp(r'(\d+\.?\d*)\s*g\s*protein', caseSensitive: false),
    RegExp(r'pro(?:tein)?[.:\s]+(\d+\.?\d*)', caseSensitive: false),
  ];

  final _carbPatterns = [
    RegExp(
      r'(?:total\s*)?carbohydrate[s]?[:\s]+(\d+\.?\d*)\s*g',
      caseSensitive: false,
    ),
    RegExp(r'carbs?[:\s]+(\d+\.?\d*)\s*g', caseSensitive: false),
    RegExp(r'(\d+\.?\d*)\s*g\s*carb', caseSensitive: false),
  ];

  final _fatPatterns = [
    RegExp(r'(?:total\s*)?fat[:\s]+(\d+\.?\d*)\s*g', caseSensitive: false),
    RegExp(r'(\d+\.?\d*)\s*g\s*fat', caseSensitive: false),
    RegExp(r'lipid[s]?[:\s]+(\d+\.?\d*)', caseSensitive: false),
  ];

  final _sugarPatterns = [
    RegExp(r'sugar[s]?[:\s]+(\d+\.?\d*)\s*g', caseSensitive: false),
    RegExp(r'(\d+\.?\d*)\s*g\s*sugar', caseSensitive: false),
  ];

  final _sodiumPatterns = [
    RegExp(r'sodium[:\s]+(\d+\.?\d*)\s*mg', caseSensitive: false),
    RegExp(r'(\d+\.?\d*)\s*mg\s*sodium', caseSensitive: false),
    RegExp(r'salt[:\s]+(\d+\.?\d*)', caseSensitive: false),
  ];

  // ── Ingredient section ────────────────────────────────────────────────────

  String _extractIngredients(String text, String lower) {
    for (final keyword in ['ingredients:', 'ingredients', 'contains:']) {
      final idx = lower.indexOf(keyword);
      if (idx != -1) {
        final slice = text.substring(idx, (idx + 400).clamp(0, text.length));
        return slice.trim();
      }
    }
    return '';
  }
}
