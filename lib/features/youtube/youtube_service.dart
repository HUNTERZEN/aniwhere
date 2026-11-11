import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/services/native_bridge.dart';
import '../../core/services/settings_storage.dart';

/// Model representing a YouTube video item in feeds, search results, or More videos.
class YouTubeVideoItem {
  final String videoId;
  final String title;
  final String channelName;
  final String? channelAvatarUrl;
  final String thumbnailUrl;
  final String durationText;
  final String viewCountText;
  final String publishedTimeText;
  final String? description;
  final bool isLive;

  const YouTubeVideoItem({
    required this.videoId,
    required this.title,
    required this.channelName,
    this.channelAvatarUrl,
    required this.thumbnailUrl,
    required this.durationText,
    required this.viewCountText,
    required this.publishedTimeText,
    this.description,
    this.isLive = false,
  });

  int get estimatedDurationSeconds {
    if (durationText.isEmpty || durationText == 'LIVE') return 210;
    final parts = durationText.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    return 210;
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'channelName': channelName,
        'channelAvatarUrl': channelAvatarUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationText': durationText,
        'viewCountText': viewCountText,
        'publishedTimeText': publishedTimeText,
        'description': description,
        'isLive': isLive,
      };

  factory YouTubeVideoItem.fromJson(Map<String, dynamic> json) {
    return YouTubeVideoItem(
      videoId: json['videoId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      channelName: json['channelName']?.toString() ?? 'YouTube',
      channelAvatarUrl: json['channelAvatarUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      durationText: json['durationText']?.toString() ?? '',
      viewCountText: json['viewCountText']?.toString() ?? '',
      publishedTimeText: json['publishedTimeText']?.toString() ?? '',
      description: json['description']?.toString(),
      isLive: json['isLive'] == true,
    );
  }
}

/// Model representing a real YouTube comment item.
class YouTubeCommentItem {
  final String authorName;
  final String? authorAvatarUrl;
  final String text;
  final String publishedTime;
  final String likeCount;
  final String replyCount;

  const YouTubeCommentItem({
    required this.authorName,
    this.authorAvatarUrl,
    required this.text,
    this.publishedTime = '',
    this.likeCount = '',
    this.replyCount = '',
  });
}

/// Model representing Watch Next data (More videos + Real Comments).
class YouTubeWatchNextData {
  final List<YouTubeVideoItem> relatedVideos;
  final List<YouTubeCommentItem> comments;
  final String commentCountText;

  const YouTubeWatchNextData({
    this.relatedVideos = const [],
    this.comments = const [],
    this.commentCountText = '',
  });
}

/// Model representing a selectable video quality stream (from 144p up to 2160p 4K).
class YouTubeQualityStream {
  final String label;
  final String badge;
  final int height;
  final int fps;
  final int bitrate;
  final int itag;
  final String codec;
  final String videoUrl;
  final String? audioUrl;
  final bool isMuxed;
  final bool isHls;
  final String userAgent;
  final int contentLength;
  final String mimeType;

  const YouTubeQualityStream({
    required this.label,
    required this.badge,
    required this.height,
    this.fps = 30,
    this.bitrate = 0,
    this.itag = 18,
    this.codec = 'MP4',
    required this.videoUrl,
    this.audioUrl,
    this.isMuxed = false,
    this.isHls = false,
    this.userAgent =
        'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    this.contentLength = 0,
    this.mimeType = 'video/mp4',
  });

  YouTubeQualityStream copyWith({
    String? audioUrl,
  }) {
    return YouTubeQualityStream(
      label: label,
      badge: badge,
      height: height,
      fps: fps,
      bitrate: bitrate,
      itag: itag,
      codec: codec,
      videoUrl: videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      isMuxed: isMuxed,
      isHls: isHls,
      userAgent: userAgent,
      contentLength: contentLength,
      mimeType: mimeType,
    );
  }

  String get formatSummary => '${height}p · $codec · itag $itag';
}

/// Complete resolved playback data for an ad-free YouTube video.
class YouTubeResolvedVideo {
  final String videoId;
  final String title;
  final String channelName;
  final String viewCountText;
  final String description;
  final List<YouTubeQualityStream> qualities;
  final String? bestAudioUrl;
  final String audioUserAgent;
  final List<YouTubeVideoItem> relatedVideos;

  const YouTubeResolvedVideo({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.viewCountText,
    required this.description,
    required this.qualities,
    this.bestAudioUrl,
    this.audioUserAgent =
        'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    this.relatedVideos = const [],
  });
}

/// Ad-Free YouTube service synced with the user's Google account (`ytm_cookie`)
/// and resolving direct streams up to 4K (`2160p`) via `ANDROID_VR` & `IOS` InnerTube.
class YouTubeService {
  static final YouTubeService _instance = YouTubeService._();
  factory YouTubeService() => _instance;
  YouTubeService._();

  static const String _ytOrigin = 'https://www.youtube.com';
  static const String _mYtOrigin = 'https://m.youtube.com';
  static const String _vrUserAgent =
      'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
  static const String _iosUserAgent =
      'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X;)';
  static const String _androidTestUserAgent =
      'com.google.android.youtube/1.9 (Linux; U; Android 12; US) gzip';
  static const String _webUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';
  static const String _mWebUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/537.36';

  String _cachedMergedCookie = '';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 9),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
        'User-Agent': _webUserAgent,
      },
    ),
  );

  /// Reads the shared Google / YouTube session cookie saved by the Music Google Sign-In flow,
  /// merged with live WebView cookies for `https://www.youtube.com`.
  String get _savedCookie {
    final stored = SettingsStorage.getString('ytm_cookie');
    if (_cachedMergedCookie.isNotEmpty && stored.isNotEmpty) {
      return _cachedMergedCookie;
    }
    return stored;
  }

  /// Syncs cookies from Android WebView CookieManager for both `youtube.com` and `music.youtube.com`
  /// so any Google login in Music is immediately active for YouTube feeds & subscriptions.
  Future<String> ensureFreshCookies() async {
    final stored = SettingsStorage.getString('ytm_cookie');
    String? ytWebCookie;
    String? ytmWebCookie;
    try {
      ytWebCookie = await NativeBridge.getCookies('https://www.youtube.com');
      ytmWebCookie = await NativeBridge.getCookies('https://music.youtube.com');
    } catch (_) {}

    final map = <String, String>{};
    void absorb(String? raw) {
      if (raw == null || raw.isEmpty) return;
      for (final part in raw.split(';')) {
        final idx = part.indexOf('=');
        if (idx <= 0) continue;
        final k = part.substring(0, idx).trim();
        final v = part.substring(idx + 1).trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          map[k] = v;
        }
      }
    }

    absorb(stored);
    absorb(ytmWebCookie);
    absorb(ytWebCookie);

    if (map.isEmpty) {
      _cachedMergedCookie = '';
      return '';
    }
    _cachedMergedCookie = map.entries.map((e) => '${e.key}=${e.value}').join('; ');
    if (stored.isEmpty && _extractSapisid(_cachedMergedCookie) != null) {
      await SettingsStorage.setString('ytm_cookie', _cachedMergedCookie);
    }
    return _cachedMergedCookie;
  }

  static String? _extractSapisid(String cookie) {
    return _extractCookieValue(cookie, 'SAPISID') ??
        _extractCookieValue(cookie, '__Secure-3PAPISID') ??
        _extractCookieValue(cookie, '__Secure-1PAPISID');
  }

  bool get isSignedIn {
    final c = _savedCookie;
    return c.isNotEmpty && _extractSapisid(c) != null;
  }

  static String? _extractCookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      if (part.substring(0, idx).trim() == name) {
        return part.substring(idx + 1).trim();
      }
    }
    return null;
  }

  /// Builds authenticated YouTube InnerTube headers using the user's Google `SAPISIDHASH`
  /// (`SAPISIDHASH` + `SAPISID1PHASH` + `SAPISID3PHASH` for 2025/2026 YouTube Web/MWeb).
  Map<String, String> _buildWebHeaders({
    bool includeAuth = true,
    bool mobileWeb = false,
  }) {
    final origin = mobileWeb ? _mYtOrigin : _ytOrigin;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': origin,
      'Referer': '$origin/',
      'X-YouTube-Client-Name': mobileWeb ? '2' : '1',
      'X-YouTube-Client-Version': '2.20250220.01.00',
      'User-Agent': mobileWeb ? _mWebUserAgent : _webUserAgent,
    };

    if (includeAuth) {
      final cookie = _savedCookie;
      final sapisid = _extractSapisid(cookie);
      if (cookie.isNotEmpty && sapisid != null && sapisid.isNotEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final hash = sha1.convert(utf8.encode('$ts $sapisid $origin')).toString();
        headers['Cookie'] = cookie;
        headers['Authorization'] =
            'SAPISIDHASH ${ts}_$hash SAPISID1PHASH ${ts}_$hash SAPISID3PHASH ${ts}_$hash';
        headers['X-Origin'] = origin;
        headers['X-Goog-AuthUser'] = '0';
      }
    }
    return headers;
  }

  static const Map<String, String> categoryQueries = {
    'All': 'trending viral videos 2026 4k',
    'Today': 'latest trending videos today 2026',
    'Videos': 'recommended popular videos 4k 2026',
    'Subscribed': 'latest channel uploads new videos 2026',
    'Watched': 'popular must watch videos 2026',
    'Liked': 'top rated music videos and anime 4k',
    'Music': 'official music videos hits 4k 2026',
    'Anime': 'anime official trailers clips episodes 2026',
    'Gaming': 'gaming gameplay highlights trailers 4k',
    '4K UHD': '4k ultra hd 60fps hdr demo music anime',
  };

  /// Curated fallback videos only when offline and not signed in.
  static final List<YouTubeVideoItem> fallbackVideos = [
    const YouTubeVideoItem(
      videoId: 'fO9e9jnhYK8',
      title: 'Demon Slayer: Kimetsu no Yaiba Infinity Castle | Official Trailer [4K]',
      channelName: 'Crunchyroll',
      thumbnailUrl: 'https://i.ytimg.com/vi/fO9e9jnhYK8/hq720.jpg',
      durationText: '2:18',
      viewCountText: '14M views',
      publishedTimeText: '2 months ago',
    ),
    const YouTubeVideoItem(
      videoId: 'B9synWjqBn8',
      title: 'Travis Scott - FE!N ft. Playboi Carti (Official Music Video)',
      channelName: 'Travis Scott',
      thumbnailUrl: 'https://i.ytimg.com/vi/B9synWjqBn8/hq720.jpg',
      durationText: '3:32',
      viewCountText: '215M views',
      publishedTimeText: '1 year ago',
    ),
    const YouTubeVideoItem(
      videoId: '4NRXx6U8ABQ',
      title: 'The Weeknd - Blinding Lights (Official Video)',
      channelName: 'The Weeknd',
      thumbnailUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hq720.jpg',
      durationText: '4:22',
      viewCountText: '910M views',
      publishedTimeText: '4 years ago',
    ),
    const YouTubeVideoItem(
      videoId: 'QdBZY2fkU-0',
      title: 'Grand Theft Auto VI Trailer 1',
      channelName: 'Rockstar Games',
      thumbnailUrl: 'https://i.ytimg.com/vi/QdBZY2fkU-0/hq720.jpg',
      durationText: '1:31',
      viewCountText: '235M views',
      publishedTimeText: '1 year ago',
    ),
    const YouTubeVideoItem(
      videoId: 'pkKu9hLT-t8',
      title: 'Jujutsu Kaisen Season 2 - Shibuya Incident | Official Trailer',
      channelName: 'TOHO animation',
      thumbnailUrl: 'https://i.ytimg.com/vi/pkKu9hLT-t8/hq720.jpg',
      durationText: '1:54',
      viewCountText: '19M views',
      publishedTimeText: '1 year ago',
    ),
    const YouTubeVideoItem(
      videoId: '34Na4j8AVgA',
      title: 'The Weeknd - Starboy ft. Daft Punk (Official Video)',
      channelName: 'The Weeknd',
      thumbnailUrl: 'https://i.ytimg.com/vi/34Na4j8AVgA/hq720.jpg',
      durationText: '4:33',
      viewCountText: '2.5B views',
      publishedTimeText: '8 years ago',
    ),
  ];

  /// Fetch videos for a category chip on the Home screen.
  Future<List<YouTubeVideoItem>> getCategoryFeed(String category) async {
    await ensureFreshCookies();

    if (isSignedIn) {
      if (category == 'Subscribed' || category == 'Subscriptions') {
        final subs = await _fetchAccountSubscriptionsFeed();
        if (subs.isNotEmpty) return subs;
      } else if (category == 'Watched' || category == 'History') {
        final history = await _fetchAuthenticatedBrowseFeed('FEhistory');
        if (history.isNotEmpty) return history;
        final subs = await _fetchAccountSubscriptionsFeed();
        if (subs.isNotEmpty) return subs;
      } else if (category == 'Liked') {
        final liked = await _fetchAuthenticatedBrowseFeed('FEliked_videos');
        if (liked.isNotEmpty) return liked;
        final vllm = await _fetchAuthenticatedBrowseFeed('VLLM');
        if (vllm.isNotEmpty) return vllm;
      } else if (category == 'All' ||
          category == 'For You' ||
          category == 'Today' ||
          category == 'Videos') {
        final combined = await _fetchPersonalizedAccountHomeFeed(category: category);
        if (combined.isNotEmpty) return combined;
      } else {
        final personal = await _fetchPersonalizedAccountHomeFeed(category: 'All');
        final lower = category.toLowerCase();
        final matched = personal
            .where((v) =>
                v.title.toLowerCase().contains(lower) ||
                v.channelName.toLowerCase().contains(lower))
            .toList();
        final searched = await searchVideos(categoryQueries[category] ?? '$category 4k');
        final seen = <String>{};
        final merged = <YouTubeVideoItem>[];
        for (final v in [...matched, ...searched]) {
          if (seen.add(v.videoId)) merged.add(v);
        }
        if (merged.isNotEmpty) return merged;
      }
    }

    final query = categoryQueries[category] ?? '$category videos 4k';
    final results = await searchVideos(query);
    if (results.isNotEmpty) return results;
    return fallbackVideos;
  }

  Future<List<YouTubeVideoItem>> _fetchPersonalizedAccountHomeFeed({
    required String category,
  }) async {
    final results = await Future.wait([
      _fetchAuthenticatedBrowseFeed('FEwhat_to_watch'),
      _fetchAccountSubscriptionsFeed(),
      _fetchAuthenticatedBrowseFeed('FEhistory'),
      _fetchAuthenticatedBrowseFeed('FEliked_videos'),
    ]);

    final homeRecs = results[0];
    final subs = results[1];
    final history = results[2];
    final liked = results[3];

    final out = <YouTubeVideoItem>[];
    final seen = <String>{};

    void addList(List<YouTubeVideoItem> list) {
      for (final item in list) {
        if (seen.add(item.videoId)) {
          out.add(item);
        }
      }
    }

    if (category == 'Today') {
      final recentSubs = subs.where((v) {
        final p = v.publishedTimeText.toLowerCase();
        return p.contains('hour') ||
            p.contains('minute') ||
            p.contains('day') ||
            p.contains('today') ||
            p.isEmpty;
      }).toList();
      addList(recentSubs);
      addList(subs);
      addList(homeRecs);
      addList(history);
    } else {
      final maxLen = [homeRecs.length, subs.length, history.length]
          .reduce((a, b) => a > b ? a : b);
      for (int i = 0; i < maxLen; i++) {
        if (i < homeRecs.length && seen.add(homeRecs[i].videoId)) {
          out.add(homeRecs[i]);
        }
        if (i < subs.length && seen.add(subs[i].videoId)) {
          out.add(subs[i]);
        }
        if (i < history.length && seen.add(history[i].videoId)) {
          out.add(history[i]);
        }
      }
      addList(liked);
    }

    if (out.length < 12 && out.isNotEmpty) {
      final seed = out.first;
      final relatedToSeed = await _fetchNextRecommendationsOnly(seed.videoId);
      addList(relatedToSeed);
    }

    return out;
  }

  Future<List<YouTubeVideoItem>> _fetchAccountSubscriptionsFeed() async {
    final videos = <YouTubeVideoItem>[];
    final seen = <String>{};

    final directSubs = await _fetchAuthenticatedBrowseFeed('FEsubscriptions');
    for (final v in directSubs) {
      if (seen.add(v.videoId)) videos.add(v);
    }

    if (videos.length >= 8) return videos;

    try {
      final res = await _dio.post(
        '$_ytOrigin/youtubei/v1/guide?prettyPrint=false',
        options: Options(headers: _buildWebHeaders(includeAuth: true)),
        data: {
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250220.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
        },
      );
      final dynamic data =
          res.data is String ? jsonDecode(res.data as String) : res.data;
      if (data is Map) {
        final channelIds = <String>[];
        _extractSubscribedChannelIds(data, channelIds);
        if (channelIds.isNotEmpty) {
          final channelFetches = channelIds.take(5).map(
                (cid) => _fetchAuthenticatedBrowseFeed(cid),
              );
          final channelLists = await Future.wait(channelFetches);
          for (final list in channelLists) {
            for (final v in list) {
              if (seen.add(v.videoId)) videos.add(v);
            }
          }
        }
      }
    } catch (_) {}

    return videos;
  }

  void _extractSubscribedChannelIds(dynamic node, List<String> out) {
    if (out.length >= 10) return;
    if (node is Map) {
      final browseId =
          node['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
      if (browseId.startsWith('UC') && !out.contains(browseId)) {
        out.add(browseId);
      }
      for (final v in node.values) {
        _extractSubscribedChannelIds(v, out);
        if (out.length >= 10) break;
      }
    } else if (node is List) {
      for (final e in node) {
        _extractSubscribedChannelIds(e, out);
        if (out.length >= 10) break;
      }
    }
  }

  Future<List<YouTubeVideoItem>> _fetchAuthenticatedBrowseFeed(String browseId) async {
    final videos = <YouTubeVideoItem>[];
    final seenIds = <String>{};

    try {
      final response = await _dio.post(
        '$_ytOrigin/youtubei/v1/browse?prettyPrint=false',
        options: Options(headers: _buildWebHeaders(includeAuth: true, mobileWeb: false)),
        data: {
          'browseId': browseId,
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250220.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
        },
      );
      final dynamic data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is Map) {
        _extractVideoRenderers(data, videos, seenIds, maxCount: 35);
      }
    } catch (_) {}

    if (videos.length < 4) {
      try {
        final response = await _dio.post(
          '$_mYtOrigin/youtubei/v1/browse?prettyPrint=false',
          options: Options(headers: _buildWebHeaders(includeAuth: true, mobileWeb: true)),
          data: {
            'browseId': browseId,
            'context': {
              'client': {
                'clientName': 'MWEB',
                'clientVersion': '2.20250220.01.00',
                'hl': 'en',
                'gl': 'US',
              },
            },
          },
        );
        final dynamic data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        if (data is Map) {
          _extractVideoRenderers(data, videos, seenIds, maxCount: 35);
        }
      } catch (_) {}
    }

    return videos;
  }

  Future<List<YouTubeVideoItem>> searchVideos(String query) async {
    if (query.trim().isEmpty) return fallbackVideos;
    try {
      final response = await _dio.post(
        '$_ytOrigin/youtubei/v1/search?prettyPrint=false',
        options: Options(headers: _buildWebHeaders(includeAuth: true)),
        data: {
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250220.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'query': query.trim(),
        },
      );

      final dynamic data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map) return [];

      final videos = <YouTubeVideoItem>[];
      final seenIds = <String>{};
      _extractVideoRenderers(data, videos, seenIds, maxCount: 30);
      return videos;
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final res = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {
          'client': 'firefox',
          'ds': 'yt',
          'q': q,
        },
      );
      final dynamic data = res.data is String ? jsonDecode(res.data as String) : res.data;
      if (data is List && data.length > 1 && data[1] is List) {
        return (data[1] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .take(8)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _extractVideoRenderers(
    dynamic node,
    List<YouTubeVideoItem> out,
    Set<String> seenIds, {
    int maxCount = 32,
  }) {
    if (out.length >= maxCount) return;
    if (node is Map) {
      if (node.containsKey('lockupViewModel') && node['lockupViewModel'] is Map) {
        final item = _parseLockupViewModel(node['lockupViewModel'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else if (node.containsKey('videoRenderer') && node['videoRenderer'] is Map) {
        final item = _parseVideoRenderer(node['videoRenderer'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else if (node.containsKey('videoWithContextRenderer') &&
          node['videoWithContextRenderer'] is Map) {
        final item = _parseVideoWithContextRenderer(node['videoWithContextRenderer'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else if (node.containsKey('compactVideoRenderer') &&
          node['compactVideoRenderer'] is Map) {
        final item = _parseVideoRenderer(node['compactVideoRenderer'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else if (node.containsKey('playlistVideoRenderer') &&
          node['playlistVideoRenderer'] is Map) {
        final item = _parseVideoRenderer(node['playlistVideoRenderer'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else if (node.containsKey('gridVideoRenderer') &&
          node['gridVideoRenderer'] is Map) {
        final item = _parseVideoRenderer(node['gridVideoRenderer'] as Map);
        if (item != null && seenIds.add(item.videoId)) {
          out.add(item);
        }
      } else {
        for (final v in node.values) {
          _extractVideoRenderers(v, out, seenIds, maxCount: maxCount);
          if (out.length >= maxCount) break;
        }
      }
    } else if (node is List) {
      for (final elem in node) {
        _extractVideoRenderers(elem, out, seenIds, maxCount: maxCount);
        if (out.length >= maxCount) break;
      }
    }
  }

  YouTubeVideoItem? _parseLockupViewModel(Map lockup) {
    try {
      final contentType = lockup['contentType']?.toString() ?? '';
      if (contentType.isNotEmpty &&
          !contentType.contains('VIDEO') &&
          !contentType.contains('SHORT')) {
        return null;
      }

      String videoId = lockup['contentId']?.toString() ?? '';
      if (videoId.isEmpty || videoId.length != 11) {
        videoId = lockup['rendererContext']?['commandContext']?['onTap']
                    ?['innertubeCommand']?['watchEndpoint']?['videoId']
                ?.toString() ??
            '';
      }
      if (videoId.isEmpty) return null;

      final metaVm = lockup['metadata']?['lockupMetadataViewModel'];
      if (metaVm is! Map) return null;

      final title = metaVm['title']?['content']?.toString() ?? '';
      if (title.isEmpty) return null;

      String channelName = 'YouTube';
      String viewCountText = '';
      String publishedTimeText = '';

      final rows =
          metaVm['metadata']?['contentMetadataViewModel']?['metadataRows'] as List?;
      if (rows != null) {
        final texts = <String>[];
        for (final row in rows) {
          if (row is! Map) continue;
          final parts = row['metadataParts'] as List?;
          if (parts == null) continue;
          for (final p in parts) {
            if (p is! Map) continue;
            final t = p['text']?['content']?.toString() ?? '';
            if (t.isNotEmpty) texts.add(t);
          }
        }
        if (texts.isNotEmpty) {
          channelName = texts.first;
        }
        for (final t in texts.skip(1)) {
          final lower = t.toLowerCase();
          if (lower.contains('view') || lower.contains('watching')) {
            viewCountText = t;
          } else if (lower.contains('ago') ||
              lower.contains('streamed') ||
              lower.contains('hour') ||
              lower.contains('day') ||
              lower.contains('week') ||
              lower.contains('month') ||
              lower.contains('year')) {
            publishedTimeText = t;
          }
        }
      }

      String? channelAvatarUrl;
      final avatarSources = metaVm['image']?['decoratedAvatarViewModel']?['avatar']
          ?['avatarViewModel']?['image']?['sources'] as List?;
      if (avatarSources != null && avatarSources.isNotEmpty) {
        channelAvatarUrl = avatarSources.last['url']?.toString();
      }

      String thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hq720.jpg';
      final thumbVm = lockup['contentImage']?['thumbnailViewModel'] ??
          lockup['contentImage']?['collectionThumbnailViewModel']?['primaryThumbnail']
              ?['thumbnailViewModel'];
      if (thumbVm is Map) {
        final sources = thumbVm['image']?['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          final best = sources.last['url']?.toString() ?? '';
          if (best.startsWith('http')) thumbnailUrl = best;
        }
      }

      String durationText = '';
      bool isLive = false;
      if (thumbVm is Map) {
        final overlays = thumbVm['overlays'] as List?;
        if (overlays != null) {
          for (final ov in overlays) {
            if (ov is! Map) continue;
            final badges =
                ov['thumbnailOverlayBadgeViewModel']?['thumbnailBadges'] as List?;
            if (badges != null) {
              for (final b in badges) {
                final text =
                    b?['thumbnailBadgeViewModel']?['text']?.toString() ?? '';
                if (text.isNotEmpty) {
                  durationText = text;
                  if (text.toUpperCase().contains('LIVE')) isLive = true;
                  break;
                }
              }
            }
          }
        }
      }

      return YouTubeVideoItem(
        videoId: videoId,
        title: title,
        channelName: channelName,
        channelAvatarUrl: channelAvatarUrl,
        thumbnailUrl: thumbnailUrl,
        durationText: durationText,
        viewCountText: viewCountText.isEmpty ? 'Recommended' : viewCountText,
        publishedTimeText: publishedTimeText,
        isLive: isLive,
      );
    } catch (_) {
      return null;
    }
  }

  YouTubeVideoItem? _parseVideoWithContextRenderer(Map r) {
    try {
      final videoId = r['videoId']?.toString() ?? '';
      if (videoId.isEmpty) return null;

      final title = _extractText(r['headline']) != ''
          ? _extractText(r['headline'])
          : _extractText(r['title']);
      if (title.isEmpty) return null;

      String channelName = _extractText(r['shortBylineText']);
      if (channelName.isEmpty) channelName = 'YouTube';

      final durationText = _extractText(r['lengthText']);
      String viewCountText = _extractText(r['shortViewCountText']);
      if (viewCountText.isEmpty) viewCountText = 'Recommended';
      final publishedTimeText = _extractText(r['publishedTimeText']);

      String thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hq720.jpg';
      final thumbs = r['thumbnail']?['thumbnails'] as List?;
      if (thumbs != null && thumbs.isNotEmpty) {
        final best = thumbs.last['url']?.toString() ?? '';
        if (best.startsWith('http')) thumbnailUrl = best;
      }

      String? channelAvatarUrl;
      final chThumbs = r['channelThumbnail']?['channelThumbnailWithLinkRenderer']
          ?['thumbnail']?['thumbnails'] as List?;
      if (chThumbs != null && chThumbs.isNotEmpty) {
        channelAvatarUrl = chThumbs.last['url']?.toString();
      }

      return YouTubeVideoItem(
        videoId: videoId,
        title: title,
        channelName: channelName,
        channelAvatarUrl: channelAvatarUrl,
        thumbnailUrl: thumbnailUrl,
        durationText: durationText,
        viewCountText: viewCountText,
        publishedTimeText: publishedTimeText,
      );
    } catch (_) {
      return null;
    }
  }

  YouTubeVideoItem? _parseVideoRenderer(Map r) {
    try {
      final videoId = r['videoId']?.toString() ?? '';
      if (videoId.isEmpty) return null;

      final title = _extractText(r['title']);
      if (title.isEmpty) return null;

      String channelName = _extractText(r['ownerText']);
      if (channelName.isEmpty) {
        channelName = _extractText(r['longBylineText']);
      }
      if (channelName.isEmpty) {
        channelName = _extractText(r['shortBylineText']);
      }
      if (channelName.isEmpty) channelName = 'YouTube';

      String durationText = _extractText(r['lengthText']);
      bool isLive = false;
      if (durationText.isEmpty) {
        final badges = r['badges'] as List?;
        if (badges != null) {
          for (final b in badges) {
            final label = b?['metadataBadgeRenderer']?['label']?.toString() ?? '';
            if (label.toUpperCase().contains('LIVE')) {
              isLive = true;
              durationText = 'LIVE';
              break;
            }
          }
        }
      }

      String viewCountText = _extractText(r['shortViewCountText']);
      if (viewCountText.isEmpty) {
        viewCountText = _extractText(r['viewCountText']);
      }
      if (viewCountText.isEmpty) viewCountText = 'Popular';

      final publishedTimeText = _extractText(r['publishedTimeText']);

      String thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hq720.jpg';
      final thumbs = r['thumbnail']?['thumbnails'] as List?;
      if (thumbs != null && thumbs.isNotEmpty) {
        final best = thumbs.last['url']?.toString() ?? '';
        if (best.startsWith('http')) {
          thumbnailUrl = best;
        }
      }

      String? channelAvatarUrl;
      final channelThumbs = r['channelThumbnailSupportedRenderers']
              ?['channelThumbnailWithLinkRenderer']?['thumbnail']?['thumbnails']
          as List?;
      if (channelThumbs != null && channelThumbs.isNotEmpty) {
        channelAvatarUrl = channelThumbs.last['url']?.toString();
      }

      String? description;
      final descSteps = r['detailedMetadataSnippets'] as List?;
      if (descSteps != null && descSteps.isNotEmpty) {
        description = _extractText(descSteps.first['snippetText']);
      }

      return YouTubeVideoItem(
        videoId: videoId,
        title: title,
        channelName: channelName,
        channelAvatarUrl: channelAvatarUrl,
        thumbnailUrl: thumbnailUrl,
        durationText: durationText,
        viewCountText: viewCountText,
        publishedTimeText: publishedTimeText,
        description: description,
        isLive: isLive,
      );
    } catch (_) {
      return null;
    }
  }

  String _extractText(dynamic node) {
    if (node == null) return '';
    if (node is String) return node;
    if (node is Map) {
      if (node['simpleText'] != null) {
        return node['simpleText'].toString();
      }
      if (node['content'] != null) {
        return node['content'].toString();
      }
      final runs = node['runs'];
      if (runs is List) {
        return runs.map((r) => r is Map ? (r['text']?.toString() ?? '') : '').join('');
      }
    }
    return '';
  }

  /// Fast stream resolution for immediate playback on first tap!
  /// Queries `ANDROID_VR` (`Oculus Quest 3`) + `IOS` (`iPhone16,2`) in parallel so every video
  /// (including brand-new uploads, 1080p, 1440p 2K, and 2160p 4K) resolves on the first attempt!
  Future<YouTubeResolvedVideo> resolveVideo(YouTubeVideoItem video) async {
    final qualities = <YouTubeQualityStream>[];
    String? bestAudioUrl;
    String audioUa = _vrUserAgent;
    String resolvedTitle = video.title;
    String resolvedChannel = video.channelName;
    String resolvedViews = video.viewCountText;
    String resolvedDesc = video.description ?? '';

    void absorbMeta(String t, String c, String v, String d) {
      if (t.isNotEmpty) resolvedTitle = t;
      if (c.isNotEmpty) resolvedChannel = c;
      if (v.isNotEmpty) resolvedViews = v;
      if (d.isNotEmpty) resolvedDesc = d;
    }

    // Run ANDROID_VR, IOS, and ANDROID (format 18) in parallel for 100% reliable 4K/2K/1080p + sound
    await Future.wait([
      // 1. ANDROID_VR (with account cookies if signed in)
      () async {
        try {
          final vrHeaders = <String, String>{
            'User-Agent': _vrUserAgent,
            'Content-Type': 'application/json',
            'X-YouTube-Client-Name': '28',
            'X-YouTube-Client-Version': '1.60.19',
          };
          final cookie = _savedCookie;
          if (cookie.isNotEmpty) {
            vrHeaders['Cookie'] = cookie;
            final sapisid = _extractSapisid(cookie);
            if (sapisid != null && sapisid.isNotEmpty) {
              final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final hash = sha1.convert(utf8.encode('$ts $sapisid $_ytOrigin')).toString();
              vrHeaders['Authorization'] = 'SAPISIDHASH ${ts}_$hash';
            }
          }

          final res = await _dio.post(
            '$_ytOrigin/youtubei/v1/player?prettyPrint=false',
            options: Options(headers: vrHeaders),
            data: {
              'videoId': video.videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
              'context': {
                'client': {
                  'clientName': 'ANDROID_VR',
                  'clientVersion': '1.60.19',
                  'deviceMake': 'Oculus',
                  'deviceModel': 'Quest 3',
                  'osName': 'Android',
                  'osVersion': '12L',
                  'androidSdkVersion': 32,
                  'hl': 'en',
                  'gl': 'US',
                },
              },
            },
          );
          _parsePlayerResponse(
            res.data,
            userAgent: _vrUserAgent,
            qualities: qualities,
            onMetadata: absorbMeta,
            onBestAudio: (url) {
              if (url.isNotEmpty) {
                bestAudioUrl = url;
                audioUa = _vrUserAgent;
              }
            },
          );
        } catch (_) {}
      }(),

      // 2. IOS Client (provides direct unthrottled 2160p 4K, 1440p 2K, 1080p, 720p adaptive streams)
      () async {
        try {
          final res = await _dio.post(
            '$_ytOrigin/youtubei/v1/player?prettyPrint=false',
            options: Options(
              headers: {
                'User-Agent': _iosUserAgent,
                'Content-Type': 'application/json',
                'X-YouTube-Client-Name': '5',
                'X-YouTube-Client-Version': '20.03.02',
              },
            ),
            data: {
              'videoId': video.videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
              'context': {
                'client': {
                  'clientName': 'IOS',
                  'clientVersion': '20.03.02',
                  'deviceMake': 'Apple',
                  'deviceModel': 'iPhone16,2',
                  'osName': 'iPhone',
                  'osVersion': '18.2.1.22C161',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
            },
          );
          _parsePlayerResponse(
            res.data,
            userAgent: _iosUserAgent,
            qualities: qualities,
            onMetadata: absorbMeta,
            onBestAudio: (url) {
              if (bestAudioUrl == null && url.isNotEmpty) {
                bestAudioUrl = url;
                audioUa = _iosUserAgent;
              }
            },
          );
        } catch (_) {}
      }(),

      // 3. ANDROID Client (provides guaranteed format 18 muxed 360p with zero bot checks + universal audio stream)
      () async {
        try {
          const androidUa = 'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip';
          final res = await _dio.post(
            '$_ytOrigin/youtubei/v1/player?prettyPrint=false',
            options: Options(
              headers: {
                'User-Agent': androidUa,
                'Content-Type': 'application/json',
                'X-YouTube-Client-Name': '3',
                'X-YouTube-Client-Version': '21.26.364',
              },
            ),
            data: {
              'videoId': video.videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
              'context': {
                'client': {
                  'clientName': 'ANDROID',
                  'clientVersion': '21.26.364',
                  'androidSdkVersion': 30,
                  'osName': 'Android',
                  'osVersion': '11',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
            },
          );
          final dynamic data = res.data is String ? jsonDecode(res.data as String) : res.data;
          if (data is Map) {
            final streaming = data['streamingData'];
            if (streaming is Map) {
              final formats = streaming['formats'];
              if (formats is List) {
                for (final f in formats) {
                  if (f is! Map) continue;
                  final url = f['url']?.toString() ?? '';
                  final mime = f['mimeType']?.toString() ?? '';
                  final itag = (f['itag'] as num?)?.toInt() ?? 18;
                  if (url.isNotEmpty && mime.contains('mp4')) {
                    if (bestAudioUrl == null) {
                      bestAudioUrl = url;
                      audioUa = androidUa;
                    }
                    if (!qualities.any((q) => q.isMuxed && q.itag == itag)) {
                      qualities.add(
                        YouTubeQualityStream(
                          label: '360p (SD Direct)',
                          badge: 'SD',
                          height: 360,
                          itag: itag,
                          codec: 'MP4',
                          videoUrl: url,
                          isMuxed: true,
                          userAgent: androidUa,
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}
      }(),
    ]);

    // 4. Ensure every adaptive stream has an audioUrl bound so 1080p, 2K, and 4K have full audio
    if (bestAudioUrl != null && bestAudioUrl!.isNotEmpty) {
      for (int i = 0; i < qualities.length; i++) {
        final q = qualities[i];
        if (!q.isMuxed && (q.audioUrl == null || q.audioUrl!.isEmpty)) {
          qualities[i] = q.copyWith(audioUrl: bestAudioUrl);
        }
      }
    }

    // 5. Fallback: ANDROID_TESTSUITE if qualities is still empty
    if (qualities.isEmpty) {
      try {
        final res = await _dio.post(
          '$_ytOrigin/youtubei/v1/player?prettyPrint=false',
          options: Options(
            headers: {
              'User-Agent': _androidTestUserAgent,
              'Content-Type': 'application/json',
              'X-YouTube-Client-Name': '30',
              'X-YouTube-Client-Version': '1.9',
            },
          ),
          data: {
            'videoId': video.videoId,
            'contentCheckOk': true,
            'racyCheckOk': true,
            'context': {
              'client': {
                'clientName': 'ANDROID_TESTSUITE',
                'clientVersion': '1.9',
                'androidSdkVersion': 32,
                'hl': 'en',
                'gl': 'US',
              },
            },
          },
        );
        _parsePlayerResponse(
          res.data,
          userAgent: _androidTestUserAgent,
          qualities: qualities,
          onMetadata: absorbMeta,
          onBestAudio: (url) {
            if (bestAudioUrl == null && url.isNotEmpty) {
              bestAudioUrl = url;
              audioUa = _androidTestUserAgent;
            }
          },
        );
      } catch (_) {}
    }

    // Sort qualities from highest resolution (2160p 4K) down to 144p
    qualities.sort((a, b) {
      final hCmp = b.height.compareTo(a.height);
      if (hCmp != 0) return hCmp;
      if (a.isMuxed != b.isMuxed) return a.isMuxed ? -1 : 1;
      return b.bitrate.compareTo(a.bitrate);
    });

    return YouTubeResolvedVideo(
      videoId: video.videoId,
      title: resolvedTitle,
      channelName: resolvedChannel,
      viewCountText: resolvedViews,
      description: resolvedDesc,
      qualities: qualities,
      bestAudioUrl: bestAudioUrl,
      audioUserAgent: audioUa,
      relatedVideos: const [],
    );
  }

  /// Fetches `More videos` (Watch Next) AND real YouTube `Comments` in parallel
  /// without blocking video stream startup!
  Future<YouTubeWatchNextData> fetchWatchNextAndComments({
    required String videoId,
    required String channelName,
    required String title,
  }) async {
    final related = <YouTubeVideoItem>[];
    final seenIds = <String>{videoId};
    final comments = <YouTubeCommentItem>[];
    String commentCountText = '';
    String? commentContinuationToken;

    // 1. Query YouTube InnerTube `next` endpoint for Watch Next + comment continuation token
    try {
      final res = await _dio.post(
        '$_ytOrigin/youtubei/v1/next?prettyPrint=false',
        options: Options(headers: _buildWebHeaders(includeAuth: true)),
        data: {
          'videoId': videoId,
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250220.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
        },
      );
      final dynamic data =
          res.data is String ? jsonDecode(res.data as String) : res.data;
      if (data is Map) {
        _extractVideoRenderers(data, related, seenIds, maxCount: 20);
        commentContinuationToken = _findCommentContinuationToken(data);
        commentCountText = _findCommentCountText(data);
      }
    } catch (_) {}

    // 2. Fetch real comments using the continuation token AND supplement related videos if needed
    await Future.wait([
      if (commentContinuationToken != null && commentContinuationToken.isNotEmpty)
        () async {
          try {
            final cRes = await _dio.post(
              '$_ytOrigin/youtubei/v1/next?prettyPrint=false',
              options: Options(headers: _buildWebHeaders(includeAuth: true)),
              data: {
                'continuation': commentContinuationToken,
                'context': {
                  'client': {
                    'clientName': 'WEB',
                    'clientVersion': '2.20250220.01.00',
                    'hl': 'en',
                    'gl': 'US',
                  },
                },
              },
            );
            final dynamic cData =
                cRes.data is String ? jsonDecode(cRes.data as String) : cRes.data;
            if (cData is Map) {
              _extractComments(cData, comments);
            }
          } catch (_) {}
        }(),
      if (related.length < 6)
        () async {
          try {
            final cleanWords = title
                .replaceAll(RegExp(r'[^\w\s]'), ' ')
                .split(RegExp(r'\s+'))
                .where((w) => w.length > 2)
                .take(4)
                .join(' ');
            final searched = await searchVideos('$channelName $cleanWords');
            for (final item in searched) {
              if (seenIds.add(item.videoId)) {
                related.add(item);
                if (related.length >= 16) break;
              }
            }
          } catch (_) {}
        }(),
    ]);

    return YouTubeWatchNextData(
      relatedVideos: related,
      comments: comments,
      commentCountText:
          commentCountText.isNotEmpty ? commentCountText : (comments.isNotEmpty ? '${comments.length}+' : ''),
    );
  }

  String? _findCommentContinuationToken(dynamic node) {
    if (node is Map) {
      // Check engagementPanelSectionListRenderer for comments panel
      if (node['panelIdentifier'] == 'engagement-panel-comments-section' ||
          node['targetId'] == 'engagement-panel-comments-section' ||
          node['sectionIdentifier'] == 'comment-item-section') {
        final tok = _findFirstToken(node);
        if (tok != null && tok.isNotEmpty) return tok;
      }
      for (final v in node.values) {
        final found = _findCommentContinuationToken(v);
        if (found != null && found.isNotEmpty) return found;
      }
    } else if (node is List) {
      for (final e in node) {
        final found = _findCommentContinuationToken(e);
        if (found != null && found.isNotEmpty) return found;
      }
    }
    return null;
  }

  String? _findFirstToken(dynamic node) {
    if (node is Map) {
      final t1 = node['continuationEndpoint']?['continuationCommand']?['token']?.toString();
      if (t1 != null && t1.isNotEmpty) return t1;
      final t2 = node['reloadContinuationItemsCommand']?['token']?.toString();
      if (t2 != null && t2.isNotEmpty) return t2;
      final t3 = node['nextContinuationData']?['continuation']?.toString();
      if (t3 != null && t3.isNotEmpty) return t3;
      for (final v in node.values) {
        final f = _findFirstToken(v);
        if (f != null && f.isNotEmpty) return f;
      }
    } else if (node is List) {
      for (final e in node) {
        final f = _findFirstToken(e);
        if (f != null && f.isNotEmpty) return f;
      }
    }
    return null;
  }

  String _findCommentCountText(dynamic node) {
    if (node is Map) {
      if (node.containsKey('commentsEntryPointHeaderRenderer')) {
        final r = node['commentsEntryPointHeaderRenderer'];
        if (r is Map) {
          final c = _extractText(r['commentCount']);
          if (c.isNotEmpty) return c;
        }
      }
      if (node.containsKey('ContextualInfo')) {
        final c = _extractText(node['ContextualInfo']);
        if (c.isNotEmpty) return c;
      }
      for (final v in node.values) {
        final f = _findCommentCountText(v);
        if (f.isNotEmpty) return f;
      }
    } else if (node is List) {
      for (final e in node) {
        final f = _findCommentCountText(e);
        if (f.isNotEmpty) return f;
      }
    }
    return '';
  }

  void _extractComments(dynamic node, List<YouTubeCommentItem> out) {
    if (out.length >= 40) return;
    if (node is Map) {
      // 1. 2025/2026 YouTube commentEntityPayload
      if (node.containsKey('commentEntityPayload') &&
          node['commentEntityPayload'] is Map) {
        final p = node['commentEntityPayload'] as Map;
        final text = p['properties']?['content']?['content']?.toString() ?? '';
        final author = p['author']?['displayName']?.toString() ?? 'YouTube User';
        final avatar = p['author']?['avatarThumbnailUrl']?.toString();
        final time = p['properties']?['publishedTime']?.toString() ?? '';
        final likes = p['toolbar']?['likeCountNotliked']?.toString() ??
            p['toolbar']?['likeCountLiked']?.toString() ??
            '';
        final replies = p['toolbar']?['replyCount']?.toString() ?? '';
        if (text.trim().isNotEmpty) {
          out.add(
            YouTubeCommentItem(
              authorName: author,
              authorAvatarUrl: avatar,
              text: text.trim(),
              publishedTime: time,
              likeCount: likes.trim(),
              replyCount: replies.trim(),
            ),
          );
        }
      } else if (node.containsKey('commentRenderer') &&
          node['commentRenderer'] is Map) {
        // 2. Classic commentRenderer
        final r = node['commentRenderer'] as Map;
        final text = _extractText(r['contentText']);
        final author = _extractText(r['authorText']);
        final time = _extractText(r['publishedTimeText']);
        final likes = _extractText(r['voteCount']);
        final thumbs = r['authorThumbnail']?['thumbnails'] as List?;
        final avatar = (thumbs != null && thumbs.isNotEmpty)
            ? thumbs.last['url']?.toString()
            : null;
        if (text.trim().isNotEmpty) {
          out.add(
            YouTubeCommentItem(
              authorName: author.isNotEmpty ? author : 'YouTube User',
              authorAvatarUrl: avatar,
              text: text.trim(),
              publishedTime: time,
              likeCount: likes.trim(),
            ),
          );
        }
      } else {
        for (final v in node.values) {
          _extractComments(v, out);
          if (out.length >= 40) break;
        }
      }
    } else if (node is List) {
      for (final e in node) {
        _extractComments(e, out);
        if (out.length >= 40) break;
      }
    }
  }

  Future<List<YouTubeVideoItem>> _fetchNextRecommendationsOnly(String videoId) async {
    final related = <YouTubeVideoItem>[];
    final seenIds = <String>{videoId};
    try {
      final res = await _dio.post(
        '$_ytOrigin/youtubei/v1/next?prettyPrint=false',
        options: Options(headers: _buildWebHeaders(includeAuth: true)),
        data: {
          'videoId': videoId,
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250220.01.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
        },
      );
      final dynamic data =
          res.data is String ? jsonDecode(res.data as String) : res.data;
      if (data is Map) {
        _extractVideoRenderers(data, related, seenIds, maxCount: 20);
      }
    } catch (_) {}
    return related;
  }

  void _parsePlayerResponse(
    dynamic rawData, {
    required String userAgent,
    required List<YouTubeQualityStream> qualities,
    required void Function(String title, String channel, String views, String desc) onMetadata,
    required void Function(String audioUrl) onBestAudio,
  }) {
    final dynamic data = rawData is String ? jsonDecode(rawData) : rawData;
    if (data is! Map) return;

    final details = data['videoDetails'];
    if (details is Map) {
      final t = details['title']?.toString() ?? '';
      final c = details['author']?.toString() ?? '';
      final d = details['shortDescription']?.toString() ?? '';
      final vc = details['viewCount']?.toString() ?? '';
      onMetadata(t, c, vc.isNotEmpty ? _formatViewCount(vc) : '', d);
    }

    final streamingData = data['streamingData'];
    if (streamingData is! Map) return;

    // 1. Extract Best Audio Stream (prefer m4a/mp4 high bitrate for crisp sync)
    String? clientBestAudio;
    final adaptive = streamingData['adaptiveFormats'];
    if (adaptive is List) {
      int bestScore = 0;
      for (final f in adaptive) {
        if (f is! Map) continue;
        final mime = f['mimeType']?.toString() ?? '';
        final url = f['url']?.toString() ?? '';
        if (url.isEmpty || !mime.startsWith('audio/')) continue;
        final br = (f['bitrate'] as num?)?.toInt() ?? 0;
        final mp4Bonus = mime.contains('mp4') ? 60000 : 0;
        if (br + mp4Bonus > bestScore) {
          bestScore = br + mp4Bonus;
          clientBestAudio = url;
        }
      }
    }
    if (clientBestAudio != null) {
      onBestAudio(clientBestAudio);
    }

    // 2. Extract Direct Muxed Formats (360p / 720p with built-in audio)
    final formats = streamingData['formats'];
    if (formats is List) {
      for (final f in formats) {
        if (f is! Map) continue;
        final url = f['url']?.toString() ?? '';
        if (url.isEmpty) continue;
        final height = (f['height'] as num?)?.toInt() ?? 360;
        final fps = (f['fps'] as num?)?.toInt() ?? 30;
        final br = (f['bitrate'] as num?)?.toInt() ?? 0;
        final itag = (f['itag'] as num?)?.toInt() ?? 18;
        final label = _formatQualityLabel(height, fps, isMuxed: true);
        final badge = _qualityBadge(height);
        if (!qualities.any((q) => q.height == height && q.isMuxed)) {
          qualities.add(
            YouTubeQualityStream(
              label: label,
              badge: badge,
              height: height,
              fps: fps,
              bitrate: br,
              itag: itag,
              codec: 'AVC1',
              videoUrl: url,
              isMuxed: true,
              userAgent: userAgent,
            ),
          );
        }
      }
    }

    // 3. Extract All Adaptive Video Resolutions from 144p up to 2160p (4K) & 4320p (8K)
    if (adaptive is List) {
      final bestByHeight = <int, YouTubeQualityStream>{};
      for (final f in adaptive) {
        if (f is! Map) continue;
        final mime = f['mimeType']?.toString() ?? '';
        final url = f['url']?.toString() ?? '';
        if (url.isEmpty || !mime.startsWith('video/')) continue;
        final height = (f['height'] as num?)?.toInt() ?? 0;
        if (height < 144) continue;
        final fps = (f['fps'] as num?)?.toInt() ?? 30;
        final br = (f['bitrate'] as num?)?.toInt() ?? 0;
        final itag = (f['itag'] as num?)?.toInt() ?? 248;
        final isMp4 = mime.contains('mp4');
        final codecName = mime.contains('vp9')
            ? 'VP9'
            : (mime.contains('av01') ? 'AV1' : (isMp4 ? 'AVC1' : 'VP9'));
        final clen = int.tryParse(f['contentLength']?.toString() ?? '0') ?? 0;

        final candidate = YouTubeQualityStream(
          label: _formatQualityLabel(height, fps, isMuxed: false),
          badge: _qualityBadge(height),
          height: height,
          fps: fps,
          bitrate: br,
          itag: itag,
          codec: codecName,
          videoUrl: url,
          audioUrl: clientBestAudio,
          isMuxed: false,
          userAgent: userAgent,
          contentLength: clen,
          mimeType: mime,
        );

        final existing = bestByHeight[height];
        if (existing == null || br > existing.bitrate) {
          bestByHeight[height] = candidate;
        }
      }

      for (final entry in bestByHeight.entries) {
        if (!qualities.any((q) => q.height == entry.key && !q.isMuxed)) {
          qualities.add(entry.value);
        }
      }
    }

    // 4. HLS Manifest URL (from IOS client — has built-in audio+video up to 1080p/4K!)
    final hlsUrl = streamingData['hlsManifestUrl']?.toString();
    if (hlsUrl != null && hlsUrl.isNotEmpty && !qualities.any((q) => q.isHls)) {
      qualities.add(
        YouTubeQualityStream(
          label: 'Auto (Adaptive HLS)',
          badge: 'AUTO',
          height: 1080,
          itag: 96,
          codec: 'HLS',
          videoUrl: hlsUrl,
          isMuxed: true,
          isHls: true,
          userAgent: userAgent,
        ),
      );
    }
  }

  String _formatQualityLabel(int height, int fps, {required bool isMuxed}) {
    final fpsSuffix = fps > 30 ? '$fps' : '';
    if (height >= 2160) return '2160p$fpsSuffix (4K UHD)';
    if (height >= 1440) return '1440p$fpsSuffix (2K QHD)';
    if (height >= 1080) return '1080p$fpsSuffix (Full HD)';
    if (height >= 720) return '720p$fpsSuffix (HD)';
    if (height >= 480) return '480p';
    if (height >= 360) return '360p';
    if (height >= 240) return '240p';
    return '144p';
  }

  String _qualityBadge(int height) {
    if (height >= 2160) return '4K';
    if (height >= 1440) return '2K';
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    return '${height}p';
  }

  String _formatViewCount(String raw) {
    final n = int.tryParse(raw);
    if (n == null) return '$raw views';
    if (n >= 1000000000) {
      return '${(n / 1000000000).toStringAsFixed(1)}B views';
    } else if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M views';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K views';
    }
    return '$n views';
  }
}
