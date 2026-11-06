import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final _supabase = Supabase.instance.client;

  Future<List<CategoryModel>> getCategories({bool activeOnly = true}) async {
    var query = _supabase.from('categories').select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('display_order', ascending: true);
    return (response as List).map((json) => CategoryModel.fromJson(json)).toList();
  }

  Future<void> saveCategory(CategoryModel category) async {
    if (category.id.isEmpty) {
      await _supabase.from('categories').insert(category.toJson());
    } else {
      await _supabase.from('categories').update(category.toJson()).eq('id', category.id);
    }
  }

  Future<void> toggleCategoryActive(String id, bool isActive) async {
    await _supabase.from('categories').update({'is_active': isActive}).eq('id', id);
  }
}
