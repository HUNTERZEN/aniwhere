import 'dart:io';

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
  static Future<Isar>? _initFuture;

  /// Get the Isar instance, initializing if needed
  static Future<Isar> get instance {
    if (_isar != null && _isar!.isOpen) {
      return Future.value(_isar!);
    }
    _initFuture ??= _initialize().whenComplete(() => _initFuture = null);
    return _initFuture!;
  }

  /// Initialize the Isar database
  static Future<Isar> _initialize() async {
    // Check if it's already running natively to support hot restarts
    final existing = Isar.getInstance('aniwhere');
    if (existing != null && existing.isOpen) {
      _isar = existing;
      return existing;
    }

    final dir = await getApplicationDocumentsDirectory();

    final schemas = [
      LibraryEntrySchema,
      ChapterSchema,
      AppSettingsSchema,
      LibraryCategorySchema,
      SearchHistoryEntrySchema,
    ];

    try {
      _isar = await Isar.open(
        schemas,
        directory: dir.path,
        name: 'aniwhere',
        inspector: kDebugMode,
      );
    } catch (e) {
      // Schema mismatch — delete old DB file and re-open
      debugPrint('Isar schema error, resetting database: $e');
      await Isar.getInstance('aniwhere')?.close();
      final dbFile = File('${dir.path}/aniwhere.isar');
      if (await dbFile.exists()) await dbFile.delete();
      final lockFile = File('${dir.path}/aniwhere.isar.lock');
      if (await lockFile.exists()) await lockFile.delete();

      _isar = await Isar.open(
        schemas,
        directory: dir.path,
        name: 'aniwhere',
        inspector: kDebugMode,
      );
    }

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
