import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';

/// Floating Dynamic Island / Top Music Capsule
/// Sits at the top of the screen right below the camera cutout/status bar
class DynamicIslandCapsule extends ConsumerStatefulWidget {
  const DynamicIslandCapsule({super.key});

  @override
  ConsumerState<DynamicIslandCapsule> createState() => _DynamicIslandCapsuleState();
}

class _DynamicIslandCapsuleState extends ConsumerState<DynamicIslandCapsule>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(musicPlayerProvider);
    final isEnabled = ref.watch(dynamicIslandEnabledProvider);

    if (!isEnabled || !playerState.hasTrack) {
      return const SizedBox.shrink();
    }

    final track = playerState.currentTrack!;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topPadding > 0 ? topPadding + 4 : 8,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _isExpanded = !_isExpanded);
          },
          onDoubleTap: () {
            HapticFeedback.mediumImpact();
            ref.read(musicPlayerProvider.notifier).togglePlayPause();
          },
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) {
              HapticFeedback.lightImpact();
              ref.read(musicPlayerProvider.notifier).next();
            } else if ((details.primaryVelocity ?? 0) > 200) {
              HapticFeedback.lightImpact();
              ref.read(musicPlayerProvider.notifier).previous();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            height: _isExpanded ? 76 : 38,
            width: _isExpanded ? 330 : 200,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(_isExpanded ? 24 : 19),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: playerState.isPlaying ? 0.35 : 0.0),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_isExpanded ? 24 : 19),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: _isExpanded
                    ? _buildExpandedContent(context, track, playerState)
                    : _buildCollapsedContent(context, track, playerState),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(
    BuildContext context,
    dynamic track,
    dynamic playerState,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Mini Art
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: track.albumArtUrl != null
              ? CachedNetworkImage(
                  imageUrl: track.albumArtUrl!,
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _artFallback(),
                )
              : _artFallback(),
        ),
        const SizedBox(width: 8),

        // Title
        Expanded(
          child: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Live Audio Wave Equalizer
        _EqualizerBars(
          isPlaying: playerState.isPlaying,
          animation: _waveAnim,
        ),
      ],
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    dynamic track,
    dynamic playerState,
  ) {
    return Row(
      children: [
        // Album art with tap to open full screen
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
            );
          },
          child: Hero(
            tag: 'island_cover',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: track.albumArtUrl != null
                  ? CachedNetworkImage(
                      imageUrl: track.albumArtUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _artFallback(size: 52),
                    )
                  : _artFallback(size: 52),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Info & Media Controls
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Quick Controls
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 20, color: Colors.white70),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(musicPlayerProvider.notifier).previous();
          },
        ),
        IconButton(
          icon: Icon(
            playerState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 28,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(musicPlayerProvider.notifier).togglePlayPause();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 20, color: Colors.white70),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(musicPlayerProvider.notifier).next();
          },
        ),
      ],
    );
  }

  Widget _artFallback({double size = 26}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[900],
      child: Icon(Icons.music_note, size: size * 0.6, color: Colors.white),
    );
  }
}

/// 3-bar animated equalizer wave
class _EqualizerBars extends StatelessWidget {
  final bool isPlaying;
  final Animation<double> animation;

  const _EqualizerBars({
    required this.isPlaying,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            width: 3,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(8 + 8 * (1 - t)),
            _bar(5 + 11 * t),
            _bar(7 + 9 * (0.5 + 0.5 * (1 - t))),
          ],
        );
      },
    );
  }

  Widget _bar(double h) {
    return Container(
      width: 3,
      height: h.clamp(4.0, 16.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
