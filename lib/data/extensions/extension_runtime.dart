import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:dio/dio.dart';

import '../sources/source.dart';
import 'extension_model.dart';

/// JavaScript runtime for executing extension code
class ExtensionRuntime {
  late JavascriptRuntime _runtime;
  final LoadedExtension extension;
  final Dio _dio = Dio();
  bool _initialized = false;

  ExtensionRuntime(this.extension);

  /// Initialize the JavaScript runtime
  Future<void> initialize() async {
    if (_initialized) return;
    
    _runtime = getJavascriptRuntime();
    
    // Inject helper functions into JS context
    await _injectHelpers();
    
    // Load extension code
    final result = _runtime.evaluate(extension.jsCode);
    if (result.isError) {
      throw Exception('Failed to load extension: ${result.stringResult}');
    }
    
    _initialized = true;
  }

  /// Inject helper functions (fetch, DOM parsing, etc.)
  Future<void> _injectHelpers() async {
    // Inject fetch implementation
    _runtime.evaluate('''
      var __fetchResults = {};
      var __fetchId = 0;
      
      function fetch(url, options) {
        var id = __fetchId++;
        __pendingFetch = { id: id, url: url, options: options || {} };
        return new Promise(function(resolve, reject) {
          __fetchResults[id] = { resolve: resolve, reject: reject };
        });
      }
      
      function __resolveFetch(id, data) {
        if (__fetchResults[id]) {
          __fetchResults[id].resolve({
            ok: true,
            status: 200,
            text: function() { return Promise.resolve(data); },
            json: function() { return Promise.resolve(JSON.parse(data)); }
          });
          delete __fetchResults[id];
        }
      }
      
      function __rejectFetch(id, error) {
        if (__fetchResults[id]) {
          __fetchResults[id].reject(new Error(error));
          delete __fetchResults[id];
        }
      }
    ''');

    // Inject DOM parser helper
    _runtime.evaluate('''
      function parseHTML(html) {
        return {
          _html: html,
          querySelector: function(selector) {
            __domQuery = { html: this._html, selector: selector, type: 'single' };
            return __domResult;
          },
          querySelectorAll: function(selector) {
            __domQuery = { html: this._html, selector: selector, type: 'all' };
            return __domResults;
          }
        };
      }
    ''');

    // Inject console.log
    _runtime.evaluate('''
      var console = {
        log: function() {
          __consoleOutput = Array.from(arguments).join(' ');
        },
        error: function() {
          __consoleError = Array.from(arguments).join(' ');
        },
        warn: function() {
          __consoleWarn = Array.from(arguments).join(' ');
        }
      };
    ''');
  }

  /// Make HTTP request from JS context
  Future<String> _handleFetch(String url, Map<String, dynamic> options) async {
    try {
      final method = (options['method'] as String?)?.toUpperCase() ?? 'GET';
      final headers = (options['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      );
      final body = options['body'];

      Response response;
      switch (method) {
        case 'POST':
          response = await _dio.post(url, data: body, options: Options(headers: headers));
          break;
        case 'PUT':
          response = await _dio.put(url, data: body, options: Options(headers: headers));
          break;
        case 'DELETE':
          response = await _dio.delete(url, options: Options(headers: headers));
          break;
        default:
          response = await _dio.get(url, options: Options(headers: headers));
      }

      if (response.data is Map || response.data is List) {
        return jsonEncode(response.data);
      }
      return response.data.toString();
    } catch (e) {
      throw Exception('Fetch error: $e');
    }
  }

  /// Execute JS function and return result
  Future<dynamic> _callJs(String functionName, List<dynamic> args) async {
    if (!_initialized) {
      await initialize();
    }

    final argsJson = args.map((a) => jsonEncode(a)).join(', ');
    final code = '$functionName($argsJson)';
    
    final result = _runtime.evaluate(code);
    
    if (result.isError) {
      throw Exception('JS error: ${result.stringResult}');
    }
    
    // Handle pending fetch requests
    final pendingFetch = _runtime.evaluate('JSON.stringify(__pendingFetch || null)');
    if (pendingFetch.stringResult != 'null' && pendingFetch.stringResult.isNotEmpty) {
      try {
        final fetch = jsonDecode(pendingFetch.stringResult);
        if (fetch != null) {
          final fetchResult = await _handleFetch(
            fetch['url'] as String,
            (fetch['options'] as Map<String, dynamic>?) ?? {},
          );
          final fetchId = fetch['id'];
          _runtime.evaluate('__resolveFetch($fetchId, ${jsonEncode(fetchResult)})');
          _runtime.evaluate('__pendingFetch = null');
        }
      } catch (e) {
        debugPrint('Fetch handling error: $e');
      }
    }
    
    // Try to parse result as JSON
    try {
      final jsonResult = _runtime.evaluate('JSON.stringify($code)');
      return jsonDecode(jsonResult.stringResult);
    } catch (e) {
      return result.stringResult;
    }
  }

  /// Get popular content
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    final result = await _callJs('getPopular', [page]);
    return _parsePaginatedResult(result);
  }

  /// Get latest content
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    final result = await _callJs('getLatest', [page]);
    return _parsePaginatedResult(result);
  }

