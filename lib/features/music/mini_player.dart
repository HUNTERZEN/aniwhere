import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import 'music_action_sheets.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';

/// Floating Neumorphic Mini-Player with fluid swipe gestures
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);
    final sigma = glassEnabled ? intensity : 0.001;
    final alpha = glassEnabled ? opacity : 0.85;

    final contentColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => const NowPlayingScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          ),
        );
      },
      onHorizontalDragStart: (_) {
        setState(() {
          _isDragging = true;
          _dragOffset = 0.0;
        });
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.primaryDelta ?? 0;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() => _isDragging = false);
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200 || _dragOffset < -60) {
            HapticFeedback.selectionClick();
            ref.read(musicPlayerProvider.notifier).next();
          } else if (details.primaryVelocity! > 200 || _dragOffset > 60) {
            HapticFeedback.selectionClick();
            ref.read(musicPlayerProvider.notifier).previous();
          }
        }
        // Spring back
        setState(() => _dragOffset = 0.0);
      },
      onHorizontalDragCancel: () {
        setState(() {
          _isDragging = false;
          _dragOffset = 0.0;
        });
      },
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 62,
        transform: Matrix4.translationValues(_dragOffset * 0.5, 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(31),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF12121C).withValues(alpha: alpha)
                    : Colors.white.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(31),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18 + (alpha * 0.12))
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.9,
                ),
              ),
              child: Stack(
                children: [
                  // Main content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  // Squircle Album Art
                  Hero(
                    tag: 'now_playing_art',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: state.isPlaying ? 0.2 : 0.0),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: track.albumArtUrl != null
                          ? CachedNetworkImage(
                              imageUrl: track.albumArtUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _artPlaceholder(isDark),
                              errorWidget: (_, __, ___) => _artPlaceholder(isDark),
                            )
                          : _artPlaceholder(isDark),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Track details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            // Quality badge
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                track.isLossless ? 'LOSSLESS' : 'E',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: contentColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: subColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Play/Pause button — neumorphic circle
                  _NeumorphicCircleButton(
                    isDark: isDark,
                    size: 36,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: Icon(
                        state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        key: ValueKey(state.isPlaying),
                        color: contentColor,
                        size: 24,
                      ),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(musicPlayerProvider.notifier).togglePlayPause();
                    },
                  ),

                  const SizedBox(width: 4),

                  // Next track button
                  _NeumorphicCircleButton(
                    isDark: isDark,
                    size: 34,
                    child: Icon(
                      Icons.skip_next_rounded,
                      color: contentColor,
                      size: 22,
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(musicPlayerProvider.notifier).next();
                    },
                  ),

                  const SizedBox(width: 2),

                  // 3-dots Menu button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showTrackOptionsSheet(context, ref, track);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 28,
                      height: 38,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: contentColor.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar at bottom
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              height: 2.5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(31)),
                child: LinearProgressIndicator(
                  value: state.progress.clamp(0.0, 1.0),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
);
  }

  Widget _artPlaceholder(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33252538) : const Color(0xFFD4D4DE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.music_note,
        size: 22,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}

/// Small Apple Music liquid glass circle button with tap-scale spring animation
class _NeumorphicCircleButton extends StatefulWidget {
  final bool isDark;
  final double size;
  final Widget child;
  final VoidCallback onTap;

  const _NeumorphicCircleButton({
    required this.isDark,
    required this.size,
    required this.child,
    required this.onTap,
  });

  @override
  State<_NeumorphicCircleButton> createState() => _NeumorphicCircleButtonState();
}

class _NeumorphicCircleButtonState extends State<_NeumorphicCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.86).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isPressed = false);
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: AppColors.appleGlassCircle(
            isDark: widget.isDark,
            isPressed: _isPressed,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
