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

      if (filters != null) {
        if (filters['type'] != null && (filters['type'] as String).isNotEmpty) {
          queryParams['type'] = filters['type'];
        }
        if (filters['status'] != null && (filters['status'] as String).isNotEmpty) {
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
      final response = await _dio.get('/manga/$id');
      return _parseMangaDetails(response.data as String, id);
    } catch (e) {
      throw Exception('Failed to fetch manga details: $e');
    }
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    try {
      final response = await _dio.get('/manga/$mediaId');
      return _parseChapters(response.data as String);
    } catch (e) {
      throw Exception('Failed to fetch chapters: $e');
    }
  }

  @override
  Future<List<SourcePage>> getPages(String chapterId) async {
    try {
      final response = await _dio.get('/chapters/$chapterId');
      return _parsePages(response.data as String);
    } catch (e) {
      throw Exception('Failed to fetch pages: $e');
    }
  }

  /// Parse manga list from HTML
  /// Structure: div.grid > div > a[href="/manga/..."] > figure > img
  SourcePaginatedResult<SourceMedia> _parseMangaList(String html, int page) {
    final document = html_parser.parse(html);
    final mangaList = <SourceMedia>[];
    final seen = <String>{};

    // Find all manga card containers - they have a structure of:
    // <div><a href="/manga/9815/meshinuma"><figure><img data-src="..."></figure></a>
    //   <div class="flex flex-col"><a href="..."><div class="font-black">Title</div></a></div></div>
    final containers = document.querySelectorAll('div.grid > div');

    for (final container in containers) {
      // Find the manga link
      final linkElement = container.querySelector('a[href^="/manga/"]');
      if (linkElement == null) continue;

      final href = linkElement.attributes['href'] ?? '';
      if (!href.startsWith('/manga/')) continue;

      // Extract ID: /manga/9815/meshinuma -> 9815/meshinuma
      final id = href.substring(7); // Remove "/manga/"
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);

      // Get title from font-black div
      final titleElement = container.querySelector('div.font-black');
      final title = titleElement?.text.trim() ?? '';
      if (title.isEmpty) continue;

      // Get cover image from img with data-src
      final imgElement = container.querySelector('img[data-src]');
      String? coverUrl = imgElement?.attributes['data-src'];
      
      // Fallback to src if data-src not found
      if (coverUrl == null || coverUrl.isEmpty) {
        coverUrl = imgElement?.attributes['src'];
      }

      mangaList.add(SourceMedia(
        id: id,
        title: title,
        coverUrl: coverUrl,
        contentType: SourceContentType.manga,
      ));
    }

    // Check for next page
    final nextPageLink = document.querySelector('a[href*="page=${page + 1}"]');
    final hasNextPage = nextPageLink != null;

    return SourcePaginatedResult(
      items: mangaList,
      hasNextPage: hasNextPage,
      currentPage: page,
    );
  }

  /// Parse manga details page
  SourceMedia _parseMangaDetails(String html, String id) {
    final document = html_parser.parse(html);

    // Title from h1.font-bold
    final titleElement = document.querySelector('h1.font-bold');
    final title = titleElement?.text.trim() ?? 'Unknown';

    // Cover image - look for img inside the flex-shrink-0 div
    final coverElement = document.querySelector('div.flex-shrink-0 img[data-src]');
    String? coverUrl = coverElement?.attributes['data-src'];
    if (coverUrl == null || coverUrl.isEmpty) {
      coverUrl = coverElement?.attributes['src'];
    }

    // Description from p.text-sm.text--secondary
    final descElement = document.querySelector('p.text-sm.text--secondary');
    String? description = descElement?.text.trim();
    if (description != null) {
      description = description.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    }

    // Genres from links
    final genreElements = document.querySelectorAll('a[href*="/search?genre="]');
    final genres = genreElements
        .map((e) => e.text.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    // Status, Type, Year from grid labels
    String? status;
    String? type;
    String? year;

    final gridDivs = document.querySelectorAll('div.grid > div');
    for (final div in gridDivs) {
      final label = div.querySelector('label');
      if (label == null) continue;
      
      final labelText = label.text.trim().toLowerCase();
      final valueDiv = div.children.length > 1 ? div.children[1] : null;
      final value = valueDiv?.text.trim() ?? '';

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

  /// Parse chapters from manga page
  /// Structure: #chapters a[href^="/chapters/"]
  List<SourceChapter> _parseChapters(String html) {
    final document = html_parser.parse(html);
    final chapters = <SourceChapter>[];
    final seen = <String>{};

    // Chapters are in div#chapters or div[data-filter-list]
    final chapterLinks = document.querySelectorAll('a[href^="/chapters/"]');

    for (final link in chapterLinks) {
      final href = link.attributes['href'] ?? '';
      if (!href.startsWith('/chapters/')) continue;

      // Extract chapter ID: /chapters/2-11179000/one-piece-chapter-1179 -> 2-11179000/one-piece-chapter-1179
      final id = href.substring(10); // Remove "/chapters/"
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);

      // Get chapter text
      final chapterText = link.text.trim();
      String title = chapterText;
      double? number;

      // Parse chapter number from text like "Chapter 1179"
      final numMatch = RegExp(r'[Cc]hapter\s*(\d+(?:\.\d+)?)')
          .firstMatch(chapterText);
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

  /// Parse pages from chapter page
  /// Structure: chapter-page img[data-src]
  List<SourcePage> _parsePages(String html) {
    final document = html_parser.parse(html);
    final pages = <SourcePage>[];
    final seen = <String>{};

    // Images are inside chapter-page elements with class js-page
    final pageImages = document.querySelectorAll('img[data-src]');

    for (final img in pageImages) {
      final imageUrl = img.attributes['data-src'] ?? '';
      
      // Only include CDN images for manga pages
      if (imageUrl.isEmpty || 
          seen.contains(imageUrl) ||
          !imageUrl.contains('cdn.readdetectiveconan.com/file/mangap')) {
        continue;
      }
      
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
