import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'source.dart';

/// Anime source using Jikan API for metadata + direct GogoAnime scraping for episodes/streaming
/// Jikan provides anime info (MyAnimeList data) — browsing, search, details
/// GogoAnime provides episode lists and video embed URLs for playback
class AniwatchSource extends WatchableSource {
  final Dio _jikanDio;
  final Dio _gogoDio;

  static const String _jikanApi = 'https://api.jikan.moe/v4';

  /// GogoAnime base URL — may need updating if domain changes
  static const String _gogoBase = 'https://www14.gogoanimes.fi';

  /// Cache of anime titles keyed by MAL ID, populated when getDetails() is called
  final Map<String, _CachedAnimeTitle> _titleCache = {};

  /// Cache of GogoAnime slugs keyed by anime title (to avoid repeated searches)
  final Map<String, String?> _gogoSlugCache = {};

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
        _gogoDio = Dio(BaseOptions(
          baseUrl: _gogoBase,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        ));

  /// Make a Jikan API request with automatic retry on rate limit (429) or DNS errors
  Future<Response> _jikanGet(String path,
      {Map<String, dynamic>? queryParameters}) async {
    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(
              Duration(milliseconds: 1000 + (attempt * 1500)));
        }
        return await _jikanDio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        final isRateLimit = e.response?.statusCode == 429;
        final isConnectionError =
            e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout;

        if ((isRateLimit || isConnectionError) && attempt < maxRetries - 1) {
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

      // Cache the titles so getChapters() can reuse them
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
  // Episodes via direct GogoAnime scraping
  // ========================================================================

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    // Step 1: Get anime title from cache (populated by getDetails())
    String animeTitle = '';
    String? animeTitleEnglish;

    final cached = _titleCache[mediaId];
    if (cached != null) {
      animeTitle = cached.title;
      animeTitleEnglish = cached.titleEnglish;
    } else {
      // Need to fetch from Jikan
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final detailsResponse = await _jikanGet('$_jikanApi/anime/$mediaId');
        final animeData = detailsResponse.data['data'];
        animeTitle = animeData['title'] as String? ?? '';
        animeTitleEnglish = animeData['title_english'] as String?;

        _titleCache[mediaId] = _CachedAnimeTitle(
          title: animeTitle,
          titleEnglish: animeTitleEnglish,
        );
      } catch (e) {
        // If even this fails, fall back to Jikan episode list
      }
    }

    // Step 2: Search GogoAnime for this anime and get episode list
    if (animeTitle.isNotEmpty) {
      try {
        final gogoSlug = await _findGogoAnimeSlug(
          animeTitle,
          animeTitleEnglish,
        );

        if (gogoSlug != null) {
          final episodes = await _scrapeGogoEpisodes(gogoSlug);
          if (episodes.isNotEmpty) {
            return episodes;
          }
        }
      } catch (e) {
        // Fall through to Jikan episodes
      }
    }

    // Fallback: Use Jikan episodes (won't have GogoAnime embed URLs)
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

      // Fetch additional pages
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
  // Video Streaming: extract embed URLs from GogoAnime episode pages
  // ========================================================================

