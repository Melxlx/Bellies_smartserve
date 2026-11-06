import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../services/local_storage_service.dart';

class ProductRepository {
  final _supabase = Supabase.instance.client;
  final _localStorage = LocalStorageService();

  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? searchQuery,
    ProductStatus? status,
  }) async {
    var query = _supabase.from('products').select('*, categories(*)');

    if (categoryId != null && categoryId != 'All') {
      query = query.eq('category_id', categoryId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('name.ilike.%$searchQuery%,sku.ilike.%$searchQuery%');
    }

    if (status != null) {
      query = query.eq('status', status.name.toUpperCase());
    } else {
      query = query.neq('status', ProductStatus.archived.name.toUpperCase());
    }

    final response = await query.order('name', ascending: true);
    final products = (response as List)
        .map((json) => ProductModel.fromJson(json))
        .where((p) => p.name.trim().toLowerCase() != 'korean noodles')
        .toList();

    if (categoryId == null && (searchQuery == null || searchQuery.isEmpty)) {
      _localStorage.cacheProducts(products);
    }

    return products;
  }

  Future<void> saveProduct(ProductModel product) async {
    if (product.id.isEmpty) {
      await _supabase.from('products').insert(product.toJson());
    } else {
      await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);
    }
  }

  Future<void> updateStatus(String id, ProductStatus status) async {
    await _supabase
        .from('products')
        .update({'status': status.name.toUpperCase()})
        .eq('id', id);
  }

  Future<List<ProductModel>> getInventoryProducts({
    String? searchQuery,
    String? categoryId,
    bool includeArchived = false,
  }) async {
    var query = _supabase.from('products').select('*, categories(*)');

    if (!includeArchived) {
      query = query.neq('status', ProductStatus.archived.name.toUpperCase());
    }
    if (categoryId != null && categoryId != 'All') {
      query = query.eq('category_id', categoryId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or(
        'name.ilike.%$term%,product_code.ilike.%$term%,sku.ilike.%$term%',
      );
    }

    final response = await query.order('name', ascending: true);
    return (response as List)
        .map((json) => ProductModel.fromJson(json))
        .toList();
  }

  Future<ProductModel> saveInventoryProduct({
    String? id,
    required String name,
    required String categoryId,
    required String unit,
    required double reorderLevel,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'category_id': categoryId,
      'inventory_unit': unit.toUpperCase(),
      'inventory_reorder_level': reorderLevel,
    };

    if (id == null || id.isEmpty) {
      final response = await _supabase
          .from('products')
          .insert({
            ...payload,
            'status': ProductStatus.available.name.toUpperCase(),
            'sku': 'INV-${DateTime.now().microsecondsSinceEpoch}',
            'selling_price': 0,
            'estimated_cost': 0,
          })
          .select('*, categories(*)')
          .single();
      return ProductModel.fromJson(response);
    }

    final response = await _supabase
        .from('products')
        .update(payload)
        .eq('id', id)
        .select('*, categories(*)')
        .single();
    return ProductModel.fromJson(response);
  }

  Future<Map<String, bool>> getBatchStockAvailability(List<String> productIds) async {
    final Map<String, bool> result = {};
    if (productIds.isEmpty) return result;

    try {
      await _supabase.rpc('update_product_availability_from_inventory');
    } catch (_) {}

    try {
      final prodsRes = await _supabase
          .from('products')
          .select('id, status, inventory_quantity')
          .inFilter('id', productIds);

      for (var p in (prodsRes as List)) {
        final id = p['id'].toString();
        final status = (p['status'] ?? '').toString().toUpperCase();
        if (status == 'UNAVAILABLE' || status == 'ARCHIVED' || status == 'OUT_OF_STOCK') {
          result[id] = false;
        } else {
          result[id] = true;
        }
      }

      final recipesRes = await _supabase
          .from('product_recipes')
          .select('product_id, quantity_required, ingredients(*)')
          .inFilter('product_id', productIds);

      for (var row in (recipesRes as List)) {
        final productId = row['product_id'].toString();
        if (result[productId] == false) continue;

        final double requiredPerUnit = (row['quantity_required'] as num? ?? 1).toDouble();
        final ingData = row['ingredients'] as Map<String, dynamic>?;

        if (ingData != null) {
          final double currentQty = (ingData['current_quantity'] as num? ?? 0).toDouble();
          final bool isActive = ingData['is_active'] ?? true;

          if (!isActive || currentQty < requiredPerUnit) {
            result[productId] = false;
          }
        }
      }

      _localStorage.updateStockCache(result);
      return result;
    } catch (e) {
      for (var id in productIds) {
        result.putIfAbsent(id, () => _localStorage.isProductAvailable(id) ?? true);
      }
      return result;
    }
  }

  Future<bool> checkStockAvailability(String productId, int quantity) async {
    try {
      await _supabase.rpc('update_product_availability_from_inventory');
    } catch (_) {}

    try {
      final prodRes = await _supabase
          .from('products')
          .select('status, inventory_quantity')
          .eq('id', productId)
          .maybeSingle();

      if (prodRes == null) return false;
      final statusStr = (prodRes['status'] ?? '').toString().toUpperCase();
      if (statusStr == 'UNAVAILABLE' || statusStr == 'ARCHIVED' || statusStr == 'OUT_OF_STOCK') {
        return false;
      }

      final recipeRes = await _supabase
          .from('product_recipes')
          .select('quantity_required, ingredients(*)')
          .eq('product_id', productId);

      final List recipes = recipeRes as List;
      for (var row in recipes) {
        final double requiredPerUnit = (row['quantity_required'] as num? ?? 1).toDouble();
        final double totalRequired = requiredPerUnit * quantity;

        final ingData = row['ingredients'] as Map<String, dynamic>?;
        if (ingData != null) {
          final double currentQty = (ingData['current_quantity'] as num? ?? 0).toDouble();
          final bool isActive = ingData['is_active'] ?? true;

          if (!isActive || currentQty < totalRequired) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      return true;
    }
  }
}
