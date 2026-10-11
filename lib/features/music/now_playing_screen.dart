import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/music_models.dart';
import 'music_action_sheets.dart';
import 'music_providers.dart';


class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _meshController;
  bool _showLyrics = true;
  bool _showQueue = false;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;
    final showStats = ref.watch(showNerdStatsProvider);

    if (track == null) {
      return const Scaffold(
        body: Center(child: Text('No track playing')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Mesh gradient backdrop ──
          _MeshGradientBackdrop(
            controller: _meshController,
            reduceAnimation: ref.watch(reduceAnimationProvider),
          ),

          // ── Blurred album art backdrop layer ──
          if (track.albumArtUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Opacity(
                  opacity: 0.20,
                  child: CachedNetworkImage(
                    imageUrl: track.albumArtUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Apple Music Header Bar (Screenshot 2) ──
                _TopBar(
                  onClose: () => Navigator.pop(context),
                  onLyrics: () => setState(() {
                    _showLyrics = !_showLyrics;
                    if (_showLyrics) _showQueue = false;
                  }),
                  onQueue: () => setState(() {
                    _showQueue = !_showQueue;
                    if (_showQueue) _showLyrics = false;
                  }),
                  showLyrics: _showLyrics,
                  showQueue: _showQueue,
                  track: track,
                ),

                const SizedBox(height: 10),

                // ── Center Stage: Synced Lyrics, Queue, or Large Artwork ──
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _showQueue
                        ? _QueueView(key: const ValueKey('queue'))
                        : _showLyrics
                            ? _LyricsView(
                                key: const ValueKey('lyrics'),
                                track: track,
                                position: state.position,
                              )
                            : _ArtworkView(
                                key: const ValueKey('artwork'),
                                track: track,
                              ),
                  ),
                ),

                // ── Nerd stats ──
                if (showStats)
                  _NerdStats(track: track),

                const SizedBox(height: 10),

                // ── Apple Music Scrubber Slider & Timestamps ──
                _ProgressSlider(state: state),

                const SizedBox(height: 8),

                // ── Main Controls (Rewind, Play/Pause, Fast-Forward) ──
                _MainControls(state: state),

                const SizedBox(height: 8),

                // ── Volume Slider (Screenshot 2) ──
                const _VolumeSlider(),

                const SizedBox(height: 14),

                // ── Bottom Action Pills: Lyrics Quote, AirPlay, Queue ──
                _BottomActions(
                  state: state,
                  showLyrics: _showLyrics,
                  showQueue: _showQueue,
                  onLyrics: () => setState(() {
                    _showLyrics = !_showLyrics;
                    if (_showLyrics) _showQueue = false;
                  }),
                  onQueue: () => setState(() {
                    _showQueue = !_showQueue;
                    if (_showQueue) _showLyrics = false;
                  }),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
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

    // Base — neumorphic dark
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.bgDark,
    );

    // Animated blobs with accent colors
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
// Top Bar
// ═══════════════════════════════════════════════════════════════════

class _TopBar extends ConsumerWidget {
  final VoidCallback onClose;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final bool showLyrics;
  final bool showQueue;
  final MusicTrack? track;

  const _TopBar({
    required this.onClose,
    required this.onLyrics,
    required this.onQueue,
    required this.showLyrics,
    required this.showQueue,
    this.track,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = track != null && ref.watch(likedSongsProvider).contains(track!.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtle top drag handle
        GestureDetector(
          onTap: onClose,
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            children: [
              // Mini Album Artwork Squircle (Screenshot 2)
              GestureDetector(
                onTap: onLyrics,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: track?.albumArtUrl != null
                      ? CachedNetworkImage(
                          imageUrl: track!.albumArtUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF202028),
                            child: const Icon(Icons.music_note, color: Colors.white24, size: 22),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF202028),
                          child: const Icon(Icons.music_note, color: Colors.white24, size: 22),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Title & Artist Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track?.title ?? 'Unknown Track',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite Star Button (Screenshot 2)
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isLiked ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey(isLiked),
                    color: isLiked ? Colors.white : Colors.white70,
                    size: 26,
                  ),
                ),
                onPressed: () {
                  if (track == null) return;
                  HapticFeedback.lightImpact();
                  ref.read(likedSongsProvider.notifier).toggleLike(track!.id);
                  if (!isLiked) {
                    ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist('fav_playlist', track!);
                  } else {
                    ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist('fav_playlist', track!.id);
                  }
                },
              ),

              // 3-dots more menu
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 26),
                onPressed: () {
                  if (track != null) {
                    showTrackOptionsSheet(context, ref, track!);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Neumorphic toggle pill — replaces the broken white _GlassPill
/// Active state: inset shadow + accent glow (not a solid white pill!)
class _NeumorphicTogglePill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NeumorphicTogglePill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NeumorphicTogglePill> createState() => _NeumorphicTogglePillState();
}

class _NeumorphicTogglePillState extends State<_NeumorphicTogglePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: AppColors.appleGlassDecoration(
            isDark: true,
            radius: 20,
            isSelected: widget.isActive,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive ? AppColors.accentLight : Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isActive ? AppColors.accentLight : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small Apple Music liquid glass press button (circle)
class _NeumorphicPressButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _NeumorphicPressButton({
    required this.onTap,
    required this.child,
  });

  @override
  State<_NeumorphicPressButton> createState() => _NeumorphicPressButtonState();
}

class _NeumorphicPressButtonState extends State<_NeumorphicPressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: AppColors.appleGlassCircle(
          isDark: true,
          isPressed: _pressed,
        ),
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Artwork View
// ═══════════════════════════════════════════════════════════════════

class _ArtworkView extends StatelessWidget {
  final MusicTrack track;
  const _ArtworkView({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'now_playing_art',
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.60),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: track.albumArtUrl != null
              ? CachedNetworkImage(
                  imageUrl: track.albumArtUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.cardDark,
                    child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.cardDark,
                    child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                  ),
                )
              : Container(
                  color: AppColors.cardDark,
                  child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Lyrics View
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
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int index, int totalLines) {
    if (index == _lastActiveIndex || !_scrollController.hasClients) return;
    _lastActiveIndex = index;

    const lineHeight = 56.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * lineHeight) - (viewportHeight / 2) + (lineHeight / 2);
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.track));
    final lyricsBlur = ref.watch(lyricsBlurProvider);

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

        int activeLine = 0;
        for (int i = 0; i < lyrics.length; i++) {
          if (widget.position >= lyrics[i].timestamp) {
            activeLine = i;
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActive(activeLine, lyrics.length);
        });

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
              stops: [0.0, 0.08, 0.92, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final isActive = index == activeLine;
              final line = lyrics[index];

              Widget lyricWidget = AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isActive ? 32 : 22,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.32),
                  height: 1.38,
                  letterSpacing: -0.4,
                  shadows: isActive
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Text(line.text),
              );

              if (lyricsBlur && !isActive) {
                lyricWidget = ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
                  child: lyricWidget,
                );
              }

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(musicPlayerProvider.notifier).seekTo(line.timestamp);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: lyricWidget,
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => const Center(
        child: Text('Could not load lyrics', style: TextStyle(color: Colors.white54)),
      ),
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
            'Queue · ${state.queue.length} tracks',
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
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: track.albumArtUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.albumArtUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.cardDark,
                              child: const Icon(Icons.music_note, size: 20, color: Colors.white24),
                            ),
                          )
                        : Container(
                            color: AppColors.cardDark,
                            child: const Icon(Icons.music_note, size: 20, color: Colors.white24),
                          ),
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
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.neumorphPressedDark(blur: 6, offset: 2),
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
// Track Info
// ═══════════════════════════════════════════════════════════════════

class _TrackInfo extends StatelessWidget {
  final MusicTrack track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Quality badge
              if (track.isLossless)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hd, size: 14, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(
                        track.codec ?? 'FLAC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Progress Slider — Neumorphic track
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
// Main Controls — Neumorphic play/pause, next, prev, shuffle, repeat
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
          // Shuffle — neumorphic toggle
          _ControlCircle(
            icon: Icons.shuffle,
            isActive: state.isShuffled,
            size: 42,
            onTap: notifier.toggleShuffle,
          ),
          // Previous
          _ControlCircle(
            icon: Icons.skip_previous,
            size: 50,
            iconSize: 30,
            onTap: notifier.previous,
          ),
          // Play/Pause — large neumorphic circle
          _PlayPauseButton(
            isPlaying: state.isPlaying,
            onTap: notifier.togglePlayPause,
          ),
          // Next
          _ControlCircle(
            icon: Icons.skip_next,
            size: 50,
            iconSize: 30,
            onTap: notifier.next,
          ),
          // Repeat — neumorphic toggle
          _ControlCircle(
            icon: state.repeatMode == MusicRepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
            isActive: state.repeatMode != MusicRepeatMode.off,
            size: 42,
            onTap: notifier.cycleRepeatMode,
          ),
        ],
      ),
    );
  }
}

