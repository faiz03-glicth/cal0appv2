import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/barcode_viewmodel.dart';
import 'package:cal0appv2/views/barcode/barcode_result_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
// BarcodeScannerView
//
// Two ways to scan a barcode:
//   1. Live camera scan (MobileScanner — original behaviour)
//   2. Upload image from device gallery (jpg/png) — new for TC_Barcode_Upload
//
// Upload flow:
//   User taps "Upload Barcode Image" → picks jpg/png from files →
//   image is decoded by MobileScannerController.analyzeImage() →
//   same _onDetect / _showResultSheet pipeline as the live camera.
//   If no barcode is found in the image, a clear error snackbar is shown.
// ══════════════════════════════════════════════════════════════════════════════

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final ImagePicker _picker = ImagePicker();

  bool _torchOn = false;
  bool _sheetOpen = false;
  bool _uploading = false; // true while gallery image is being analysed

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

  // ── Live camera detection ───────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || _sheetOpen) return;

    final vm = context.read<BarcodeViewModel>();
    if (!vm.canScan) return;

    await vm.onBarcodeDetected(barcode);
    if (!mounted) return;

    final state = vm.state;
    if (state == BarcodeScanState.found ||
        state == BarcodeScanState.notFound ||
        state == BarcodeScanState.failed) {
      _controller.stop();
      _sheetOpen = true;
      await _showResultSheet();
    }
  }

  // ── Gallery / file upload ───────────────────────────────────────────────

  Future<void> _pickAndAnalyseImage() async {
    if (_uploading || _sheetOpen) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _uploading = true;
    });
    _controller.stop(); // pause live scanner while we decode the static image

    try {
      // analyzeImage decodes the file and fires _onDetect if a barcode is found
      final found = await _controller.analyzeImage(picked.path);

      if (!mounted) return;

      if (found != true) {
        // No barcode detected in the uploaded image
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No barcode found in this image. '
                    'Please upload a clearer photo of the barcode.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        // Restart live scanner so user can try again
        if (mounted) _controller.start();
      }
      // If found == true, _onDetect fires automatically and opens the sheet
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        _controller.start();
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ── Result sheet ────────────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────────

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
              setState(() {
                _torchOn = !_torchOn;
              });
              _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Live camera ──────────────────────────────────────────────
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // ── Scan window overlay ──────────────────────────────────────
          _ScanOverlay(),

          // ── Upload button — bottom-left of scan area ─────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              onUpload: _pickAndAnalyseImage,
              uploading: _uploading,
              state: vm.state,
              error: vm.errorMessage,
              primaryColor: c.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar: upload button + status banner ──────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onUpload;
  final bool uploading;
  final BarcodeScanState state;
  final String? error;
  final Color primaryColor;

  const _BottomBar({
    required this.onUpload,
    required this.uploading,
    required this.state,
    required this.error,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status / error banner
          if (state == BarcodeScanState.failed && error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (state == BarcodeScanState.scanning ||
              state == BarcodeScanState.saving ||
              uploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      uploading
                          ? 'Analysing image…'
                          : state == BarcodeScanState.saving
                          ? 'Saving…'
                          : 'Looking up product…',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Hint text
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Point camera at barcode, or upload an image',
              style: TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),

          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: uploading
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white30, width: 1),
                ),
                elevation: 0,
              ),
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(
                uploading ? 'Reading barcode…' : 'Upload Barcode Image',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              onPressed: uploading ? null : onUpload,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan window overlay ────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OverlayPainter(), child: const SizedBox.expand());
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const scanAreaSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 60; // shift up a bit to leave room for button
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