  /// Search content
  Future<SourcePaginatedResult<SourceMedia>> search(
    String query,
    int page, {
    Map<String, dynamic>? filters,
  }) async {
    final result = await _callJs('search', [query, page, filters ?? {}]);
    return _parsePaginatedResult(result);
  }

  /// Get media details
  Future<SourceMedia> getDetails(String id) async {
    final result = await _callJs('getDetails', [id]);
    return _parseMedia(result);
  }

  /// Get chapters
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    final result = await _callJs('getChapters', [mediaId]);
    return _parseChapters(result);
  }

  /// Get pages (for manga)
  Future<List<SourcePage>> getPages(String chapterId) async {
    final result = await _callJs('getPages', [chapterId]);
    return _parsePages(result);
  }

  /// Get video streams (for anime)
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    final result = await _callJs('getVideoStreams', [episodeId]);
    return _parseVideos(result);
  }

  /// Parse paginated result from JS
  SourcePaginatedResult<SourceMedia> _parsePaginatedResult(dynamic result) {
    if (result is! Map<String, dynamic>) {
      return const SourcePaginatedResult(items: []);
    }

    final items = (result['items'] as List<dynamic>?)
        ?.map((item) => _parseMedia(item))
        .toList() ?? [];

    return SourcePaginatedResult(
      items: items,
      hasNextPage: result['hasNextPage'] as bool? ?? false,
      currentPage: result['currentPage'] as int?,
      totalPages: result['totalPages'] as int?,
    );
  }

  /// Parse single media item
  SourceMedia _parseMedia(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid media data');
    }

    final contentType = switch (extension.metadata.contentType) {
      'anime' => SourceContentType.anime,
      'novel' => SourceContentType.novel,
      _ => SourceContentType.manga,
    };

    return SourceMedia.fromJson(data, contentType);
  }

  /// Parse chapters list
  List<SourceChapter> _parseChapters(dynamic data) {
    if (data is! List) {
      return [];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map((c) => SourceChapter.fromJson(c))
        .toList();
  }

  /// Parse pages list
  List<SourcePage> _parsePages(dynamic data) {
    if (data is! List) {
      return [];
    }
    return data.asMap().entries.map((entry) {
      final page = entry.value;
      if (page is String) {
        return SourcePage(index: entry.key, imageUrl: page);
      }
      if (page is Map<String, dynamic>) {
        return SourcePage(
          index: page['index'] as int? ?? entry.key,
          imageUrl: page['imageUrl'] as String? ?? page['url'] as String? ?? '',
          headers: (page['headers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        );
      }
      return SourcePage(index: entry.key, imageUrl: '');
    }).toList();
  }

  /// Parse videos list
  List<SourceVideo> _parseVideos(dynamic data) {
    if (data is! List) {
      return [];
    }
    return data.whereType<Map<String, dynamic>>().map((v) {
      return SourceVideo(
        url: v['url'] as String? ?? '',
        quality: v['quality'] as String? ?? 'auto',
        headers: (v['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        isM3U8: v['isM3U8'] as bool? ?? v['url']?.toString().contains('.m3u8') ?? false,
      );
    }).toList();
  }

  /// Dispose runtime
  void dispose() {
    if (_initialized) {
      _runtime.dispose();
    }
  }
}
