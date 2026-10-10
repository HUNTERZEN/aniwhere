import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  bool _showLyrics = false;
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
      backgroundColor: Colors.black,
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
                  opacity: 0.25,
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
                // ── Top bar ──
                _TopBar(
                  onClose: () => Navigator.pop(context),
                  onLyrics: () => setState(() => _showLyrics = !_showLyrics),
                  onQueue: () => setState(() => _showQueue = !_showQueue),
                  showLyrics: _showLyrics,
                  showQueue: _showQueue,
                  track: state.currentTrack,
                ),

                const SizedBox(height: 16),

                // ── Artwork or lyrics ──
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _showLyrics
                        ? _LyricsView(track: track, position: state.position)
                        : _showQueue
                            ? _QueueView()
                            : _ArtworkView(track: track),
                  ),
                ),

                // ── Nerd stats (codec, bitrate, sample rate) ──
                if (showStats)
                  _NerdStats(track: track),

                // ── Track info ──
                _TrackInfo(track: track),

                const SizedBox(height: 8),

                // ── Thin slider (progress bar) ──
                _ProgressSlider(state: state),

                const SizedBox(height: 4),

                // ── Timestamps ──
                _Timestamps(state: state),

                const SizedBox(height: 12),

                // ── Main controls ──
                _MainControls(state: state),

                const SizedBox(height: 12),

                // ── Bottom actions (volume, speed, etc.) ──
                _BottomActions(state: state),

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1a0a2e),
              Color(0xFF0a0a1a),
              Color(0xFF0e061a),
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

    // Base dark
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0a0a14),
    );

    // Animated blobs
    final blobs = [
      _Blob(
        color: AppColors.primary.withValues(alpha: 0.25),
        cx: w * (0.3 + 0.15 * sin(t * 2 * pi)),
        cy: h * (0.25 + 0.1 * cos(t * 2 * pi * 0.7)),
        r: w * 0.45,
      ),
      _Blob(
        color: AppColors.accent.withValues(alpha: 0.18),
        cx: w * (0.7 + 0.12 * cos(t * 2 * pi * 1.3)),
        cy: h * (0.6 + 0.15 * sin(t * 2 * pi * 0.5)),
        r: w * 0.5,
      ),
      _Blob(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
            onPressed: onClose,
          ),
          const Spacer(),
          _GlassPill(
            icon: Icons.lyrics,
            label: 'Lyrics',
            isActive: showLyrics,
            onTap: onLyrics,
          ),
          const SizedBox(width: 8),
          _GlassPill(
            icon: Icons.queue_music,
            label: 'Queue',
            isActive: showQueue,
            onTap: onQueue,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () {
              if (track != null) {
                showTrackOptionsSheet(context, ref, track!);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Artwork View with animated album art
// ═══════════════════════════════════════════════════════════════════

class _ArtworkView extends StatelessWidget {
  final MusicTrack track;
  const _ArtworkView({required this.track});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'now_playing_art',
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 5,
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
// Lyrics View — synced lyrics with blur effect 
// ═══════════════════════════════════════════════════════════════════

class _LyricsView extends ConsumerStatefulWidget {
  final MusicTrack track;
  final Duration position;

  const _LyricsView({required this.track, required this.position});

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

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return const Center(
            child: Text(
              'No lyrics found for this track',
              style: TextStyle(color: Colors.white54, fontSize: 16),
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
              stops: [0.0, 0.1, 0.9, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final isActive = index == activeLine;
              final line = lyrics[index];

              return InkWell(
                onTap: () {
                  ref.read(musicPlayerProvider.notifier).seekTo(line.timestamp);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: isActive ? 26 : 19,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white38,
                      height: 1.45,
                      letterSpacing: -0.3,
                    ),
                    child: Text(line.text),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
                    color: isCurrent ? AppColors.primary : Colors.white,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? AppColors.primary.withValues(alpha: 0.7) : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                trailing: isCurrent
                    ? const Icon(Icons.equalizer, color: AppColors.primary, size: 20)
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                color: AppColors.primary,
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
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hd, size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        track.codec ?? 'FLAC',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
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
// Progress Slider — 
// ═══════════════════════════════════════════════════════════════════

class _ProgressSlider extends ConsumerWidget {
  final NowPlayingState state;
  const _ProgressSlider({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.15),
        ),
        child: Slider(
          value: state.position.inMilliseconds.toDouble(),
          max: (state.currentTrack?.duration.inMilliseconds ?? 1).toDouble(),
          onChanged: (value) {
            ref.read(musicPlayerProvider.notifier)
                .seekTo(Duration(milliseconds: value.round()));
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Timestamps
// ═══════════════════════════════════════════════════════════════════

class _Timestamps extends StatelessWidget {
  final NowPlayingState state;
  const _Timestamps({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDuration(state.position),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '-${_formatDuration((state.currentTrack?.duration ?? Duration.zero) - state.position)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
// Main Controls — Play/Pause, Next, Previous, Shuffle, Repeat
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
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: state.isShuffled ? AppColors.primary : Colors.white54,
              size: 22,
            ),
            onPressed: notifier.toggleShuffle,
          ),
          // Previous
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
            onPressed: notifier.previous,
          ),
          // Play/Pause — large glass button
          GestureDetector(
            onTap: notifier.togglePlayPause,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 34,
              ),
            ),
          ),
          // Next
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
            onPressed: notifier.next,
          ),
          // Repeat
          IconButton(
            icon: Icon(
              state.repeatMode == MusicRepeatMode.one
                  ? Icons.repeat_one
                  : Icons.repeat,
              color: state.repeatMode != MusicRepeatMode.off
                  ? AppColors.primary
                  : Colors.white54,
              size: 22,
            ),
            onPressed: notifier.cycleRepeatMode,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom Actions Row — Volume, Speed, Sleep Timer, Like
// ═══════════════════════════════════════════════════════════════════

class _BottomActions extends ConsumerWidget {
  final NowPlayingState state;
  const _BottomActions({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Volume
          _SmallActionButton(
            icon: state.volume > 0.5
                ? Icons.volume_up
                : state.volume > 0
                    ? Icons.volume_down
                    : Icons.volume_off,
            onTap: () => _showVolumeSheet(context, ref, state),
          ),
          // Speed
          _SmallActionButton(
            icon: Icons.speed,
            label: state.playbackSpeed != 1.0 ? '${state.playbackSpeed}x' : null,
            onTap: () => _showSpeedSheet(context, ref, state),
          ),
          // Sleep timer
          _SmallActionButton(
            icon: Icons.bedtime_outlined,
            isActive: ref.watch(sleepTimerProvider) != null,
            label: ref.watch(sleepTimerProvider) != null
                ? '${ref.watch(sleepTimerProvider)!.inMinutes}m'
                : null,
            onTap: () => showSleepTimerSheet(context, ref),
          ),
          // Favorite
          _SmallActionButton(
            icon: (state.currentTrack != null &&
                    ref.watch(likedSongsProvider).contains(state.currentTrack!.id))
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            isActive: state.currentTrack != null &&
                ref.watch(likedSongsProvider).contains(state.currentTrack!.id),
            onTap: () {
              final track = state.currentTrack;
              if (track == null) return;
              final isLiked = ref.read(likedSongsProvider).contains(track.id);
              ref.read(likedSongsProvider.notifier).toggleLike(track.id);
              if (isLiked) {
                ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist('fav_playlist', track.id);
              } else {
                ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist('fav_playlist', track);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isLiked ? 'Removed from Liked Songs' : 'Saved to Liked Songs ❤️'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // Nerd stats toggle
          _SmallActionButton(
            icon: Icons.info_outline,
            isActive: ref.watch(showNerdStatsProvider),
            onTap: () {
              ref.read(showNerdStatsProvider.notifier).state =
                  !ref.read(showNerdStatsProvider);
            },
          ),
        ],
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorderDark),
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
                      activeColor: AppColors.primary,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.glassBorderDark),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          color: isActive ? AppColors.primary : Colors.white70,
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

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool isActive;

  const _SmallActionButton({
    required this.icon,
    this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isActive ? AppColors.primary : Colors.white54,
          ),
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? AppColors.primary : Colors.white38,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
