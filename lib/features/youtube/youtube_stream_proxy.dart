import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Cached target metadata for proxied streams
class _ProxyTarget {
  final String remoteUrl;
  final String userAgent;
  int totalLength;
  final String mimeType;
  final DateTime createdAt;

  _ProxyTarget({
    required this.remoteUrl,
    required this.userAgent,
    required this.totalLength,
    required this.mimeType,
  }) : createdAt = DateTime.now();
}

/// Lightweight loopback HTTP proxy (running on 127.0.0.1) that translates open-ended
/// byte range requests from mpv/media_kit into bounded chunk range requests acceptable by
/// YouTube's CDN (which returns HTTP 403 Forbidden for open-ended requests on iOS streams).
class YouTubeStreamProxy {
  static final YouTubeStreamProxy _instance = YouTubeStreamProxy._();
  factory YouTubeStreamProxy() => _instance;
  YouTubeStreamProxy._();

  HttpServer? _server;
  int _port = 0;
  final Map<String, _ProxyTarget> _targets = {};
  int _counter = 0;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  bool get isRunning => _server != null;

  /// Ensures the loopback HTTP server is running on 127.0.0.1
  Future<void> ensureStarted() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {
        // Silently ignore server listen errors
      });
    } catch (_) {
      _server = null;
      _port = 0;
    }
  }

  /// Registers a remote YouTube googlevideo URL with its required User-Agent and length,
  /// and returns a local `http://127.0.0.1:$port/stream/$id.$ext` URL that media_kit can open.
  Future<String> getProxyUrl({
    required String remoteUrl,
    required String userAgent,
    int totalLength = 0,
    String mimeType = 'video/mp4',
  }) async {
    await ensureStarted();
    if (_port == 0) return remoteUrl; // Fallback to direct URL if proxy fails to bind

    final id = (++_counter).toString();
    String ext = 'mp4';
    if (mimeType.contains('webm')) {
      ext = 'webm';
    } else if (mimeType.contains('audio')) {
      ext = 'm4a';
    }

    _targets[id] = _ProxyTarget(
      remoteUrl: remoteUrl,
      userAgent: userAgent,
      totalLength: totalLength,
      mimeType: mimeType,
    );

    // Prune stale targets older than 2 hours
    if (_targets.length > 50) {
      final now = DateTime.now();
      _targets.removeWhere(
        (_, t) => now.difference(t.createdAt).inHours >= 2,
      );
    }

    return 'http://127.0.0.1:$_port/stream/$id.$ext';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (!path.startsWith('/stream/')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Extract target ID from /stream/<id>.<ext>
    final filename = path.substring('/stream/'.length);
    final dotIdx = filename.indexOf('.');
    final targetId = dotIdx > 0 ? filename.substring(0, dotIdx) : filename;
    final target = _targets[targetId];

    if (target == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Resolve totalLength if not known upfront using a 1-byte probe request
    if (target.totalLength <= 0) {
      try {
        final probeReq = await _client.getUrl(Uri.parse(target.remoteUrl));
        probeReq.headers.set(HttpHeaders.userAgentHeader, target.userAgent);
        probeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        final probeResp = await probeReq.close();
        final contentRange = probeResp.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last.trim();
          final parsed = int.tryParse(totalStr);
          if (parsed != null && parsed > 0) {
            target.totalLength = parsed;
          }
        }
        await probeResp.drain();
      } catch (_) {}
    }

    final total = target.totalLength > 0 ? target.totalLength : 500 * 1024 * 1024;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int end = total - 1;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      final parsedStart = int.tryParse(parts[0]);
      if (parsedStart != null) start = parsedStart;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        final parsedEnd = int.tryParse(parts[1]);
        if (parsedEnd != null) end = min(total - 1, parsedEnd);
      }
    }

    final response = request.response;
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(HttpHeaders.contentTypeHeader, target.mimeType);
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
    response.headers.contentLength = (end - start + 1);

    const int chunkSize = 512 * 1024; // 512KB chunks are 100% accepted by YouTube iOS CDN
    int current = start;

    try {
      while (current <= end) {
        final subEnd = min(current + chunkSize - 1, end);
        final upstreamReq = await _client.getUrl(Uri.parse(target.remoteUrl));
        upstreamReq.headers.set(HttpHeaders.userAgentHeader, target.userAgent);
        upstreamReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$current-$subEnd');
        final upstreamResp = await upstreamReq.close();

        if (upstreamResp.statusCode != HttpStatus.ok &&
            upstreamResp.statusCode != HttpStatus.partialContent) {
          await upstreamResp.drain();
          break;
        }

        await response.addStream(upstreamResp);
        current = subEnd + 1;
      }
    } catch (_) {
      // Client disconnected (e.g., seek, stop, or pause)
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// Stops the proxy server
  Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = 0;
    _targets.clear();
  }
}

