import 'package:isar/isar.dart';

import '../models/chapter.dart';
import '../sources/database_service.dart';

typedef TrackerSyncCallback = Future<void> Function(String entrySourceId, int progress, bool isConsumed);

/// Repository for managing chapter reading progress in Isar
class ChapterRepository {
  final TrackerSyncCallback? onSync;

  ChapterRepository({this.onSync});

  /// Get a specific chapter's stored data
  Future<Chapter?> getChapter(String entrySourceId, String chapterId) async {
    final isar = await DatabaseService.instance;
    return isar.chapters
        .filter()
        .entrySourceIdEqualTo(entrySourceId)
        .chapterIdEqualTo(chapterId)
        .findFirst();
  }

  /// Save reading progress for a chapter
  Future<void> saveProgress({
    required String entrySourceId,
    required String chapterId,
    required int currentPage,
    required int totalPages,
    String? title,
    double? number,
  }) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      // Find existing or create new chapter record
      var chapter = await isar.chapters
          .filter()
          .entrySourceIdEqualTo(entrySourceId)
          .chapterIdEqualTo(chapterId)
          .findFirst();

      if (chapter == null) {
        chapter = Chapter()
          ..entrySourceId = entrySourceId
          ..chapterId = chapterId;
      }

      chapter.progress = currentPage;
      chapter.total = totalPages;
      if (title != null) chapter.title = title;
      if (number != null) chapter.number = number;

      // Mark as fully consumed if on the last page
      if (currentPage >= totalPages - 1) {
        chapter.isConsumed = true;
        chapter.consumedAt = DateTime.now();
      }

      await isar.chapters.put(chapter);
    });

    if (onSync != null) {
      // Calculate total number of read chapters for this entry to report progress
      final totalRead = await getReadChapters(entrySourceId).then((list) => list.length);
      onSync!(entrySourceId, totalRead, currentPage >= totalPages - 1);
    }
  }

  /// Mark a chapter as read/consumed
  Future<void> markAsRead(String entrySourceId, String chapterId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      var chapter = await isar.chapters
          .filter()
          .entrySourceIdEqualTo(entrySourceId)
          .chapterIdEqualTo(chapterId)
          .findFirst();

      if (chapter == null) {
        chapter = Chapter()
          ..entrySourceId = entrySourceId
          ..chapterId = chapterId;
      }

      chapter.isConsumed = true;
      chapter.consumedAt = DateTime.now();
      await isar.chapters.put(chapter);
    });

    if (onSync != null) {
      final totalRead = await getReadChapters(entrySourceId).then((list) => list.length);
      onSync!(entrySourceId, totalRead, true);
    }
  }

  /// Mark a chapter as unread
  Future<void> markAsUnread(String entrySourceId, String chapterId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final chapter = await isar.chapters
          .filter()
          .entrySourceIdEqualTo(entrySourceId)
          .chapterIdEqualTo(chapterId)
          .findFirst();

      if (chapter != null) {
        chapter.isConsumed = false;
        chapter.consumedAt = null;
        await isar.chapters.put(chapter);
      }
    });
  }

  /// Get all read/consumed chapters for a library entry
  Future<List<Chapter>> getReadChapters(String entrySourceId) async {
    final isar = await DatabaseService.instance;
    return isar.chapters
        .filter()
        .entrySourceIdEqualTo(entrySourceId)
        .isConsumedEqualTo(true)
        .findAll();
  }

  /// Get all chapters for a library entry (read and unread)
  Future<List<Chapter>> getAllChapters(String entrySourceId) async {
    final isar = await DatabaseService.instance;
    return isar.chapters
        .filter()
        .entrySourceIdEqualTo(entrySourceId)
        .findAll();
  }

  /// Delete all chapter data for a library entry
  Future<void> deleteAllForEntry(String entrySourceId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.chapters
          .filter()
          .entrySourceIdEqualTo(entrySourceId)
          .deleteAll();
    });
  }
}
