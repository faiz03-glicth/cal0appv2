import 'package:cal0appv2/models/barcode_food_model.dart';
import 'package:cal0appv2/services/cache/barcode_cache_service.dart';
import 'package:cal0appv2/services/food/open_food_facts_service.dart';
import 'package:cal0appv2/services/scan/barcode_scanner_service.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class BarcodeRepository {
  final OpenFoodFactsService _apiService;
  final BarcodeScannerService _scannerService;

  BarcodeRepository({
    OpenFoodFactsService? apiService,
    BarcodeScannerService? scannerService,
  }) : _apiService = apiService ?? OpenFoodFactsService(),
       _scannerService = scannerService ?? BarcodeScannerService();

  Future<BarcodeLookupResult> lookup(String rawBarcode) async {
    final barcode = _scannerService.normalize(rawBarcode);

    if (!_scannerService.isValidBarcode(barcode)) {
      return const BarcodeLookupError('Invalid barcode format');
    }

    // 1. Check cache first
    final cached = await BarcodeCacheService.get(barcode);
    if (cached != null) {
      if (cached.productName.isEmpty) {
        LogService.info('BarcodeRepository: cached not-found for $barcode');
        return BarcodeLookupNotFound(barcode);
      }
      LogService.info(
        'BarcodeRepository: cache hit for $barcode (${cached.productName})',
      );
      return BarcodeLookupSuccess(cached);
    }

    // 2. Network lookup
    final result = await _apiService.lookupBarcode(barcode);

    // 3. Cache the result
    switch (result) {
      case BarcodeLookupSuccess(:final food):
        await BarcodeCacheService.save(food);
      case BarcodeLookupNotFound(:final barcode):
        await BarcodeCacheService.saveNotFound(barcode);
      case BarcodeLookupError():
        break; // Don't cache errors (might be transient)
    }

    return result;
  }
}
