import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';

import '../models/library_entry.dart';
import '../models/chapter.dart';
import '../sources/database_service.dart';

/// Repository for backup and restore operations
class BackupRepository {
  /// Export the entire library to a JSON file.
  /// Returns the absolute path of the generated file.
  Future<String> exportLibrary() async {
    final isar = await DatabaseService.instance;

    // Fetch all library entries
    final entries = await isar.libraryEntrys.where().findAll();

    // Fetch all chapters
    final chapters = await isar.chapters.where().findAll();

    // Build the backup payload
    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'libraryEntries': entries.map((e) => _entryToMap(e)).toList(),
      'chapters': chapters.map((c) => _chapterToMap(c)).toList(),
    };

    // Write to file
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/aniwhere_backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backup));

    return file.path;
  }

  /// Import library from a JSON backup file at [filePath].
  /// Returns the number of entries restored.
  Future<int> importLibrary(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found: $filePath');
    }

    final jsonStr = await file.readAsString();
    final backup = json.decode(jsonStr) as Map<String, dynamic>;

    final isar = await DatabaseService.instance;
    int count = 0;

    // Restore library entries
    final entriesJson = backup['libraryEntries'] as List? ?? [];
    await isar.writeTxn(() async {
      for (final map in entriesJson) {
        final entry = _mapToEntry(map as Map<String, dynamic>);
        await isar.libraryEntrys.put(entry);
        count++;
      }
    });

    // Restore chapters
    final chaptersJson = backup['chapters'] as List? ?? [];
    await isar.writeTxn(() async {
      for (final map in chaptersJson) {
        final chapter = _mapToChapter(map as Map<String, dynamic>);
        await isar.chapters.put(chapter);
      }
    });

    return count;
  }

  // ──────────────── Serialization helpers ────────────────

  Map<String, dynamic> _entryToMap(LibraryEntry e) {
    return {
      'sourceId': e.sourceId,
      'mediaId': e.mediaId,
      'sourceName': e.sourceName,
      'title': e.title,
      'altTitles': e.altTitles,
      'description': e.description,
      'coverUrl': e.coverUrl,
      'mediaType': e.mediaType.name,
      'status': e.status.name,
      'rating': e.rating,
      'totalCount': e.totalCount,
      'currentProgress': e.currentProgress,
      'lastConsumedId': e.lastConsumedId,
      'categories': e.categories,
      'genres': e.genres,
      'authors': e.authors,
      'artists': e.artists,
      'publicationStatus': e.publicationStatus.name,
      'isFavorite': e.isFavorite,
      'dateAdded': e.dateAdded.toIso8601String(),
      'lastUpdated': e.lastUpdated.toIso8601String(),
      'lastProgress': e.lastProgress?.toIso8601String(),
      'malId': e.malId,
      'anilistId': e.anilistId,
      'kitsuId': e.kitsuId,
      'notes': e.notes,
      'extraData': e.extraData,
    };
  }

  LibraryEntry _mapToEntry(Map<String, dynamic> m) {
    return LibraryEntry()
      ..sourceId = m['sourceId'] as String
      ..mediaId = m['mediaId'] as String
      ..sourceName = m['sourceName'] as String
      ..title = m['title'] as String
      ..altTitles = List<String>.from(m['altTitles'] ?? [])
      ..description = m['description'] as String?
      ..coverUrl = m['coverUrl'] as String?
      ..mediaType = MediaType.values.firstWhere(
          (v) => v.name == m['mediaType'],
          orElse: () => MediaType.manga)
      ..status = MediaStatus.values.firstWhere(
          (v) => v.name == m['status'],
          orElse: () => MediaStatus.planToRead)
      ..rating = (m['rating'] as num?)?.toDouble()
      ..totalCount = m['totalCount'] as int?
      ..currentProgress = m['currentProgress'] as int? ?? 0
      ..lastConsumedId = m['lastConsumedId'] as String?
      ..categories = List<String>.from(m['categories'] ?? [])
      ..genres = List<String>.from(m['genres'] ?? [])
      ..authors = List<String>.from(m['authors'] ?? [])
      ..artists = List<String>.from(m['artists'] ?? [])
      ..publicationStatus = PublicationStatus.values.firstWhere(
          (v) => v.name == m['publicationStatus'],
          orElse: () => PublicationStatus.unknown)
      ..isFavorite = m['isFavorite'] as bool? ?? false
      ..dateAdded = DateTime.tryParse(m['dateAdded'] ?? '') ?? DateTime.now()
      ..lastUpdated = DateTime.tryParse(m['lastUpdated'] ?? '') ?? DateTime.now()
      ..lastProgress = m['lastProgress'] != null
          ? DateTime.tryParse(m['lastProgress'])
          : null
      ..malId = m['malId'] as int?
      ..anilistId = m['anilistId'] as int?
      ..kitsuId = m['kitsuId'] as String?
      ..notes = m['notes'] as String?
      ..extraData = m['extraData'] as String?;
  }

  Map<String, dynamic> _chapterToMap(Chapter c) {
    return {
      'entrySourceId': c.entrySourceId,
      'chapterId': c.chapterId,
      'number': c.number,
      'title': c.title,
      'volume': c.volume,
      'scanlator': c.scanlator,
      'isConsumed': c.isConsumed,
      'progress': c.progress,
      'total': c.total,
      'consumedAt': c.consumedAt?.toIso8601String(),
      'releasedAt': c.releasedAt?.toIso8601String(),
      'url': c.url,
      'isDownloaded': c.isDownloaded,
      'localPath': c.localPath,
    };
  }

  Chapter _mapToChapter(Map<String, dynamic> m) {
    return Chapter()
      ..entrySourceId = m['entrySourceId'] as String
      ..chapterId = m['chapterId'] as String
      ..number = (m['number'] as num?)?.toDouble()
      ..title = m['title'] as String?
      ..volume = m['volume'] as int?
      ..scanlator = m['scanlator'] as String?
      ..isConsumed = m['isConsumed'] as bool? ?? false
      ..progress = m['progress'] as int? ?? 0
      ..total = m['total'] as int?
      ..consumedAt = m['consumedAt'] != null
          ? DateTime.tryParse(m['consumedAt'])
          : null
      ..releasedAt = m['releasedAt'] != null
          ? DateTime.tryParse(m['releasedAt'])
          : null
      ..url = m['url'] as String?
      ..isDownloaded = m['isDownloaded'] as bool? ?? false
      ..localPath = m['localPath'] as String?;
  }
}
