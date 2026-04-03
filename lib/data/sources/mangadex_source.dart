import 'package:dio/dio.dart';

import 'source.dart';

/// MangaDex source implementation using their public API
/// API Docs: https://api.mangadex.org/docs/
class MangaDexSource extends ReadableSource {
  final Dio _dio;

  MangaDexSource() : _dio = Dio(BaseOptions(
    baseUrl: 'https://api.mangadex.org',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  String get id => 'mangadex';

  @override
  String get name => 'MangaDex';

  @override
  String get language => 'multi';

  @override
  String get baseUrl => 'https://api.mangadex.org';

  @override
  String? get iconUrl => 'https://mangadex.org/favicon.ico';

  @override
  bool get supportsLatest => true;

  @override
  List<SourceFilter> get filters => [
    const SourceFilter(
      id: 'contentRating',
      name: 'Content Rating',
      type: FilterType.multiSelect,
      options: [
        FilterOption(id: 'safe', name: 'Safe'),
        FilterOption(id: 'suggestive', name: 'Suggestive'),
        FilterOption(id: 'erotica', name: 'Erotica'),
      ],
      defaultValue: ['safe', 'suggestive'],
    ),
    const SourceFilter(
      id: 'status',
      name: 'Status',
      type: FilterType.multiSelect,
      options: [
        FilterOption(id: 'ongoing', name: 'Ongoing'),
        FilterOption(id: 'completed', name: 'Completed'),
        FilterOption(id: 'hiatus', name: 'Hiatus'),
        FilterOption(id: 'cancelled', name: 'Cancelled'),
      ],
    ),
    const SourceFilter(
      id: 'demographic',
      name: 'Demographic',
      type: FilterType.multiSelect,
      options: [
        FilterOption(id: 'shounen', name: 'Shounen'),
        FilterOption(id: 'shoujo', name: 'Shoujo'),
        FilterOption(id: 'seinen', name: 'Seinen'),
        FilterOption(id: 'josei', name: 'Josei'),
      ],
    ),
    const SourceFilter(
      id: 'sort',
      name: 'Sort By',
      type: FilterType.select,
      options: [
        FilterOption(id: 'relevance', name: 'Relevance'),
        FilterOption(id: 'latestUploadedChapter', name: 'Latest Upload'),
        FilterOption(id: 'followedCount', name: 'Popularity'),
        FilterOption(id: 'createdAt', name: 'Recently Added'),
        FilterOption(id: 'rating', name: 'Rating'),
      ],
      defaultValue: 'relevance',
    ),
  ];

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    try {
      final response = await _dio.get('/manga', queryParameters: {
        'limit': 20,
        'offset': (page - 1) * 20,
        'order[followedCount]': 'desc',
        'contentRating[]': ['safe', 'suggestive'],
        'includes[]': ['cover_art', 'author', 'artist'],
        'availableTranslatedLanguage[]': ['en'],
        'hasAvailableChapters': true,
      });

      return _parseMangaList(response.data);
    } catch (e) {
      throw Exception('Failed to fetch popular manga: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    try {
      final response = await _dio.get('/manga', queryParameters: {
        'limit': 20,
        'offset': (page - 1) * 20,
        'order[latestUploadedChapter]': 'desc',
        'contentRating[]': ['safe', 'suggestive'],
        'includes[]': ['cover_art', 'author', 'artist'],
        'availableTranslatedLanguage[]': ['en'],
        'hasAvailableChapters': true,
      });

      return _parseMangaList(response.data);
    } catch (e) {
      throw Exception('Failed to fetch latest manga: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> search(
    String query,
    int page, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': 20,
        'offset': (page - 1) * 20,
        'title': query,
        'contentRating[]': filters?['contentRating'] ?? ['safe', 'suggestive'],
        'availableTranslatedLanguage[]': ['en'],
        'includes[]': ['cover_art', 'author', 'artist'],
      };

      // Apply filters
      if (filters != null) {
        if (filters['status'] != null) {
          queryParams['status[]'] = filters['status'];
        }
        if (filters['demographic'] != null) {
          queryParams['publicationDemographic[]'] = filters['demographic'];
        }
        if (filters['sort'] != null) {
          queryParams['order[${filters['sort']}]'] = 'desc';
        }
      }

      final response = await _dio.get('/manga', queryParameters: queryParams);
      return _parseMangaList(response.data);
    } catch (e) {
      throw Exception('Failed to search manga: $e');
    }
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    try {
      final response = await _dio.get('/manga/$id', queryParameters: {
        'includes[]': ['cover_art', 'author', 'artist', 'tag'],
      });

      final manga = response.data['data'];
      return _parseManga(manga);
    } catch (e) {
      throw Exception('Failed to fetch manga details: $e');
    }
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    try {
      final chapters = <SourceChapter>[];
      int offset = 0;
      const limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await _dio.get('/manga/$mediaId/feed', queryParameters: {
          'limit': limit,
          'offset': offset,
          'order[chapter]': 'desc',
          'translatedLanguage[]': ['en'],
          'includes[]': ['scanlation_group'],
        });

        final data = response.data['data'] as List;
        for (final chapter in data) {
          chapters.add(_parseChapter(chapter));
        }

        final total = response.data['total'] as int;
        offset += limit;
        hasMore = offset < total;
      }

      return chapters;
    } catch (e) {
      throw Exception('Failed to fetch chapters: $e');
    }
  }

  @override
  Future<List<SourcePage>> getPages(String chapterId) async {
    try {
      // Get the chapter's base URL and hash
      final response = await _dio.get('/at-home/server/$chapterId');
      final baseUrl = response.data['baseUrl'] as String;
      final chapter = response.data['chapter'];
      final hash = chapter['hash'] as String;
      final data = (chapter['data'] as List).cast<String>();

      // Build page URLs
      return data.asMap().entries.map((entry) {
        return SourcePage(
          index: entry.key,
          imageUrl: '$baseUrl/data/$hash/${entry.value}',
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch pages: $e');
    }
  }

  // Helper methods
  SourcePaginatedResult<SourceMedia> _parseMangaList(Map<String, dynamic> data) {
    final mangaList = (data['data'] as List).map((m) => _parseManga(m)).toList();
    final total = data['total'] as int;
    final limit = data['limit'] as int;
    final offset = data['offset'] as int;

    return SourcePaginatedResult(
      items: mangaList,
      hasNextPage: offset + limit < total,
      currentPage: (offset ~/ limit) + 1,
      totalPages: (total / limit).ceil(),
    );
  }

  SourceMedia _parseManga(Map<String, dynamic> manga) {
    final attributes = manga['attributes'] as Map<String, dynamic>;
    final relationships = manga['relationships'] as List;

    // Get title (prefer English)
    final titles = attributes['title'] as Map<String, dynamic>;
    final altTitles = attributes['altTitles'] as List? ?? [];
    String title = titles['en'] ?? 
                   titles['ja-ro'] ?? 
                   titles['ja'] ?? 
                   titles.values.first;

    // Try to find English alt title if main isn't English
    if (!titles.containsKey('en')) {
      for (final alt in altTitles) {
        if ((alt as Map).containsKey('en')) {
          title = alt['en'];
          break;
        }
      }
    }

    // Get cover
    String? coverUrl;
    final coverRel = relationships.where((r) => r['type'] == 'cover_art').firstOrNull;
    if (coverRel != null) {
      final fileName = coverRel['attributes']?['fileName'];
      if (fileName != null) {
        coverUrl = 'https://uploads.mangadex.org/covers/${manga['id']}/$fileName.256.jpg';
      }
    }

    // Get author/artist
    String? author;
    String? artist;
    for (final rel in relationships) {
      if (rel['type'] == 'author' && author == null) {
        author = rel['attributes']?['name'];
      }
      if (rel['type'] == 'artist' && artist == null) {
        artist = rel['attributes']?['name'];
      }
    }

    // Get description
    final descriptions = attributes['description'] as Map<String, dynamic>? ?? {};
    final description = descriptions['en'] ?? descriptions.values.firstOrNull;

    // Get genres/tags
    final tags = attributes['tags'] as List? ?? [];
    final genres = tags
        .map((t) => (t['attributes']['name'] as Map)['en'] as String?)
        .whereType<String>()
        .toList();

    return SourceMedia(
      id: manga['id'],
      title: title,
      coverUrl: coverUrl,
      description: description,
      author: author,
      artist: artist,
      genres: genres,
      status: attributes['status'],
      contentType: SourceContentType.manga,
      extra: {
        'year': attributes['year'],
        'contentRating': attributes['contentRating'],
        'demographic': attributes['publicationDemographic'],
        'originalLanguage': attributes['originalLanguage'],
      },
    );
  }

  SourceChapter _parseChapter(Map<String, dynamic> chapter) {
    final attributes = chapter['attributes'] as Map<String, dynamic>;
    final relationships = chapter['relationships'] as List;

    // Get scanlator
    String? scanlator;
    final scanlatorRel = relationships.where((r) => r['type'] == 'scanlation_group').firstOrNull;
    if (scanlatorRel != null) {
      scanlator = scanlatorRel['attributes']?['name'];
    }

    // Build title
    final chapterNum = attributes['chapter'];
    final volume = attributes['volume'];
    final chapterTitle = attributes['title'];
    
    String title = '';
    if (volume != null) title += 'Vol. $volume ';
    if (chapterNum != null) title += 'Ch. $chapterNum';
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      title += title.isEmpty ? chapterTitle : ' - $chapterTitle';
    }
    if (title.isEmpty) title = 'Oneshot';

    return SourceChapter(
      id: chapter['id'],
      title: title.trim(),
      number: chapterNum != null ? double.tryParse(chapterNum.toString()) : null,
      volume: volume != null ? int.tryParse(volume.toString()) : null,
      scanlator: scanlator,
      dateUpload: attributes['publishAt'] != null
          ? DateTime.tryParse(attributes['publishAt'])
          : null,
      extra: {
        'pages': attributes['pages'],
        'externalUrl': attributes['externalUrl'],
      },
    );
  }
}
