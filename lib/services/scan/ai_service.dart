import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cal0appv2/services/logs/debuglog_services.dart';

class AminoSpikingAI {
  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  final int maxLength = 128; // Matches your Colab export

  // Load Model & Dictionary when app starts
  Future<void> initialize() async {
    try {
      // 1. Load the Brain (TFLite Model)
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/distilbert_model.tflite',
      );

      // 2. Load the Dictionary (tokenizer.json)
      final jsonString = await rootBundle.loadString(
        'assets/ml/tokenizer.json',
      );
      final jsonMap = jsonDecode(jsonString);
      Map<String, dynamic> rawVocab = jsonMap['model']['vocab'];
      rawVocab.forEach((key, value) {
        _vocab[key] = value as int;
      });

      LogService.info(
        "✅ AI Initialized: Model & ${_vocab.length} words loaded.",
      );
    } catch (e) {
      LogService.error("❌ Failed to load AI: $e");
    }
  }

  // Run Inference
  Future<bool> analyzeIngredients(String text) async {
    if (_interpreter == null || _vocab.isEmpty) return false;

    // 1. Tokenize text into 128 numbers
    List<int> inputIds = _tokenize(text);

    // 2. Format Input & Output shapes for TFLite
    var input = [inputIds]; // Shape: [1, 128]
    var output = [
      [0.0, 0.0],
    ]; // Shape: [1, 2] (Authentic, Spiked)

    // 3. Run the Model
    _interpreter!.run(input, output);

    double authenticScore = output[0][0];
    double spikedScore = output[0][1];

    LogService.info(
      "AI Scores -> Authentic: $authenticScore | Spiked: $spikedScore",
    );

    // 4. Return True if Spiked is higher
    return spikedScore > authenticScore;
  }

  // Converts words to IDs
  List<int> _tokenize(String text) {
    String cleanText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    List<String> words = cleanText.split(RegExp(r'\s+'));

    List<int> inputIds = [101]; // [CLS] token

    for (String word in words) {
      if (word.isEmpty) continue;
      inputIds.add(
        _vocab.containsKey(word) ? _vocab[word]! : 100,
      ); // 100 = [UNK]
      if (inputIds.length >= maxLength - 1) break;
    }

    inputIds.add(102); // [SEP] token

    while (inputIds.length < maxLength) {
      inputIds.add(0); // [PAD] tokens
    }

    return inputIds;
  }

  void dispose() {
    _interpreter?.close();
  }
}