/// Neumorphic control circle with press animation
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

/// Large neumorphic play/pause button with scale animation
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
            border: Border.all(
              color: Colors.white.withValues(alpha: _pressed ? 0.40 : 0.25),
              width: 1.0,
            ),
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
// Bottom Actions Row — Neumorphic icon buttons
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// Volume Slider (Screenshot 2)
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
// Bottom Actions Row — Apple Music iOS Pills (Screenshot 2)
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
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Synced Lyrics Toggle Button (Screenshot 2: speech quote pill)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onLyrics();
            },
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

          // 2. AirPlay / Audio Output Button (Screenshot 2)
          IconButton(
            icon: Icon(
              Icons.airplay_rounded,
              color: Colors.white.withValues(alpha: 0.70),
              size: 23,
            ),
            onPressed: () => _showAirplaySheet(context),
          ),

          // 3. Queue List Button with infinity loop badge (Screenshot 2)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onQueue();
            },
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

  void _showVolumeSheet(BuildContext context, WidgetRef ref, NowPlayingState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppColors.neumorphRaisedDark(blur: 20, offset: 8),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Volume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.volume_down, color: Colors.white54, size: 20),
                  Expanded(
                    child: Slider(
                      value: state.volume,
                      activeColor: AppColors.accent,
                      inactiveColor: Colors.white12,
                      onChanged: (v) {
                        ref.read(musicPlayerProvider.notifier).setVolume(v);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Colors.white54, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedSheet(BuildContext context, WidgetRef ref, NowPlayingState state) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppColors.neumorphRaisedDark(blur: 20, offset: 8),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Playback Speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: speeds.map((s) {
                  final isActive = (state.playbackSpeed - s).abs() < 0.01;
                  return GestureDetector(
                    onTap: () {
                      ref.read(musicPlayerProvider.notifier).setPlaybackSpeed(s);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isActive
                            ? [
                                ...AppColors.neumorphPressedDark(blur: 4, offset: 2),
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ]
                            : AppColors.neumorphRaisedDark(blur: 6, offset: 2),
                      ),
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          color: isActive ? AppColors.accent : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neumorphic small action button with press feedback
class _NeumorphSmallAction extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _NeumorphSmallAction({
    required this.icon,
    this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  State<_NeumorphSmallAction> createState() => _NeumorphSmallActionState();
}

class _NeumorphSmallActionState extends State<_NeumorphSmallAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final activeCol = widget.activeColor ?? AppColors.accent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: AppColors.appleGlassCircle(
          isDark: true,
          isSelected: widget.isActive,
          isPressed: _pressed,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 20,
              color: widget.isActive ? activeCol : Colors.white70,
            ),
            if (widget.label != null)
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 8,
                  color: widget.isActive ? activeCol : Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
