import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2';
  static const Duration _timeout = Duration(seconds: 8);

  // Malaysian product endpoint tried first, then global
  static const List<String> _endpoints = [
    'https://my.openfoodfacts.org/api/v2',
    'https://world.openfoodfacts.org/api/v2',
  ];

  static const Map<String, String> _headers = {
    'User-Agent': 'C0App/1.0 (Flutter; contact@c0app.my)',
    'Accept': 'application/json',
  };

  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    if (barcode.trim().isEmpty) {
      return const BarcodeLookupError('Empty barcode');
    }

    LogService.info('OpenFoodFacts: looking up barcode $barcode');

    for (final endpoint in _endpoints) {
      try {
        final uri = Uri.parse(
          '$endpoint/product/$barcode'
          '?fields=product_name,product_name_en,product_name_ms,'
          'brands,nutriments,serving_size,serving_quantity,serving_unit,'
          'ingredients_text,ingredients_text_en,image_front_url,image_url',
        );

        final response = await http
            .get(uri, headers: _headers)
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final status = data['status'];

          if (status == 1 || status == '1') {
            final model = BarcodeFoodModel.fromOpenFoodFacts(data, barcode);
            LogService.info(
              'OpenFoodFacts: found "${model.productName}" '
              'verified=${model.isVerified}',
            );
            return BarcodeLookupSuccess(model);
          } else {
            // Status 0 = product not found in this region, try next endpoint
            LogService.info(
              'OpenFoodFacts: not found at $endpoint, trying next',
            );
            continue;
          }
        }

        if (response.statusCode == 404) continue;

        LogService.error(
          'OpenFoodFacts: HTTP ${response.statusCode} from $endpoint',
        );
      } catch (e) {
        LogService.error('OpenFoodFacts: request failed for $endpoint', e);
        continue;
      }
    }

    return BarcodeLookupNotFound(barcode);
  }
}
