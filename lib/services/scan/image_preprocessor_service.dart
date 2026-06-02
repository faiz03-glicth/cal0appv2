import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class PreprocessResult {
  final File processedFile;

  /// 0.0 – 1.0. Below ~0.35 the image is too poor for reliable OCR.
  final double qualityScore;

  final String diagnostics;
  final bool wasUpscaled;
  final bool wasRotated;
  final bool roiDetected;

  const PreprocessResult({
    required this.processedFile,
    required this.qualityScore,
    required this.diagnostics,
    this.wasUpscaled = false,
    this.wasRotated = false,
    this.roiDetected = false,
  });
}

class ImagePreprocessorService {
  static const int _minWidth = 1200;
  static const int _minHeight = 900;
  static const int _targetWidth = 2400;

  Future<PreprocessResult> preprocess(File imageFile) async {
    final sw = Stopwatch()..start();
    LogService.info('Preprocessor: start');

    try {
      // ── 1. Decode ──────────────────────────────────────────────────────
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        LogService.error('Preprocessor: decode failed');
        return PreprocessResult(
          processedFile: imageFile,
          qualityScore: 0.0,
          diagnostics: 'decode_failed',
        );
      }
      LogService.info('Preprocessor: decoded ${image.width}×${image.height}');

      bool wasRotated = false;
      bool wasUpscaled = false;
      bool roiDetected = false;

      // ── 2. EXIF auto-rotate ────────────────────────────────────────────
      final rotated = img.bakeOrientation(image);
      wasRotated =
          (rotated.width != image.width || rotated.height != image.height);
      image = rotated;

      // ── 3. Upscale if too small ────────────────────────────────────────
      if (image.width < _minWidth || image.height < _minHeight) {
        final scale = _targetWidth / image.width;
        final newH = (image.height * scale).round();
        image = img.copyResize(
          image,
          width: _targetWidth,
          height: newH,
          interpolation: img.Interpolation.cubic,
        );
        wasUpscaled = true;
        LogService.info(
          'Preprocessor: upscaled to ${image.width}×${image.height}',
        );
      }

      // ── 4. Greyscale ───────────────────────────────────────────────────
      image = img.grayscale(image);

      // ── 5. Contrast stretching ─────────────────────────────────────────
      image = _stretchContrast(image);

      // ── 6. Unsharp mask (sharpening) ──────────────────────────────────
      image = _unsharpMask(image, sigma: 1.2, amount: 1.5);

      // ── 7. Denoise (light Gaussian) ────────────────────────────────────
      image = img.gaussianBlur(image, radius: 1);

      // ── 8. Adaptive threshold ──────────────────────────────────────────
      final binarised = _adaptiveThreshold(image, blockSize: 31, c: 10);

      // ── 9. ROI crop ────────────────────────────────────────────────────
      final roi = _detectLabelROI(binarised);
      final finalImage = roi != null
          ? img.copyCrop(
              binarised,
              x: roi.x,
              y: roi.y,
              width: roi.w,
              height: roi.h,
            )
          : binarised;
      roiDetected = roi != null;
      if (roiDetected) {
        LogService.info(
          'Preprocessor: ROI ${roi!.x},${roi.y} ${roi.w}×${roi.h}',
        );
      }

      // ── 10. Encode ─────────────────────────────────────────────────────
      final tmp = await getTemporaryDirectory();
      final outPath =
          '${tmp.path}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outBytes = img.encodeJpg(finalImage, quality: 95);
      final outFile = File(outPath)..writeAsBytesSync(outBytes);

      final quality = _estimateQuality(finalImage);
      sw.stop();

      final diag =
          '${finalImage.width}×${finalImage.height} | '
          'q=${(quality * 100).toStringAsFixed(0)}% | '
          'up=$wasUpscaled roi=$roiDetected | ${sw.elapsedMilliseconds}ms';
      LogService.info('Preprocessor: done — $diag');

      return PreprocessResult(
        processedFile: outFile,
        qualityScore: quality,
        diagnostics: diag,
        wasUpscaled: wasUpscaled,
        wasRotated: wasRotated,
        roiDetected: roiDetected,
      );
    } catch (e, st) {
      LogService.error('Preprocessor: pipeline error', e, st);
      return PreprocessResult(
        processedFile: imageFile,
        qualityScore: 0.3,
        diagnostics: 'pipeline_error: $e',
      );
    }
  }

  // ── Contrast stretching ────────────────────────────────────────────────────

  img.Image _stretchContrast(img.Image src) {
    int minL = 255, maxL = 0;
    for (int y = 0; y < src.height; y += 4) {
      for (int x = 0; x < src.width; x += 4) {
        final l = img.getLuminance(src.getPixel(x, y)).toInt();
        if (l < minL) minL = l;
        if (l > maxL) maxL = l;
      }
    }
    if (maxL - minL < 40) return src; // already well-contrasted

    final range = (maxL - minL).toDouble();
    final out = img.Image.from(src);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final l = img.getLuminance(src.getPixel(x, y)).toInt();
        final s = (((l - minL) / range) * 255).clamp(0, 255).toInt();
        out.setPixelRgb(x, y, s, s, s);
      }
    }
    return out;
  }

  // ── Unsharp mask ──────────────────────────────────────────────────────────

  img.Image _unsharpMask(
    img.Image src, {
    double sigma = 1.0,
    double amount = 1.0,
  }) {
    final r = math.max(1, (sigma * 2).round());
    final blurred = img.gaussianBlur(src, radius: r);
    final out = img.Image.from(src);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final orig = img.getLuminance(src.getPixel(x, y)).toInt();
        final blur = img.getLuminance(blurred.getPixel(x, y)).toInt();
        final sharp = (orig + amount * (orig - blur)).clamp(0, 255).toInt();
        out.setPixelRgb(x, y, sharp, sharp, sharp);
      }
    }
    return out;
  }

  // ── Adaptive threshold (Sauvola-style, integral image fast path) ──────────

  img.Image _adaptiveThreshold(
    img.Image src, {
    int blockSize = 31,
    int c = 10,
  }) {
    final out = img.Image.from(src);
    final half = blockSize ~/ 2;
    final w = src.width;
    final h = src.height;

    // Build integral image
    final ii = List.generate(h + 1, (_) => List<int>.filled(w + 1, 0));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = img.getLuminance(src.getPixel(x, y)).toInt();
        ii[y + 1][x + 1] = v + ii[y][x + 1] + ii[y + 1][x] - ii[y][x];
      }
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final x1 = math.max(0, x - half);
        final y1 = math.max(0, y - half);
        final x2 = math.min(w - 1, x + half);
        final y2 = math.min(h - 1, y + half);
        final count = (x2 - x1 + 1) * (y2 - y1 + 1);
        final sum =
            ii[y2 + 1][x2 + 1] - ii[y1][x2 + 1] - ii[y2 + 1][x1] + ii[y1][x1];
        final mean = sum ~/ count;
        final pix = img.getLuminance(src.getPixel(x, y)).toInt();
        final bin = pix > (mean - c) ? 255 : 0;
        out.setPixelRgb(x, y, bin, bin, bin);
      }
    }
    return out;
  }

  // ── ROI detection (find text-dense rectangle) ─────────────────────────────

  _Rect? _detectLabelROI(img.Image src) {
    const cols = 4;
    const rows = 6;
    final cw = src.width ~/ cols;
    final ch = src.height ~/ rows;
    final scores = List.generate(rows, (_) => List<double>.filled(cols, 0));

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int dark = 0, total = 0;
        for (int y = r * ch; y < (r + 1) * ch && y < src.height; y++) {
          for (int x = c * cw; x < (c + 1) * cw && x < src.width; x++) {
            total++;
            if (img.getLuminance(src.getPixel(x, y)) < 128) dark++;
          }
        }
        final ratio = total > 0 ? dark / total : 0.0;
        // Text cells have 5–45% dark pixels
        scores[r][c] = (ratio >= 0.05 && ratio <= 0.45) ? ratio : 0.0;
      }
    }

    int minR = rows, maxR = -1, minC = cols, maxC = -1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (scores[r][c] > 0.05) {
          if (r < minR) minR = r;
          if (r > maxR) maxR = r;
          if (c < minC) minC = c;
          if (c > maxC) maxC = c;
        }
      }
    }

    if (maxR < 0 || (maxR - minR + 1) >= rows - 1) return null;

    const pad = 1;
    final left = math.max(0, (minC - pad) * cw);
    final top = math.max(0, (minR - pad) * ch);
    final right = math.min(src.width, (maxC + 1 + pad) * cw);
    final bottom = math.min(src.height, (maxR + 1 + pad) * ch);

    final rw = right - left;
    final rh = bottom - top;
    if (rw < src.width * 0.25) return null; // too narrow
    return _Rect(left, top, rw, rh);
  }

  // ── Quality estimation ─────────────────────────────────────────────────────

  double _estimateQuality(img.Image image) {
    int sum = 0, sumSq = 0, dark = 0, sampled = 0;
    for (int y = 0; y < image.height; y += 8) {
      for (int x = 0; x < image.width; x += 8) {
        final l = img.getLuminance(image.getPixel(x, y)).toInt();
        sum += l;
        sumSq += l * l;
        if (l < 128) dark++;
        sampled++;
      }
    }
    if (sampled == 0) return 0.0;
    final mean = sum / sampled;
    final variance = (sumSq / sampled) - (mean * mean);
    final stdDev = math.sqrt(variance.clamp(0.0, double.infinity));
    final contrastScore = (stdDev / 128).clamp(0.0, 1.0);
    final textDensity = dark / sampled;
    final densityScore = (textDensity >= 0.05 && textDensity <= 0.50)
        ? 1.0
        : textDensity < 0.05
        ? textDensity / 0.05
        : 1.0 - (textDensity - 0.50) / 0.50;
    return (contrastScore * 0.6 + densityScore * 0.4).clamp(0.0, 1.0);
  }
}

class _Rect {
  final int x, y, w, h;
  const _Rect(this.x, this.y, this.w, this.h);
}
