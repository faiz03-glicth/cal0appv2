import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class AminoSpikingAI {
  OrtSession? _session;
  final Map<String, int> _vocab = {};
  final int maxLength = 128;

  static const int _clsId = 101;
  static const int _sepId = 102;
  static const int _padId = 0;
  static const int _unkId = 100;

  static const List<String> _labels = ['Authentic', 'Spiked', 'Plant-Based'];

  bool get isReady => _session != null && _vocab.isNotEmpty;

  Future<void> initialize() async {
    try {
      final ort = OnnxRuntime();
      _session = await ort.createSessionFromAsset('assets/ml/model.onnx');
      LogService.info(
        'AI: ONNX model loaded ✅ '
        'inputs=${_session!.inputNames} '
        'outputs=${_session!.outputNames}',
      );

      // Load vocab
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

  /// Returns a Map with keys:
  ///   'isSpiked'   → bool
  ///   'confidence' → double (0.0 – 1.0)
  ///   'label'      → String ('Authentic' | 'Spiked' | 'Plant-Based')
  ///   'labelIndex' → int (0 | 1 | 2)
  Future<Map<String, dynamic>> analyzeIngredients(String ingredientText) async {
    if (!isReady) {
      LogService.error('AI: not ready, skipping inference');
      return {
        'isSpiked': false,
        'confidence': 0.0,
        'label': 'Unknown',
        'labelIndex': 0,
      };
    }

    try {
      final tokens = _tokenize(ingredientText);
      final inputIds = tokens[0];
      final attentionMask = tokens[1];

      // Build input tensors — shape [1, 128] as int64
      final inputIdsTensor = await OrtValue.fromList(
        inputIds.map((e) => e.toInt()).toList(),
        [1, maxLength],
      );
      final attentionMaskTensor = await OrtValue.fromList(
        attentionMask.map((e) => e.toInt()).toList(),
        [1, maxLength],
      );

      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      };

      final outputs = await _session!.run(inputs);

      // Dispose input tensors
      inputIdsTensor.dispose();
      attentionMaskTensor.dispose();

      // Extract logits — output shape [1, 3]
      final logitsTensor = outputs['logits'];
      if (logitsTensor == null) {
        LogService.error('AI: no logits output');
        _disposeOutputs(outputs);
        return {
          'isSpiked': false,
          'confidence': 0.0,
          'label': 'Unknown',
          'labelIndex': 0,
        };
      }

      final rawList = await logitsTensor.asList();
      _disposeOutputs(outputs);

      if (rawList == null || rawList.isEmpty) {
        LogService.error('AI: empty logits');
        return {
          'isSpiked': false,
          'confidence': 0.0,
          'label': 'Unknown',
          'labelIndex': 0,
        };
      }

      // rawList is flat [v0, v1, v2] since batch=1
      final List<double> logits = (rawList as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final probs = _softmax(logits);

      // Find best class
      int bestLabel = 0;
      double bestProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestProb) {
          bestProb = probs[i];
          bestLabel = i;
        }
      }

      final isSpiked = bestLabel == 1;
      final label = _labels[bestLabel];

      LogService.info(
        'AI result → '
        'authentic=${probs[0].toStringAsFixed(3)} '
        'spiked=${probs[1].toStringAsFixed(3)} '
        'plant=${probs[2].toStringAsFixed(3)} '
        'verdict=$label (${(bestProb * 100).toStringAsFixed(1)}%)',
      );

      return {
        'isSpiked': isSpiked,
        'confidence': bestProb,
        'label': label,
        'labelIndex': bestLabel,
      };
    } catch (e) {
      LogService.error('AI: inference error', e);
      return {
        'isSpiked': false,
        'confidence': 0.0,
        'label': 'Unknown',
        'labelIndex': 0,
      };
    }
  }

  void _disposeOutputs(Map<String, OrtValue?> outputs) {
    for (final v in outputs.values) {
      v?.dispose();
    }
  }

  List<List<int>> _tokenize(String text) {
    final clean = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s,.\-%()/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = clean.split(' ');
    final tokenIds = <int>[_clsId];

    for (final word in words) {
      if (word.isEmpty) continue;
      if (tokenIds.length >= maxLength - 1) break;
      final wordTokens = _wordPieceTokenize(word);
      for (final id in wordTokens) {
        if (tokenIds.length >= maxLength - 1) break;
        tokenIds.add(id);
      }
    }
    tokenIds.add(_sepId);

    final inputIds = List<int>.filled(maxLength, _padId);
    final attentionMask = List<int>.filled(maxLength, 0);

    for (int i = 0; i < tokenIds.length && i < maxLength; i++) {
      inputIds[i] = tokenIds[i];
      attentionMask[i] = 1;
    }

    return [inputIds, attentionMask];
  }

  List<int> _wordPieceTokenize(String word) {
    if (_vocab.containsKey(word)) return [_vocab[word]!];

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

      if (foundId == null) return [_unkId];
      result.add(foundId);
      start = end;
    }

    return result;
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps = logits.map((l) => exp(l - maxVal)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  Future<void> dispose() async {
    await _session?.close();
    _vocab.clear();
    LogService.info('AI: disposed');
  }
}