  @override
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    try {
      // episodeId is a GogoAnime episode slug like "one-piece-episode-1"
      final response = await _gogoDio.get('/$episodeId');
      final html = response.data as String;
      final document = html_parser.parse(html);

      final videos = <SourceVideo>[];

      // Extract data-video attributes from streaming server links
      final serverLinks = document.querySelectorAll('a[data-video]');
      for (final link in serverLinks) {
        final embedUrl = link.attributes['data-video'];
        if (embedUrl == null || embedUrl.isEmpty) continue;

        // Get server name from link text or class
        final serverName =
            link.text.trim().isNotEmpty ? link.text.trim() : 'Server';

        // Build full URL if relative
        String fullUrl = embedUrl;
        if (fullUrl.startsWith('//')) {
          fullUrl = 'https:$fullUrl';
        }

        videos.add(SourceVideo(
          url: fullUrl,
          quality: serverName,
          embedUrl: fullUrl,
          useWebView: true,
          isM3U8: false,
        ));
      }

      // Also check for iframe src as fallback
      if (videos.isEmpty) {
        final iframes = document.querySelectorAll('iframe[src]');
        for (final iframe in iframes) {
          final src = iframe.attributes['src'];
          if (src != null && src.isNotEmpty) {
            String fullUrl = src;
            if (fullUrl.startsWith('//')) {
              fullUrl = 'https:$fullUrl';
            }
            videos.add(SourceVideo(
              url: fullUrl,
              quality: 'Default',
              embedUrl: fullUrl,
              useWebView: true,
              isM3U8: false,
            ));
          }
        }
      }

      if (videos.isEmpty) {
        throw Exception('No video sources found for this episode');
      }

      return videos;
    } catch (e) {
      throw Exception('Failed to fetch video streams: $e');
    }
  }

  // ========================================================================
  // GogoAnime Scraping Helpers
  // ========================================================================

  /// Search GogoAnime for an anime by title, returns the slug (e.g. "one-piece")
  Future<String?> _findGogoAnimeSlug(
    String title,
    String? titleEnglish,
  ) async {
    // Try English title first, then Japanese/romaji title
    final searchTitles = <String>[];
    if (titleEnglish != null && titleEnglish.isNotEmpty) {
      searchTitles.add(titleEnglish);
    }
    if (title.isNotEmpty && title != titleEnglish) {
      searchTitles.add(title);
    }

    for (final searchTitle in searchTitles) {
      // Check cache first
      if (_gogoSlugCache.containsKey(searchTitle.toLowerCase())) {
        return _gogoSlugCache[searchTitle.toLowerCase()];
      }

      try {
        final response = await _gogoDio.get('/search.html', queryParameters: {
          'keyword': searchTitle,
        });

        final html = response.data as String;
        final document = html_parser.parse(html);

        // Find category links in search results
        final categoryLinks =
            document.querySelectorAll('a[href*="/category/"]');

        if (categoryLinks.isNotEmpty) {
          // Try to find the best match
          String? bestSlug;
          final searchLower = searchTitle.toLowerCase();

          for (final link in categoryLinks) {
            final href = link.attributes['href'] ?? '';
            if (!href.contains('/category/')) continue;

            final slug = href.split('/category/').last.trim();
            if (slug.isEmpty) continue;

            // Get title text
            final linkTitle =
                link.querySelector('.name')?.text.trim() ??
                    link.text.trim();
            final titleLower = linkTitle.toLowerCase();

            // Exact match
            if (titleLower == searchLower) {
              bestSlug = slug;
              break;
            }

            // Partial match — prefer non-dub versions
            if (bestSlug == null && !slug.endsWith('-dub')) {
              bestSlug = slug;
            }
          }

          bestSlug ??= categoryLinks.first.attributes['href']
              ?.split('/category/')
              .last
              .trim();

          if (bestSlug != null && bestSlug.isNotEmpty) {
            _gogoSlugCache[searchTitle.toLowerCase()] = bestSlug;
            return bestSlug;
          }
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// Scrape episode list from a GogoAnime category page
  Future<List<SourceChapter>> _scrapeGogoEpisodes(String slug) async {
    final response = await _gogoDio.get('/category/$slug');
    final html = response.data as String;
    final document = html_parser.parse(html);

    final episodes = <SourceChapter>[];
    final seen = <String>{};

    // Episodes are in #episode_related list or loaded inline in the category
    final episodeLinks = document.querySelectorAll(
        '#episode_related a[href], ul#episode_related a');

    for (final link in episodeLinks) {
      final href = (link.attributes['href'] ?? '').trim();
      if (href.isEmpty) continue;

      // Clean the href — remove leading slash and spaces
      String episodeSlug = href.replaceAll(RegExp(r'^\s*/'), '');
      if (episodeSlug.isEmpty || seen.contains(episodeSlug)) continue;
      seen.add(episodeSlug);

      // Extract episode number from the slug
      final numMatch =
          RegExp(r'episode-(\d+(?:\.\d+)?)').firstMatch(episodeSlug);
      final number = numMatch != null
          ? double.tryParse(numMatch.group(1)!)
          : null;

      // Get episode sub/dub type
      final cate = link.querySelector('.cate')?.text.trim() ?? '';
      final suffix = cate.isNotEmpty ? ' ($cate)' : '';

      episodes.add(SourceChapter(
        id: episodeSlug, // This is used as episodeId for getVideoStreams
        title: 'Episode ${number?.toInt() ?? '?'}$suffix',
        number: number,
      ));
    }

    // If no episodes found in the HTML, try the AJAX endpoint
    if (episodes.isEmpty) {
      // Get movie_id from the page
      final movieIdInput = document.querySelector('#movie_id');
      final movieId = movieIdInput?.attributes['value'];

      if (movieId != null && movieId.isNotEmpty) {
        try {
          final ajaxResponse = await _gogoDio.get(
            '/ajax/load-list-episode',
            queryParameters: {
              'ep_start': 0,
              'ep_end': 9999,
              'id': movieId,
            },
          );

          final ajaxHtml = ajaxResponse.data as String;
          final ajaxDoc = html_parser.parse(ajaxHtml);
          final ajaxLinks = ajaxDoc.querySelectorAll('a[href]');

          for (final link in ajaxLinks) {
            final href = (link.attributes['href'] ?? '').trim();
            if (href.isEmpty) continue;

            String episodeSlug = href.replaceAll(RegExp(r'^\s*/'), '');

            // Fix episode links that might be missing the anime slug
            // e.g. "-episode-5" -> "slug-episode-5"
            if (episodeSlug.startsWith('-episode-') ||
                episodeSlug.startsWith('episode-')) {
              episodeSlug = '$slug-$episodeSlug'.replaceAll('--', '-');
            }

            if (episodeSlug.isEmpty || seen.contains(episodeSlug)) continue;
            seen.add(episodeSlug);

            final numMatch =
                RegExp(r'episode-(\d+(?:\.\d+)?)').firstMatch(episodeSlug);
            final number = numMatch != null
                ? double.tryParse(numMatch.group(1)!)
                : null;

            final cate = link.querySelector('.cate')?.text.trim() ?? '';
            final suffix = cate.isNotEmpty ? ' ($cate)' : '';

            episodes.add(SourceChapter(
              id: episodeSlug,
              title: 'Episode ${number?.toInt() ?? '?'}$suffix',
              number: number,
            ));
          }
        } catch (e) {
          // AJAX failed, return whatever we have
        }
      }
    }

    // Sort episodes ascending by number
    episodes.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return episodes;
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

  /// Parse a Jikan episode (fallback when GogoAnime scraping is unavailable)
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
