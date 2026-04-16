class ScanLogModel {
  String _supplementId,
      _userId,
      _supplementName,
      _brandName,
      _scannedIngredients,
      _analysisResult,
      _flaggedIngredients,
      _imagePath,
      _barcode;
  DateTime _scanTimestamp;

  ScanLogModel({
    required String supplementId,
    required String userId,
    required String supplementName,
    required String brandName,
    required String scannedIngredients,
    required String analysisResult,
    required String flaggedIngredients,
    required String imagePath,
    required String barcode,
    required DateTime scanTimestamp,
  }) : _supplementId = supplementId,
       _userId = userId,
       _supplementName = supplementName,
       _brandName = brandName,
       _scannedIngredients = scannedIngredients,
       _analysisResult = analysisResult,
       _flaggedIngredients = flaggedIngredients,
       _imagePath = imagePath,
       _barcode = barcode,
       _scanTimestamp = scanTimestamp;

  // Getters
  String get supplementId => _supplementId;
  String get userId => _userId;
  String get supplementName => _supplementName;
  String get brandName => _brandName;
  String get scannedIngredients => _scannedIngredients;
  String get analysisResult => _analysisResult;
  String get flaggedIngredients => _flaggedIngredients;
  String get imagePath => _imagePath;
  String get barcode => _barcode;
  DateTime get scanTimestamp => _scanTimestamp;

  // Setters
  set supplementId(String value) => _supplementId = value;
  set userId(String value) => _userId = value;
  set supplementName(String value) => _supplementName = value;
  set brandName(String value) => _brandName = value;
  set scannedIngredients(String value) => _scannedIngredients = value;
  set analysisResult(String value) => _analysisResult = value;
  set flaggedIngredients(String value) => _flaggedIngredients = value;
  set imagePath(String value) => _imagePath = value;
  set barcode(String value) => _barcode = value;
  set scanTimestamp(DateTime value) => _scanTimestamp = value;

  factory ScanLogModel.fromMap(Map<String, dynamic> map) => ScanLogModel(
    supplementId: map['supplementId'],
    userId: map['userId'],
    supplementName: map['supplementName'],
    brandName: map['brandName'],
    scannedIngredients: map['scannedIngredients'],
    analysisResult: map['analysisResult'],
    flaggedIngredients: map['flaggedIngredients'],
    imagePath: map['imagePath'],
    barcode: map['barcode'],
    scanTimestamp: DateTime.parse(map['scanTimestamp']),
  );

  Map<String, dynamic> toMap() => {
    'supplementId': _supplementId,
    'userId': _userId,
    'supplementName': _supplementName,
    'brandName': _brandName,
    'scannedIngredients': _scannedIngredients,
    'analysisResult': _analysisResult,
    'flaggedIngredients': _flaggedIngredients,
    'imagePath': _imagePath,
    'barcode': _barcode,
    'scanTimestamp': _scanTimestamp.toIso8601String(),
  };
}
