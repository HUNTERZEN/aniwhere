import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sources/source.dart';
import 'player_providers.dart';

/// WebView-based video player for anime episodes.
/// Used when the streaming server requires JavaScript execution
/// to decrypt/generate video source URLs (e.g. GogoAnime embeds).
class WebViewPlayerScreen extends StatefulWidget {
  final PlayerParams params;

  const WebViewPlayerScreen({
    super.key,
    required this.params,
  });

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  int _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.params.initialEpisodeIndex;

    // Lock to landscape for video playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initWebView();
    _loadEpisode();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
              // Inject CSS to hide ads and make player fullscreen
              _injectPlayerCSS();
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(
                  () => _error = 'Failed to load video: ${error.description}');
            }
          },
          onNavigationRequest: (request) {
            // Block navigation to ad URLs
            final url = request.url.toLowerCase();
            if (_isAdUrl(url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
  }

  bool _isAdUrl(String url) {
    final adDomains = [
      'doubleclick.net',
      'googlesyndication.com',
      'googleadservices.com',
      'facebook.com/tr',
      'popads.net',
      'popcash.net',
      'propellerads.com',
      'adsterra.com',
      'exoclick.com',
      'juicyads.com',
      'clickadu.com',
      'pushground.com',
      'trafficjunky.com',
      'bodegashunlike.com',
      'linkmansclate.com',
      'statlytic.net',
    ];
    return adDomains.any((domain) => url.contains(domain));
  }

  Future<void> _injectPlayerCSS() async {
    try {
      await _controller.runJavaScript('''
        // Hide common ad elements and expand the video player
        (function() {
          var style = document.createElement('style');
          style.textContent = `
            body { margin: 0 !important; padding: 0 !important; background: #000 !important; overflow: hidden !important; }
            iframe, video, .jw-video, .plyr, #player, .mg3-player, .fix-area {
              width: 100vw !important; height: 100vh !important;
              position: fixed !important; top: 0 !important; left: 0 !important;
              z-index: 9999 !important;
            }
            .ads, [class*="ad-"], [id*="ad-"], .popunder, .overlay,
            [class*="banner"], [class*="popup"], .ns { display: none !important; }
          `;
          document.head.appendChild(style);
        })();
      ''');
    } catch (e) {
      // CSS injection failed, not critical
    }
  }

  Future<void> _loadEpisode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final episode = widget.params.episodes[_currentEpisodeIndex];

    try {
      final source = widget.params.source;
      if (source is! WatchableSource) {
        setState(() => _error = 'Source is not watchable');
        return;
      }

      final streams = await source.getVideoStreams(episode.id);
      if (!mounted) return;

      if (streams.isEmpty) {
        setState(() => _error = 'No video sources found for this episode');
        return;
      }

      // Find a WebView-compatible stream (prefer first one)
      final stream = streams.firstWhere(
        (s) => s.useWebView && s.embedUrl != null,
        orElse: () => streams.first,
      );

      final embedUrl = stream.embedUrl ?? stream.url;

      await _controller.loadRequest(Uri.parse(embedUrl));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load episode: $e');
      }
    }
  }

  void _switchEpisode(int index) {
    if (index < 0 || index >= widget.params.episodes.length) return;
    setState(() => _currentEpisodeIndex = index);
    _loadEpisode();
  }

  @override
  void dispose() {
    // Restore orientation and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEpisode = widget.params.episodes[_currentEpisodeIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView player
          if (_error == null)
            WebViewWidget(controller: _controller),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          // Error view
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadEpisode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),

          // Top controls bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              episodeTitle: currentEpisode.title,
              onBack: () => Navigator.of(context).pop(),
              onPrevious: _currentEpisodeIndex <
                      widget.params.episodes.length - 1
                  ? () => _switchEpisode(_currentEpisodeIndex + 1)
                  : null,
              onNext: _currentEpisodeIndex > 0
                  ? () => _switchEpisode(_currentEpisodeIndex - 1)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar overlay with back, episode info, and prev/next controls
class _TopBar extends StatefulWidget {
  final String episodeTitle;
  final VoidCallback onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _TopBar({
    required this.episodeTitle,
    required this.onBack,
    this.onPrevious,
    this.onNext,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Auto-hide after 4 seconds
    _scheduleHide();
  }

  void _scheduleHide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _toggle() {
    setState(() => _visible = !_visible);
    if (_visible) _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.translucent,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onBack,
                  ),
                  Expanded(
                    child: Text(
                      widget.episodeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onPrevious != null)
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: widget.onPrevious,
                      tooltip: 'Previous Episode',
                    ),
                  if (widget.onNext != null)
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: widget.onNext,
                      tooltip: 'Next Episode',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
