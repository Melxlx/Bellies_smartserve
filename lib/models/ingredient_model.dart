enum IngredientUnit {
  gram,
  kilogram,
  milliliter,
  liter,
  piece,
  pack,
  bottle,
  can,
  tray,
}

enum InventoryStatus { available, lowStock, outOfStock, expiringSoon }

class IngredientModel {
  final String id;
  final String code;
  final String name;
  final String category;
  final IngredientUnit unit;
  final double currentQuantity;
  final double reorderLevel;
  final double averageUnitCost;
  final DateTime? nearestExpiryDate;
  final bool isActive;
  final DateTime? lastUpdated;

  IngredientModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentQuantity,
    required this.reorderLevel,
    required this.averageUnitCost,
    this.nearestExpiryDate,
    this.isActive = true,
    this.lastUpdated,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    return IngredientModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['ingredient_code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      category: json['category']?.toString() ?? 'General',
      unit: IngredientUnit.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['unit'] as String? ?? 'piece').toLowerCase(),
        orElse: () => IngredientUnit.piece,
      ),
      currentQuantity: (json['current_quantity'] as num? ?? 0).toDouble(),
      reorderLevel: (json['reorder_level'] as num? ?? 0).toDouble(),
      averageUnitCost: (json['average_unit_cost'] as num? ?? 0).toDouble(),
      nearestExpiryDate: json['nearest_expiry_date'] != null
          ? DateTime.parse(json['nearest_expiry_date'])
          : null,
      isActive: json['is_active'] ?? true,
      lastUpdated: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  IngredientModel copyWith({
    double? quantity,
    DateTime? lastUpdated,
    String? id,
    String? code,
    String? name,
    String? category,
    IngredientUnit? unit,
    double? reorderLevel,
    double? averageUnitCost,
    DateTime? nearestExpiryDate,
    bool? isActive,
  }) {
    return IngredientModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentQuantity: quantity ?? currentQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      averageUnitCost: averageUnitCost ?? this.averageUnitCost,
      nearestExpiryDate: nearestExpiryDate ?? this.nearestExpiryDate,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  double get quantity => currentQuantity;
  String get itemName => name;

  InventoryStatus get status {
    if (currentQuantity <= 0) return InventoryStatus.outOfStock;
    if (nearestExpiryDate != null &&
        nearestExpiryDate!.difference(DateTime.now()).inDays <= 7) {
      return InventoryStatus.expiringSoon;
    }
    if (currentQuantity <= reorderLevel) return InventoryStatus.lowStock;
    return InventoryStatus.available;
  }
}
