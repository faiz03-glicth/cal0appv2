import 'package:cal0appv2/services/logs/debuglog_services.dart';

// ── Result model ───────────────────────────────────────────────────────────

class CleanedOcrResult {
  final String fullText;
  final String ingredientSection;
  final String nutritionSection;
  final String productName;
  final Map<String, double> wordConfidence; // word → 0.0–1.0
  final double overallConfidence;
  final List<String> uncertainTokens;
  final bool hasIngredients;
  final bool hasNutrition;

  const CleanedOcrResult({
    required this.fullText,
    required this.ingredientSection,
    required this.nutritionSection,
    required this.productName,
    required this.wordConfidence,
    required this.overallConfidence,
    required this.uncertainTokens,
    required this.hasIngredients,
    required this.hasNutrition,
  });

  static const empty = CleanedOcrResult(
    fullText: '',
    ingredientSection: '',
    nutritionSection: '',
    productName: '',
    wordConfidence: {},
    overallConfidence: 0.0,
    uncertainTokens: [],
    hasIngredients: false,
    hasNutrition: false,
  );
}

// ── Service ────────────────────────────────────────────────────────────────

class OcrTextCleanerService {
  // ── Section headers ────────────────────────────────────────────────────

  static const _ingredientHeaders = [
    // English
    'ingredients:', 'ingredients', 'ingred.', 'ingredient list',
    'contains:', 'composition:', 'other ingredients:', 'other ingredients',
    'active ingredients:', 'inactive ingredients:',
    'formula:', 'formulation:', 'blend:', 'proprietary blend',
    'supplement blend', 'protein blend', 'amino acid blend',
    'matrix:', 'complex:', 'contains the following',
    // Malay
    'kandungan:', 'bahan-bahan:', 'bahan:',
    'ramuan:', 'komposisi:', 'mengandungi:',
  ];

  static const _nutritionHeaders = [
    'nutrition facts',
    'supplement facts',
    'nutritional information',
    'nutrition information',
    'maklumat nutrisi',
    'nilai nutrisi',
    'nutrition per',
    'per serving',
    'per 100g',
    'per 100 g',
    'amount per serving',
    'servings per container',
  ];

  // ── Stop-words for product name detection ─────────────────────────────

  static const _nameStopWords = {
    'nutrition',
    'supplement',
    'facts',
    'ingredients',
    'contains',
    'serving',
    'amount',
    'calories',
    'total',
    'protein',
    'carbohydrate',
    'carbohydrates',
    'fat',
    'sodium',
    'sugar',
    'fiber',
    'vitamin',
    'mineral',
    'riboflavin',
    'niacin',
    'thiamine',
  };

  // ── Known food ingredient vocabulary (for confidence boosting) ─────────

  static const _knownTerms = {
    // Proteins
    'whey', 'casein', 'hydrolyzed', 'isolate', 'concentrate', 'protein',
    'egg', 'albumin', 'collagen', 'gelatin', 'soy', 'pea', 'rice',
    // Carbs / sugars
    'maltodextrin', 'dextrose', 'glucose', 'fructose', 'sucrose',
    'lactose', 'galactose', 'trehalose', 'palatinose',
    // Sweeteners
    'sucralose', 'aspartame', 'acesulfame', 'stevia', 'xylitol',
    'sorbitol', 'erythritol', 'monk', 'thaumatin',
    // Amino acids
    'leucine', 'isoleucine', 'valine', 'glycine', 'taurine', 'creatine',
    'arginine', 'glutamine', 'lysine', 'methionine', 'threonine',
    'tryptophan', 'phenylalanine', 'histidine', 'alanine', 'proline',
    // Additives / emulsifiers
    'lecithin', 'sunflower', 'soy lecithin', 'carrageenan', 'xanthan',
    'guar', 'locust', 'pectin', 'agar', 'cellulose', 'inulin',
    'carboxymethylcellulose',
    // Vitamins / minerals
    'niacin', 'riboflavin', 'thiamine', 'folate', 'biotin', 'pantothenate',
    'pyridoxine', 'cyanocobalamin', 'ascorbic', 'tocopherol',
    'calcium', 'sodium', 'potassium', 'magnesium', 'zinc', 'iron',
    'phosphorus', 'chromium', 'selenium', 'manganese',
    // Fats / oils
    'palm', 'canola', 'olive', 'coconut', 'flaxseed', 'mct', 'omega',
    // Common food terms
    'salt', 'sugar', 'water', 'oil', 'starch', 'flour', 'extract',
    'natural', 'artificial', 'flavour', 'flavor', 'color', 'colour',
    'milk', 'wheat', 'gluten', 'cocoa', 'vanilla', 'chocolate',
    'strawberry', 'banana', 'preservative', 'antioxidant',
  };

  // ── Entry point ────────────────────────────────────────────────────────

  CleanedOcrResult clean(List<String> rawLines) {
    if (rawLines.isEmpty) return CleanedOcrResult.empty;
    LogService.info('OcrCleaner: ${rawLines.length} raw lines');

    // Stage 1: character-level cleanup
    final cleaned = rawLines
        .map(_cleanLine)
        .where((l) => l.isNotEmpty)
        .toList();

    // Stage 2: merge fragmented ingredient continuation lines
    final merged = _mergeFragmentedLines(cleaned);

    // Stage 3: extract sections
    final ingredients = _extractSection(merged, _ingredientHeaders);
    final nutrition = _extractSection(merged, _nutritionHeaders);

    // Stage 4: product name
    final productName = _detectProductName(merged);

    // Stage 5: word confidence
    final allText = merged.join('\n');
    final wordConf = _scoreWords(allText);
    final uncertain = wordConf.entries
        .where((e) => e.value < 0.50)
        .map((e) => e.key)
        .toList();

    // Stage 6: overall confidence
    final overall = _computeOverall(wordConf, ingredients, nutrition);

    LogService.info(
      'OcrCleaner: conf=${overall.toStringAsFixed(2)} '
      'hasIngr=${ingredients.isNotEmpty} hasNutr=${nutrition.isNotEmpty}',
    );

    return CleanedOcrResult(
      fullText: allText,
      ingredientSection: ingredients,
      nutritionSection: nutrition,
      productName: productName,
      wordConfidence: wordConf,
      overallConfidence: overall,
      uncertainTokens: uncertain,
      hasIngredients: ingredients.isNotEmpty,
      hasNutrition: nutrition.isNotEmpty,
    );
  }

