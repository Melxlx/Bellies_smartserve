import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_movement_model.dart';

class InventoryRepository {
  final _supabase = Supabase.instance.client;

  Future<void> recordMovement({
    required String productId,
    required MovementType movementType,
    required double quantity,
    String? reason,
  }) async {
    try {
      await _supabase.rpc(
        'record_product_inventory_movement',
        params: {
          'p_product_id': productId,
          'p_movement_type': movementType.name == 'stockIn'
              ? 'STOCK_IN'
              : movementType.name == 'stockOut'
              ? 'MANUAL_STOCK_OUT'
              : movementType.name.toUpperCase(),
          'p_quantity': quantity,
          'p_reason': reason,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw StateError(
          'Product inventory migration is not applied in Supabase. '
          'Apply 20260921223000_product_based_inventory.sql first.',
        );
      }
      rethrow;
    }
  }

  Future<List<InventoryMovementModel>> getMovementHistory({
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    var query = _supabase.from('inventory_movements').select();

    if (productId != null) {
      query = query.eq('product_id', productId);
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return (response as List)
        .map((json) => InventoryMovementModel.fromJson(json))
        .toList();
  }
}
