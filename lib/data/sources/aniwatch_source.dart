import 'package:dio/dio.dart';

import 'source.dart';

/// Anime source using Jikan API (MyAnimeList data)
/// Provides anime metadata with English information
class AniwatchSource extends WatchableSource {
  final Dio _dio;
  
  static const String _jikanApi = 'https://api.jikan.moe/v4';

  AniwatchSource() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
    },
  ));

  @override
  String get id => 'aniwatch';

  @override
  String get name => 'Aniwatch';

  @override
  String get language => 'en';

  @override
  String get baseUrl => _jikanApi;

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
        FilterOption(id: 'tv', name: 'TV'),
        FilterOption(id: 'movie', name: 'Movie'),
        FilterOption(id: 'ova', name: 'OVA'),
        FilterOption(id: 'ona', name: 'ONA'),
        FilterOption(id: 'special', name: 'Special'),
        FilterOption(id: 'music', name: 'Music'),
      ],
      defaultValue: 'tv',
    ),
    const SourceFilter(
      id: 'status',
      name: 'Status',
      type: FilterType.select,
      options: [
        FilterOption(id: 'airing', name: 'Airing'),
        FilterOption(id: 'complete', name: 'Complete'),
        FilterOption(id: 'upcoming', name: 'Upcoming'),
      ],
    ),
    const SourceFilter(
      id: 'rating',
      name: 'Rating',
      type: FilterType.select,
      options: [
        FilterOption(id: 'g', name: 'G - All Ages'),
        FilterOption(id: 'pg', name: 'PG - Children'),
        FilterOption(id: 'pg13', name: 'PG-13 - Teens'),
        FilterOption(id: 'r17', name: 'R - 17+'),
      ],
    ),
    const SourceFilter(
      id: 'order_by',
      name: 'Order By',
      type: FilterType.select,
      options: [
        FilterOption(id: 'score', name: 'Score'),
        FilterOption(id: 'popularity', name: 'Popularity'),
        FilterOption(id: 'rank', name: 'Rank'),
        FilterOption(id: 'start_date', name: 'Start Date'),
      ],
      defaultValue: 'score',
    ),
  ];

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    try {
      // Use top anime endpoint for popular
      final response = await _dio.get('$_jikanApi/top/anime', queryParameters: {
        'page': page,
        'filter': 'airing',
        'limit': 25,
      });

      return _parseAnimeList(response.data, page);
    } catch (e) {
      throw Exception('Failed to fetch popular anime: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    try {
      // Get currently airing anime sorted by start date
      final response = await _dio.get('$_jikanApi/seasons/now', queryParameters: {
        'page': page,
        'limit': 25,
      });

      return _parseAnimeList(response.data, page);
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
    try {
      final params = <String, dynamic>{
        'q': query,
        'page': page,
        'limit': 25,
        'sfw': false,
      };
      
      // Apply filters
      if (filters != null) {
        if (filters['type'] != null) params['type'] = filters['type'];
        if (filters['status'] != null) params['status'] = filters['status'];
        if (filters['rating'] != null) params['rating'] = filters['rating'];
        if (filters['order_by'] != null) params['order_by'] = filters['order_by'];
      }

      final response = await _dio.get('$_jikanApi/anime', queryParameters: params);

      return _parseAnimeList(response.data, page);
    } catch (e) {
      throw Exception('Failed to search anime: $e');
    }
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    try {
      final response = await _dio.get('$_jikanApi/anime/$id/full');
      return _parseAnimeDetails(response.data['data']);
    } catch (e) {
      throw Exception('Failed to fetch anime details: $e');
    }
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    try {
      final response = await _dio.get('$_jikanApi/anime/$mediaId/episodes', queryParameters: {
        'page': 1,
      });
      
      final episodes = <SourceChapter>[];
      final data = response.data['data'] as List? ?? [];
      final pagination = response.data['pagination'] as Map<String, dynamic>?;
      final lastPage = pagination?['last_visible_page'] as int? ?? 1;
      
      // Parse first page
      for (final ep in data) {
        episodes.add(_parseEpisode(ep));
      }
      
      // Fetch remaining pages if any
      for (int page = 2; page <= lastPage && page <= 10; page++) {
        await Future.delayed(const Duration(milliseconds: 350)); // Rate limit
        final pageResponse = await _dio.get('$_jikanApi/anime/$mediaId/episodes', queryParameters: {
          'page': page,
        });
        final pageData = pageResponse.data['data'] as List? ?? [];
        for (final ep in pageData) {
          episodes.add(_parseEpisode(ep));
        }
      }

      // Sort by episode number
      episodes.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
      
      return episodes;
    } catch (e) {
      throw Exception('Failed to fetch episodes: $e');
    }
  }

  @override
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    // Jikan API doesn't provide streaming URLs
    // Return a placeholder that indicates the user needs external streaming
    // The app can integrate with external players or sources
    
    // For now, return empty list with a note
    // Users can use external apps to watch
    return [
      SourceVideo(
        url: 'https://myanimelist.net/anime/$episodeId',
        quality: 'External Link',
        isM3U8: false,
        headers: {},
      ),
    ];
  }

  // Helper methods
  SourcePaginatedResult<SourceMedia> _parseAnimeList(
    Map<String, dynamic> response,
    int page,
  ) {
    final data = response['data'] as List? ?? [];
    final pagination = response['pagination'] as Map<String, dynamic>?;
    final hasNextPage = pagination?['has_next_page'] as bool? ?? false;

    final animeList = data.map((a) {
      final images = a['images'] as Map<String, dynamic>?;
      final jpg = images?['jpg'] as Map<String, dynamic>?;
      final coverUrl = jpg?['large_image_url'] ?? jpg?['image_url'];
      
      final genres = (a['genres'] as List?)
          ?.map((g) => g['name'] as String)
          .toList() ?? [];
      
      return SourceMedia(
        id: (a['mal_id'] as int).toString(),
        title: a['title'] as String? ?? a['title_english'] as String? ?? 'Unknown',
        coverUrl: coverUrl as String?,
        description: a['synopsis'] as String?,
        genres: genres,
        status: a['status'] as String?,
        contentType: SourceContentType.anime,
        extra: {
          'titleEnglish': a['title_english'],
          'titleJapanese': a['title_japanese'],
          'score': a['score'],
          'episodes': a['episodes'],
          'type': a['type'],
          'rating': a['rating'],
          'year': a['year'],
          'season': a['season'],
        },
      );
    }).toList();

    return SourcePaginatedResult(
      items: animeList,
      hasNextPage: hasNextPage,
      currentPage: page,
    );
  }

  SourceMedia _parseAnimeDetails(Map<String, dynamic> data) {
    final images = data['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    final coverUrl = jpg?['large_image_url'] ?? jpg?['image_url'];
    
    final genres = (data['genres'] as List?)
        ?.map((g) => g['name'] as String)
        .toList() ?? [];
    
    final studios = (data['studios'] as List?)
        ?.map((s) => s['name'] as String)
        .toList() ?? [];
    
    final producers = (data['producers'] as List?)
        ?.map((p) => p['name'] as String)
        .toList() ?? [];

    return SourceMedia(
      id: (data['mal_id'] as int).toString(),
      title: data['title'] as String? ?? data['title_english'] as String? ?? 'Unknown',
      coverUrl: coverUrl as String?,
      description: data['synopsis'] as String?,
      genres: genres,
      status: data['status'] as String?,
      contentType: SourceContentType.anime,
      extra: {
        'titleEnglish': data['title_english'],
        'titleJapanese': data['title_japanese'],
        'score': data['score'],
        'scoredBy': data['scored_by'],
        'rank': data['rank'],
        'popularity': data['popularity'],
        'members': data['members'],
        'favorites': data['favorites'],
        'episodes': data['episodes'],
        'type': data['type'],
        'source': data['source'],
        'duration': data['duration'],
        'rating': data['rating'],
        'season': data['season'],
        'year': data['year'],
        'studios': studios,
        'producers': producers,
        'aired': data['aired']?['string'],
        'background': data['background'],
        'trailer': data['trailer']?['url'],
      },
    );
  }

  SourceChapter _parseEpisode(Map<String, dynamic> episode) {
    final number = episode['mal_id'] as int?;
    final title = episode['title'] as String?;
    final titleRomanji = episode['title_romanji'] as String?;
    final aired = episode['aired'] as String?;
    
    String episodeTitle = 'Episode ${number ?? '?'}';
    if (title != null && title.isNotEmpty) {
      episodeTitle = '$episodeTitle: $title';
    } else if (titleRomanji != null && titleRomanji.isNotEmpty) {
      episodeTitle = '$episodeTitle: $titleRomanji';
    }

    return SourceChapter(
      id: number?.toString() ?? '',
      title: episodeTitle,
      number: number?.toDouble(),
      dateUpload: aired != null ? DateTime.tryParse(aired) : null,
      url: episode['url'] as String?,
    );
  }
}

