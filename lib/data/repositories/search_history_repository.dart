import 'package:isar/isar.dart';

import '../models/search_history.dart';
import '../sources/database_service.dart';

/// Repository for managing local search history
class SearchHistoryRepository {
  /// Save a search query. If it exists, update its timestamp. Also enforces a limit on stored entries.
  Future<void> addQuery(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    final isar = await DatabaseService.instance;

    await isar.writeTxn(() async {
      final entry = SearchHistoryEntry()
        ..query = trimmedQuery
        ..timestamp = DateTime.now();

      await isar.searchHistoryEntrys.putByQuery(entry);

      // Keep only last 15 queries to avoid DB bloat
      final count = await isar.searchHistoryEntrys.count();
      if (count > 15) {
        final oldestEntries = await isar.searchHistoryEntrys
            .where()
            .sortByTimestamp()
            .limit(count - 15)
            .findAll();
            
        await isar.searchHistoryEntrys.deleteAll(
          oldestEntries.map((e) => e.id).toList(),
        );
      }
    });
  }

  /// Get the recent search history descending by timestamp
  Future<List<SearchHistoryEntry>> getRecentSearches() async {
    final isar = await DatabaseService.instance;
    return await isar.searchHistoryEntrys
        .where()
        .sortByTimestampDesc()
        .limit(15)
        .findAll();
  }

  /// Watch recent searches for real-time UI updates
  Stream<List<SearchHistoryEntry>> watchRecentSearches() async* {
    final isar = await DatabaseService.instance;
    yield* isar.searchHistoryEntrys
        .where()
        .sortByTimestampDesc()
        .limit(15)
        .watch(fireImmediately: true);
  }

  /// Delete a specific query
  Future<void> deleteQuery(String query) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.searchHistoryEntrys.deleteByQuery(query);
    });
  }

  /// Clear all recent searches
  Future<void> clearHistory() async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.searchHistoryEntrys.clear();
    });
  }
}
