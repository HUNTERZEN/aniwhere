import 'package:dio/dio.dart';

import 'source.dart';
import 'database_service.dart';
import '../models/app_settings.dart';

/// Gogoanime-style anime source implementation
/// Uses consumet API as a proxy for anime content
class GogoanimeSource extends WatchableSource {
  final Dio _dio;

  // Using consumet API as backend (self-hostable)
  // You can replace with your own API endpoint
  static const String _apiBase = 'https://api.consumet.org/anime/gogoanime';

  GogoanimeSource() : _dio = Dio(BaseOptions(
    baseUrl: _apiBase,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<void> _updateSettings() async {
    try {
      final isar = await DatabaseService.instance;
      final settings = await isar.appSettings.get(0);
      if (settings != null) {
        if (settings.consumetApiUrl.isNotEmpty) {
          _dio.options.baseUrl = settings.consumetApiUrl;
        }
      }
    } catch (e) {
      // Ignore database errs and fallback to init options
    }
  }

  Future<AnimeAudioPreference> _getAudioPreference() async {
    try {
      final isar = await DatabaseService.instance;
      final settings = await isar.appSettings.get(0);
      return settings?.animeAudioPreference ?? AnimeAudioPreference.sub;
    } catch (e) {
      return AnimeAudioPreference.sub;
    }
  }

  @override
  String get id => 'gogoanime';

  @override
  String get name => 'Gogoanime';

  @override
  String get language => 'en';

  @override
  String get baseUrl => _apiBase;

  @override
  SourceContentType get contentType => SourceContentType.anime;

  @override
  String? get iconUrl => null;

  @override
  bool get supportsLatest => true;

  @override
  List<SourceFilter> get filters => [
    const SourceFilter(
      id: 'type',
      name: 'Type',
      type: FilterType.select,
      options: [
        FilterOption(id: '1', name: 'Japanese'),
        FilterOption(id: '2', name: 'English Dubbed'),
        FilterOption(id: '3', name: 'Chinese'),
      ],
      defaultValue: '1',
    ),
    const SourceFilter(
      id: 'status',
      name: 'Status',
      type: FilterType.select,
      options: [
        FilterOption(id: 'ongoing', name: 'Ongoing'),
        FilterOption(id: 'completed', name: 'Completed'),
      ],
    ),
    const SourceFilter(
      id: 'genre',
      name: 'Genre',
      type: FilterType.select,
      options: [
        FilterOption(id: 'action', name: 'Action'),
        FilterOption(id: 'adventure', name: 'Adventure'),
        FilterOption(id: 'comedy', name: 'Comedy'),
        FilterOption(id: 'drama', name: 'Drama'),
        FilterOption(id: 'fantasy', name: 'Fantasy'),
        FilterOption(id: 'horror', name: 'Horror'),
        FilterOption(id: 'mecha', name: 'Mecha'),
        FilterOption(id: 'mystery', name: 'Mystery'),
        FilterOption(id: 'romance', name: 'Romance'),
        FilterOption(id: 'sci-fi', name: 'Sci-Fi'),
        FilterOption(id: 'slice-of-life', name: 'Slice of Life'),
        FilterOption(id: 'sports', name: 'Sports'),
        FilterOption(id: 'supernatural', name: 'Supernatural'),
      ],
    ),
  ];

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    await _updateSettings();
    try {
      final response = await _dio.get('/top-airing', queryParameters: {
        'page': page,
      });

      return _parseAnimeList(response.data, page);
    } catch (e) {
      throw Exception('Failed to fetch popular anime: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    await _updateSettings();
    final audioPref = await _getAudioPreference();
    final type = audioPref == AnimeAudioPreference.dub ? 2 : 1;
    
    try {
      final response = await _dio.get('/recent-episodes', queryParameters: {
        'page': page,
        'type': type,
      });

      return _parseRecentEpisodes(response.data, page);
    } catch (e) {
      throw Exception('Failed to fetch latest anime: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> search(
    String query,
    int page, {
    Map<String, dynamic>? filters,
  }) async {
    await _updateSettings();
    
    // Gogoanime treats sub/dub as separate query items. We could append '(Dub)' to the search query if dub is preferred.
    final audioPref = await _getAudioPreference();
    final searchQuery = audioPref == AnimeAudioPreference.dub ? '$query dub' : query;

    try {
      final response = await _dio.get('/$searchQuery', queryParameters: {
        'page': page,
      });

      return _parseAnimeList(response.data, page);
    } catch (e) {
      throw Exception('Failed to search anime: $e');
    }
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    await _updateSettings();
    try {
      final response = await _dio.get('/info/$id');
      return _parseAnimeDetails(response.data);
    } catch (e) {
      throw Exception('Failed to fetch anime details: $e');
    }
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    await _updateSettings();
    try {
      final response = await _dio.get('/info/$mediaId');
      final episodes = response.data['episodes'] as List? ?? [];

      return episodes.map((ep) => _parseEpisode(ep)).toList();
    } catch (e) {
      throw Exception('Failed to fetch episodes: $e');
    }
  }

  @override
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    await _updateSettings();
    try {
      final response = await _dio.get('/watch/$episodeId');
      final sources = response.data['sources'] as List? ?? [];

      return sources.map((s) => SourceVideo(
        url: s['url'] as String,
        quality: s['quality'] as String? ?? 'default',
        isM3U8: s['isM3U8'] as bool? ?? true,
      )).toList();
    } catch (e) {
      throw Exception('Failed to fetch video streams: $e');
    }
  }

  // Helper methods
  SourcePaginatedResult<SourceMedia> _parseAnimeList(
    Map<String, dynamic> data,
    int page,
  ) {
    final results = data['results'] as List? ?? [];
    final hasNextPage = data['hasNextPage'] as bool? ?? false;

    final animeList = results.map((a) => SourceMedia(
      id: a['id'] as String,
      title: a['title'] as String,
      coverUrl: a['image'] as String?,
      description: null,
      genres: [],
      status: a['status'] as String?,
      contentType: SourceContentType.anime,
      extra: {
        'subOrDub': a['subOrDub'],
      },
    )).toList();

    return SourcePaginatedResult(
      items: animeList,
      hasNextPage: hasNextPage,
      currentPage: page,
    );
  }

  SourcePaginatedResult<SourceMedia> _parseRecentEpisodes(
    Map<String, dynamic> data,
    int page,
  ) {
    final results = data['results'] as List? ?? [];
    final hasNextPage = data['hasNextPage'] as bool? ?? false;

    final animeList = results.map((a) => SourceMedia(
      id: a['id'] as String,
      title: a['title'] as String? ?? a['id'] as String,
      coverUrl: a['image'] as String?,
      description: null,
      genres: [],
      contentType: SourceContentType.anime,
      extra: {
        'episodeNumber': a['episodeNumber'],
        'episodeId': a['episodeId'],
      },
    )).toList();

    return SourcePaginatedResult(
      items: animeList,
      hasNextPage: hasNextPage,
      currentPage: page,
    );
  }

  SourceMedia _parseAnimeDetails(Map<String, dynamic> data) {
    final genres = (data['genres'] as List?)?.cast<String>() ?? [];

    return SourceMedia(
      id: data['id'] as String,
      title: data['title'] as String,
      coverUrl: data['image'] as String?,
      description: data['description'] as String?,
      genres: genres,
      status: data['status'] as String?,
      contentType: SourceContentType.anime,
      extra: {
        'subOrDub': data['subOrDub'],
        'type': data['type'],
        'releaseDate': data['releaseDate'],
        'totalEpisodes': data['totalEpisodes'],
        'otherName': data['otherName'],
      },
    );
  }

  SourceChapter _parseEpisode(Map<String, dynamic> episode) {
    final number = episode['number'];

    return SourceChapter(
      id: episode['id'] as String,
      title: 'Episode ${number ?? '?'}',
      number: number != null ? (number as num).toDouble() : null,
      url: episode['url'] as String?,
    );
  }
}
