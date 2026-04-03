import 'package:isar/isar.dart';

import '../models/library_entry.dart';
import '../sources/database_service.dart';

/// Repository for managing library entries
class LibraryRepository {
  /// Get all library entries
  Future<List<LibraryEntry>> getAllEntries() async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys.where().findAll();
  }

  /// Get library entries by media type
  Future<List<LibraryEntry>> getEntriesByType(MediaType type) async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys.filter().mediaTypeEqualTo(type).findAll();
  }

  /// Get library entries by status
  Future<List<LibraryEntry>> getEntriesByStatus(MediaStatus status) async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys.filter().statusEqualTo(status).findAll();
  }

  /// Get favorited entries
  Future<List<LibraryEntry>> getFavorites() async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Get entry by source ID
  Future<LibraryEntry?> getBySourceId(String sourceId) async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys.filter().sourceIdEqualTo(sourceId).findFirst();
  }

  /// Add or update a library entry
  Future<int> saveEntry(LibraryEntry entry) async {
    final isar = await DatabaseService.instance;
    entry.lastUpdated = DateTime.now();
    return isar.writeTxn(() => isar.libraryEntrys.put(entry));
  }

  /// Update an existing library entry
  Future<int> updateEntry(LibraryEntry entry) async {
    final isar = await DatabaseService.instance;
    entry.lastUpdated = DateTime.now();
    return isar.writeTxn(() => isar.libraryEntrys.put(entry));
  }

  /// Delete a library entry
  Future<bool> deleteEntry(int id) async {
    final isar = await DatabaseService.instance;
    return isar.writeTxn(() => isar.libraryEntrys.delete(id));
  }

  /// Delete entry by source ID
  Future<bool> deleteBySourceId(String sourceId) async {
    final isar = await DatabaseService.instance;
    return isar.writeTxn(() async {
      final count = await isar.libraryEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .deleteAll();
      return count > 0;
    });
  }

  /// Update entry progress
  Future<void> updateProgress(String sourceId, int progress, String? lastConsumedId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final entry = await isar.libraryEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .findFirst();
      if (entry != null) {
        entry.currentProgress = progress;
        entry.lastConsumedId = lastConsumedId;
        entry.lastProgress = DateTime.now();
        entry.lastUpdated = DateTime.now();
        await isar.libraryEntrys.put(entry);
      }
    });
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String sourceId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final entry = await isar.libraryEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .findFirst();
      if (entry != null) {
        entry.isFavorite = !entry.isFavorite;
        entry.lastUpdated = DateTime.now();
        await isar.libraryEntrys.put(entry);
      }
    });
  }

  /// Search library entries by title
  Future<List<LibraryEntry>> search(String query) async {
    final isar = await DatabaseService.instance;
    return isar.libraryEntrys
        .filter()
        .titleContains(query, caseSensitive: false)
        .findAll();
  }

  /// Watch all library entries (reactive stream)
  Stream<List<LibraryEntry>> watchAll() async* {
    final isar = await DatabaseService.instance;
    yield* isar.libraryEntrys.where().watch(fireImmediately: true);
  }

  /// Check if entry exists in library
  Future<bool> isInLibrary(String sourceId) async {
    final entry = await getBySourceId(sourceId);
    return entry != null;
  }
}
