import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'music_action_sheets.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';

/// Floating stadium capsule Mini-Player with true BitChord Liquid Glass aesthetics
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    final useGlass = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);

    // Liquid surface background tint bound to settings sliders
    final glassColor = isDark
        ? const Color(0xFF101014).withValues(alpha: opacity.clamp(0.12, 0.70))
        : Colors.white.withValues(alpha: (opacity * 1.3).clamp(0.20, 0.75));

    final solidColor = isDark ? const Color(0xFF18181C) : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 320),
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
                child: child,
              );
            },
          ),
        );
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            // Swiped left -> Next track
            HapticFeedback.selectionClick();
            ref.read(musicPlayerProvider.notifier).next();
          } else if (details.primaryVelocity! > 200) {
            // Swiped right -> Previous track
            HapticFeedback.selectionClick();
            ref.read(musicPlayerProvider.notifier).previous();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: useGlass ? intensity : 0.01,
              sigmaY: useGlass ? intensity : 0.01,
            ),
            child: Stack(
              children: [
                // Liquid glass background with specular rim
                Container(
                  decoration: BoxDecoration(
                    color: useGlass ? glassColor : solidColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    gradient: useGlass
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: isDark ? 0.22 : 0.40),
                              Colors.white.withValues(alpha: isDark ? 0.04 : 0.10),
                            ],
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      // Squircle Album Art
                      Hero(
                        tag: 'now_playing_art',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
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

                      // Track details: [E] / Lossless tag + Title + Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                // Explicit / Lossless tag
                                Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.14)
                                        : Colors.black.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    track.isLossless ? 'LOSSLESS' : 'E',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: contentColor,
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

                      // Play/Pause button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(musicPlayerProvider.notifier).togglePlayPause();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 38,
                          alignment: Alignment.center,
                          child: Icon(
                            state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: contentColor,
                            size: 28,
                          ),
                        ),
                      ),

                      // Next track button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(musicPlayerProvider.notifier).next();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 34,
                          height: 38,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: contentColor,
                            size: 26,
                          ),
                        ),
                      ),

                      // 3-dots Menu button (Workable)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showTrackOptionsSheet(context, ref, track);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 30,
                          height: 38,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: contentColor.withValues(alpha: 0.75),
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle Progress Bar at bottom of capsule
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 0,
                  height: 2.2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    child: LinearProgressIndicator(
                      value: state.progress.clamp(0.0, 1.0),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                    ),
                  ),
                ),
              ],
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
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.music_note,
        size: 22,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}
