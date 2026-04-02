import 'package:isar/isar.dart';

part 'library_entry.g.dart';

/// Represents a library entry for manga, anime, or novel
@collection
class LibraryEntry {
  Id id = Isar.autoIncrement;

  /// Unique identifier from source (e.g., MangaDex ID)
  @Index(unique: true, replace: true)
  late String sourceId;

  /// Name of the source (e.g., 'mangadex', 'gogoanime')
  @Index()
  late String sourceName;

  /// Title of the media
  @Index(type: IndexType.value, caseSensitive: false)
  late String title;

  /// Alternative titles (for search)
  List<String> altTitles = [];

  /// Description/synopsis
  String? description;

  /// Cover image URL
  String? coverUrl;

  /// Type of content
  @Enumerated(EnumType.name)
  late MediaType mediaType;

  /// Current reading/watching status
  @Enumerated(EnumType.name)
  MediaStatus status = MediaStatus.planToConsume;

  /// User's personal rating (0-10)
  double? rating;

  /// Total chapters/episodes (null if ongoing)
  int? totalCount;

  /// Current progress (chapter/episode number)
  int currentProgress = 0;

  /// Last read/watched chapter/episode ID
  String? lastConsumedId;

  /// Categories/tags assigned by user
  @Index(type: IndexType.value)
  List<String> categories = [];

  /// Genres from source
  List<String> genres = [];

  /// Author(s)
  List<String> authors = [];

  /// Artist(s) - for manga
  List<String> artists = [];

  /// Publication status
  @Enumerated(EnumType.name)
  PublicationStatus publicationStatus = PublicationStatus.unknown;

  /// Is favorited
  @Index()
  bool isFavorite = false;

  /// Date added to library
  @Index()
  DateTime dateAdded = DateTime.now();

  /// Last updated in library
  DateTime lastUpdated = DateTime.now();

  /// Last time progress was made
  DateTime? lastProgress;

  /// External tracker IDs
  int? malId;
  int? anilistId;
  String? kitsuId;

  /// Custom notes
  String? notes;

  /// Extra data as JSON string
  String? extraData;
}

/// Type of media content
enum MediaType {
  manga,
  anime,
  novel,
  webtoon,
  manhua,
  manhwa,
}

/// User's consumption status
enum MediaStatus {
  reading,
  watching,
  completed,
  onHold,
  dropped,
  planToConsume,
}

/// Publication status from source
enum PublicationStatus {
  ongoing,
  completed,
  hiatus,
  cancelled,
  unknown,
}
