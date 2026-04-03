import 'package:isar/isar.dart';

import '../models/category.dart';
import '../sources/database_service.dart';

/// Repository for managing categories
class CategoryRepository {
  /// Get all categories sorted by order
  Future<List<LibraryCategory>> getAllCategories() async {
    final isar = await DatabaseService.instance;
    return isar.libraryCategorys.where().sortBySortOrder().findAll();
  }

  /// Get category by ID
  Future<LibraryCategory?> getCategoryById(int id) async {
    final isar = await DatabaseService.instance;
    return isar.libraryCategorys.get(id);
  }

  /// Get category by name
  Future<LibraryCategory?> getCategoryByName(String name) async {
    final isar = await DatabaseService.instance;
    return isar.libraryCategorys.filter().nameEqualTo(name).findFirst();
  }

  /// Create or update a category
  Future<int> saveCategory(LibraryCategory category) async {
    final isar = await DatabaseService.instance;
    return isar.writeTxn(() => isar.libraryCategorys.put(category));
  }

  /// Delete a category
  Future<bool> deleteCategory(int id) async {
    final isar = await DatabaseService.instance;
    return isar.writeTxn(() => isar.libraryCategorys.delete(id));
  }

  /// Reorder categories
  Future<void> reorderCategories(List<LibraryCategory> categories) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      for (var i = 0; i < categories.length; i++) {
        categories[i].sortOrder = i;
        await isar.libraryCategorys.put(categories[i]);
      }
    });
  }

  /// Get default category (or create one)
  Future<LibraryCategory> getOrCreateDefaultCategory() async {
    final isar = await DatabaseService.instance;
    var defaultCat = await isar.libraryCategorys.filter().isDefaultEqualTo(true).findFirst();
    
    if (defaultCat == null) {
      defaultCat = LibraryCategory()
        ..name = 'Default'
        ..isDefault = true
        ..sortOrder = 0;
      await isar.writeTxn(() => isar.libraryCategorys.put(defaultCat!));
    }
    
    return defaultCat;
  }

  /// Watch all categories (reactive stream)
  Stream<List<LibraryCategory>> watchAll() async* {
    final isar = await DatabaseService.instance;
    yield* isar.libraryCategorys.where().sortBySortOrder().watch(fireImmediately: true);
  }
}
