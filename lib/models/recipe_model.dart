class RecipeItemModel {
  final String id;
  final String productId;
  final String ingredientId;
  final String ingredientName;
  final String ingredientCode;
  final String unit;
  final double quantityRequired;

  RecipeItemModel({
    required this.id,
    required this.productId,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientCode,
    required this.unit,
    required this.quantityRequired,
  });

  factory RecipeItemModel.fromJson(Map<String, dynamic> json) {
    final ingMap = json['ingredients'] as Map<String, dynamic>?;

    return RecipeItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      ingredientId: json['ingredient_id']?.toString() ?? '',
      ingredientName: ingMap?['name']?.toString() ?? json['ingredient_name']?.toString() ?? 'Ingredient',
      ingredientCode: ingMap?['code']?.toString() ?? json['ingredient_code']?.toString() ?? '',
      unit: ingMap?['unit']?.toString() ?? json['unit']?.toString() ?? 'unit',
      quantityRequired: (json['quantity_required'] as num? ?? 1).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'product_id': productId,
      'ingredient_id': ingredientId,
      'quantity_required': quantityRequired,
    };
  }

  RecipeItemModel copyWith({
    String? id,
    String? productId,
    String? ingredientId,
    String? ingredientName,
    String? ingredientCode,
    String? unit,
    double? quantityRequired,
  }) {
    return RecipeItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ingredientId: ingredientId ?? this.ingredientId,
      ingredientName: ingredientName ?? this.ingredientName,
      ingredientCode: ingredientCode ?? this.ingredientCode,
      unit: unit ?? this.unit,
      quantityRequired: quantityRequired ?? this.quantityRequired,
    );
  }
}
