import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'source.dart';

/// MangaPill source implementation using web scraping
/// Site: https://mangapill.com/
class MangaPillSource extends ReadableSource {
  final Dio _dio;

  MangaPillSource()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://mangapill.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://mangapill.com/',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        ));

  @override
  String get id => 'mangapill';

  @override
  String get name => 'MangaPill';

  @override
  String get language => 'en';

  @override
  String get baseUrl => 'https://mangapill.com';

  @override
  String? get iconUrl => 'https://mangapill.com/static/favicon/favicon-32x32.png';

  @override
  bool get supportsLatest => true;

  @override
  List<SourceFilter> get filters => [
        const SourceFilter(
          id: 'type',
          name: 'Type',
          type: FilterType.select,
          options: [
            FilterOption(id: '', name: 'All'),
            FilterOption(id: 'manga', name: 'Manga'),
            FilterOption(id: 'novel', name: 'Novel'),
            FilterOption(id: 'one-shot', name: 'One-shot'),
            FilterOption(id: 'doujinshi', name: 'Doujinshi'),
            FilterOption(id: 'manhua', name: 'Manhua'),
          ],
        ),
        const SourceFilter(
          id: 'status',
          name: 'Status',
          type: FilterType.select,
          options: [
            FilterOption(id: '', name: 'All'),
            FilterOption(id: 'publishing', name: 'Publishing'),
            FilterOption(id: 'finished', name: 'Finished'),
            FilterOption(id: 'on hiatus', name: 'On Hiatus'),
            FilterOption(id: 'discontinued', name: 'Discontinued'),
            FilterOption(id: 'not yet published', name: 'Not Yet Published'),
          ],
        ),
      ];

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    try {
      // MangaPill doesn't have a dedicated popular page, use search with type=manga
      final response = await _dio.get('/search', queryParameters: {
        'page': page,
        'type': 'manga',
      });

      return _parseMangaList(response.data as String, page);
    } catch (e) {
      throw Exception('Failed to fetch popular manga: $e');
    }
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    try {
      // Use new mangas page for latest
      final response = await _dio.get('/mangas/new', queryParameters: {
        'page': page,
      });

      return _parseMangaList(response.data as String, page);
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
        'q': query,
        'page': page,
      };

      // Apply filters
      if (filters != null) {
        if (filters['type'] != null && (filters['type'] as String).isNotEmpty) {
          queryParams['type'] = filters['type'];
        }
        if (filters['status'] != null &&
            (filters['status'] as String).isNotEmpty) {
          queryParams['status'] = filters['status'];
        }
      }

