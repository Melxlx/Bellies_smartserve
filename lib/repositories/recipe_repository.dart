import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_model.dart';

class RecipeRepository {
  final SupabaseClient _supabase;

  RecipeRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  // In-memory fallback map for offline / local recipe storage
  static final Map<String, List<RecipeItemModel>> _localRecipes = {};

  // Fetch recipe items for a given product
  Future<List<RecipeItemModel>> getRecipeForProduct(
    String productId, {
    String? productName,
  }) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .select('*, ingredients(*)')
          .eq('product_id', productId);

      final List list = response as List;
      final items = list.map((json) => RecipeItemModel.fromJson(json)).toList();
      if (items.isNotEmpty) {
        _localRecipes[productId] = items;
        return items;
      }
    } catch (e) {
      debugPrint("Error loading product recipe: $e");
    }

    if (_localRecipes.containsKey(productId) && _localRecipes[productId]!.isNotEmpty) {
      return _localRecipes[productId]!;
    }

    return _generateDefaultRecipe(productId, productName);
  }

  List<RecipeItemModel> _generateDefaultRecipe(String productId, String? productName) {
    if (productName == null || productName.trim().isEmpty) return [];

    final name = productName.toLowerCase();
    final List<RecipeItemModel> recipe = [];

    if (name.contains('noodle') ||
        name.contains('noodles') ||
        name.contains('ramen') ||
        name.contains('buldak') ||
        name.contains('pancit') ||
        name.contains('pasta') ||
        name.contains('spaghetti') ||
        name.contains('canton')) {
      recipe.add(RecipeItemModel(
        id: 'def_noodle',
        productId: productId,
        ingredientId: 'I007',
        ingredientName: 'Korean Jin Ramen / Buldak Pack',
        ingredientCode: 'NOOD-001',
        unit: 'PACK',
        quantityRequired: 1,
      ));
      if (name.contains('egg') || name.contains('overload') || name.contains('special')) {
        recipe.add(RecipeItemModel(
          id: 'def_egg',
          productId: productId,
          ingredientId: 'I002',
          ingredientName: 'Eggs (Large)',
          ingredientCode: 'EGG-001',
          unit: 'PCS',
          quantityRequired: 1,
        ));
      }
    } else if (name.contains('lugaw') || name.contains('goto') || name.contains('arroz caldo')) {
      recipe.add(RecipeItemModel(
        id: 'def_rice',
        productId: productId,
        ingredientId: 'I001',
        ingredientName: 'Rice Grains (Sinandomeng)',
        ingredientCode: 'RICE-001',
        unit: 'KG',
        quantityRequired: 0.15,
      ));
      recipe.add(RecipeItemModel(
        id: 'def_spice',
        productId: productId,
        ingredientId: 'I010',
        ingredientName: 'Garlic & Seasonings',
        ingredientCode: 'SPICE-001',
        unit: 'KG',
        quantityRequired: 0.02,
      ));
      if (name.contains('egg') || name.contains('overload')) {
        recipe.add(RecipeItemModel(
          id: 'def_egg',
          productId: productId,
          ingredientId: 'I002',
          ingredientName: 'Eggs (Large)',
          ingredientCode: 'EGG-001',
          unit: 'PCS',
          quantityRequired: 1,
        ));
      }
    } else if (name.contains('silog') ||
        name.contains('tapsilog') ||
        name.contains('tocilog') ||
        name.contains('hotsilog') ||
        name.contains('bangsilog') ||
        name.contains('chicksilog') ||
        name.contains('porksilog') ||
        name.contains('sisig')) {
      String meatName = 'Marinated Beef Tapa / Meat Portion';
      if (name.contains('tocilog')) meatName = 'Sweet Pork Tocino';
      if (name.contains('hotsilog')) meatName = 'Jumbo Hotdogs';
      if (name.contains('sisig')) meatName = 'Pork Sisig Portion';

      recipe.add(RecipeItemModel(
        id: 'def_meat',
        productId: productId,
        ingredientId: 'I003',
        ingredientName: meatName,
        ingredientCode: 'MEAT-001',
        unit: 'KG',
        quantityRequired: 0.15,
      ));
      recipe.add(RecipeItemModel(
        id: 'def_rice',
        productId: productId,
        ingredientId: 'I001',
        ingredientName: 'Rice Grains (Sinandomeng)',
        ingredientCode: 'RICE-001',
        unit: 'KG',
        quantityRequired: 0.15,
      ));
      recipe.add(RecipeItemModel(
        id: 'def_egg',
        productId: productId,
        ingredientId: 'I002',
        ingredientName: 'Eggs (Large)',
        ingredientCode: 'EGG-001',
        unit: 'PCS',
        quantityRequired: 1,
      ));
    } else if (name.contains('chicken') || name.contains('wings') || name.contains('fillet')) {
      recipe.add(RecipeItemModel(
        id: 'def_chicken',
        productId: productId,
        ingredientId: 'I008',
        ingredientName: 'Fresh Chicken Cuts',
        ingredientCode: 'MEAT-005',
        unit: 'KG',
        quantityRequired: 0.20,
      ));
    } else if (name.contains('coffee') ||
        name.contains('tea') ||
        name.contains('drink') ||
        name.contains('beverage') ||
        name.contains('juice') ||
        name.contains('shake')) {
      recipe.add(RecipeItemModel(
        id: 'def_drink',
        productId: productId,
        ingredientId: 'I009',
        ingredientName: 'Beverage Syrup & Powder',
        ingredientCode: 'DRINK-001',
        unit: 'KG',
        quantityRequired: 0.05,
      ));
    } else if (name.contains('rice') || name.contains('kanin') || name.contains('bowl')) {
      recipe.add(RecipeItemModel(
        id: 'def_gen_rice',
        productId: productId,
        ingredientId: 'I001',
        ingredientName: 'Rice Grains (Sinandomeng)',
        ingredientCode: 'RICE-001',
        unit: 'KG',
        quantityRequired: 0.15,
      ));
    }

    return recipe;
  }

  // Save / overwrite recipe for a given product
  Future<void> saveRecipeForProduct(
    String productId,
    List<RecipeItemModel> items,
  ) async {
    _localRecipes[productId] = List.from(items);

    try {
      // 1. Clear existing recipe items for product
      await _supabase
          .from('product_recipes')
          .delete()
          .eq('product_id', productId);

      // 2. Insert new items if non-empty
      if (items.isNotEmpty) {
        final payload = items
            .map((item) => {
                  'product_id': productId,
                  'ingredient_id': item.ingredientId,
                  'quantity_required': item.quantityRequired,
                })
            .toList();

        await _supabase.from('product_recipes').insert(payload);
      }
      await _supabase.rpc('update_product_availability_from_inventory');
    } catch (e) {
      debugPrint("Error saving product recipe to Supabase: $e");
    }
  }

  // Atomically deduct ingredients for an order via Supabase RPC
  Future<void> deductIngredientsForOrder(String orderId) async {
    try {
      await _supabase.rpc(
        'deduct_order_ingredients',
        params: {'p_order_id': orderId},
      );
      await _supabase.rpc('update_product_availability_from_inventory');
    } catch (e) {
      debugPrint("Error calling deduct_order_ingredients RPC: $e");
    }
  }
}
