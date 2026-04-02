import 'package:isar/isar.dart';

part 'chapter.g.dart';

/// Represents a chapter/episode for tracking read/watch progress
@collection
class Chapter {
  Id id = Isar.autoIncrement;

  /// Source entry ID this chapter belongs to
  @Index()
  late String entrySourceId;

  /// Chapter/episode ID from source
  @Index(unique: true, replace: true, composite: [CompositeIndex('entrySourceId')])
  late String chapterId;

  /// Chapter/episode number (can be decimal for .5 chapters)
  @Index()
  double? number;

  /// Chapter/episode title
  String? title;

  /// Volume number (for manga)
  int? volume;

  /// Scanlation group (for manga)
  String? scanlator;

  /// Is this chapter read/watched
  @Index()
  bool isConsumed = false;

  /// Reading progress (page number) or watching progress (seconds)
  int progress = 0;

  /// Total pages or duration in seconds
  int? total;

  /// Date this chapter was read/watched
  DateTime? consumedAt;

  /// Date chapter was released
  DateTime? releasedAt;

  /// Source URL or stream URL
  String? url;

  /// Is downloaded locally
  @Index()
  bool isDownloaded = false;

  /// Local file path if downloaded
  String? localPath;
}
