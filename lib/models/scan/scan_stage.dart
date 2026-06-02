enum ScanStage {
  idle,
  preparingImage,
  enhancingQuality,
  extractingText,
  analyzingIngredients,
  generatingInsights,
  done,
}

extension ScanStageX on ScanStage {
  String get label {
    switch (this) {
      case ScanStage.idle:
        return '';
      case ScanStage.preparingImage:
        return 'Preparing image...';
      case ScanStage.enhancingQuality:
        return 'Enhancing quality...';
      case ScanStage.extractingText:
        return 'Extracting text...';
      case ScanStage.analyzingIngredients:
        return 'Analysing ingredients...';
      case ScanStage.generatingInsights:
        return 'Generating insights...';
      case ScanStage.done:
        return 'Done!';
    }
  }

  String get subtitle {
    switch (this) {
      case ScanStage.preparingImage:
        return 'Correcting rotation and exposure';
      case ScanStage.enhancingQuality:
        return 'Sharpening text and reducing noise';
      case ScanStage.extractingText:
        return 'Reading ingredient and nutrition panels';
      case ScanStage.analyzingIngredients:
        return 'Checking for amino spiking patterns';
      case ScanStage.generatingInsights:
        return 'Structuring nutrition data';
      default:
        return '';
    }
  }

  double get progress {
    switch (this) {
      case ScanStage.idle:
        return 0.0;
      case ScanStage.preparingImage:
        return 0.15;
      case ScanStage.enhancingQuality:
        return 0.32;
      case ScanStage.extractingText:
        return 0.55;
      case ScanStage.analyzingIngredients:
        return 0.78;
      case ScanStage.generatingInsights:
        return 0.92;
      case ScanStage.done:
        return 1.0;
    }
  }

  bool get isActive => this != ScanStage.idle && this != ScanStage.done;
}
