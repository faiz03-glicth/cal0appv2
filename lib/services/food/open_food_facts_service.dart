import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class OpenFoodFactsService {
  OpenFoodFactsService() {
    // Set user agent once — required so you don't get blocked
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'C0App',
      url: 'https://github.com/faiz03-glitch/cal0appv2',
    );
    OpenFoodAPIConfiguration.globalLanguages = <OpenFoodFactsLanguage>[
      OpenFoodFactsLanguage.ENGLISH,
      OpenFoodFactsLanguage.MALAY,
    ];
    OpenFoodAPIConfiguration.globalCountry = OpenFoodFactsCountry.MALAYSIA;
  }

  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    if (barcode.trim().isEmpty) {
      return const BarcodeLookupError('Empty barcode');
    }

    LogService.info('OpenFoodFacts: looking up barcode $barcode');

    try {
      final config = ProductQueryConfiguration(
        barcode,
        version: ProductQueryVersion.v3,
        fields: [
          ProductField.NAME,
          ProductField.BRANDS,
          ProductField.NUTRIMENTS,
          ProductField.SERVING_SIZE,
          ProductField.SERVING_QUANTITY,
          ProductField.INGREDIENTS_TEXT,
          ProductField.IMAGE_FRONT_URL,
        ],
      );

      final result = await OpenFoodAPIClient.getProductV3(config);

      if (result.status == ProductResultV3.statusSuccess &&
          result.product != null) {
        final p = result.product!;
        final n = p.nutriments;

        LogService.info('OpenFoodFacts: found "${p.productName}"');

        return BarcodeLookupSuccess(
          BarcodeFoodModel(
            barcode: barcode,
            productName:
                p.productName ??
                p.productNameInLanguages?[OpenFoodFactsLanguage.ENGLISH] ??
                '',
            brandName: p.brands,
            imageUrl: p.imageFrontUrl,
            calories: n
                ?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams)
                ?.toInt(),
            protein: n?.getValue(Nutrient.proteins, PerSize.oneHundredGrams),
            carbs: n?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams),
            fat: n?.getValue(Nutrient.fat, PerSize.oneHundredGrams),
            sugar: n?.getValue(Nutrient.sugars, PerSize.oneHundredGrams),
            sodium:
                n?.getValue(Nutrient.sodium, PerSize.oneHundredGrams) != null
                ? n!.getValue(Nutrient.sodium, PerSize.oneHundredGrams)! * 1000
                : null,
            servingSize: p.servingQuantity,
            servingUnit: 'g',
            ingredientText: p.ingredientsText,
            isVerified: n != null,
            cachedAt: DateTime.now(),
          ),
        );
      }

      LogService.info('OpenFoodFacts: product not found for $barcode');
      return BarcodeLookupNotFound(barcode);
    } catch (e) {
      LogService.error('OpenFoodFacts: error looking up $barcode', e);
      return BarcodeLookupError(e.toString());
    }
  }
}
