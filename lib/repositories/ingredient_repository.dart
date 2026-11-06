import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sample_data.dart';
import '../models/ingredient_model.dart';
import '../models/inventory_movement_model.dart';
import 'notification_repository.dart';

class IngredientRepository {
  final _supabase = Supabase.instance.client;

  bool _isUuid(String? id) {
    if (id == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<List<IngredientModel>> getIngredients({
    String? category,
    String? searchQuery,
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase.from('ingredients').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,code.ilike.%$searchQuery%');
      }

      final response = await query.order('updated_at', ascending: false);
      final List list = response as List;
      final supabaseItems = list.map((json) => IngredientModel.fromJson(json)).toList();

      if (supabaseItems.isNotEmpty) {
        return supabaseItems;
      }

      // Check if initial seeding has already been performed
      final prefs = await SharedPreferences.getInstance();
      final hasSeeded = prefs.getBool('inventory_seeded_v4') ?? false;

      if (!hasSeeded) {
        await _seedDefaultIngredients();
        await prefs.setBool('inventory_seeded_v4', true);

        final seededResponse = await query.order('updated_at', ascending: false);
        final List seededList = seededResponse as List;
        return seededList.map((json) => IngredientModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint("Error fetching ingredients from Supabase: $e");
      return _filterSampleIngredients(category, searchQuery);
    }
  }

  Future<void> _seedDefaultIngredients() async {
    try {
      final defaultItems = [
        {
          'code': 'RICE-001',
          'ingredient_code': 'RICE-001',
          'name': 'Rice Grains (Sinandomeng)',
          'category': 'Grains',
          'unit': 'KILOGRAM',
          'current_quantity': 50.0,
          'reorder_level': 10.0,
          'average_unit_cost': 52.0,
          'is_active': true,
        },
        {
          'code': 'EGG-001',
          'ingredient_code': 'EGG-001',
          'name': 'Eggs (Large)',
          'category': 'Poultry',
          'unit': 'PIECE',
          'current_quantity': 120.0,
          'reorder_level': 30.0,
          'average_unit_cost': 7.0,
          'is_active': true,
        },
        {
          'code': 'MEAT-001',
          'ingredient_code': 'MEAT-001',
          'name': 'Marinated Beef Tapa',
          'category': 'Meat',
          'unit': 'KILOGRAM',
          'current_quantity': 15.0,
          'reorder_level': 5.0,
          'average_unit_cost': 280.0,
          'is_active': true,
        },
        {
          'code': 'MEAT-002',
          'ingredient_code': 'MEAT-002',
          'name': 'Sweet Pork Tocino',
          'category': 'Meat',
          'unit': 'KILOGRAM',
          'current_quantity': 3.0,
          'reorder_level': 5.0,
          'average_unit_cost': 240.0,
          'is_active': true,
        },
        {
          'code': 'MEAT-003',
          'ingredient_code': 'MEAT-003',
          'name': 'Chicken Meat',
          'category': 'Poultry',
          'unit': 'KILOGRAM',
          'current_quantity': 20.0,
          'reorder_level': 5.0,
          'average_unit_cost': 180.0,
          'is_active': true,
        },
        {
          'code': 'MEAT-004',
          'ingredient_code': 'MEAT-004',
          'name': 'Jumbo Hotdogs',
          'category': 'Meat',
          'unit': 'PIECE',
          'current_quantity': 0.0,
          'reorder_level': 15.0,
          'average_unit_cost': 12.0,
          'is_active': true,
        },
        {
          'code': 'NOOD-001',
          'ingredient_code': 'NOOD-001',
          'name': 'Korean Jin Ramen Packs',
          'category': 'Noodles',
          'unit': 'PACK',
          'current_quantity': 40.0,
          'reorder_level': 10.0,
          'average_unit_cost': 45.0,
          'is_active': true,
        },
        {
          'code': 'NOOD-002',
          'ingredient_code': 'NOOD-002',
          'name': 'Buldak Carbonara Packs',
          'category': 'Noodles',
          'unit': 'PACK',
          'current_quantity': 25.0,
          'reorder_level': 10.0,
          'average_unit_cost': 55.0,
          'is_active': true,
        },
        {
          'code': 'OIL-001',
          'ingredient_code': 'OIL-001',
          'name': 'Cooking Oil',
          'category': 'Oil & Fats',
          'unit': 'LITER',
          'current_quantity': 10.0,
          'reorder_level': 3.0,
          'average_unit_cost': 90.0,
          'is_active': true,
        },
        {
          'code': 'SPICE-001',
          'ingredient_code': 'SPICE-001',
          'name': 'Garlic & Seasonings',
          'category': 'Seasoning',
          'unit': 'KILOGRAM',
          'current_quantity': 8.0,
          'reorder_level': 2.0,
          'average_unit_cost': 120.0,
          'is_active': true,
        },
      ];

      await _supabase.from('ingredients').upsert(
        defaultItems,
        onConflict: 'code',
      );
    } catch (e) {
      debugPrint("Error seeding default ingredients: $e");
    }
  }

  List<IngredientModel> _filterSampleIngredients(
    String? category,
    String? searchQuery,
  ) {
    var items = List<IngredientModel>.from(SampleData.inventory);
    if (category != null && category != 'All') {
      items = items
          .where((i) => i.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      items = items
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.code.toLowerCase().contains(q),
          )
          .toList();
    }
    return items;
  }

  Future<void> saveIngredient(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    final fullPayload = Map<String, dynamic>.from(payload);
    fullPayload['is_active'] = fullPayload['is_active'] ?? true;
    fullPayload['updated_at'] = DateTime.now().toIso8601String();

    // Ensure both code and ingredient_code are populated for database schema compatibility
    if (fullPayload.containsKey('code') && fullPayload['code'] != null) {
      fullPayload['ingredient_code'] = fullPayload['code'];
    } else if (fullPayload.containsKey('ingredient_code') && fullPayload['ingredient_code'] != null) {
      fullPayload['code'] = fullPayload['ingredient_code'];
    }

    if (fullPayload.containsKey('unit') && fullPayload['unit'] != null) {
      fullPayload['unit'] = fullPayload['unit'].toString().toUpperCase();
    }

    final double newQty = (fullPayload['current_quantity'] as num? ?? 0).toDouble();
    final user = _supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email ?? 'System';

    try {
      if (id != null && id.isNotEmpty && _isUuid(id)) {
        final prev = await _supabase
            .from('ingredients')
            .select('current_quantity, code, name')
            .eq('id', id)
            .maybeSingle();

        final double prevQty = (prev?['current_quantity'] as num? ?? 0).toDouble();

        await _supabase
            .from('ingredients')
            .update(fullPayload)
            .eq('id', id);

        final double delta = newQty - prevQty;
        if (delta != 0) {
          final typeStr = delta > 0 ? 'STOCK_IN' : 'MANUAL_STOCK_OUT';
          await _supabase.from('inventory_movements').insert({
            'ingredient_id': id,
            'product_id': id,
            'product_code': fullPayload['code'] ?? prev?['code'] ?? '',
            'product_name': fullPayload['name'] ?? prev?['name'] ?? '',
            'movement_type': typeStr,
            'quantity': delta.abs(),
            'previous_quantity': prevQty,
            'updated_quantity': newQty,
            'new_quantity': newQty,
            'reference_type': typeStr,
            'performed_by': userName,
            'user_name': userName,
            'user_id': user?.id,
            'reason': 'Manual stock edit',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        final code = fullPayload['code'];
        if (code != null && code.toString().isNotEmpty) {
          final existing = await _supabase
              .from('ingredients')
              .select('id, current_quantity, code, name')
              .eq('code', code)
              .maybeSingle();

          if (existing != null && existing['id'] != null) {
            final double prevQty = (existing['current_quantity'] as num? ?? 0).toDouble();
            final String existingId = existing['id'].toString();

            await _supabase
                .from('ingredients')
                .update(fullPayload)
                .eq('id', existingId);

            final double delta = newQty - prevQty;
            if (delta != 0) {
              final typeStr = delta > 0 ? 'STOCK_IN' : 'MANUAL_STOCK_OUT';
              await _supabase.from('inventory_movements').insert({
                'ingredient_id': existingId,
                'product_id': existingId,
                'product_code': fullPayload['code'] ?? existing['code'] ?? '',
                'product_name': fullPayload['name'] ?? existing['name'] ?? '',
                'movement_type': typeStr,
                'quantity': delta.abs(),
                'previous_quantity': prevQty,
                'updated_quantity': newQty,
                'new_quantity': newQty,
                'reference_type': typeStr,
                'performed_by': userName,
                'user_name': userName,
                'user_id': user?.id,
                'reason': 'Manual stock edit',
                'created_at': DateTime.now().toIso8601String(),
              });
            }

            await checkProductAvailabilityFromInventory();
            return;
          }
        }

        final inserted = await _supabase
            .from('ingredients')
            .insert(fullPayload)
            .select('id, code, name')
            .single();

        final insertedId = inserted['id']?.toString();
        if (insertedId != null && newQty > 0) {
          await _supabase.from('inventory_movements').insert({
            'ingredient_id': insertedId,
            'product_id': insertedId,
            'product_code': inserted['code'] ?? '',
            'product_name': inserted['name'] ?? '',
            'movement_type': 'STOCK_IN',
            'quantity': newQty,
            'previous_quantity': 0,
            'updated_quantity': newQty,
            'new_quantity': newQty,
            'reference_type': 'STOCK_IN',
            'performed_by': userName,
            'user_name': userName,
            'user_id': user?.id,
            'reason': 'Initial ingredient creation',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
      await checkProductAvailabilityFromInventory();
    } catch (e) {
      debugPrint("Save ingredient Supabase error: $e");
      rethrow;
    }
  }

  Future<void> updateIngredientQuantity(
    String id,
    double newQuantity, {
    String? code,
  }) async {
    String ingName = 'Ingredient';
    String ingCode = '';
    double reorderLvl = 10.0;
    double prevQty = 0.0;
    final user = _supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email ?? 'System';

    try {
      if (_isUuid(id)) {
        final existing = await _supabase
            .from('ingredients')
            .select('name, code, current_quantity, reorder_level')
            .eq('id', id)
            .maybeSingle();

        if (existing != null) {
          ingName = existing['name']?.toString() ?? ingName;
          ingCode = existing['code']?.toString() ?? ingCode;
          prevQty = (existing['current_quantity'] as num? ?? 0).toDouble();
          reorderLvl = (existing['reorder_level'] as num?)?.toDouble() ?? reorderLvl;
        }

        await _supabase
            .from('ingredients')
            .update({
              'current_quantity': newQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);

        final double delta = newQuantity - prevQty;
        if (delta != 0) {
          final typeStr = delta > 0 ? 'STOCK_IN' : 'MANUAL_STOCK_OUT';
          await _supabase.from('inventory_movements').insert({
            'ingredient_id': id,
            'product_id': id,
            'product_code': ingCode,
            'product_name': ingName,
            'movement_type': typeStr,
            'quantity': delta.abs(),
            'previous_quantity': prevQty,
            'updated_quantity': newQuantity,
            'new_quantity': newQuantity,
            'reference_type': typeStr,
            'performed_by': userName,
            'user_name': userName,
            'user_id': user?.id,
            'reason': 'Stock quantity adjustment',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else if (code != null && code.isNotEmpty) {
        final res = await _supabase
            .from('ingredients')
            .update({
              'current_quantity': newQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('code', code)
            .select('name, reorder_level')
            .maybeSingle();
        if (res != null) {
          ingName = res['name']?.toString() ?? ingName;
          reorderLvl = (res['reorder_level'] as num?)?.toDouble() ?? reorderLvl;
        }
      }
      await checkProductAvailabilityFromInventory();

      if (newQuantity <= 0) {
        await NotificationRepository().addNotification(
          title: 'Ingredient Out of Stock',
          message: '$ingName: This ingredient is out of stock and required for preparation.',
          category: 'OUT_OF_STOCK',
          route: '/staff/inventory',
          targetRole: 'KITCHEN,OWNER',
        );
      } else if (newQuantity <= reorderLvl) {
        await NotificationRepository().addNotification(
          title: 'Low Ingredient Stock',
          message: '$ingName: Ingredient stock level is running low.',
          category: 'LOW_STOCK',
          route: '/staff/inventory',
          targetRole: 'KITCHEN,OWNER',
        );
      }
    } catch (e) {
      debugPrint("Update quantity error: $e");
      rethrow;
    }
  }

  Future<void> recordIngredientMovement({
    required String ingredientId,
    required MovementType movementType,
    required double quantity,
    String? reason,
  }) async {
    try {
      final typeStr = switch (movementType) {
        MovementType.stockIn => 'STOCK_IN',
        MovementType.stockOut => 'MANUAL_STOCK_OUT',
        MovementType.wastage => 'WASTAGE',
        MovementType.damaged => 'DAMAGED',
      };

      if (_isUuid(ingredientId)) {
        await _supabase.rpc(
          'record_ingredient_inventory_movement',
          params: {
            'p_ingredient_id': ingredientId,
            'p_movement_type': typeStr,
            'p_quantity': quantity,
            'p_reason': reason,
          },
        );
      } else {
        final ing = await _supabase
            .from('ingredients')
            .select('current_quantity')
            .eq('id', ingredientId)
            .maybeSingle();

        if (ing != null) {
          final current = (ing['current_quantity'] as num? ?? 0).toDouble();
          final delta = movementType == MovementType.stockIn ? quantity : -quantity;
          final updated = (current + delta).clamp(0.0, double.infinity);

          await _supabase
              .from('ingredients')
              .update({
                'current_quantity': updated,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', ingredientId);
        }
      }
      await checkProductAvailabilityFromInventory();
    } catch (e) {
      debugPrint("Error recording ingredient movement: $e");
      rethrow;
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      if (_isUuid(id)) {
        await _supabase
            .from('ingredients')
            .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', id);
      }
      await checkProductAvailabilityFromInventory();
    } catch (e) {
      debugPrint("Toggle active error: $e");
      rethrow;
    }
  }

  Future<void> checkProductAvailabilityFromInventory() async {
    try {
      await _supabase.rpc('update_product_availability_from_inventory');
    } catch (e) {
      debugPrint("Error updating product availability: $e");
    }
  }

  Future<void> deleteIngredients(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('ingredients').delete().inFilter('id', ids);
      await checkProductAvailabilityFromInventory();
    } catch (e) {
      debugPrint("Delete ingredients error: $e");
      rethrow;
    }
  }
}
