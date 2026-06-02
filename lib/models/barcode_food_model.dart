class BarcodeFoodModel {
  final String barcode;
  final String productName;
  final String? brandName;
  final String? imageUrl;
  final int? calories; // per 100g
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? sugar;
  final double? sodium; // mg per 100g
  final double? servingSize;
  final String servingUnit;
  final String? ingredientText;
  final bool isVerified;
  final DateTime cachedAt;

  const BarcodeFoodModel({
    required this.barcode,
    required this.productName,
    this.brandName,
    this.imageUrl,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.sugar,
    this.sodium,
    this.servingSize,
    this.servingUnit = 'g',
    this.ingredientText,
    this.isVerified = false,
    required this.cachedAt,
  });

  bool get hasNutrition => calories != null || protein != null || carbs != null;

  String get displayName =>
      productName.isNotEmpty ? productName : 'Unknown Product';

  String get displayBrand => brandName ?? '';

  /// Scale nutrients from per-100g to per-serving grams
  Map<String, dynamic> toFoodLogMap(double servingGrams) {
    final factor = servingGrams / 100.0;
    return {
      'calories': calories != null ? (calories! * factor).round() : 0,
      'protein': protein != null ? protein! * factor : 0.0,
      'carbs': carbs != null ? carbs! * factor : 0.0,
      'fat': fat != null ? fat! * factor : 0.0,
      'sugar': sugar != null ? sugar! * factor : 0.0,
      'sodium': sodium != null ? sodium! * factor : 0.0,
    };
  }

  /// Scale nutrients from per-100g to per-serving
  BarcodeFoodModel scaledToServing(double servingGrams) {
    final factor = servingGrams / 100.0;
    return copyWith(
      calories: calories != null ? (calories! * factor).round() : null,
      protein: protein != null ? protein! * factor : null,
      carbs: carbs != null ? carbs! * factor : null,
      fat: fat != null ? fat! * factor : null,
      sugar: sugar != null ? sugar! * factor : null,
      sodium: sodium != null ? sodium! * factor : null,
    );
  }

  factory BarcodeFoodModel.fromOpenFoodFacts(
    Map<String, dynamic> json,
    String barcode,
  ) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    double? n(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key];
      if (v == null) return null;
      return (v as num).toDouble();
    }

    int? cal() {
      final v =
          n('energy-kcal') ??
          (n('energy') != null ? n('energy')! / 4.184 : null);
      return v?.round();
    }

    return BarcodeFoodModel(
      barcode: barcode,
      productName:
          product['product_name'] ??
          product['product_name_en'] ??
          product['product_name_ms'] ??
          '',
      brandName: product['brands'],
      imageUrl: product['image_front_url'] ?? product['image_url'],
      calories: cal(),
      protein: n('proteins'),
      carbs: n('carbohydrates'),
      fat: n('fat'),
      sugar: n('sugars'),
      sodium: n('sodium') != null
          ? n('sodium')! * 1000
          : n('salt') != null
          ? n('salt')! * 400
          : null,
      servingSize: double.tryParse(
        product['serving_quantity']?.toString() ?? '',
      ),
      servingUnit: product['serving_unit'] ?? 'g',
      ingredientText:
          product['ingredients_text'] ?? product['ingredients_text_en'],
      isVerified: nutriments.isNotEmpty,
      cachedAt: DateTime.now(),
    );
  }

  BarcodeFoodModel copyWith({
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? sugar,
    double? sodium,
  }) => BarcodeFoodModel(
    barcode: barcode,
    productName: productName,
    brandName: brandName,
    imageUrl: imageUrl,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    sugar: sugar ?? this.sugar,
    sodium: sodium ?? this.sodium,
    servingSize: servingSize,
    servingUnit: servingUnit,
    ingredientText: ingredientText,
    isVerified: isVerified,
    cachedAt: cachedAt,
  );

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'productName': productName,
    'brandName': brandName,
    'imageUrl': imageUrl,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'sodium': sodium,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'ingredientText': ingredientText,
    'isVerified': isVerified,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory BarcodeFoodModel.fromJson(Map<String, dynamic> json) =>
      BarcodeFoodModel(
        barcode: json['barcode'] ?? '',
        productName: json['productName'] ?? '',
        brandName: json['brandName'],
        imageUrl: json['imageUrl'],
        calories: json['calories'],
        protein: (json['protein'] as num?)?.toDouble(),
        carbs: (json['carbs'] as num?)?.toDouble(),
        fat: (json['fat'] as num?)?.toDouble(),
        sugar: (json['sugar'] as num?)?.toDouble(),
        sodium: (json['sodium'] as num?)?.toDouble(),
        servingSize: (json['servingSize'] as num?)?.toDouble(),
        servingUnit: json['servingUnit'] ?? 'g',
        ingredientText: json['ingredientText'],
        isVerified: json['isVerified'] ?? false,
        cachedAt: DateTime.tryParse(json['cachedAt'] ?? '') ?? DateTime.now(),
      );
}

/// Result wrapper — separates success/failure cleanly
sealed class BarcodeLookupResult {
  const BarcodeLookupResult();
}

class BarcodeLookupSuccess extends BarcodeLookupResult {
  final BarcodeFoodModel food;
  const BarcodeLookupSuccess(this.food);
}

class BarcodeLookupNotFound extends BarcodeLookupResult {
  final String barcode;
  const BarcodeLookupNotFound(this.barcode);
}

class BarcodeLookupError extends BarcodeLookupResult {
  final String message;
  const BarcodeLookupError(this.message);
}
