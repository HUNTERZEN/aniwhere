import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/music_models.dart';
import 'music_action_sheets.dart';
import 'music_providers.dart';

/// Opens [NowPlayingScreen] as an Apple Music iOS modal sheet with a
/// translucent backdrop so swiping down smoothly reveals the underlying screen.
Future<void> showNowPlayingScreen(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 440),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, _, _) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _meshController;
  late final AnimationController _dragResetController;

  // Start in Artwork view so the user sees the large album cover first;
  // switching to Lyrics or Queue animates the album cover up into the header.
  bool _showLyrics = false;
  bool _showQueue = false;

  double _dragOffsetY = 0.0;

  bool get _isCompactHeader => _showLyrics || _showQueue;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _dragResetController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _dragOffsetY = _dragResetController.value.clamp(0.0, 1200.0);
        });
      });
  }

  @override
  void dispose() {
    _meshController.dispose();
    _dragResetController.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragResetController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    final next = _dragOffsetY + (delta < 0 ? delta * 0.25 : delta);
    setState(() {
      _dragOffsetY = next.clamp(0.0, 900.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final screenH = MediaQuery.of(context).size.height;

    if (_dragOffsetY > screenH * 0.18 || velocity > 680) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    // Spring back to 0 using iOS-like critically damped spring physics
    const spring = SpringDescription(mass: 1.0, stiffness: 460, damping: 34);
    final sim = SpringSimulation(spring, _dragOffsetY, 0.0, velocity / 1000.0);
    _dragResetController.animateWith(sim);
  }

  void _toggleLyrics() {
    HapticFeedback.selectionClick();
    setState(() {
      _showLyrics = !_showLyrics;
      if (_showLyrics) _showQueue = false;
    });
  }

  void _toggleQueue() {
    HapticFeedback.selectionClick();
    setState(() {
      _showQueue = !_showQueue;
      if (_showQueue) _showLyrics = false;
    });
  }

  void _showArtworkStage() {
    if (!_showLyrics && !_showQueue) return;
    HapticFeedback.selectionClick();
    setState(() {
      _showLyrics = false;
      _showQueue = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;
    final showStats = ref.watch(showNerdStatsProvider);
    final reduceAnim = ref.watch(reduceAnimationProvider);
    final animatedCanvas = ref.watch(animatedCanvasProvider);
    final fullBleed = ref.watch(fullBleedArtworkProvider);

    if (track == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('No track playing')),
      );
    }

    final screenH = MediaQuery.of(context).size.height;
    final dragProgress = (_dragOffsetY / (screenH * 0.45)).clamp(0.0, 1.0);
    final sheetScale = 1.0 - (dragProgress * 0.05);
    // Smooth continuous squircle corners at the top of the player card (and all 4 corners while dragging)
    final topCornerRadius = 38.0 + (dragProgress * 8.0);
    final bottomCornerRadius = dragProgress > 0.01 ? 38.0 : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragOffsetY),
          child: Transform.scale(
            scale: sheetScale,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: ShapeDecoration(
                color: AppColors.bgDark,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(topCornerRadius * 1.45),
                    bottom: Radius.circular(bottomCornerRadius * 1.45),
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 36,
                    spreadRadius: 2,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Mesh gradient backdrop ──
                  _MeshGradientBackdrop(
                    controller: _meshController,
                    reduceAnimation: reduceAnim || !animatedCanvas,
                  ),

                  // ── Blurred album art ambient backdrop layer ──
                  if (track.albumArtUrl != null)
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 68, sigmaY: 68),
                        child: Opacity(
                          opacity: _isCompactHeader ? 0.34 : 0.26,
                          child: CachedNetworkImage(
                            imageUrl: track.albumArtUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),

                  // ── Main content ──
                  SafeArea(
                    child: Column(
                      children: [
                        // ── Drag Handle + Compact Header (ONLY visible in Lyrics / Queue mode) ──
                        _SheetHeader(
                          isCompactHeader: _isCompactHeader,
                          track: track,
                          onClose: () => Navigator.pop(context),
                          onTapMiniArtwork: _showArtworkStage,
                        ),

                        const SizedBox(height: 6),

                        // ── Center Stage: Large Artwork OR Synced Lyrics OR Queue ──
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final isArt = child.key == const ValueKey('artwork');
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: isArt
                                        ? const Offset(0, -0.14)
                                        : const Offset(0, 0.08),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: isArt ? 0.82 : 0.96,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: _showQueue
                                ? const _QueueView(key: ValueKey('queue'))
                                : _showLyrics
                                    ? _LyricsView(
                                        key: const ValueKey('lyrics'),
                                        track: track,
                                        position: state.position,
                                      )
                                    : _ArtworkStage(
                                        key: const ValueKey('artwork'),
                                        track: track,
                                        isPlaying: state.isPlaying,
                                        fullBleed: fullBleed,
                                      ),
                          ),
                        ),

                        // ── Nerd stats ──
                        if (showStats) _NerdStats(track: track),

                        const SizedBox(height: 6),

                        // ── Apple Music Scrubber Slider & Timestamps ──
                        _ProgressSlider(state: state),

                        const SizedBox(height: 6),

                        // ── Main Controls (Shuffle, Prev, Play/Pause, Next, Repeat) ──
                        _MainControls(state: state),

                        const SizedBox(height: 8),

                        // ── Volume Slider ──
                        const _VolumeSlider(),

                        const SizedBox(height: 12),

                        // ── Bottom Action Pills: Lyrics Quote, Download, AirPlay, Queue ──
                        _BottomActions(
                          state: state,
                          showLyrics: _showLyrics,
                          showQueue: _showQueue,
                          onLyrics: _toggleLyrics,
                          onQueue: _toggleQueue,
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _MeshGradientBackdrop extends StatelessWidget {
  final AnimationController controller;
  final bool reduceAnimation;

  const _MeshGradientBackdrop({
    required this.controller,
    required this.reduceAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceAnimation) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.bgDark,
              const Color(0xFF151528),
              AppColors.bgDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return CustomPaint(
          painter: _MeshPainter(t),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double t;
  _MeshPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.bgDark,
    );

    final blobs = [
      _Blob(
        color: AppColors.accent.withValues(alpha: 0.18),
        cx: w * (0.3 + 0.15 * sin(t * 2 * pi)),
        cy: h * (0.25 + 0.1 * cos(t * 2 * pi * 0.7)),
        r: w * 0.45,
      ),
      _Blob(
        color: AppColors.accentLight.withValues(alpha: 0.10),
        cx: w * (0.7 + 0.12 * cos(t * 2 * pi * 1.3)),
        cy: h * (0.6 + 0.15 * sin(t * 2 * pi * 0.5)),
        r: w * 0.5,
      ),
      _Blob(
        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
        cx: w * (0.5 + 0.2 * sin(t * 2 * pi * 0.9 + 1)),
        cy: h * (0.8 + 0.08 * cos(t * 2 * pi * 0.6)),
        r: w * 0.4,
      ),
    ];

    for (final blob in blobs) {
      paint.shader = RadialGradient(
        colors: [blob.color, blob.color.withValues(alpha: 0)],
      ).createShader(
        Rect.fromCircle(center: Offset(blob.cx, blob.cy), radius: blob.r),
      );
      canvas.drawCircle(Offset(blob.cx, blob.cy), blob.r, paint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.t != t;
}

class _Blob {
  final Color color;
  final double cx, cy, r;
  const _Blob({required this.color, required this.cx, required this.cy, required this.r});
}

// ═══════════════════════════════════════════════════════════════════
// Sheet Header: Grab handle + animated compact track header (only in Lyrics/Queue)
// ═══════════════════════════════════════════════════════════════════

class _SheetHeader extends ConsumerWidget {
  final bool isCompactHeader;
  final MusicTrack track;
  final VoidCallback onClose;
  final VoidCallback onTapMiniArtwork;

  const _SheetHeader({
    required this.isCompactHeader,
    required this.track,
    required this.onClose,
    required this.onTapMiniArtwork,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(likedSongsProvider).contains(track.id);
    final downloaded = ref.watch(downloadedTracksProvider);
    final isDownloaded = downloaded.containsKey(track.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grabber pill (tap or swipe down to dismiss)
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8, left: 48, right: 48),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),

        // Compact header row smoothly expands ONLY when in Lyrics or Queue mode
        AnimatedAlign(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          heightFactor: isCompactHeader ? 1.0 : 0.0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            opacity: isCompactHeader ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !isCompactHeader,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 14, 6),
                child: Row(
                  children: [
                    // Small rounded squircle album art (tap to return to full Artwork view)
                    GestureDetector(
                      onTap: onTapMiniArtwork,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: ShapeDecoration(
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.42),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _AlbumImage(url: track.albumArtUrl, iconSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: onTapMiniArtwork,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      icon: isLiked ? Icons.star_rounded : Icons.star_outline_rounded,
                      active: isLiked,
                      onTap: () => _toggleLike(ref, track, isLiked),
                    ),
                    _HeaderIconButton(
                      icon: isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                      active: isDownloaded,
                      activeColor: const Color(0xFFFA2D48),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDownloadMusicQualitySheet(context, ref, track);
                      },
                    ),
                    _HeaderIconButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: () => showTrackOptionsSheet(context, ref, track),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _toggleLike(WidgetRef ref, MusicTrack track, bool isLiked) {
  HapticFeedback.lightImpact();
  ref.read(likedSongsProvider.notifier).toggleLike(track.id);
  if (!isLiked) {
    ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist('fav_playlist', track);
  } else {
    ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist('fav_playlist', track.id);
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    this.active = false,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: active ? 0.16 : 0.08),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? (activeColor ?? Colors.white) : Colors.white70,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Artwork Stage: Single large smooth-cornered album cover + Track Title below
// ═══════════════════════════════════════════════════════════════════

class _ArtworkStage extends ConsumerWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool fullBleed;

  const _ArtworkStage({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.fullBleed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(likedSongsProvider).contains(track.id);
    final downloaded = ref.watch(downloadedTracksProvider);
    final isDownloaded = downloaded.containsKey(track.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxArtSize = (constraints.maxHeight - 88).clamp(180.0, 340.0);
        final horizontalPad = fullBleed ? 22.0 : 32.0;
        final artSize = min(constraints.maxWidth - horizontalPad * 2, maxArtSize);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large smooth-cornered Apple Music squircle album cover
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    scale: isPlaying ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 460),
                    curve: isPlaying ? Curves.easeOutBack : Curves.easeOutCubic,
                    child: Container(
                      width: artSize,
                      height: artSize,
                      decoration: ShapeDecoration(
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(56),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isPlaying ? 0.58 : 0.35),
                            blurRadius: isPlaying ? 42 : 22,
                            spreadRadius: isPlaying ? 2 : 0,
                            offset: Offset(0, isPlaying ? 18 : 10),
                          ),
                        ],
                      ),
                      child: ClipPath(
                        clipper: ShapeBorderClipper(
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(56),
                          ),
                        ),
                        child: _AlbumImage(url: track.albumArtUrl, iconSize: 80),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Apple Music Track Title + Artist + Favorite + More below the large artwork
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (track.isLossless) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'LOSSLESS',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    icon: isLiked ? Icons.star_rounded : Icons.star_outline_rounded,
                    active: isLiked,
                    onTap: () => _toggleLike(ref, track, isLiked),
                  ),
                  _HeaderIconButton(
                    icon: isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                    active: isDownloaded,
                    activeColor: const Color(0xFFFA2D48),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showDownloadMusicQualitySheet(context, ref, track);
                    },
                  ),
                  _HeaderIconButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: () => showTrackOptionsSheet(context, ref, track),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumImage extends StatelessWidget {
  final String? url;
  final double iconSize;

  const _AlbumImage({required this.url, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: AppColors.cardDark,
        child: Icon(Icons.music_note_rounded, size: iconSize, color: Colors.white24),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: AppColors.cardDark,
        child: Icon(Icons.music_note_rounded, size: iconSize, color: Colors.white24),
      ),
      errorWidget: (_, _, _) => Container(
        color: AppColors.cardDark,
        child: Icon(Icons.music_note_rounded, size: iconSize, color: Colors.white24),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Apple Music / Cider Synced Lyrics View
// ═══════════════════════════════════════════════════════════════════

class _LyricsView extends ConsumerStatefulWidget {
  final MusicTrack track;
  final Duration position;

  const _LyricsView({super.key, required this.track, required this.position});

  @override
  ConsumerState<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<_LyricsView> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = const [];
  int _lastActiveIndex = -1;
  String _lastTrackId = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureKeys(int count, String trackId) {
    if (_lineKeys.length != count || _lastTrackId != trackId) {
      _lineKeys = List<GlobalKey>.generate(count, (_) => GlobalKey());
      _lastTrackId = trackId;
      _lastActiveIndex = -1;
    }
  }

  void _scrollToActive(int index) {
    if (index == _lastActiveIndex) return;
    if (index < 0 || index >= _lineKeys.length) return;
    final ctx = _lineKeys[index].currentContext;
    if (ctx == null) return;
    _lastActiveIndex = index;

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25, // Upper-third focal point like Apple Music / Cider
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.track));
    final lyricsBlur = ref.watch(lyricsBlurProvider);
    final syncedEnabled = ref.watch(syncedLyricsProvider);

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'No lyrics found for this track',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        _ensureKeys(lyrics.length, widget.track.id);

        int activeLine = 0;
        for (int i = 0; i < lyrics.length; i++) {
          if (widget.position >= lyrics[i].timestamp) {
            activeLine = i;
          }
        }

        // Compute intra-line progress (0.0 -> 1.0) for smooth word-by-word highlight
        double lineProgress = 1.0;
        if (syncedEnabled && activeLine < lyrics.length) {
          final startMs = lyrics[activeLine].timestamp.inMilliseconds;
          final endMs = (activeLine + 1 < lyrics.length)
              ? lyrics[activeLine + 1].timestamp.inMilliseconds
              : widget.track.duration.inMilliseconds;
          final span = (endMs - startMs).clamp(400, 60000);
          lineProgress = ((widget.position.inMilliseconds - startMs) / span).clamp(0.0, 1.0);
        }

        if (syncedEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActive(activeLine);
          });
        }

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.06, 0.90, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(lyrics.length, (index) {
                final isActive = syncedEnabled ? index == activeLine : true;
                final isPast = syncedEnabled && index < activeLine;
                final distance = (index - activeLine).abs();
                final line = lyrics[index];

                Widget lineContent;
                if (isActive && syncedEnabled) {
                  lineContent = _WordSyncedLyricText(
                    text: line.text,
                    progress: lineProgress,
                  );
                } else {
                  final alpha = !syncedEnabled
                      ? 0.88
                      : (isPast ? 0.24 : (distance == 1 ? 0.42 : 0.30));
                  lineContent = Text(
                    line.text,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: alpha),
                      height: 1.32,
                      letterSpacing: -0.5,
                    ),
                  );
                }

                if (lyricsBlur && syncedEnabled && !isActive) {
                  final sigma = (0.7 + distance * 0.35).clamp(0.7, 2.2);
                  lineContent = ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: lineContent,
                  );
                }

                return GestureDetector(
                  key: _lineKeys[index],
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(musicPlayerProvider.notifier).seekTo(line.timestamp);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      scale: isActive ? 1.0 : 0.95,
                      child: lineContent,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, _) => const Center(
        child: Text('Could not load lyrics', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}

/// Renders the active lyric line with Cider / Apple Music style progressive
/// word-by-word illumination and zero layout reflow or harsh shadow artifacts.
class _WordSyncedLyricText extends StatelessWidget {
  final String text;
  final double progress;

  const _WordSyncedLyricText({
    required this.text,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const SizedBox.shrink();

    final exactWordPos = progress * words.length;
    final spans = <InlineSpan>[];

    for (var i = 0; i < words.length; i++) {
      // Smoothly interpolate each word's brightness as the song advances through the line
      final wordFill = (exactWordPos - i + 0.35).clamp(0.0, 1.0);
      final alpha = 0.45 + 0.53 * Curves.easeOut.transform(wordFill);
      spans.add(
        TextSpan(
          text: i < words.length - 1 ? '${words[i]} ' : words[i],
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: alpha),
            height: 1.32,
            letterSpacing: -0.5,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Queue View
// ═══════════════════════════════════════════════════════════════════

class _QueueView extends ConsumerWidget {
  const _QueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Playing Next · ${state.queue.length} tracks',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.queue.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              ref.read(musicPlayerProvider.notifier).reorderQueue(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final track = state.queue[index];
              final isCurrent = index == state.currentIndex;

              return ListTile(
                key: ValueKey('queue_$index'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _AlbumImage(url: track.albumArtUrl, iconSize: 20),
                  ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? AppColors.accent : Colors.white,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? AppColors.accent.withValues(alpha: 0.7) : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(Icons.equalizer, color: AppColors.accent, size: 20)
                    : const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
                onTap: () {
                  ref.read(musicPlayerProvider.notifier).playTrack(
                        track,
                        queue: state.queue,
                        index: index,
                      );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Nerd Stats Bar
// ═══════════════════════════════════════════════════════════════════

class _NerdStats extends StatelessWidget {
  final MusicTrack track;
  const _NerdStats({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatChip(label: track.codec ?? 'Unknown'),
            _StatDot(),
            _StatChip(label: '${track.bitrate ?? '?'} kbps'),
            _StatDot(),
            _StatChip(label: '${((track.sampleRate ?? 44100) / 1000).toStringAsFixed(1)} kHz'),
            if (track.isLossless) ...[
              _StatDot(),
              _StatChip(
                label: 'Lossless',
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _StatChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white54,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StatDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Progress Slider
// ═══════════════════════════════════════════════════════════════════

class _ProgressSlider extends ConsumerWidget {
  final NowPlayingState state;
  const _ProgressSlider({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = state.position.inMilliseconds.toDouble();
    final dur = (state.currentTrack?.duration.inMilliseconds ?? 1).toDouble();
    final clamped = pos.clamp(0.0, dur > 0 ? dur : 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white.withValues(alpha: 0.90),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: Colors.white.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: clamped,
              max: dur > 0 ? dur : 1.0,
              onChanged: (value) {
                ref.read(musicPlayerProvider.notifier)
                    .seekTo(Duration(milliseconds: value.round()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '-${_formatDuration((state.currentTrack?.duration ?? Duration.zero) - state.position)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Main Controls
// ═══════════════════════════════════════════════════════════════════

class _MainControls extends ConsumerWidget {
  final NowPlayingState state;
  const _MainControls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(musicPlayerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ControlCircle(
            icon: Icons.shuffle_rounded,
            isActive: state.isShuffled,
            size: 42,
            onTap: notifier.toggleShuffle,
          ),
          _ControlCircle(
            icon: Icons.skip_previous_rounded,
            size: 50,
            iconSize: 30,
            onTap: notifier.previous,
          ),
          _PlayPauseButton(
            isPlaying: state.isPlaying,
            onTap: notifier.togglePlayPause,
          ),
          _ControlCircle(
            icon: Icons.skip_next_rounded,
            size: 50,
            iconSize: 30,
            onTap: notifier.next,
          ),
          _ControlCircle(
            icon: state.repeatMode == MusicRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            isActive: state.repeatMode != MusicRepeatMode.off,
            size: 42,
            onTap: notifier.cycleRepeatMode,
          ),
        ],
      ),
    );
  }
}

class _ControlCircle extends StatefulWidget {
  final IconData icon;
  final double size;
  final double? iconSize;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlCircle({
    required this.icon,
    this.size = 44,
    this.iconSize,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_ControlCircle> createState() => _ControlCircleState();
}

class _ControlCircleState extends State<_ControlCircle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: widget.size,
        height: widget.size,
        decoration: AppColors.appleGlassCircle(
          isDark: true,
          isSelected: widget.isActive,
          isPressed: _pressed,
        ),
        child: Icon(
          widget.icon,
          color: widget.isActive ? AppColors.accentLight : Colors.white,
          size: widget.iconSize ?? (widget.size * 0.48),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _scaleController.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _scaleController.reverse();
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () {
        _scaleController.reverse();
        setState(() => _pressed = false);
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: _pressed ? 0.22 : 0.14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(widget.isPlaying),
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Volume Slider
// ═══════════════════════════════════════════════════════════════════

class _VolumeSlider extends ConsumerWidget {
  const _VolumeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Icon(
            Icons.volume_down_rounded,
            color: Colors.white.withValues(alpha: 0.50),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                activeTrackColor: Colors.white.withValues(alpha: 0.85),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: Colors.white,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: Colors.white.withValues(alpha: 0.10),
              ),
              child: Slider(
                value: state.volume.clamp(0.0, 1.0),
                onChanged: (v) {
                  ref.read(musicPlayerProvider.notifier).setVolume(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.volume_up_rounded,
            color: Colors.white.withValues(alpha: 0.50),
            size: 19,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom Actions Row — Apple Music iOS Pills
// ═══════════════════════════════════════════════════════════════════

class _BottomActions extends ConsumerWidget {
  final NowPlayingState state;
  final bool showLyrics;
  final bool showQueue;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;

  const _BottomActions({
    required this.state,
    required this.showLyrics,
    required this.showQueue,
    required this.onLyrics,
    required this.onQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Synced Lyrics Toggle Button
          GestureDetector(
            onTap: onLyrics,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: showLyrics
                  ? AppColors.appleGlassDecoration(
                      isDark: true,
                      radius: 14,
                      isSelected: true,
                      intensity: intensity,
                      opacity: opacity,
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.transparent,
                    ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: showLyrics ? Colors.white : Colors.white.withValues(alpha: 0.55),
                size: 21,
              ),
            ),
          ),

          // 2. Download Music Button
          Consumer(
            builder: (context, ref, _) {
              final track = state.currentTrack;
              final downloaded = ref.watch(downloadedTracksProvider);
              final progressMap = ref.watch(downloadProgressProvider);
              final activeProgress = track != null ? progressMap[track.id] : null;
              final isDownloading = activeProgress != null;
              final isDownloaded = track != null && downloaded.containsKey(track.id);
              final quality = isDownloaded ? downloaded[track.id] : null;

              return GestureDetector(
                onTap: () {
                  if (track != null) {
                    HapticFeedback.lightImpact();
                    showDownloadMusicQualitySheet(context, ref, track);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: (isDownloaded || isDownloading)
                      ? AppColors.appleGlassDecoration(
                          isDark: true,
                          radius: 14,
                          isSelected: true,
                          intensity: intensity,
                          opacity: opacity,
                        )
                      : BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.transparent,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDownloading) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            value: activeProgress > 0.02 ? activeProgress : null,
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(activeProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                          color: isDownloaded ? Colors.white : Colors.white.withValues(alpha: 0.55),
                          size: 21,
                        ),
                        if (isDownloaded && quality != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            quality.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. AirPlay / Audio Output Button
          IconButton(
            icon: Icon(
              Icons.airplay_rounded,
              color: Colors.white.withValues(alpha: 0.70),
              size: 23,
            ),
            onPressed: () => _showAirplaySheet(context),
          ),

          // 4. Queue List Button with infinity loop badge
          GestureDetector(
            onTap: onQueue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: showQueue
                  ? AppColors.appleGlassDecoration(
                      isDark: true,
                      radius: 14,
                      isSelected: true,
                      intensity: intensity,
                      opacity: opacity,
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.transparent,
                    ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.format_list_bulleted_rounded,
                    color: showQueue ? Colors.white : Colors.white.withValues(alpha: 0.55),
                    size: 21,
                  ),
                  Positioned(
                    top: -3,
                    right: -6,
                    child: Icon(
                      Icons.all_inclusive_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAirplaySheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: AppColors.appleGlassDecoration(isDark: true, radius: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.airplay_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Audio Output & Cast',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.speaker_rounded, color: Color(0xFFFA2D48)),
              title: const Text('Internal Speaker (Hi-Res PCM)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('32-bit / 96kHz Lossless Direct', style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.check_rounded, color: Color(0xFFFA2D48)),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth_audio_rounded, color: Colors.white70),
              title: const Text('Bluetooth & System Default', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: const Text('Connected system audio session', style: TextStyle(color: Colors.white54, fontSize: 12)),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
