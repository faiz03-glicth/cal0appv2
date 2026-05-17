// lib/services/scan/amino_spike_detector_service.dart

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';
import 'package:cal0appv2/services/scan/bert_tokenizer_service.dart';
import 'package:cal0appv2/services/scan/text_preprocessor_service.dart';

class DetectionResult {
  final bool isSpiked;
  final double confidence; // 0.0 – 1.0
  final List<String> flaggedIngredients;

  const DetectionResult({
    required this.isSpiked,
    required this.confidence,
    required this.flaggedIngredients,
  });
}

class AminoSpikeDetectorService {
  static const int _maxLen = 128;

  Interpreter? _interpreter;
  final BertTokenizerService _tokenizer = BertTokenizerService();
  bool _isReady = false;

  // Known spiking agents (rule-based fallback + label overlay)
  static const _suspectIngredients = [
    'glycine',
    'taurine',
    'creatine',
    'arginine',
    'glutamine',
    'beta-alanine',
    'hydroxyproline',
    'alanine',
    'sarcosine',
  ];

  Future<void> init() async {
    try {
      await _tokenizer.init();
      _interpreter = await Interpreter.fromAsset(
        'assets/model/amino_model.tflite',
      );
      _isReady = true;
      LogService.info('AminoSpikeDetector: TFLite model loaded ✅');
    } catch (e) {
      LogService.error('AminoSpikeDetector: failed to load model', e);
      _isReady = false;
    }
  }

  /// Main entry point — call this from ScanViewModel.
  Future<DetectionResult> analyze(List<String> ocrLines) async {
    final rawText = TextPreprocessorService.joinLines(ocrLines);
    final cleanText = TextPreprocessorService.preprocess(rawText);

    // Rule-based flagging (always runs)
    final flagged = _suspectIngredients
        .where((s) => rawText.toLowerCase().contains(s))
        .toList();

    // TFLite inference (if model loaded)
    if (_isReady && _interpreter != null && cleanText.isNotEmpty) {
      try {
        final result = _runInference(cleanText);
        LogService.info(
          'AminoSpikeDetector: label=${result.$1} conf=${result.$2.toStringAsFixed(3)}',
        );
        return DetectionResult(
          isSpiked: result.$1 == 1 || flagged.isNotEmpty,
          confidence: result.$2,
          flaggedIngredients: flagged,
        );
      } catch (e) {
        LogService.error('AminoSpikeDetector: inference error', e);
      }
    }

    // Fallback — rule-based only
    return DetectionResult(
      isSpiked: flagged.isNotEmpty,
      confidence: flagged.isNotEmpty ? 0.85 : 0.15,
      flaggedIngredients: flagged,
    );
  }

  (int label, double confidence) _runInference(String text) {
    final tokens = _tokenizer.tokenize(text);
    final inputIds = tokens[0];
    final attentionMask = tokens[1];

    // Shape: [1, 128]
    final inputIdsTensor = [inputIds];
    final attentionMaskTensor = [attentionMask];

    // Output shape: [1, 2]  (logits for label 0 and 1)
    final output = List.generate(1, (_) => List.filled(2, 0.0));

    _interpreter!.runForMultipleInputs(
      [inputIdsTensor, attentionMaskTensor],
      {0: output},
    );

    final logits = output[0];
    final probs = _softmax(logits);
    final label = probs[1] >= 0.5 ? 1 : 0;
    return (label, probs[label]);
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits
        .map(
          (l) => (l - maxLogit).abs() < 50
              ? 1.0 * (l - maxLogit == 0 ? 1 : l - maxLogit)
              : 0.0,
        )
        .toList();
    // Proper softmax
    final expA = logits.map((l) => _exp(l - maxLogit)).toList();
    final sum = expA.reduce((a, b) => a + b);
    return expA.map((e) => e / sum).toList();
  }

  double _exp(double x) {
    if (x < -50) return 0.0;
    if (x > 50) return 1e21;
    return x == 0
        ? 1.0
        : (x > 0
              ? (1 + x + x * x / 2 + x * x * x / 6 + x * x * x * x / 24)
              : 1.0 / (1 - x + x * x / 2 - x * x * x / 6 + x * x * x * x / 24));
  }

  void dispose() {
    _interpreter?.close();
    _isReady = false;
  }
}
