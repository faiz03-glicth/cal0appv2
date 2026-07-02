import 'package:cal0appv2/models/scan_result_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class NutritionExtractorService {
  // ── Supplement detection keywords ─────────────────────────────────────────

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

  // ── Main entry point ──────────────────────────────────────────────────────

  ScanResultModel extract(List<String> ocrLines) {
    LogService.info('NutritionExtractor: ${ocrLines.length} raw lines');

    // Step 1: normalise raw OCR → clean lines
    final cleanLines = _normaliseOcrText(ocrLines);
    final fullText = cleanLines.join('\n');
    final lower = fullText.toLowerCase();

    LogService.info('NutritionExtractor: ${cleanLines.length} clean lines');

    final isSupplementDetected = _supplementKeywords.any(
      (kw) => lower.contains(kw),
    );

    // Step 2: extract each field from the normalised text
    final productName = _extractProductName(cleanLines, lower);
    final brandName = _extractBrandName(cleanLines, lower);
    final serving = _extractServing(fullText);
    final servingsPer = _extractServingsPerContainer(fullText);
    final calories = _extractCalories(fullText);
    final protein = _extractNutrient(fullText, _proteinPat, maxVal: 200);
    final carbs = _extractNutrient(fullText, _carbPat, maxVal: 500);
    final fat = _extractNutrient(fullText, _fatPat, maxVal: 200);
    final sugar = _extractNutrient(fullText, _sugarPat, maxVal: 200);
    final fiber = _extractNutrient(fullText, _fiberPat, maxVal: 100);
    final satFat = _extractNutrient(fullText, _satFatPat, maxVal: 100);
    final transFat = _extractNutrient(fullText, _transFatPat, maxVal: 50);
    final unsatFat = _extractNutrient(fullText, _unsatFatPat, maxVal: 100);
    final cholesterol = _extractNutrient(fullText, _cholPat, maxVal: 1000);
    final sodium = _extractNutrient(fullText, _sodiumPat, maxVal: 5000);
    final potassium = _extractNutrient(fullText, _potassiumPat, maxVal: 5000);
    final creatine = _extractNutrient(fullText, _creatinePat, maxVal: 20);
    final bcaa = _extractNutrient(fullText, _bcaaPat, maxVal: 30);
    final leucine = _extractNutrient(fullText, _leucinePat, maxVal: 20);
    final isoleucine = _extractNutrient(fullText, _isoleucinePat, maxVal: 20);
    final valine = _extractNutrient(fullText, _valinePat, maxVal: 20);
    final glutamine = _extractNutrient(fullText, _glutaminePat, maxVal: 20);
    final taurine = _extractNutrient(fullText, _taurinePat, maxVal: 10);
    final caffeine = _extractNutrient(fullText, _caffeinePat, maxVal: 500);
    final vitaminC = _extractNutrient(fullText, _vitCPat, maxVal: 2000);
    final vitaminD = _extractNutrient(fullText, _vitDPat, maxVal: 100);
    final calcium = _extractNutrient(fullText, _calciumPat, maxVal: 2000);
    final iron = _extractNutrient(fullText, _ironPat, maxVal: 100);
    final magnesium = _extractNutrient(fullText, _magnPat, maxVal: 1000);
    final zinc = _extractNutrient(fullText, _zincPat, maxVal: 100);
    final ingredients = _extractIngredients(fullText, lower);

    // Step 3: confidence score based on how many core fields were found
    final coreFound = [
      calories > 0,
      protein > 0,
      carbs > 0,
      fat > 0,
      productName.isNotEmpty,
      serving.$1 != null,
    ].where((f) => f).length;
    final confidence = coreFound / 6.0;

    final result = ScanResultModel(
      productName: productName,
      brandName: brandName,
      servingSize: serving.$1,
      servingUnit: serving.$2,
      servingsPerContainer: servingsPer,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      fiber: fiber,
      saturatedFat: satFat,
      transFat: transFat,
      unsaturatedFat: unsatFat,
      cholesterol: cholesterol,
      sodium: sodium,
      potassium: potassium,
      creatineMonohydrate: creatine,
      bcaa: bcaa,
      leucine: leucine,
      isoleucine: isoleucine,
      valine: valine,
      glutamine: glutamine,
      taurine: taurine,
      caffeine: caffeine,
      vitaminC: vitaminC,
      vitaminD: vitaminD,
      calcium: calcium,
      iron: iron,
      magnesium: magnesium,
      zinc: zinc,
      ingredientText: ingredients,
      isSupplementDetected: isSupplementDetected,
      extractionConfidence: confidence,
    );

    LogService.info(
      'NutritionExtractor: confidence=${confidence.toStringAsFixed(2)} '
      'cal=$calories pro=${protein}g creatine=${creatine}g '
      'bcaa=${bcaa}g sodium=${sodium}mg optFields=${result.filledOptionalFields}',
    );

    return result;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // JARGON NORMALISER
  // This is the key piece that turns messy OCR output into parseable text.
  // ────────────────────────────────────────────────────────────────────────────

  List<String> _normaliseOcrText(List<String> rawLines) {
    if (rawLines.isEmpty) return [];

    // Pass 1: character-level cleanup per line
    final cleaned = rawLines
        .map(_cleanLine)
        .where((l) => l.isNotEmpty)
        .toList();

    // Pass 2: merge continuation lines
    // A "continuation" is a short line that starts lowercase or with a comma,
    // OR a known supplement name fragment that was split across lines
    // e.g. "Creatine" + "Monohydrate" → "Creatine Monohydrate"
    final merged = _mergeFragments(cleaned);

    // Pass 3: strip kJ parentheticals AFTER merging
    return merged
        .map(
          (l) => l.replaceAll(
            RegExp(r'\(\d+\.?\d*\s*kj\)', caseSensitive: false),
            '',
          ),
        )
        .toList();
  }

  String _cleanLine(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    // Drop lines that are pure noise (< 2 meaningful chars)
    final meaningful = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (meaningful.length < 2) return '';

    // Remove decorative chars
    s = s
        .replaceAll('®', '')
        .replaceAll('™', '')
        .replaceAll('©', '')
        .replaceAll('|', 'I')
        .replaceAll('¢', 'c')
        .replaceAll('\u2019', "'")
        .replaceAll('\u2022', '') // bullet
        .replaceAll('\u00b7', '') // middle dot
        .replaceAll(RegExp(r'\.{3,}'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Fix common OCR digit/letter swaps ONLY in numeric context
    // e.g. "l00g" → "100g", "5Og" → "50g", "O.5g" → "0.5g"
    s = s.replaceAllMapped(
      RegExp(r'(?<=[0-9])[OoIl](?=[0-9g\s])|(?<=[^a-zA-Z])[OoIl](?=[0-9])'),
      (m) {
        final c = m.group(0)!;
        return (c == 'O' || c == 'o') ? '0' : '1';
      },
    );

    return s;
  }

  List<String> _mergeFragments(List<String> lines) {
    // Known multi-word supplement names that OCR commonly splits
    const splitKeywords = [
      'monohydrate',
      'hydrochloride',
      'phosphate',
      'citrate',
      'malate',
      'complex',
      'blend',
      'matrix',
      'concentrate',
      'isolate',
      'hydrolyzed',
      'extract',
      'peptides',
    ];

    final result = <String>[];
    String buffer = '';

    for (final line in lines) {
      final lower = line.toLowerCase().trim();

      if (buffer.isEmpty) {
        buffer = line;
        continue;
      }

      final prevLower = buffer.toLowerCase();
      final prevShort = buffer.trim().length < 30;

      // Merge if this line is a known continuation fragment
      final isContinuation = splitKeywords.any((kw) => lower.startsWith(kw));

      // Merge if previous line ends without punctuation and this starts lowercase
      final prevOpenEnded = !RegExp(r'[.!?:\d]$').hasMatch(buffer.trim());
      final startsLower = RegExp(r'^[a-z(,]').hasMatch(line);

      // Merge if previous line is a pure nutrient name (no number yet)
      // and this line is the number
      final prevIsNutrientName = RegExp(
        r'^(protein|carb|fat|sugar|fiber|sodium|potassium|calcium|iron|'
        r'magnesium|zinc|creatine|leucine|isoleucine|valine|glutamine|'
        r'taurine|bcaa|caffeine|vitamin|cholesterol)$',
        caseSensitive: false,
      ).hasMatch(buffer.trim());
      final thisIsNumber = RegExp(r'^[\d.]+').hasMatch(line.trim());

      if (isContinuation ||
          (prevShort && isContinuation) ||
          (prevOpenEnded && startsLower) ||
          (prevIsNutrientName && thisIsNumber)) {
        buffer = '${buffer.trim()} ${line.trim()}';
      } else {
        result.add(buffer);
        buffer = line;
      }
    }
    if (buffer.isNotEmpty) result.add(buffer);
    return result;
  }

  // ── Product name ──────────────────────────────────────────────────────────

  String _extractProductName(List<String> lines, String lower) {
    // Strategy 1: line before "supplement facts" / "nutrition facts"
    for (int i = 1; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l.contains('supplement facts') || l.contains('nutrition facts')) {
        final prev = lines[i - 1].trim();
        if (prev.length > 3 && !RegExp(r'^\d').hasMatch(prev)) return prev;
      }
    }
    // Strategy 2: known brand patterns
    final brandPat = RegExp(
      r'(optimum nutrition|dymatize|musclepharm|bsn|myprotein|'
      r'gold standard|iso100|serious mass|nitrotech|muscletech|'
      r"gnc|nature's best|allmax|rule1|on gold)",
      caseSensitive: false,
    );
    for (final line in lines) {
      if (brandPat.hasMatch(line)) return line.trim();
    }
    // Strategy 3: first meaningful non-numeric line
    for (final line in lines) {
      final t = line.trim();
      if (t.length > 5 &&
          !RegExp(r'^\d').hasMatch(t) &&
          !t.toLowerCase().contains('serving') &&
          !t.toLowerCase().contains('facts')) {
        return t;
      }
    }
    return '';
  }

  String _extractBrandName(List<String> lines, String lower) {
    final brandPat = RegExp(
      r'(optimum nutrition|dymatize|musclepharm|bsn|myprotein|'
      r'gold standard|muscletech|gnc|allmax|rule1)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = brandPat.firstMatch(line);
      if (m != null) return m.group(0)!.trim();
    }
    return '';
  }

  // ── Serving size ──────────────────────────────────────────────────────────

  (double?, String) _extractServing(String text) {
    final patterns = [
      RegExp(
        r'serving\s*size[:\s]+(\d+\.?\d*)\s*(g|ml|oz|scoop|tbsp|tsp)',
        caseSensitive: false,
      ),
      RegExp(r'(\d+\.?\d*)\s*(g|ml|oz)\s*/?\s*serving', caseSensitive: false),
      RegExp(
        r'(?:1\s*scoop\s*)?[\(\[](\d+\.?\d*)\s*(g|ml)[\)\]]',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v > 0 && v < 2000) {
          return (v, m.group(2)?.toLowerCase() ?? 'g');
        }
      }
    }
    return (null, 'g');
  }

  int? _extractServingsPerContainer(String text) {
    final m = RegExp(
      r'servings?\s*per\s*(?:container|tub|bag)[:\s]+(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  // ── Calories ──────────────────────────────────────────────────────────────

  int _extractCalories(String text) {
    // Strip kJ blocks first so "Energy 502kJ / 120kcal" works
    final clean = text.replaceAll(
      RegExp(r'\d+\.?\d*\s*kj\s*/?\s*', caseSensitive: false),
      '',
    );
    final patterns = [
      RegExp(r'calories?[:\s]+(\d{2,4})', caseSensitive: false),
      RegExp(r'energy[:\s]+(\d{2,4})\s*kcal', caseSensitive: false),
      RegExp(r'(\d{2,4})\s*kcal', caseSensitive: false),
      RegExp(r'^(\d{2,4})\s*cal\b', caseSensitive: false, multiLine: true),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(clean);
      if (m != null) {
        final v = int.tryParse(m.group(1)!);
        if (v != null && v > 0 && v < 5000) return v;
      }
    }
    return 0;
  }

  // ── Generic nutrient extractor ────────────────────────────────────────────
  // Grabs the FIRST number after the matched keyword — handles two-column
  // tables where OCR gives "Protein 25g 83g" (per-serving always first).

  double _extractNutrient(String text, RegExp pattern, {double maxVal = 1000}) {
    final m = pattern.firstMatch(text);
    if (m == null) return 0.0;
    final raw = m.group(1)!.replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v < 0 || v > maxVal) return 0.0;
    return v;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NUTRIENT PATTERNS
  //
  // Design rule: keyword → optional separator (: . space) → optional unit
  //              → FIRST number (the per-serving value)
  //
  // \D{0,30} = up to 30 non-digit chars (allows "Total Carbohydrate  9.0 g")
  // dotAll:true = matches across line breaks (handles OCR split lines)
  // ────────────────────────────────────────────────────────────────────────────

  // Core macros
  static final _proteinPat = RegExp(
    r'(?:^|\n)[^\n]*protein[^\n\d]{0,20}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: false,
    multiLine: true,
  );
  static final _carbPat = RegExp(
    r'(?:total\s*)?carbohydrate[s]?\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _fatPat = RegExp(
    r'total\s*fat\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sugarPat = RegExp(
    r'(?:total\s*)?sugar[s]?\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _fiberPat = RegExp(
    r'(?:dietary\s*)?fi(?:bre|ber)\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _satFatPat = RegExp(
    r'saturated\s*fat\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _transFatPat = RegExp(
    r'trans\s*fat\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _unsatFatPat = RegExp(
    r'(?:mono)?unsaturated\s*fat\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _cholPat = RegExp(
    r'cholesterol\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sodiumPat = RegExp(
    r'sodium\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _potassiumPat = RegExp(
    r'potassium\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // Supplement-specific rows
  // Creatine is the main one users were missing — the compound name spans
  // two words so OCR often splits it; the normaliser merges it, then this
  // pattern catches "Creatine Monohydrate 3g" in any variant.
  static final _creatinePat = RegExp(
    r'creatine(?:\s+monohydrate|\s+hcl|\s+ethyl)?\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _bcaaPat = RegExp(
    r'(?:bcaa|branched[\s\-]chain\s+amino)\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _leucinePat = RegExp(
    r'l?-?leucine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _isoleucinePat = RegExp(
    r'l?-?isoleucine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _valinePat = RegExp(
    r'l?-?valine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _glutaminePat = RegExp(
    r'l?-?glutamine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _taurinePat = RegExp(
    r'taurine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _caffeinePat = RegExp(
    r'caffeine\D{0,10}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // Vitamins & minerals
  static final _vitCPat = RegExp(
    r'vitamin\s*c\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _vitDPat = RegExp(
    r'vitamin\s*d[23]?\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _calciumPat = RegExp(
    r'calcium\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _ironPat = RegExp(
    r'\biron\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _magnPat = RegExp(
    r'magnesium\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _zincPat = RegExp(
    r'\bzinc\D{0,15}(\d+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // ── Ingredient section ────────────────────────────────────────────────────

  String _extractIngredients(String text, String lower) {
    final keywords = [
      'ingredients:',
      'ingredients',
      'contains:',
      'kandungan:',
      'bahan:',
    ];
    for (final kw in keywords) {
      final idx = lower.indexOf(kw);
      if (idx != -1) {
        final slice = text.substring(idx, (idx + 600).clamp(0, text.length));
        return slice.trim();
      }
    }
    return '';
  }
}
