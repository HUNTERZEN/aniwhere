import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/native_bridge.dart';
import '../../core/services/settings_storage.dart';
import '../../data/models/music_models.dart';
import '../music/music_providers.dart';

/// Prefix used for playlists that were imported from YouTube Music, so a
/// re-sync can replace them without touching the user's local playlists.
const String kYtmPlaylistPrefix = 'ytm_';

const String _ytmOrigin = 'https://music.youtube.com';

// ============================================================================
// Models
// ============================================================================

class YtMusicAccount {
  final String name;
  final String? handle;
  final String? photoUrl;

  const YtMusicAccount({required this.name, this.handle, this.photoUrl});

  Map<String, dynamic> toJson() => {
        'name': name,
        'handle': handle,
        'photoUrl': photoUrl,
      };

  factory YtMusicAccount.fromJson(Map<String, dynamic> json) => YtMusicAccount(
        name: json['name'] as String? ?? 'YouTube Music',
        handle: json['handle'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}

class YtMusicAuthState {
  final String? cookie;
  final YtMusicAccount? account;
  final bool isSyncing;
  final DateTime? lastSynced;
  final int syncedPlaylistCount;
  final String? error;

  const YtMusicAuthState({
    this.cookie,
    this.account,
    this.isSyncing = false,
    this.lastSynced,
    this.syncedPlaylistCount = 0,
    this.error,
  });

  bool get isSignedIn => cookie != null && cookie!.isNotEmpty;

  YtMusicAuthState copyWith({
    String? cookie,
    YtMusicAccount? account,
    bool? isSyncing,
    DateTime? lastSynced,
    int? syncedPlaylistCount,
    String? error,
    bool clearError = false,
  }) {
    return YtMusicAuthState(
      cookie: cookie ?? this.cookie,
      account: account ?? this.account,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSynced: lastSynced ?? this.lastSynced,
      syncedPlaylistCount: syncedPlaylistCount ?? this.syncedPlaylistCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================================
// Authenticated YouTube Music (InnerTube WEB_REMIX) client
// ============================================================================

class YtMusicApi {
  final String cookie;

  YtMusicApi(this.cookie);

  static const String _clientVersion = '1.20241106.01.00';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$_ytmOrigin/youtubei/v1/',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Extract a cookie value by name from a raw `Cookie` header.
  static String? cookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      if (part.substring(0, idx).trim() == name) {
        return part.substring(idx + 1).trim();
      }
    }
    return null;
  }

  /// A cookie is usable when it carries the SAPISID used for request signing.
  static bool isValidCookie(String? cookie) {
    if (cookie == null || cookie.isEmpty) return false;
    return cookieValue(cookie, 'SAPISID') != null ||
        cookieValue(cookie, '__Secure-3PAPISID') != null;
  }

  Map<String, String> _headers() {
    final sapisid = cookieValue(cookie, 'SAPISID') ??
        cookieValue(cookie, '__Secure-3PAPISID') ??
        '';
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hash = sha1.convert(utf8.encode('$ts $sapisid $_ytmOrigin')).toString();
    return {
      'Cookie': cookie,
      'Authorization': 'SAPISIDHASH ${ts}_$hash',
      'Content-Type': 'application/json',
      'Origin': _ytmOrigin,
      'X-Origin': _ytmOrigin,
      'Referer': '$_ytmOrigin/',
      'X-Goog-AuthUser': '0',
      'X-Youtube-Client-Name': '67',
      'X-Youtube-Client-Version': _clientVersion,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    };
  }

  Map<String, dynamic> get _context => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': _clientVersion,
          'hl': 'en',
          'gl': 'US',
        },
        'user': {'lockedSafetyMode': false},
      };

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await _dio.post(
      '$endpoint?prettyPrint=false',
      data: jsonEncode({'context': _context, ...body}),
      options: Options(headers: _headers(), responseType: ResponseType.plain),
    );
    final decoded = jsonDecode(response.data as String);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Fetch the signed-in account's name / handle / avatar.
  Future<YtMusicAccount?> fetchAccount() async {
    final data = await _post('account/account_menu', {});
    final headers = _findAll(data, 'activeAccountHeaderRenderer');
    if (headers.isEmpty) return null;
    final h = headers.first;
    final name = _runsText(h['accountName']) ?? 'YouTube Music';
    final handle = _runsText(h['channelHandle']) ?? _runsText(h['email']);
    final thumbs = (h['accountPhoto']?['thumbnails'] as List?) ?? const [];
    final photo = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : null;
    return YtMusicAccount(name: name, handle: handle, photoUrl: photo);
  }

  /// List all playlists in the user's YouTube Music library.
  Future<List<RemotePlaylist>> fetchLibraryPlaylists() async {
    final data = await _post('browse', {'browseId': 'FEmusic_liked_playlists'});
    final result = <RemotePlaylist>[];
    final seen = <String>{};

    for (final item in _findAll(data, 'musicTwoRowItemRenderer')) {
      final browseId =
          item['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
      if (!browseId.startsWith('VL') || !seen.add(browseId)) continue;

      final title = _runsText(item['title']) ?? 'Playlist';
      final subtitle = _runsText(item['subtitle']);
      final thumbs = (item['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List?) ??
          const [];
      final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : null;

      result.add(RemotePlaylist(
        browseId: browseId,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumb,
      ));
    }
    return result;
  }

  /// Fetch every track of a playlist, following continuation tokens.
  Future<List<MusicTrack>> fetchPlaylistTracks(String browseId, {int maxPages = 12}) async {
    final tracks = <MusicTrack>[];
    final seen = <String>{};

    var data = await _post('browse', {'browseId': browseId});
    for (var page = 0; page < maxPages; page++) {
      for (final r in _findAll(data, 'musicResponsiveListItemRenderer')) {
        final t = _mapTrack(r);
        if (t != null && seen.add(t.id)) tracks.add(t);
      }

      final token = _continuationToken(data);
      if (token == null) break;
      try {
        data = await _post('browse', {'continuation': token});
      } catch (_) {
        break;
      }
    }
    return tracks;
  }

  // ── Parsing helpers ──

  static String? _continuationToken(Map<String, dynamic> data) {
    final items = _findAll(data, 'continuationItemRenderer');
    for (final c in items) {
      final token = c['continuationEndpoint']?['continuationCommand']?['token']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    final legacy = _findAll(data, 'nextContinuationData');
    for (final c in legacy) {
      final token = c['continuation']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  static MusicTrack? _mapTrack(Map r) {
    final videoId = r['playlistItemData']?['videoId']?.toString() ??
        r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                ?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']
                ?['videoId']
            ?.toString();
    if (videoId == null || videoId.isEmpty) return null;

    final flex = (r['flexColumns'] as List?) ?? const [];
    String col(int i) {
      if (flex.length <= i) return '';
      return _runsText(flex[i]?['musicResponsiveListItemFlexColumnRenderer']?['text']) ?? '';
    }

    final title = col(0);
    if (title.isEmpty) return null;
    final artist = col(1).isNotEmpty ? col(1) : 'YouTube Music';
    final album = col(2).isNotEmpty ? col(2) : 'Single';

    var duration = const Duration(minutes: 3, seconds: 30);
    final fixed = (r['fixedColumns'] as List?) ?? const [];
    if (fixed.isNotEmpty) {
      final text = _runsText(fixed.first?['musicResponsiveListItemFixedColumnRenderer']?['text']);
      final parsed = _parseDuration(text);
      if (parsed != null) duration = parsed;
    }

    final thumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
            as List?) ??
        const [];
    String? art = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : null;
    // Request a sharper artwork variant from the image CDN
    if (art != null) {
      art = art.replaceAll(RegExp(r'=w\d+-h\d+'), '=w544-h544');
    }

    return MusicTrack(
      id: 'yt_$videoId',
      title: title,
      artist: artist,
      album: album,
      albumArtUrl: art,
      duration: duration,
      streamUrl: '',
      quality: AudioQuality.high,
      bitrate: 256,
      sampleRate: 44100,
      codec: 'YouTube Music',
    );
  }

  static Duration? _parseDuration(String? text) {
    if (text == null) return null;
    final parts = text.trim().split(':').map(int.tryParse).toList();
    if (parts.isEmpty || parts.any((p) => p == null)) return null;
    var seconds = 0;
    for (final p in parts) {
      seconds = seconds * 60 + p!;
    }
    return Duration(seconds: seconds);
  }

  static String? _runsText(dynamic node) {
    if (node is! Map) return null;
    final runs = node['runs'];
    if (runs is List && runs.isNotEmpty) {
      final text = runs.map((r) => r is Map ? (r['text']?.toString() ?? '') : '').join();
      return text.trim().isEmpty ? null : text.trim();
    }
    final simple = node['simpleText']?.toString();
    return (simple == null || simple.isEmpty) ? null : simple;
  }

  static List<Map<String, dynamic>> _findAll(dynamic node, String key) {
    final out = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map) {
        final v = n[key];
        if (v is Map<String, dynamic>) out.add(v);
        for (final child in n.values) {
          walk(child);
        }
      } else if (n is List) {
        for (final child in n) {
          walk(child);
        }
      }
    }

    walk(node);
    return out;
  }
}

class RemotePlaylist {
  final String browseId;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;

  const RemotePlaylist({
    required this.browseId,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
  });
}

// ============================================================================
// Auth state notifier
// ============================================================================

class YtMusicAuthNotifier extends StateNotifier<YtMusicAuthState> {
  final Ref _ref;

  static const _kCookie = 'ytm_cookie';
  static const _kAccount = 'ytm_account_json';
  static const _kLastSync = 'ytm_last_sync';
  static const _kCount = 'ytm_synced_count';

  YtMusicAuthNotifier(this._ref) : super(_load());

  static YtMusicAuthState _load() {
    final cookie = SettingsStorage.getString(_kCookie);
    if (cookie.isEmpty) return const YtMusicAuthState();

    YtMusicAccount? account;
    final rawAccount = SettingsStorage.getString(_kAccount);
    if (rawAccount.isNotEmpty) {
      try {
        account = YtMusicAccount.fromJson(jsonDecode(rawAccount) as Map<String, dynamic>);
      } catch (_) {}
    }
    final lastSyncMs = SettingsStorage.getInt(_kLastSync);
    return YtMusicAuthState(
      cookie: cookie,
      account: account,
      lastSynced: lastSyncMs > 0 ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs) : null,
      syncedPlaylistCount: SettingsStorage.getInt(_kCount),
    );
  }

  /// Called by the sign-in screen once the WebView holds valid Google cookies.
  /// Returns null on success, or an error message.
  Future<String?> completeSignIn(String cookie) async {
    if (!YtMusicApi.isValidCookie(cookie)) {
      return 'Sign-in incomplete: no YouTube session cookie was found.';
    }

    final api = YtMusicApi(cookie);
    YtMusicAccount? account;
    try {
      account = await api.fetchAccount();
    } catch (_) {
      account = null;
    }
    if (account == null) {
      return 'Could not verify your YouTube Music account. Please try again.';
    }

    await SettingsStorage.setString(_kCookie, cookie);
    await SettingsStorage.setString(_kAccount, jsonEncode(account.toJson()));
    state = YtMusicAuthState(cookie: cookie, account: account);

    // Kick off the first playlist sync in the background
    unawaited(syncPlaylists());
    return null;
  }

  /// Import every library playlist (incl. Liked Music) into the app.
  /// Returns the number of playlists synced, or -1 on failure.
  Future<int> syncPlaylists() async {
    final cookie = state.cookie;
    if (cookie == null || state.isSyncing) return -1;

    state = state.copyWith(isSyncing: true, clearError: true);
    final api = YtMusicApi(cookie);

    try {
      final remote = await api.fetchLibraryPlaylists();
      final imported = <MusicPlaylist>[];

      for (final pl in remote) {
        List<MusicTrack> tracks;
        try {
          tracks = await api.fetchPlaylistTracks(pl.browseId);
        } catch (_) {
          tracks = const [];
        }
        imported.add(MusicPlaylist(
          id: '$kYtmPlaylistPrefix${pl.browseId}',
          title: pl.title,
          description: pl.subtitle != null ? 'YouTube Music · ${pl.subtitle}' : 'YouTube Music',
          thumbnailUrl: pl.thumbnailUrl ?? (tracks.isNotEmpty ? tracks.first.albumArtUrl : null),
          tracks: tracks,
          trackCount: tracks.length,
        ));
      }

      _ref.read(userPlaylistsProvider.notifier).replaceSyncedPlaylists(
            kYtmPlaylistPrefix,
            imported,
          );

      final now = DateTime.now();
      await SettingsStorage.setInt(_kLastSync, now.millisecondsSinceEpoch);
      await SettingsStorage.setInt(_kCount, imported.length);
      state = state.copyWith(
        isSyncing: false,
        lastSynced: now,
        syncedPlaylistCount: imported.length,
      );
      return imported.length;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = (code == 401 || code == 403)
          ? 'Your Google session expired. Please sign in again.'
          : 'Sync failed: ${e.message ?? 'network error'}';
      state = state.copyWith(isSyncing: false, error: msg);
      return -1;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: 'Sync failed: $e');
      return -1;
    }
  }

  Future<void> signOut({bool removePlaylists = true}) async {
    await SettingsStorage.setString(_kCookie, '');
    await SettingsStorage.setString(_kAccount, '');
    await SettingsStorage.setInt(_kLastSync, 0);
    await SettingsStorage.setInt(_kCount, 0);
    await NativeBridge.clearCookies();
    if (removePlaylists) {
      _ref.read(userPlaylistsProvider.notifier).replaceSyncedPlaylists(kYtmPlaylistPrefix, const []);
    }
    state = const YtMusicAuthState();
  }
}

final ytMusicAuthProvider =
    StateNotifierProvider<YtMusicAuthNotifier, YtMusicAuthState>((ref) {
  return YtMusicAuthNotifier(ref);
});

