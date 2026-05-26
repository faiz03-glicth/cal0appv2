import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/viewmodels/scan/barcode_viewmodel.dart';
import 'package:cal0appv2/views/barcode/barcode_result_sheet.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _torchOn = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
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
    if (barcode == null || _sheetOpen) return;

    final vm = context.read<BarcodeViewModel>();
    if (!vm.canScan) return;

    await vm.onBarcodeDetected(barcode);

    if (!mounted) return;

    if (vm.state == BarcodeScanState.found ||
        vm.state == BarcodeScanState.notFound) {
      _controller.stop();
      _sheetOpen = true;
      await _showResultSheet();
    }
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
          // Camera
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Scanning overlay
          _ScanOverlay(),

          // Status indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _StatusBanner(state: vm.state),
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

    // Dark overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paint,
    );

    // Corner guides
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

class _StatusBanner extends StatelessWidget {
  final BarcodeScanState state;
  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == BarcodeScanState.idle) return const SizedBox.shrink();

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
            if (state == BarcodeScanState.scanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            const SizedBox(width: 8),
            Text(switch (state) {
              BarcodeScanState.scanning => 'Looking up product...',
              BarcodeScanState.saving => 'Saving...',
              _ => '',
            }, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