      final response = await _dio.get('/search', queryParameters: queryParams);
      return _parseMangaList(response.data as String, page);
    } catch (e) {
      throw Exception('Failed to search manga: $e');
    }
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    try {
      // ID format: "2/one-piece" -> URL: /manga/2/one-piece
      final response = await _dio.get('/manga/$id');
      return _parseMangaDetails(response.data as String, id);
    } catch (e) {
      throw Exception('Failed to fetch manga details: $e');
    }
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    try {
      // mediaId format: "2/one-piece"
      final response = await _dio.get('/manga/$mediaId');
      return _parseChapters(response.data as String);
    } catch (e) {
      throw Exception('Failed to fetch chapters: $e');
    }
  }

  @override
  Future<List<SourcePage>> getPages(String chapterId) async {
    try {
      // chapterId format: "2-11179000/one-piece-chapter-1179"
      final response = await _dio.get('/chapters/$chapterId');
      return _parsePages(response.data as String);
    } catch (e) {
      throw Exception('Failed to fetch pages: $e');
    }
  }

  // Helper methods
  SourcePaginatedResult<SourceMedia> _parseMangaList(String html, int page) {
    final document = html_parser.parse(html);
    final mangaList = <SourceMedia>[];
    final seen = <String>{};

    // Find manga items in the grid - these are the divs containing manga links
    // Structure: div > a[href="/manga/..."] > figure > img + div with title
    final mangaContainers = document.querySelectorAll('div.my-3.grid > div, div.grid.gap-3 > div');
    
    for (final container in mangaContainers) {
      final linkElement = container.querySelector('a[href*="/manga/"]');
      if (linkElement == null) continue;
      
      final href = linkElement.attributes['href'] ?? '';
      if (!href.startsWith('/manga/')) continue;
      
      // Extract ID from URL: /manga/2/one-piece -> 2/one-piece
      final id = href.replaceFirst('/manga/', '');
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);

      // Get title from the font-black div
      final titleElement = container.querySelector('div.font-black');
      final title = titleElement?.text.trim() ?? '';
      if (title.isEmpty) continue;

      // Get cover image
      final imgElement = container.querySelector('img');
      final coverUrl = imgElement?.attributes['data-src'] ??
          imgElement?.attributes['src'];

      // Get genres
      final genreElements = container.querySelectorAll('div.bg-card');
      final genres = genreElements
          .map((e) => e.text.trim())
          .where((g) => g.isNotEmpty)
          .toList();

      // Get status from colored badges
      String? status;
      final statusBadge = container.querySelector('div.bg-green-500, div.bg-red-500, div.bg-yellow-500');
      if (statusBadge != null) {
        status = statusBadge.text.trim();
      }

      mangaList.add(SourceMedia(
        id: id,
        title: title,
        coverUrl: coverUrl,
        genres: genres,
        status: status,
        contentType: SourceContentType.manga,
      ));
    }

    // Check for next page link
    final nextPageLink = document.querySelector('a[href*="page=${page + 1}"]');
    final hasNextPage = nextPageLink != null;

    return SourcePaginatedResult(
      items: mangaList,
      hasNextPage: hasNextPage,
      currentPage: page,
    );
  }

  SourceMedia _parseMangaDetails(String html, String id) {
    final document = html_parser.parse(html);

    // Get title from h1
    final titleElement = document.querySelector('h1.font-bold');
    final title = titleElement?.text.trim() ?? 'Unknown';

    // Get cover - look for the main manga image
    final coverElement = document.querySelector('div.flex-shrink-0 img');
    final coverUrl = coverElement?.attributes['data-src'] ??
        coverElement?.attributes['src'];

    // Get description from the paragraph
    final descElement = document.querySelector('p.text-sm.text--secondary');
    String? description = descElement?.text.trim();
    // Clean up HTML entities
    description = description?.replaceAll('<br/>', '\n').replaceAll(RegExp(r'<[^>]*>'), '');

    // Get genres from the links
    final genreElements = document.querySelectorAll('a.text-brand[href*="/search?genre="]');
    final genres = genreElements
        .map((e) => e.text.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    // Get status, type, year from the info grid
    String? status;
    String? type;
    String? year;
    
    final infoLabels = document.querySelectorAll('label.text-secondary');
    for (final label in infoLabels) {
      final labelText = label.text.trim().toLowerCase();
      final valueElement = label.nextElementSibling;
      if (valueElement == null) continue;
      final value = valueElement.text.trim();
      
      if (labelText == 'status') {
        status = value;
      } else if (labelText == 'type') {
        type = value;
      } else if (labelText == 'year') {
        year = value;
      }
    }

    return SourceMedia(
      id: id,
      title: title,
      coverUrl: coverUrl,
      description: description,
      genres: genres,
      status: status,
      contentType: SourceContentType.manga,
      extra: {
        'type': type,
        'year': year,
      },
    );
  }

  List<SourceChapter> _parseChapters(String html) {
    final document = html_parser.parse(html);
    final chapters = <SourceChapter>[];
    final seen = <String>{};

    // Find chapter links in the chapters section
    // Structure: div#chapters a[href="/chapters/..."]
    final chapterElements = document.querySelectorAll('#chapters a[href*="/chapters/"], div[data-filter-list] a[href*="/chapters/"]');

    for (final element in chapterElements) {
      final href = element.attributes['href'] ?? '';
      if (!href.startsWith('/chapters/')) continue;

      // Extract chapter ID: /chapters/2-11179000/one-piece-chapter-1179 -> 2-11179000/one-piece-chapter-1179
      final id = href.replaceFirst('/chapters/', '');
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);

      // Get title/number from the link text
      final titleText = element.text.trim();
      String title = titleText;
      double? number;

      // Try to parse chapter number from text like "Chapter 1179"
      final numMatch = RegExp(r'chapter\s*(\d+(?:\.\d+)?)', caseSensitive: false)
          .firstMatch(titleText);
      if (numMatch != null) {
        number = double.tryParse(numMatch.group(1)!);
      }

      if (title.isEmpty) {
        title = number != null ? 'Chapter $number' : 'Chapter';
      }

      chapters.add(SourceChapter(
        id: id,
        title: title,
        number: number,
      ));
    }

    return chapters;
  }

  List<SourcePage> _parsePages(String html) {
    final document = html_parser.parse(html);
    final pages = <SourcePage>[];
    final seen = <String>{};

    // Find page images inside chapter-page elements
    // Structure: chapter-page > div > picture > img.js-page[data-src]
    final pageImages = document.querySelectorAll('chapter-page img.js-page, chapter-page picture img');

    for (final element in pageImages) {
      final imageUrl = element.attributes['data-src'] ??
          element.attributes['src'] ??
          '';

      // Skip if empty or already seen
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;
      
      // Only include actual manga page images (from CDN)
      if (!imageUrl.contains('cdn.readdetectiveconan.com') && 
          !imageUrl.contains('mangapill')) continue;
      
      seen.add(imageUrl);
      
      pages.add(SourcePage(
        index: pages.length,
        imageUrl: imageUrl,
        headers: {
          'Referer': 'https://mangapill.com/',
        },
      ));
    }

    return pages;
  }
}
