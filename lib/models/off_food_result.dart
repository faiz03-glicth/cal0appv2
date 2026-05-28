class OFFFoodResult {
  // ── Identity ───────────────────────────────────────────────────────────
  final String barcode; // empty string for search-only results
  final String name;
  final String brand;
  final String? imageUrl;
  final String? nutritionGrade; // a / b / c / d / e  (nova score from OFF)
  final String? ecoscoreGrade;

  // ── Serving ────────────────────────────────────────────────────────────
  final double servingSize; // grams; default 100 if unknown
  final String servingUnit;

  // ── Per-100g macro values ──────────────────────────────────────────────
  // Stored per 100g so we can scale to any serving size on the fly.
  final double caloriesPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final double fiberPer100;
  final double sugarPer100;
  final double saturatedFatPer100;
  final double transFatPer100;
  final double sodiumPer100; // mg
  final double potassiumPer100; // mg
  final double cholesterolPer100; // mg
  final double vitaminCPer100; // mg
  final double calciumPer100; // mg
  final double ironPer100; // mg

  // ── Metadata ───────────────────────────────────────────────────────────
  final String? ingredientsText;
  final bool isVerified; // true if nutriments block was present
  final double completeness; // 0.0 – 1.0
  final DateTime cachedAt;

  // ── Source tag ─────────────────────────────────────────────────────────
  final String source; // 'barcode' | 'search' | 'cache'

  const OFFFoodResult({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.imageUrl,
    this.nutritionGrade,
    this.ecoscoreGrade,
    this.servingSize = 100,
    this.servingUnit = 'g',
    this.caloriesPer100 = 0,
    this.proteinPer100 = 0,
    this.carbsPer100 = 0,
    this.fatPer100 = 0,
    this.fiberPer100 = 0,
    this.sugarPer100 = 0,
    this.saturatedFatPer100 = 0,
    this.transFatPer100 = 0,
    this.sodiumPer100 = 0,
    this.potassiumPer100 = 0,
    this.cholesterolPer100 = 0,
    this.vitaminCPer100 = 0,
    this.calciumPer100 = 0,
    this.ironPer100 = 0,
    this.ingredientsText,
    this.isVerified = false,
    this.completeness = 0,
    required this.cachedAt,
    this.source = 'search',
  });

  // ── Display helpers ────────────────────────────────────────────────────

  String get displayName => name.trim().isNotEmpty ? name : 'Unknown Product';
  String get displayBrand => brand.trim();
  bool get hasBrand => brand.trim().isNotEmpty;
  bool get hasNutrition => caloriesPer100 > 0 || proteinPer100 > 0;
  bool get isIncomplete => completeness < 0.5;
  bool get hasBarcode => barcode.isNotEmpty;

  // Grade colour helper (used by UI)
  String get gradeLabel {
    switch ((nutritionGrade ?? '').toUpperCase()) {
      case 'A':
        return 'A';
      case 'B':
        return 'B';
      case 'C':
        return 'C';
      case 'D':
        return 'D';
      case 'E':
        return 'E';
      default:
        return '?';
    }
  }

  // ── Scale nutrients to a given gram serving ───────────────────────────

  int caloriesForServing(double grams) =>
      (caloriesPer100 * grams / 100).round();
  double proteinForServing(double grams) => proteinPer100 * grams / 100;
  double carbsForServing(double grams) => carbsPer100 * grams / 100;
  double fatForServing(double grams) => fatPer100 * grams / 100;
  double fiberForServing(double grams) => fiberPer100 * grams / 100;
  double sugarForServing(double grams) => sugarPer100 * grams / 100;
  double saturatedFatForServing(double g) => saturatedFatPer100 * g / 100;
  double sodiumForServing(double grams) => sodiumPer100 * grams / 100;

  /// Returns a flat map that can be passed directly to FoodLogViewModel.selectFood()
  Map<String, dynamic> toFoodMap({double? servingGrams}) {
    final g = servingGrams ?? servingSize;
    return {
      'name': displayName,
      'calories': caloriesForServing(g),
      'protein': proteinForServing(g),
      'carbs': carbsForServing(g),
      'fat': fatForServing(g),
      'fiber': fiberForServing(g),
      'sugar': sugarForServing(g),
      'saturatedFat': saturatedFatForServing(g),
      'sodium': sodiumForServing(g),
      'servingSize': g,
      'servingUnit': servingUnit,
      'brand': brand,
      'barcode': barcode,
      'imageUrl': imageUrl ?? '',
      // pass raw per-100g so the VM can rescale later
      '_caloriesPer100': caloriesPer100,
      '_proteinPer100': proteinPer100,
      '_carbsPer100': carbsPer100,
      '_fatPer100': fatPer100,
      '_fiberPer100': fiberPer100,
      '_sugarPer100': sugarPer100,
      '_saturatedFatPer100': saturatedFatPer100,
      '_sodiumPer100': sodiumPer100,
    };
  }

  // ── Cache serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'brand': brand,
    'imageUrl': imageUrl,
    'nutritionGrade': nutritionGrade,
    'ecoscoreGrade': ecoscoreGrade,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'caloriesPer100': caloriesPer100,
    'proteinPer100': proteinPer100,
    'carbsPer100': carbsPer100,
    'fatPer100': fatPer100,
    'fiberPer100': fiberPer100,
    'sugarPer100': sugarPer100,
    'saturatedFatPer100': saturatedFatPer100,
    'transFatPer100': transFatPer100,
    'sodiumPer100': sodiumPer100,
    'potassiumPer100': potassiumPer100,
    'cholesterolPer100': cholesterolPer100,
    'vitaminCPer100': vitaminCPer100,
    'calciumPer100': calciumPer100,
    'ironPer100': ironPer100,
    'ingredientsText': ingredientsText,
    'isVerified': isVerified,
    'completeness': completeness,
    'cachedAt': cachedAt.toIso8601String(),
    'source': source,
  };

  factory OFFFoodResult.fromJson(Map<String, dynamic> j) => OFFFoodResult(
    barcode: j['barcode'] as String? ?? '',
    name: j['name'] as String? ?? '',
    brand: j['brand'] as String? ?? '',
    imageUrl: j['imageUrl'] as String?,
    nutritionGrade: j['nutritionGrade'] as String?,
    ecoscoreGrade: j['ecoscoreGrade'] as String?,
    servingSize: (j['servingSize'] as num?)?.toDouble() ?? 100,
    servingUnit: j['servingUnit'] as String? ?? 'g',
    caloriesPer100: (j['caloriesPer100'] as num?)?.toDouble() ?? 0,
    proteinPer100: (j['proteinPer100'] as num?)?.toDouble() ?? 0,
    carbsPer100: (j['carbsPer100'] as num?)?.toDouble() ?? 0,
    fatPer100: (j['fatPer100'] as num?)?.toDouble() ?? 0,
    fiberPer100: (j['fiberPer100'] as num?)?.toDouble() ?? 0,
    sugarPer100: (j['sugarPer100'] as num?)?.toDouble() ?? 0,
    saturatedFatPer100: (j['saturatedFatPer100'] as num?)?.toDouble() ?? 0,
    transFatPer100: (j['transFatPer100'] as num?)?.toDouble() ?? 0,
    sodiumPer100: (j['sodiumPer100'] as num?)?.toDouble() ?? 0,
    potassiumPer100: (j['potassiumPer100'] as num?)?.toDouble() ?? 0,
    cholesterolPer100: (j['cholesterolPer100'] as num?)?.toDouble() ?? 0,
    vitaminCPer100: (j['vitaminCPer100'] as num?)?.toDouble() ?? 0,
    calciumPer100: (j['calciumPer100'] as num?)?.toDouble() ?? 0,
    ironPer100: (j['ironPer100'] as num?)?.toDouble() ?? 0,
    ingredientsText: j['ingredientsText'] as String?,
    isVerified: j['isVerified'] as bool? ?? false,
    completeness: (j['completeness'] as num?)?.toDouble() ?? 0,
    cachedAt:
        DateTime.tryParse(j['cachedAt'] as String? ?? '') ?? DateTime.now(),
    source: j['source'] as String? ?? 'cache',
  );

  /// Build a placeholder "not found" entry for negative caching
  factory OFFFoodResult.notFound(String barcode) => OFFFoodResult(
    barcode: barcode,
    name: '',
    cachedAt: DateTime.now(),
    source: 'cache',
  );

  bool get isNotFoundPlaceholder => barcode.isNotEmpty && name.isEmpty;
}
