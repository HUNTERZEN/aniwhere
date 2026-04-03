import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/library_entry.dart';
import '../models/chapter.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/search_history.dart';

/// Database service for managing Isar database instance
class DatabaseService {
  static Isar? _isar;

  /// Get the Isar instance, initializing if needed
  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }
    return await _initialize();
  }

  /// Initialize the Isar database
  static Future<Isar> _initialize() async {
    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        LibraryEntrySchema,
        ChapterSchema,
        AppSettingsSchema,
        LibraryCategorySchema,
        SearchHistoryEntrySchema,
      ],
      directory: dir.path,
      name: 'aniwhere',
      inspector: kDebugMode, // Enable inspector in debug mode
    );

    // Ensure default settings exist
    final settings = await _isar!.appSettings.get(0);
    if (settings == null) {
      await _isar!.writeTxn(() async {
        await _isar!.appSettings.put(AppSettings());
      });
    }
    
    // Ensure default category exists
    final defaultCat = await _isar!.libraryCategorys.filter().isDefaultEqualTo(true).findFirst();
    if (defaultCat == null) {
      await _isar!.writeTxn(() async {
        await _isar!.libraryCategorys.put(LibraryCategory()
          ..name = 'Default'
          ..isDefault = true
          ..sortOrder = 0);
      });
    }

    return _isar!;
  }

  /// Close the database
  static Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }

  /// Clear all data (for testing or reset)
  static Future<void> clearAll() async {
    final isar = await instance;
    await isar.writeTxn(() async {
      await isar.clear();
      // Recreate default settings
      await isar.appSettings.put(AppSettings());
    });
  }
}
