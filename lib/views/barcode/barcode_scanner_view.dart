import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/barcode_viewmodel.dart';
import 'package:cal0appv2/views/barcode/barcode_result_sheet.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _torchOn = false;
  // Guards against opening the sheet multiple times concurrently.
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller.stop();
      default:
        break;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;

    debugPrint(
      '📸 Capture received — barcodes: ${capture.barcodes.length}'
      '${barcode != null ? ", value: $barcode" : ""}',
    );

    // No readable barcode in this frame, or sheet already open
    if (barcode == null || _sheetOpen) return;

    final vm = context.read<BarcodeViewModel>();

    // ViewModel isn't ready to accept a new scan
    if (!vm.canScan) {
      debugPrint('⏭ VM not ready — state: ${vm.state}');
      return;
    }

    // Kick off the lookup — this changes vm.state to `scanning`
    await vm.onBarcodeDetected(barcode);

    // Check mounted before doing anything UI-related post-await
    if (!mounted) return;

    final resultState = vm.state;
    debugPrint('📦 Post-lookup state: $resultState');

    if (resultState == BarcodeScanState.found ||
        resultState == BarcodeScanState.notFound ||
        resultState == BarcodeScanState.failed) {
      // Stop scanning while sheet is open
      _controller.stop();
      _sheetOpen = true;
      await _showResultSheet();
    }
    // If still scanning (shouldn't happen) or idle, do nothing extra
  }

  Future<void> _showResultSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<BarcodeViewModel>(),
        child: const BarcodeResultSheet(),
      ),
    );

    // Sheet dismissed — reset VM and restart scanner
    _sheetOpen = false;
    if (mounted) {
      context.read<BarcodeViewModel>().reset();
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final vm = context.watch<BarcodeViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _ScanOverlay(),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _StatusBanner(state: vm.state, error: vm.errorMessage),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const scanAreaSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: scanAreaSize,
      height: scanAreaSize * 0.6,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paint,
    );

    final guidePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const guideLen = 24.0;
    final corners = [
      [
        rect.topLeft,
        Offset(rect.left + guideLen, rect.top),
        Offset(rect.left, rect.top + guideLen),
      ],
      [
        rect.topRight,
        Offset(rect.right - guideLen, rect.top),
        Offset(rect.right, rect.top + guideLen),
      ],
      [
        rect.bottomLeft,
        Offset(rect.left + guideLen, rect.bottom),
        Offset(rect.left, rect.bottom - guideLen),
      ],
      [
        rect.bottomRight,
        Offset(rect.right - guideLen, rect.bottom),
        Offset(rect.right, rect.bottom - guideLen),
      ],
    ];
    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], guidePaint);
      canvas.drawLine(corner[0], corner[2], guidePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Shows scanning status + any error messages below the scan window.
class _StatusBanner extends StatelessWidget {
  final BarcodeScanState state;
  final String? error;

  const _StatusBanner({required this.state, this.error});

  @override
  Widget build(BuildContext context) {
    // Show error even when state goes back to failed
    if (state == BarcodeScanState.failed && error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            error!,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state == BarcodeScanState.idle) return const SizedBox.shrink();

    final String label;
    final bool showSpinner;

    switch (state) {
      case BarcodeScanState.scanning:
        label = 'Looking up product...';
        showSpinner = true;
      case BarcodeScanState.saving:
        label = 'Saving...';
        showSpinner = true;
      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
