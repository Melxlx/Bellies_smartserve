enum MovementType { stockIn, stockOut, wastage, damaged }

class InventoryMovementModel {
  final String id;
  final String productId;
  final String productCode;
  final String productName;
  final MovementType movementType;
  final String rawMovementType;
  final double quantity;
  final double previousQuantity;
  final double updatedQuantity;
  final String? reason;
  final String? userName;
  final DateTime createdAt;

  const InventoryMovementModel({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.movementType,
    required this.rawMovementType,
    required this.quantity,
    required this.previousQuantity,
    required this.updatedQuantity,
    required this.createdAt,
    this.reason,
    this.userName,
  });

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) {
    final movement = (json['movement_type']?.toString() ?? json['reference_type']?.toString() ?? 'STOCK_IN')
        .toUpperCase();

    final isOut = movement == 'STOCK_OUT' ||
        movement == 'MANUAL_STOCK_OUT' ||
        movement == 'ORDER_DEDUCTION' ||
        movement == 'WASTAGE' ||
        movement == 'DAMAGED';

    return InventoryMovementModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? json['ingredient_id']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? json['ingredient_code']?.toString() ?? json['code']?.toString() ?? 'ITEM',
      productName: json['product_name']?.toString() ?? json['ingredient_name']?.toString() ?? json['name']?.toString() ?? 'Inventory Item',
      movementType: isOut ? MovementType.stockOut : MovementType.stockIn,
      rawMovementType: movement,
      quantity: (json['quantity'] as num? ?? json['quantity_changed'] as num? ?? 0).toDouble().abs(),
      previousQuantity: (json['previous_quantity'] as num? ?? json['previous_qty'] as num? ?? 0).toDouble(),
      updatedQuantity: (json['updated_quantity'] as num? ?? json['new_quantity'] as num? ?? json['updated_qty'] as num? ?? 0).toDouble(),
      reason: json['reason']?.toString(),
      userName: json['user_name']?.toString() ?? json['performed_by']?.toString() ?? json['user_email']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get formattedMovementType {
    switch (rawMovementType) {
      case 'ORDER_DEDUCTION':
        return 'ORDER DEDUCTION';
      case 'MANUAL_STOCK_OUT':
      case 'STOCK_OUT':
        return 'STOCK OUT';
      case 'WASTAGE':
        return 'WASTAGE';
      case 'DAMAGED':
        return 'DAMAGED';
      default:
        return 'STOCK IN';
    }
  }

  // Compatibility aliases for existing activity-log consumers.
  String get ingredientName => productName;
  String get ingredientId => productId;
}
