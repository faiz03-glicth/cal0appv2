import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class OFFService {
  static bool _configured = false;

  static void _configure() {
    if (_configured) return;
    // ← Remove 'const' — UserAgent is NOT a const constructor
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'C0App',
      version: '1.0.0',
      url: 'https://github.com/faiz03-glitch/cal0appv2',
    );
    OpenFoodAPIConfiguration.globalLanguages = [
      OpenFoodFactsLanguage.ENGLISH,
      OpenFoodFactsLanguage.MALAY,
    ];
    OpenFoodAPIConfiguration.globalCountry = OpenFoodFactsCountry.MALAYSIA;
    _configured = true;
  }

  OFFService() {
    _configure();
  }

  static final List<ProductField> _fields = [
    ProductField.BARCODE,
    ProductField.NAME,
    ProductField.NAME_IN_LANGUAGES,
    ProductField.BRANDS,
    ProductField.NUTRIMENTS,
    ProductField.NUTRIMENT_ENERGY_UNIT,
    ProductField.SERVING_SIZE,
    ProductField.SERVING_QUANTITY,
    ProductField.INGREDIENTS_TEXT,
    ProductField.IMAGE_FRONT_URL,
    // ProductField.NUTRISCORE_DATA,
    ProductField.ECOSCORE_GRADE,
    // ProductField.COMPLETENESS,
  ];

  // ── BARCODE LOOKUP ──────────────────────────────────────────────────────

  Future<OFFFoodResult?> lookupBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    LogService.info('OFFService: barcode lookup $barcode');

    try {
      final config = ProductQueryConfiguration(
        barcode,
        version: ProductQueryVersion.v3,
        fields: _fields,
      );
      final result = await OpenFoodAPIClient.getProductV3(
        config,
      ).timeout(const Duration(seconds: 12));

      if (result.status == ProductResultV3.statusSuccess &&
          result.product != null) {
        final mapped = _mapProduct(result.product!, source: 'barcode');
        LogService.info(
          'OFFService: barcode hit — "${mapped.displayName}" '
          '(completeness ${(mapped.completeness * 100).toStringAsFixed(0)}%)',
        );
        return mapped;
      }
      LogService.info('OFFService: barcode not found — $barcode');
      return null;
    } catch (e) {
      LogService.error('OFFService.lookupBarcode', e);
      return null;
    }
  }

  // ── TEXT SEARCH ─────────────────────────────────────────────────────────

  static const String _searchBase = 'https://search.openfoodfacts.org/search';

  static const String _searchFields =
      'code,product_name,product_name_en,product_name_ms,'
      'brands,nutriments,serving_size,serving_quantity,'
      'image_front_url,nutriscore_grade,completeness,'
      'ingredients_text,ingredients_text_en';

  Future<List<OFFFoodResult>> searchFood(
    String query, {
    int pageSize = 24,
    int page = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    LogService.info('OFFService: search "$q" page=$page');

    try {
      final uri = Uri.parse(_searchBase).replace(
        queryParameters: {
          'q': q,
          'fields': _searchFields,
          'json': '1',
          'page_size': '$pageSize',
          'page': '$page',
          'lc': 'ms,en',
          'cc': 'my',
        },
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'C0App/1.0'})
          .timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        LogService.error('OFFService.searchFood: HTTP ${response.statusCode}');
        return [];
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final hits = body['hits'] as List<dynamic>? ?? [];

      final results = hits
          .whereType<Map<String, dynamic>>()
          .map(_mapSearchHit)
          .where((r) => r.name.isNotEmpty)
          .toList();

      LogService.info('OFFService: search returned ${results.length} results');
      return results;
    } catch (e) {
      LogService.error('OFFService.searchFood', e);
      return [];
    }
  }

  // ── MAP Product → OFFFoodResult ────────────────────────────────────────

  OFFFoodResult _mapProduct(Product p, {String source = 'search'}) {
    final n = p.nutriments;

    return OFFFoodResult(
      barcode: p.barcode ?? '',
      name: _productName(p),
      brand: p.brands ?? '',
      imageUrl: p.imageFrontUrl,
      nutritionGrade: p.nutriscore,
      servingSize: p.servingQuantity ?? 100,
      servingUnit: 'g',
      caloriesPer100: _kcalPer100(n),
      proteinPer100: _n100(n, Nutrient.proteins),
      carbsPer100: _n100(n, Nutrient.carbohydrates),
      fatPer100: _n100(n, Nutrient.fat),
      fiberPer100: _n100(n, Nutrient.fiber),
      sugarPer100: _n100(n, Nutrient.sugars),
      saturatedFatPer100: _n100(n, Nutrient.saturatedFat),
      transFatPer100: _n100(n, Nutrient.transFat),
      sodiumPer100: _sodiumMg(n),
      potassiumPer100: _n100(n, Nutrient.potassium) * 1000,
      cholesterolPer100: _n100(n, Nutrient.cholesterol) * 1000,
      vitaminCPer100: _n100(n, Nutrient.vitaminC) * 1000,
      calciumPer100: _n100(n, Nutrient.calcium) * 1000,
      ironPer100: _n100(n, Nutrient.iron) * 1000,
      ingredientsText:
          p.ingredientsText ??
          p.ingredientsTextInLanguages?[OpenFoodFactsLanguage.ENGLISH],
      isVerified: n != null,
      completeness: _completeness(p, n),
      cachedAt: DateTime.now(),
      source: source,
    );
  }

  // ── MAP search hit → OFFFoodResult ────────────────────────────────────

  OFFFoodResult _mapSearchHit(Map<String, dynamic> hit) {
    final n = hit['nutriments'] as Map<String, dynamic>? ?? {};

    final name = (hit['product_name_en'] as String?)?.trim().isNotEmpty == true
        ? hit['product_name_en'] as String
        : (hit['product_name_ms'] as String?)?.trim().isNotEmpty == true
        ? hit['product_name_ms'] as String
        : (hit['product_name'] as String?)?.trim() ?? '';

    double nv(String key) => (n[key] as num?)?.toDouble() ?? 0.0;

    double cal = nv('energy-kcal_100g');
    if (cal == 0) {
      final kj = nv('energy_100g');
      if (kj > 0) cal = kj / 4.184;
    }

    final sodium = nv('sodium_100g') > 0
        ? nv('sodium_100g') * 1000
        : nv('salt_100g') * 400;

    final servingQty = (hit['serving_quantity'] as num?)?.toDouble() ?? 100.0;
    final completeness = (hit['completeness'] as num?)?.toDouble() ?? 0;

    return OFFFoodResult(
      barcode: (hit['code'] as String?)?.trim() ?? '',
      name: name,
      brand: (hit['brands'] as String?)?.trim() ?? '',
      imageUrl: hit['image_front_url'] as String?,
      nutritionGrade: hit['nutriscore_grade'] as String?,
      servingSize: servingQty > 0 ? servingQty : 100,
      servingUnit: 'g',
      caloriesPer100: cal,
      proteinPer100: nv('proteins_100g'),
      carbsPer100: nv('carbohydrates_100g'),
      fatPer100: nv('fat_100g'),
      fiberPer100: nv('fiber_100g'),
      sugarPer100: nv('sugars_100g'),
      saturatedFatPer100: nv('saturated-fat_100g'),
      transFatPer100: nv('trans-fat_100g'),
      sodiumPer100: sodium,
      potassiumPer100: nv('potassium_100g') * 1000,
      cholesterolPer100: nv('cholesterol_100g') * 1000,
      vitaminCPer100: nv('vitamin-c_100g') * 1000,
      calciumPer100: nv('calcium_100g') * 1000,
      ironPer100: nv('iron_100g') * 1000,
      ingredientsText:
          (hit['ingredients_text_en'] as String?) ??
          hit['ingredients_text'] as String?,
      isVerified: n.isNotEmpty,
      completeness: (completeness / 100).clamp(0.0, 1.0),
      cachedAt: DateTime.now(),
      source: 'search',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _productName(Product p) {
    final en = p.productNameInLanguages?[OpenFoodFactsLanguage.ENGLISH]?.trim();
    if (en != null && en.isNotEmpty) return en;
    final ms = p.productNameInLanguages?[OpenFoodFactsLanguage.MALAY]?.trim();
    if (ms != null && ms.isNotEmpty) return ms;
    return p.productName ?? '';
  }

  double _n100(Nutriments? n, Nutrient nutrient) =>
      n?.getValue(nutrient, PerSize.oneHundredGrams) ?? 0.0;

  double _kcalPer100(Nutriments? n) {
    final kcal = n?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams) ?? 0;
    if (kcal > 0) return kcal;
    final kj = n?.getValue(Nutrient.energyKJ, PerSize.oneHundredGrams) ?? 0;
    return kj > 0 ? kj / 4.184 : 0;
  }

  double _sodiumMg(Nutriments? n) {
    final sodium = n?.getValue(Nutrient.sodium, PerSize.oneHundredGrams) ?? 0;
    if (sodium > 0) return sodium * 1000;
    final salt = n?.getValue(Nutrient.salt, PerSize.oneHundredGrams) ?? 0;
    return salt > 0 ? salt * 400 : 0;
  }

  double _completeness(Product p, Nutriments? n) {
    int found = 0;
    if ((p.productName ?? '').isNotEmpty) found++;
    if ((p.brands ?? '').isNotEmpty) found++;
    if (n != null) {
      if (_kcalPer100(n) > 0) found++;
      if (_n100(n, Nutrient.proteins) > 0) found++;
      if (_n100(n, Nutrient.carbohydrates) > 0) found++;
      if (_n100(n, Nutrient.fat) > 0) found++;
    }
    return found / 6.0;
  }
}
