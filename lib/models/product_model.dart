import 'category_model.dart';

enum ProductStatus { available, unavailable, archived }

enum InventoryStatus { inStock, lowStock, outOfStock }

class ProductModel {
  final String id;
  final String sku;
  final String productCode;
  final String name;
  final String? description;
  final double sellingPrice;
  final double estimatedCost;
  final String categoryId;
  final ProductStatus status;
  final String? imagePath;
  final DateTime createdAt;
  final CategoryModel? category;
  final String? stockItemId;
  final String inventoryUnit;
  final double inventoryQuantity;
  final double inventoryReorderLevel;
  final DateTime? inventoryUpdatedAt;

  ProductModel({
    required this.id,
    required this.sku,
    this.productCode = '',
    required this.name,
    this.description,
    required this.sellingPrice,
    required this.estimatedCost,
    required this.categoryId,
    required this.status,
    this.imagePath,
    required this.createdAt,
    this.category,
    this.stockItemId,
    this.inventoryUnit = 'PIECE',
    this.inventoryQuantity = 0,
    this.inventoryReorderLevel = 0,
    this.inventoryUpdatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Product',
      description: json['description']?.toString(),
      sellingPrice: (json['selling_price'] as num? ?? 0).toDouble(),
      estimatedCost: (json['estimated_cost'] as num? ?? 0).toDouble(),
      categoryId: json['category_id']?.toString() ?? '',
      status: ProductStatus.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (json['status'] as String? ?? 'available').toLowerCase(),
        orElse: () => ProductStatus.available,
      ),
      imagePath: json['image_path']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      category: json['categories'] != null
          ? CategoryModel.fromJson(json['categories'])
          : null,
      stockItemId: json['stock_item_id']?.toString(),
      inventoryUnit: json['inventory_unit']?.toString() ?? 'PIECE',
      inventoryQuantity: (json['inventory_quantity'] as num? ?? 0).toDouble(),
      inventoryReorderLevel: (json['inventory_reorder_level'] as num? ?? 0)
          .toDouble(),
      inventoryUpdatedAt: json['inventory_updated_at'] != null
          ? DateTime.tryParse(json['inventory_updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description?.trim(),
      'selling_price': sellingPrice,
      'estimated_cost': estimatedCost,
      'category_id': categoryId,
      'status': status.name.toUpperCase(),
      'image_path': imagePath,
      'stock_item_id': stockItemId,
    };
  }

  ProductModel copyWith({
    String? sku,
    String? productCode,
    String? name,
    String? description,
    double? sellingPrice,
    double? estimatedCost,
    String? categoryId,
    ProductStatus? status,
    String? imagePath,
    CategoryModel? category,
    String? stockItemId,
    String? inventoryUnit,
    double? inventoryQuantity,
    double? inventoryReorderLevel,
    DateTime? inventoryUpdatedAt,
  }) {
    return ProductModel(
      id: id,
      sku: sku ?? this.sku,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      description: description ?? this.description,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
      category: category ?? this.category,
      stockItemId: stockItemId ?? this.stockItemId,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryQuantity: inventoryQuantity ?? this.inventoryQuantity,
      inventoryReorderLevel:
          inventoryReorderLevel ?? this.inventoryReorderLevel,
      inventoryUpdatedAt: inventoryUpdatedAt ?? this.inventoryUpdatedAt,
    );
  }

  InventoryStatus get inventoryStatus {
    if (inventoryQuantity <= 0) return InventoryStatus.outOfStock;
    if (inventoryQuantity <= inventoryReorderLevel) {
      return InventoryStatus.lowStock;
    }
    return InventoryStatus.inStock;
  }
}
