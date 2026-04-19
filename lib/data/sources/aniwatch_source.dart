import 'package:dio/dio.dart';

import 'source.dart';
import 'database_service.dart';
import '../models/app_settings.dart';

/// Anime source using Jikan API for metadata + Consumet API for streaming
/// Jikan provides anime info (MyAnimeList data)
/// Consumet provides actual video streams (via gogoanime provider)
class AniwatchSource extends WatchableSource {
  final Dio _jikanDio;
  final Dio _consumetDio;

  static const String _jikanApi = 'https://api.jikan.moe/v4';
  static const String _defaultConsumetApi =
      'https://consumet-api-clone.vercel.app/anime/gogoanime';

  /// Cache of anime titles keyed by MAL ID, populated when getDetails() is called
  /// so getChapters() doesn't need to make another Jikan request.
  final Map<String, _CachedAnimeTitle> _titleCache = {};

  AniwatchSource()
      : _jikanDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
          },
        )),
        _consumetDio = Dio(BaseOptions(
          baseUrl: _defaultConsumetApi,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Update Consumet API URL from user settings
  Future<void> _updateConsumetSettings() async {
    try {
      final isar = await DatabaseService.instance;
      final settings = await isar.appSettings.get(0);
      if (settings != null && settings.consumetApiUrl.isNotEmpty) {
        _consumetDio.options.baseUrl = settings.consumetApiUrl;
      }
    } catch (e) {
      // Fallback to default
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

  /// Make a Jikan API request with automatic retry on rate limit (429) or DNS errors
  Future<Response> _jikanGet(String path,
      {Map<String, dynamic>? queryParameters}) async {
    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // Wait progressively longer between retries
          await Future.delayed(Duration(milliseconds: 1000 + (attempt * 1500)));
        }
        return await _jikanDio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        final isRateLimit = e.response?.statusCode == 429;
        final isConnectionError =
            e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout;

        if ((isRateLimit || isConnectionError) && attempt < maxRetries - 1) {
          // Rate limited or DNS temp failure — wait and retry
          await Future.delayed(
              Duration(milliseconds: 2000 + (attempt * 2000)));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Failed after $maxRetries retries');
  }

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

  // ========================================================================
  // Metadata via Jikan API (browsing, search, details)
  // ========================================================================

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    try {
      final response =
          await _jikanGet('$_jikanApi/top/anime', queryParameters: {
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
      final response =
          await _jikanGet('$_jikanApi/seasons/now', queryParameters: {
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

      if (filters != null) {
        if (filters['type'] != null) params['type'] = filters['type'];
        if (filters['status'] != null) params['status'] = filters['status'];
        if (filters['rating'] != null) params['rating'] = filters['rating'];
        if (filters['order_by'] != null) {
          params['order_by'] = filters['order_by'];
        }
      }

      final response =
          await _jikanGet('$_jikanApi/anime', queryParameters: params);

      return _parseAnimeList(response.data, page);
    } catch (e) {
      throw Exception('Failed to search anime: $e');
    }
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    try {
      final response = await _jikanGet('$_jikanApi/anime/$id/full');
      final data = response.data['data'];

      // Cache the titles so getChapters() can reuse them without
      // making another Jikan request
      _titleCache[id] = _CachedAnimeTitle(
        title: data['title'] as String? ?? '',
        titleEnglish: data['title_english'] as String?,
      );

      return _parseAnimeDetails(data);
    } catch (e) {
      throw Exception('Failed to fetch anime details: $e');
    }
  }

  // ========================================================================
  // Episodes: Use cached title → Consumet search → Consumet episodes
  // Falls back to Jikan episodes if Consumet unavailable
  // ========================================================================

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    await _updateConsumetSettings();

    // Step 1: Get anime title from cache (populated by getDetails())
    // If not cached, fetch minimally from Jikan
    String animeTitle = '';
    String? animeTitleEnglish;

    final cached = _titleCache[mediaId];
    if (cached != null) {
      animeTitle = cached.title;
      animeTitleEnglish = cached.titleEnglish;
    } else {
      // Need to fetch — add a delay to avoid rate limiting since getDetails()
      // likely just ran
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final detailsResponse =
            await _jikanGet('$_jikanApi/anime/$mediaId');
        final animeData = detailsResponse.data['data'];
        animeTitle = animeData['title'] as String? ?? '';
        animeTitleEnglish = animeData['title_english'] as String?;

        // Cache for future use
        _titleCache[mediaId] = _CachedAnimeTitle(
          title: animeTitle,
          titleEnglish: animeTitleEnglish,
        );
      } catch (e) {
        // If even this fails, we can't search Consumet by title
        // Fall through to Jikan episode list
      }
    }

    // Step 2: Search Consumet for this anime to get the Consumet anime ID
    if (animeTitle.isNotEmpty) {
      String? consumetAnimeId;
      try {
        consumetAnimeId = await _findConsumetAnimeId(
          animeTitle,
          animeTitleEnglish,
        );
      } catch (e) {
        // If Consumet search fails, fall back to Jikan episode list
      }

      // Step 3: If we found the Consumet anime, get episodes from Consumet
      if (consumetAnimeId != null) {
        try {
          final consumetEpisodes =
              await _getConsumetEpisodes(consumetAnimeId);
          if (consumetEpisodes.isNotEmpty) {
            return consumetEpisodes;
          }
        } catch (e) {
          // Fall through to Jikan episodes
        }
      }
    }

    // Fallback: Use Jikan episodes (won't be playable via Consumet,
    // but shows the list)
    await Future.delayed(const Duration(milliseconds: 1000));
    try {
      final response = await _jikanGet(
        '$_jikanApi/anime/$mediaId/episodes',
        queryParameters: {'page': 1},
      );

      final episodes = <SourceChapter>[];
      final data = response.data['data'] as List? ?? [];
      final pagination =
          response.data['pagination'] as Map<String, dynamic>?;
      final lastPage = pagination?['last_visible_page'] as int? ?? 1;

      for (final ep in data) {
        episodes.add(_parseJikanEpisode(ep));
      }

      // Fetch additional pages with increased delays to respect rate limits
      for (int page = 2; page <= lastPage && page <= 5; page++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final pageResponse = await _jikanGet(
            '$_jikanApi/anime/$mediaId/episodes',
            queryParameters: {'page': page},
          );
          final pageData = pageResponse.data['data'] as List? ?? [];
          for (final ep in pageData) {
            episodes.add(_parseJikanEpisode(ep));
          }
        } catch (e) {
          // Stop paginating on error
          break;
        }
      }

      episodes.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
      return episodes;
    } catch (e) {
      throw Exception('Failed to fetch episodes: $e');
    }
  }

  // ========================================================================
  // Video Streaming via Consumet API
  // ========================================================================

  @override
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    await _updateConsumetSettings();

    try {
      final response = await _consumetDio.get('/watch/$episodeId');
      final sources = response.data['sources'] as List? ?? [];

      if (sources.isEmpty) {
        throw Exception('No streams found for this episode');
      }

      return sources
          .map((s) => SourceVideo(
                url: s['url'] as String,
                quality: s['quality'] as String? ?? 'default',
                isM3U8: s['isM3U8'] as bool? ?? true,
              ))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to fetch video streams: $e\n\nMake sure your Consumet API URL is correct in Settings → API Configuration.');
    }
  }

  // ========================================================================
  // Consumet Helper Methods
  // ========================================================================

  /// Search Consumet API for an anime by title, returns the Consumet anime ID
  Future<String?> _findConsumetAnimeId(
    String title,
    String? titleEnglish,
  ) async {
    final audioPref = await _getAudioPreference();

    // Try English title first (usually better match on Gogoanime), then Japanese
    final searchTitles = <String>[];
    if (titleEnglish != null && titleEnglish.isNotEmpty) {
      searchTitles.add(titleEnglish);
    }
    if (title.isNotEmpty && title != titleEnglish) {
      searchTitles.add(title);
    }

    for (final searchTitle in searchTitles) {
      final query = audioPref == AnimeAudioPreference.dub
          ? '$searchTitle dub'
          : searchTitle;

      try {
        final response = await _consumetDio.get('/$query');
        final results = response.data['results'] as List? ?? [];

        if (results.isNotEmpty) {
          // Try to find an exact or close match
          for (final result in results) {
            final resultTitle =
                (result['title'] as String?)?.toLowerCase() ?? '';
            final searchLower = searchTitle.toLowerCase();

            // Exact match
            if (resultTitle == searchLower) {
              return result['id'] as String?;
            }
          }

          // If no exact match, return the first result
          return results.first['id'] as String?;
        }
      } catch (e) {
        // Try next title variant
        continue;
      }
    }

    return null;
  }

  /// Get episode list from Consumet (these have playable IDs)
  Future<List<SourceChapter>> _getConsumetEpisodes(
      String consumetAnimeId) async {
    final response = await _consumetDio.get('/info/$consumetAnimeId');
    final episodes = response.data['episodes'] as List? ?? [];

    return episodes.map((ep) {
      final number = ep['number'];
      return SourceChapter(
        id: ep['id']
            as String, // This is the Consumet episode ID used for streaming
        title: 'Episode ${number ?? '?'}',
        number: number != null ? (number as num).toDouble() : null,
        url: ep['url'] as String?,
      );
    }).toList();
  }

  // ========================================================================
  // Jikan Parsing Helpers
  // ========================================================================

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

      final genres =
          (a['genres'] as List?)?.map((g) => g['name'] as String).toList() ??
              [];

      return SourceMedia(
        id: (a['mal_id'] as int).toString(),
        title:
            a['title'] as String? ?? a['title_english'] as String? ?? 'Unknown',
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

    final genres =
        (data['genres'] as List?)?.map((g) => g['name'] as String).toList() ??
            [];

    final studios =
        (data['studios'] as List?)?.map((s) => s['name'] as String).toList() ??
            [];

    final producers = (data['producers'] as List?)
            ?.map((p) => p['name'] as String)
            .toList() ??
        [];

    return SourceMedia(
      id: (data['mal_id'] as int).toString(),
      title: data['title'] as String? ??
          data['title_english'] as String? ??
          'Unknown',
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

  /// Parse a Jikan episode (fallback when Consumet is unavailable)
  SourceChapter _parseJikanEpisode(Map<String, dynamic> episode) {
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

/// Cached anime title data to avoid duplicate Jikan API calls
class _CachedAnimeTitle {
  final String title;
  final String? titleEnglish;

  const _CachedAnimeTitle({
    required this.title,
    this.titleEnglish,
  });
}
