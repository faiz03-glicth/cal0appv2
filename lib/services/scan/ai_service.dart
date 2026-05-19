import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class AminoSpikingAI {
  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  final int maxLength = 128;

  // ── Special token IDs (standard BERT/DistilBERT) ──────────────────────────
  static const int _clsId = 101;
  static const int _sepId = 102;
  static const int _padId = 0;
  static const int _unkId = 100;

  // ── Public state ──────────────────────────────────────────────────────────
  bool get isReady => _interpreter != null && _vocab.isNotEmpty;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      // 1. Load TFLite model from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/distilbert_model.tflite',
      );
      LogService.info(
        'AI: model loaded — '
        'inputs=${_interpreter!.getInputTensors().length} '
        'outputs=${_interpreter!.getOutputTensors().length}',
      );

      // 2. Load vocab.txt — one token per line, line index = token ID
      final raw = await rootBundle.loadString('assets/ml/vocab.txt');
      final lines = raw.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) _vocab[token] = i;
      }

      LogService.info('AI: vocab loaded — ${_vocab.length} tokens ✅');
    } catch (e) {
      LogService.error('AI: initialization failed', e);
    }
  }

  // ── Inference ─────────────────────────────────────────────────────────────

  /// Returns a Map with keys:
  ///   'isSpiked'   → bool
  ///   'confidence' → double (0.0 – 1.0)
  Future<Map<String, dynamic>> analyzeIngredients(String ingredientText) async {
    if (!isReady) {
      LogService.error('AI: not ready, skipping inference');
      return {'isSpiked': false, 'confidence': 0.0};
    }

    try {
      // Tokenize → inputIds + attentionMask, both length 128
      final tokens = _tokenize(ingredientText);
      final inputIds = tokens[0];
      final attentionMask = tokens[1];

      // TFLite expects shape [1, 128]
      final inputIdsTensor = [inputIds];
      final attentionMaskTensor = [attentionMask];

      // Output shape [1, 2] — logits for [label_0_clean, label_1_spiked]
      final output = [List<double>.filled(2, 0.0)];

      // Two inputs: must use runForMultipleInputs
      _interpreter!.runForMultipleInputs(
        [inputIdsTensor, attentionMaskTensor],
        {0: output},
      );

      final logits = output[0];
      final probs = _softmax(logits);

      final isSpiked = probs[1] > probs[0];
      final confidence = probs[isSpiked ? 1 : 0];

      LogService.info(
        'AI result → '
        'clean=${probs[0].toStringAsFixed(3)} '
        'spiked=${probs[1].toStringAsFixed(3)} '
        'verdict=${isSpiked ? "SPIKED" : "CLEAN"}',
      );

      return {'isSpiked': isSpiked, 'confidence': confidence};
    } catch (e) {
      LogService.error('AI: inference error', e);
      return {'isSpiked': false, 'confidence': 0.0};
    }
  }

  // ── Tokenization ──────────────────────────────────────────────────────────

  /// Returns [inputIds, attentionMask], both padded to maxLength.
  List<List<int>> _tokenize(String text) {
    // Clean text — mirrors training preprocessing in your Colab notebook
    final clean = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s,.\-%()/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = clean.split(' ');
    final tokenIds = <int>[_clsId]; // start with [CLS]

    for (final word in words) {
      if (word.isEmpty) continue;
      if (tokenIds.length >= maxLength - 1) break;
      final wordTokens = _wordPieceTokenize(word);
      for (final id in wordTokens) {
        if (tokenIds.length >= maxLength - 1) break;
        tokenIds.add(id);
      }
    }
    tokenIds.add(_sepId); // end with [SEP]

    // Build padded tensors
    final inputIds = List<int>.filled(maxLength, _padId);
    final attentionMask = List<int>.filled(maxLength, 0);

    for (int i = 0; i < tokenIds.length && i < maxLength; i++) {
      inputIds[i] = tokenIds[i];
      attentionMask[i] = 1; // 1 = real token, 0 = padding
    }

    return [inputIds, attentionMask];
  }

  /// WordPiece tokenization — matches HuggingFace DistilBERT tokenizer.
  List<int> _wordPieceTokenize(String word) {
    // Try the whole word first
    if (_vocab.containsKey(word)) return [_vocab[word]!];

    // Greedy longest-match subword split
    final result = <int>[];
    int start = 0;

    while (start < word.length) {
      int end = word.length;
      int? foundId;

      while (start < end) {
        final sub = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (_vocab.containsKey(sub)) {
          foundId = _vocab[sub];
          break;
        }
        end--;
      }

      if (foundId == null) {
        // Whole word is unknown — return [UNK]
        return [_unkId];
      }

      result.add(foundId);
      start = end;
    }

    return result;
  }

  // ── Softmax ───────────────────────────────────────────────────────────────

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps = logits.map((l) => exp(l - maxVal)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    _interpreter?.close();
    _vocab.clear();
    LogService.info('AI: disposed');
  }
}