  // ── Stage 1: character cleanup ─────────────────────────────────────────

  String _cleanLine(String line) {
    var s = line.trim();
    if (s.isEmpty) return '';

    // Drop lines that are basically noise (< 3 meaningful chars)
    final meaningful = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (meaningful.length < 2) return '';

    s = s
        .replaceAll('|', 'I')
        .replaceAll('¢', 'c')
        .replaceAll('©', 'o')
        .replaceAll('®', '')
        .replaceAll('™', '')
        .replaceAll('\u2019', "'")
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll(RegExp(r'\.{3,}'), '...')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Fix digit ↔ letter substitutions in numeric contexts
    // e.g.  "l00g" → "100g",  "5Og" → "50g"
    s = s.replaceAllMapped(RegExp(r'(?<=[0-9])[OoIl]|[OoIl](?=[0-9])'), (m) {
      switch (m.group(0)) {
        case 'O':
        case 'o':
          return '0';
        case 'I':
        case 'l':
          return '1';
        default:
          return m.group(0)!;
      }
    });

    return s;
  }

  // ── Stage 2: line merging ──────────────────────────────────────────────

  List<String> _mergeFragmentedLines(List<String> lines) {
    final result = <String>[];
    String buffer = '';

    for (final line in lines) {
      if (buffer.isEmpty) {
        buffer = line;
        continue;
      }

      final prevEndsOpen = !RegExp(r'[.!?]$').hasMatch(buffer);
      final nextStartsLower = RegExp(r'^[a-z(]').hasMatch(line);
      final nextIsComma = line.startsWith(',');
      final prevIsShort = buffer.length < 55;

      if ((prevEndsOpen && nextStartsLower) ||
          nextIsComma ||
          (prevIsShort && nextStartsLower)) {
        buffer = '$buffer $line';
      } else {
        result.add(buffer);
        buffer = line;
      }
    }
    if (buffer.isNotEmpty) result.add(buffer);
    return result;
  }

  // ── Stage 3: section extraction ────────────────────────────────────────

  String _extractSection(List<String> lines, List<String> headers) {
    final lower = lines.map((l) => l.toLowerCase()).toList();
    int start = -1;

    for (int i = 0; i < lower.length; i++) {
      for (final h in headers) {
        if (lower[i].contains(h)) {
          start = i;
          break;
        }
      }
      if (start >= 0) break;
    }
    if (start < 0) return '';

    // Find end (next major section header)
    int end = lines.length;
    final allHeaders = [..._ingredientHeaders, ..._nutritionHeaders];
    for (int i = start + 1; i < lower.length; i++) {
      for (final h in allHeaders) {
        if (lower[i].contains(h) && i > start + 1) {
          end = i;
          break;
        }
      }
      if (end < lines.length) break;
    }

    return lines.sublist(start, end).take(35).join('\n').trim();
  }

  // ── Stage 4: product name detection ───────────────────────────────────

  String _detectProductName(List<String> lines) {
    for (final line in lines.take(8)) {
      final lower = line.toLowerCase();
      if (_ingredientHeaders.any((h) => lower.contains(h))) continue;
      if (_nutritionHeaders.any((h) => lower.contains(h))) continue;
      if (line.length < 4) continue;
      if (RegExp(r'^[\d\s.%gcal]+$', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final words = lower.split(RegExp(r'\s+')).toSet();
      final stopOverlap = words.intersection(_nameStopWords).length;
      if (stopOverlap > words.length * 0.5) continue;
      return line.trim();
    }
    return '';
  }

  // ── Stage 5: word confidence scoring ──────────────────────────────────

  Map<String, double> _scoreWords(String text) {
    final result = <String, double>{};
    final words = text.split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.length < 2) continue;
      final clean = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      if (clean.isEmpty) continue;

      double score = 0.50; // baseline

      if (_knownTerms.contains(clean)) score += 0.35;
      if (RegExp(r'^[a-zA-Z]+$').hasMatch(word)) score += 0.10;

      // Penalty for unusual mixed case (e.g. pR0tE1n)
      final alphas = word.runes
          .where((c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122))
          .length;
      final uppers = word.runes.where((c) => c >= 65 && c <= 90).length;
      if (alphas > 3) {
        final ur = uppers / alphas;
        if (ur > 0.0 && ur < 1.0 && (ur - 0.5).abs() > 0.2) {
          score -= 0.15;
        }
      }

      if (clean.length <= 2) score -= 0.10;

      result[word] = score.clamp(0.0, 1.0);
    }
    return result;
  }

  // ── Stage 6: overall confidence ───────────────────────────────────────

  double _computeOverall(
    Map<String, double> wc,
    String ingredients,
    String nutrition,
  ) {
    if (wc.isEmpty) return 0.0;
    final avg = wc.values.fold(0.0, (a, b) => a + b) / wc.length;
    double bonus = 0.0;
    if (ingredients.isNotEmpty) bonus += 0.15;
    if (nutrition.isNotEmpty) bonus += 0.10;
    return (avg + bonus).clamp(0.0, 1.0);
  }
}
