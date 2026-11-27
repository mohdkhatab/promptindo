import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._supabase);

  final SupabaseClient _supabase;

  Category _map(Map<String, dynamic> row) =>
      Category.fromMap(row, id: asString(row['id']));

  @override
  Future<List<Category>> fetchCategories() async {
    try {
      final rows = await _supabase
          .from('categories')
          .select()
          .order('sort_order', ascending: true);
      return rows.map(_map).toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Stream<List<Category>> watchCategories() => _supabase
      .from('categories')
      .stream(primaryKey: ['id'])
      .order('sort_order', ascending: true)
      .map((rows) => rows.map(_map).toList());

  @override
  Future<Category?> getCategory(String id) async {
    try {
      final row = await _supabase
          .from('categories')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }
}
