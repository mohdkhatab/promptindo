import '../domain/category.dart';

/// Category contract — read-only for regular users (writes are admin-only in
/// firestore.rules and go through the `adminSaveCategory` callable).
abstract interface class CategoryRepository {
  Future<List<Category>> fetchCategories();

  Stream<List<Category>> watchCategories();

  Future<Category?> getCategory(String id);
}
