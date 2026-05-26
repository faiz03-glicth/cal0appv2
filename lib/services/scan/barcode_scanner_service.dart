class BarcodeScannerConfig {
  final bool torchEnabled;
  final bool frontCamera;

  const BarcodeScannerConfig({
    this.torchEnabled = false,
    this.frontCamera = false,
  });
}

// The actual scanning UI is handled by MobileScannerController in the View.
// This service handles the business logic around what to do with a scan result.

class BarcodeScannerService {
  /// Validates a scanned barcode string
  bool isValidBarcode(String? barcode) {
    if (barcode == null || barcode.trim().isEmpty) return false;
    // EAN-13, EAN-8, UPC-A, UPC-E, Code128, QR
    final clean = barcode.trim();
    return clean.length >= 6 &&
        clean.length <= 30 &&
        RegExp(r'^[0-9A-Za-z\-]+$').hasMatch(clean);
  }

  /// Normalizes barcode (removes leading zeros for some formats etc.)
  String normalize(String barcode) => barcode.trim();
}
