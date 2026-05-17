// lib/services/scan/bert_tokenizer_service.dart

import 'package:flutter/services.dart';

class BertTokenizerService {
  static const int _maxLen = 128;
  static const int _clsId = 101; // [CLS]
  static const int _sepId = 102; // [SEP]
  static const int _padId = 0; // [PAD]
  static const int _unkId = 100; // [UNK]

  Map<String, int>? _vocab;

  Future<void> init() async {
    if (_vocab != null) return;
    final raw = await rootBundle.loadString('assets/model/vocab.txt');
    final lines = raw.split('\n');
    _vocab = {};
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) _vocab![token] = i;
    }
  }

  /// Returns [inputIds, attentionMask] each of length [_maxLen].
  List<List<int>> tokenize(String text) {
    assert(_vocab != null, 'Call init() first');

    // Simple whitespace + WordPiece tokenization
    final words = text.split(RegExp(r'\s+'));
    final tokens = <int>[_clsId];

    for (final word in words) {
      if (tokens.length >= _maxLen - 1) break;
      final wordTokens = _wordPiece(word);
      for (final id in wordTokens) {
        if (tokens.length >= _maxLen - 1) break;
        tokens.add(id);
      }
    }
    tokens.add(_sepId);

    // Pad to maxLen
    final inputIds = List<int>.filled(_maxLen, _padId);
    final attentionMask = List<int>.filled(_maxLen, 0);

    for (int i = 0; i < tokens.length && i < _maxLen; i++) {
      inputIds[i] = tokens[i];
      attentionMask[i] = 1;
    }

    return [inputIds, attentionMask];
  }

  List<int> _wordPiece(String word) {
    final vocab = _vocab!;
    // Try the whole word first
    if (vocab.containsKey(word)) return [vocab[word]!];

    // Character-level WordPiece fallback
    final result = <int>[];
    int start = 0;
    while (start < word.length) {
      int end = word.length;
      int? curId;
      while (start < end) {
        final substr = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (vocab.containsKey(substr)) {
          curId = vocab[substr];
          break;
        }
        end--;
      }
      if (curId == null) {
        result.add(_unkId);
        break;
      }
      result.add(curId);
      start = end;
    }
    return result;
  }
}
