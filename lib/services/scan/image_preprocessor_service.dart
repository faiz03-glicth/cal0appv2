import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // compute()
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

// ── Isolate-safe payload ───────────────────────────────────────────────────
// compute() cannot capture closures, so we pass all data in a plain record.

class _PreprocessInput {
  final String inputPath;
  final String outputDir;
  const _PreprocessInput(this.inputPath, this.outputDir);
}

class _PreprocessOutput {
  final String outputPath;
  final double qualityScore;
  final String diagnostics;
  final bool wasUpscaled;
  final bool wasRotated;
  final bool roiDetected;

  const _PreprocessOutput({
    required this.outputPath,
    required this.qualityScore,
    required this.diagnostics,
    this.wasUpscaled = false,
    this.wasRotated = false,
    this.roiDetected = false,
  });
}

// ── Top-level function required by compute() ───────────────────────────────
// Must be a top-level (not instance) function so the isolate can reference it.

_PreprocessOutput _preprocessInIsolate(_PreprocessInput input) {
  final sw = Stopwatch()..start();
  const int minWidth = 1200;
  const int minHeight = 900;
  const int targetWidth = 2400;

  try {
    // 1. Decode
    final bytes = File(input.inputPath).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) {
      return _PreprocessOutput(
        outputPath: input.inputPath,
        qualityScore: 0.0,
        diagnostics: 'decode_failed',
      );
    }

    bool wasRotated = false;
    bool wasUpscaled = false;
    bool roiDetected = false;

    // 2. EXIF auto-rotate
    final rotated = img.bakeOrientation(image);
    wasRotated =
        (rotated.width != image.width || rotated.height != image.height);
    image = rotated;

    // 3. Upscale if too small
    if (image.width < minWidth || image.height < minHeight) {
      final scale = targetWidth / image.width;
      final newH = (image.height * scale).round();
      image = img.copyResize(
        image,
        width: targetWidth,
        height: newH,
        interpolation: img.Interpolation.cubic,
      );
      wasUpscaled = true;
    }

    // 4. Greyscale
    image = img.grayscale(image);

    // 5. Contrast stretching
    image = _stretchContrast(image);

    // 6. Unsharp mask
    image = _unsharpMask(image, sigma: 1.2, amount: 1.5);

    // 7. Light denoise
    image = img.gaussianBlur(image, radius: 1);

    // 8. Adaptive threshold
    final binarised = _adaptiveThreshold(image, blockSize: 31, c: 10);

    // 9. ROI crop
    final roi = _detectLabelROI(binarised);
    final finalImage = roi != null
        ? img.copyCrop(
            binarised,
            x: roi[0],
            y: roi[1],
            width: roi[2],
            height: roi[3],
          )
        : binarised;
    roiDetected = roi != null;

    // 10. Encode to output path
    final outPath =
        '${input.outputDir}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outBytes = img.encodeJpg(finalImage, quality: 95);
    File(outPath).writeAsBytesSync(outBytes);

    final quality = _estimateQuality(finalImage);
    sw.stop();

    final diag =
        '${finalImage.width}×${finalImage.height} | '
        'q=${(quality * 100).toStringAsFixed(0)}% | '
        'up=$wasUpscaled roi=$roiDetected | ${sw.elapsedMilliseconds}ms';

    return _PreprocessOutput(
      outputPath: outPath,
      qualityScore: quality,
      diagnostics: diag,
      wasUpscaled: wasUpscaled,
      wasRotated: wasRotated,
      roiDetected: roiDetected,
    );
  } catch (e) {
    return _PreprocessOutput(
      outputPath: input.inputPath,
      qualityScore: 0.3,
      diagnostics: 'pipeline_error: $e',
    );
  }
}

// ── Pure functions used inside the isolate ────────────────────────────────

img.Image _stretchContrast(img.Image src) {
  int minL = 255, maxL = 0;
  for (int y = 0; y < src.height; y += 4) {
    for (int x = 0; x < src.width; x += 4) {
      final l = img.getLuminance(src.getPixel(x, y)).toInt();
      if (l < minL) minL = l;
      if (l > maxL) maxL = l;
    }
  }
  if (maxL - minL < 40) return src;
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

img.Image _adaptiveThreshold(img.Image src, {int blockSize = 31, int c = 10}) {
  final out = img.Image.from(src);
  final half = blockSize ~/ 2;
  final w = src.width;
  final h = src.height;

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

/// Returns [x, y, w, h] or null.
List<int>? _detectLabelROI(img.Image src) {
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
  if (rw < src.width * 0.25) return null;
  return [left, top, rw, rh];
}

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

// ── Public service class ───────────────────────────────────────────────────

class ImagePreprocessorService {
  /// Preprocesses [imageFile] entirely off the UI thread using compute().
  /// Returns a [PreprocessResult] with the path to the processed image.
  Future<PreprocessResult> preprocess(File imageFile) async {
    LogService.info('Preprocessor: start (background isolate)');

    try {
      final tmp = await getTemporaryDirectory();
      final input = _PreprocessInput(imageFile.path, tmp.path);

      // compute() runs _preprocessInIsolate in a background isolate.
      // The UI thread is completely free during this call — no ANR.
      final output = await compute(_preprocessInIsolate, input);

      LogService.info('Preprocessor: done — ${output.diagnostics}');

      return PreprocessResult(
        processedFile: File(output.outputPath),
        qualityScore: output.qualityScore,
        diagnostics: output.diagnostics,
        wasUpscaled: output.wasUpscaled,
        wasRotated: output.wasRotated,
        roiDetected: output.roiDetected,
      );
    } catch (e, st) {
      LogService.error('Preprocessor: compute() failed', e, st);
      return PreprocessResult(
        processedFile: imageFile,
        qualityScore: 0.3,
        diagnostics: 'compute_error: $e',
      );
    }
  }
}
