/// Base source model and interfaces for content sources

/// Content type enum
enum SourceContentType {
  manga,
  anime,
  novel,
}

/// Filter types for browsing
enum FilterType {
  text,
  select,
  multiSelect,
  checkbox,
  sort,
}

/// A filter option for source browsing
class SourceFilter {
  final String id;
  final String name;
  final FilterType type;
  final List<FilterOption> options;
  final dynamic defaultValue;

  const SourceFilter({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
    this.defaultValue,
  });
}

/// Individual filter option
class FilterOption {
  final String id;
  final String name;

  const FilterOption({required this.id, required this.name});
}

/// Represents a media item (manga, anime, novel)
class SourceMedia {
  final String id;
  final String title;
  final String? coverUrl;
  final String? description;
  final String? author;
  final String? artist;
  final List<String> genres;
  final String? status;
  final SourceContentType contentType;
  final Map<String, dynamic> extra;

  const SourceMedia({
    required this.id,
    required this.title,
    this.coverUrl,
    this.description,
    this.author,
    this.artist,
    this.genres = const [],
    this.status,
    required this.contentType,
    this.extra = const {},
  });

  factory SourceMedia.fromJson(Map<String, dynamic> json, SourceContentType type) {
    return SourceMedia(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      author: json['author'] as String?,
      artist: json['artist'] as String?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String?,
      contentType: type,
      extra: json['extra'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'description': description,
    'author': author,
    'artist': artist,
    'genres': genres,
    'status': status,
    'contentType': contentType.name,
    'extra': extra,
  };
}

/// Represents a chapter (manga/novel) or episode (anime)
class SourceChapter {
  final String id;
  final String title;
  final double? number;
  final int? volume;
  final String? scanlator;
  final DateTime? dateUpload;
  final String? url;
  final Map<String, dynamic> extra;

  const SourceChapter({
    required this.id,
    required this.title,
    this.number,
    this.volume,
    this.scanlator,
    this.dateUpload,
    this.url,
    this.extra = const {},
  });

  factory SourceChapter.fromJson(Map<String, dynamic> json) {
    return SourceChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      number: (json['number'] as num?)?.toDouble(),
      volume: json['volume'] as int?,
      scanlator: json['scanlator'] as String?,
      dateUpload: json['dateUpload'] != null
          ? DateTime.tryParse(json['dateUpload'] as String)
          : null,
      url: json['url'] as String?,
      extra: json['extra'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Page data for manga reader
class SourcePage {
  final int index;
  final String imageUrl;
  final Map<String, String>? headers;

  const SourcePage({
    required this.index,
    required this.imageUrl,
    this.headers,
  });
}

/// Video stream data for anime player
class SourceVideo {
  final String url;
  final String quality;
  final Map<String, String>? headers;
  final bool isM3U8;

  const SourceVideo({
    required this.url,
    required this.quality,
    this.headers,
    this.isM3U8 = false,
  });
}

/// Paginated result
class SourcePaginatedResult<T> {
  final List<T> items;
  final bool hasNextPage;
  final int? currentPage;
  final int? totalPages;

  const SourcePaginatedResult({
    required this.items,
    this.hasNextPage = false,
    this.currentPage,
    this.totalPages,
  });
}

/// Abstract base class for all content sources
abstract class Source {
  /// Unique identifier for this source
  String get id;

  /// Display name
  String get name;

  /// Language code (e.g., 'en', 'ja', 'multi')
  String get language;

  /// Base URL for the source
  String get baseUrl;

  /// Content type this source provides
  SourceContentType get contentType;

  /// Icon URL or asset path
  String? get iconUrl;

  /// Whether this source supports latest updates
  bool get supportsLatest;

  /// Available filters for this source
  List<SourceFilter> get filters;

  /// Get popular/trending content
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page);

  /// Get latest updates
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page);

  /// Search for content
  Future<SourcePaginatedResult<SourceMedia>> search(
    String query,
    int page, {
    Map<String, dynamic>? filters,
  });

  /// Get full details for a media item
  Future<SourceMedia> getDetails(String id);

  /// Get chapters/episodes for a media item
  Future<List<SourceChapter>> getChapters(String mediaId);
}

/// Extension of Source for manga/novel sources
abstract class ReadableSource extends Source {
  @override
  SourceContentType get contentType => SourceContentType.manga;

  /// Get pages for a chapter
  Future<List<SourcePage>> getPages(String chapterId);
}

/// Extension of Source for anime sources
abstract class WatchableSource extends Source {
  @override
  SourceContentType get contentType => SourceContentType.anime;

  /// Get video streams for an episode
  Future<List<SourceVideo>> getVideoStreams(String episodeId);
}
