import 'package:cal0appv2/models/off_food_result.dart';
import 'package:cal0appv2/services/food/off_service.dart';
import 'package:cal0appv2/services/cache/off_food_cache.dart';
import 'package:cal0appv2/services/scan/barcode_scanner_service.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

// ── Result types (same sealed-class pattern used by old BarcodeRepository)

sealed class FoodLookupResult {
  const FoodLookupResult();
}

class FoodLookupSuccess extends FoodLookupResult {
  final OFFFoodResult food;
  const FoodLookupSuccess(this.food);
}

class FoodLookupNotFound extends FoodLookupResult {
  final String identifier; // barcode or query
  const FoodLookupNotFound(this.identifier);
}

class FoodLookupError extends FoodLookupResult {
  final String message;
  const FoodLookupError(this.message);
}

// ── Repository ─────────────────────────────────────────────────────────────

class OFFFoodRepository {
  final OFFService _service;
  final BarcodeScannerService _scanner;

  OFFFoodRepository({OFFService? service, BarcodeScannerService? scanner})
    : _service = service ?? OFFService(),
      _scanner = scanner ?? BarcodeScannerService();

  // ── BARCODE lookup ──────────────────────────────────────────────────────
  // 1. Validate barcode format
  // 2. Check local cache
  // 3. If cache miss → network lookup
  // 4. Cache result (positive or negative)
  // 5. Return sealed result

  Future<FoodLookupResult> lookupBarcode(String rawBarcode) async {
    final barcode = _scanner.normalize(rawBarcode);

    if (!_scanner.isValidBarcode(barcode)) {
      return const FoodLookupError('Invalid barcode format');
    }

    // 1. Cache hit
    final cached = await OFFFoodCache.getBarcode(barcode);
    if (cached != null) {
      if (cached.isNotFoundPlaceholder) {
        LogService.info('OFFFoodRepository: cached not-found $barcode');
        return FoodLookupNotFound(barcode);
      }
      LogService.info('OFFFoodRepository: cache hit barcode $barcode');
      return FoodLookupSuccess(cached);
    }

    // 2. Network
    try {
      final result = await _service.lookupBarcode(barcode);
      if (result == null) {
        await OFFFoodCache.saveBarcodeNotFound(barcode);
        return FoodLookupNotFound(barcode);
      }
      await OFFFoodCache.saveBarcode(result);
      return FoodLookupSuccess(result);
    } catch (e) {
      LogService.error('OFFFoodRepository.lookupBarcode', e);
      return FoodLookupError(e.toString());
    }
  }

  // ── TEXT SEARCH ─────────────────────────────────────────────────────────
  // 1. Check local cache for this query
  // 2. If cache miss or stale → network search
  // 3. Cache results
  // Returns empty list on any failure (never throws)

  Future<List<OFFFoodResult>> searchFood(
    String query, {
    int pageSize = 24,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Cache only for page 1 (pagination bypasses cache)
    if (page == 1 && !forceRefresh) {
      final cached = await OFFFoodCache.getSearch(q);
      if (cached != null) {
        LogService.info(
          'OFFFoodRepository: cache hit search "$q" (${cached.length} results)',
        );
        return cached;
      }
    }

    try {
      final results = await _service.searchFood(
        q,
        pageSize: pageSize,
        page: page,
      );
      if (page == 1 && results.isNotEmpty) {
        await OFFFoodCache.saveSearch(q, results);
      }
      return results;
    } catch (e) {
      LogService.error('OFFFoodRepository.searchFood', e);
      return [];
    }
  }

  // ── BARCODE → OFFFoodResult convenience (for BarcodeViewModel) ─────────

  Future<OFFFoodResult?> getByBarcode(String barcode) async {
    final result = await lookupBarcode(barcode);
    return result is FoodLookupSuccess ? result.food : null;
  }
}
