import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/router/app_router.dart';
import '../../data/models/music_models.dart';
import '../../features/music/mini_player.dart';
import '../../features/music/music_providers.dart';
import '../../features/music/now_playing_screen.dart';

/// Main screen with Apple Music Liquid Glass navigation bar,
/// interactive drag magnifying bubble, and iOS Dynamic Docking Capsule on scroll down.
class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({
    super.key,
    required this.child,
  });

  static const double _navBarHeight = 66.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final playerState = ref.watch(musicPlayerProvider);
    final isBarVisible = ref.watch(isBottomBarVisibleProvider);
    final isDocked = ref.watch(isDockedCapsuleProvider);

    final navBottomMargin = bottomPadding > 0 ? bottomPadding : 16.0;
    final miniPlayerBottom = navBottomMargin + _navBarHeight + 10.0;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            if (notification.direction == ScrollDirection.reverse) {
              // User scrolled down -> morph to compact dock capsule (Screenshot 3)
              if (!ref.read(isDockedCapsuleProvider)) {
                ref.read(isDockedCapsuleProvider.notifier).state = true;
              }
            } else if (notification.direction == ScrollDirection.forward) {
              // User scrolled up -> expand to full bar + mini player (Screenshot 1)
              if (ref.read(isDockedCapsuleProvider)) {
                ref.read(isDockedCapsuleProvider.notifier).state = false;
              }
            }
          } else if (notification is ScrollUpdateNotification) {
            // Near top -> always restore expanded mode
            if (notification.metrics.pixels <= 15 && ref.read(isDockedCapsuleProvider)) {
              ref.read(isDockedCapsuleProvider.notifier).state = false;
            }
          }
          return false;
        },
        child: Stack(
          children: [
            child,

            // Floating Mini Player (Visible in expanded mode, slides into dock in collapsed mode)
            if (playerState.hasTrack)
              Positioned(
                left: 0,
                right: 0,
                bottom: miniPlayerBottom,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  offset: (!isDocked && isBarVisible) ? Offset.zero : const Offset(0, 1.8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 280),
                    opacity: (!isDocked && isBarVisible) ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: isDocked || !isBarVisible,
                      child: const MiniPlayer(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        offset: isBarVisible ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isBarVisible ? 1.0 : 0.0,
          child: _NeumorphicNavBar(
            selectedIndex: selectedIndex,
            isDark: isDark,
            isPlaying: playerState.isPlaying,
            isDocked: isDocked && playerState.hasTrack,
            onTabSelected: (index) => _onItemTapped(context, ref, index),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRouter.music) return 0;
    if (location == AppRouter.browse) return 1;
    if (location == AppRouter.home || location == AppRouter.library) return 2;
    if (location == AppRouter.settings) return 3;
    if (location == AppRouter.search) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
    ref.read(isBottomBarVisibleProvider.notifier).state = true;

    final shellNavigator = AppRouter.shellNavigatorKey.currentState;
    if (shellNavigator != null && shellNavigator.canPop()) {
      shellNavigator.pop();
    }

    switch (index) {
      case 0:
        context.go(AppRouter.music);
        break;
      case 1:
        context.go(AppRouter.browse);
        break;
      case 2:
        context.go(AppRouter.home);
        break;
      case 3:
        context.go(AppRouter.settings);
        break;
      case 4:
        context.go(AppRouter.search);
        break;
    }
  }
}

/// Neumorphic Floating Navigation Bar with spring-physics traveling indicator,
/// liquid magnifying drag lens, and dynamic scroll docking capsule.
class _NeumorphicNavBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final bool isDark;
  final bool isPlaying;
  final bool isDocked;
  final ValueChanged<int> onTabSelected;

  const _NeumorphicNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.isPlaying,
    required this.isDocked,
    required this.onTabSelected,
  });

  @override
  ConsumerState<_NeumorphicNavBar> createState() => _NeumorphicNavBarState();
}

class _NeumorphicNavBarState extends ConsumerState<_NeumorphicNavBar> {
  static const int _tabCount = 5;

  bool _isDragging = false;
  double _dragX = 0.0;
  int _hoverIndex = 0;

  @override
  void initState() {
    super.initState();
    _hoverIndex = widget.selectedIndex.clamp(0, _tabCount - 1);
  }

  @override
  void didUpdateWidget(covariant _NeumorphicNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.selectedIndex != widget.selectedIndex) {
      if (widget.selectedIndex < _tabCount) {
        _hoverIndex = widget.selectedIndex;
      }
    }
  }

  void _handleDragStart(DragStartDetails details, double totalWidth) {
    setState(() {
      _isDragging = true;
      _dragX = details.localPosition.dx.clamp(0.0, totalWidth);
      final tabWidth = totalWidth / _tabCount;
      _hoverIndex = (_dragX / tabWidth).floor().clamp(0, _tabCount - 1);
    });
    HapticFeedback.selectionClick();
  }

  void _handleDragUpdate(DragUpdateDetails details, double totalWidth) {
    final tabWidth = totalWidth / _tabCount;
    final newX = details.localPosition.dx.clamp(0.0, totalWidth);
    final newHover = (newX / tabWidth).floor().clamp(0, _tabCount - 1);

    if (newHover != _hoverIndex) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragX = newX;
      _hoverIndex = newHover;
    });
  }

  void _handleDragEnd(DragEndDetails details, double totalWidth) {
    final tabWidth = totalWidth / _tabCount;
    final targetIndex = (_dragX / tabWidth).floor().clamp(0, _tabCount - 1);

    setState(() {
      _isDragging = false;
      _hoverIndex = targetIndex;
    });

    HapticFeedback.lightImpact();
    widget.onTabSelected(targetIndex);
  }

  void _handleDragCancel() {
    setState(() {
      _isDragging = false;
      _hoverIndex = widget.selectedIndex < _tabCount ? widget.selectedIndex : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final marginBottom = bottomPadding > 0 ? bottomPadding : 16.0;

    final reduceAnim = ref.watch(reduceAnimationProvider);
    final glassEnabled = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);

    final sigma = glassEnabled ? intensity : 0.0;
    final alpha = glassEnabled ? opacity : 0.85;

    // AMOLED Liquid Glass base color
    final glassColor = isDark
        ? const Color(0xFF101018).withValues(alpha: alpha)
        : Colors.white.withValues(alpha: alpha);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: widget.isDocked
          ? _buildDockedCapsule(context, ref, marginBottom, isDark, sigma, alpha)
          : _buildExpandedNavBar(
              context,
              marginBottom,
              isDark,
              glassColor,
              sigma,
              alpha,
              reduceAnim,
            ),
    );
  }

  /// Compact iOS Docking Capsule on Scroll Down (Screenshot 3)
  Widget _buildDockedCapsule(
    BuildContext context,
    WidgetRef ref,
    double marginBottom,
    bool isDark,
    double sigma,
    double alpha,
  ) {
    final playerState = ref.watch(musicPlayerProvider);
    final track = playerState.currentTrack;

    return Container(
      key: const ValueKey('docked_capsule'),
      margin: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: marginBottom,
      ),
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left Circle: Home (Active tab)
          _DockCircleButton(
            icon: Icons.home_rounded,
            iconColor: const Color(0xFFFA2D48),
            isDark: isDark,
            sigma: sigma,
            alpha: alpha,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(isDockedCapsuleProvider.notifier).state = false;
              widget.onTabSelected(0);
            },
          ),

          const SizedBox(width: 8),

          // Center Capsule: Compact Mini Player
          if (track != null)
            Expanded(
              child: _DockMiniPlayerCapsule(
                track: track,
                isPlaying: playerState.isPlaying,
                isDark: isDark,
                sigma: sigma,
                alpha: alpha,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 420),
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
                onPlayPause: () {
                  HapticFeedback.selectionClick();
                  ref.read(musicPlayerProvider.notifier).togglePlayPause();
                },
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 8),

          // Right Circle: Search
          _DockCircleButton(
            icon: Icons.search_rounded,
            iconColor: Colors.white,
            isDark: isDark,
            sigma: sigma,
            alpha: alpha,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTabSelected(4);
            },
          ),
        ],
      ),
    );
  }

  /// Full 5-Tab Navigation Bar with Liquid Drag Bubble (Screenshot 1 & Screenshot 4)
  Widget _buildExpandedNavBar(
    BuildContext context,
    double marginBottom,
    bool isDark,
    Color glassColor,
    double sigma,
    double alpha,
    bool reduceAnim,
  ) {
    return Container(
      key: const ValueKey('expanded_navbar'),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: marginBottom,
      ),
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma > 0 ? sigma : 0.001, sigmaY: sigma > 0 ? sigma : 0.001),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(33),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18 + (alpha * 0.12))
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final tabWidth = totalWidth / _tabCount;

                // While dragging: expand to a big liquid bubble lens! (Screenshot 4)
                final pillWidth = _isDragging ? 68.0 : 52.0;
                final pillHeight = _isDragging ? 52.0 : 44.0;

                final normalPillLeft = widget.selectedIndex < _tabCount
                    ? widget.selectedIndex * tabWidth + (tabWidth - pillWidth) / 2
                    : 0.0;
                final draggingPillLeft =
                    (_dragX - pillWidth / 2).clamp(0.0, totalWidth - pillWidth);
                final activePillLeft = _isDragging ? draggingPillLeft : normalPillLeft;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) => _handleDragStart(d, totalWidth),
                  onHorizontalDragUpdate: (d) => _handleDragUpdate(d, totalWidth),
                  onHorizontalDragEnd: (d) => _handleDragEnd(d, totalWidth),
                  onHorizontalDragCancel: _handleDragCancel,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ── Liquid Glass Active Indicator / Lens (Screenshot 4) ──
                      AnimatedPositioned(
                        duration: _isDragging
                            ? const Duration(milliseconds: 20)
                            : (reduceAnim ? Duration.zero : const Duration(milliseconds: 380)),
                        curve: _isDragging ? Curves.linear : Curves.easeOutBack,
                        left: activePillLeft,
                        width: pillWidth,
                        height: pillHeight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(pillHeight / 2),
                            color: isDark
                                ? (_isDragging
                                    ? const Color(0xFFFA2D48).withValues(alpha: 0.28)
                                    : Colors.white.withValues(alpha: 0.15))
                                : (_isDragging
                                    ? const Color(0xFFFA2D48).withValues(alpha: 0.22)
                                    : Colors.black.withValues(alpha: 0.08)),
                            border: Border.all(
                              color: isDark
                                  ? (_isDragging
                                      ? Colors.white.withValues(alpha: 0.60)
                                      : Colors.white.withValues(alpha: 0.35))
                                  : (_isDragging
                                      ? const Color(0xFFFA2D48).withValues(alpha: 0.70)
                                      : Colors.black.withValues(alpha: 0.12)),
                              width: _isDragging ? 1.4 : 1.0,
                            ),
                            boxShadow: [
                              // Translucent liquid glow ring
                              BoxShadow(
                                color: const Color(0xFFFA2D48).withValues(
                                  alpha: _isDragging ? 0.45 : 0.25,
                                ),
                                blurRadius: _isDragging ? 22 : 12,
                                spreadRadius: _isDragging ? 2.5 : 0.5,
                              ),
                              if (_isDragging)
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: -1,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ── All 5 Tab Destinations (Screenshot 1) ──
                      Row(
                        children: [
                          _NeumorphTabItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            isSelected: _isDragging
                                ? _hoverIndex == 0
                                : widget.selectedIndex == 0,
                            isMagnified: _isDragging && _hoverIndex == 0,
                            isDark: isDark,
                            hasGlow: widget.isPlaying,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(0);
                            },
                          ),
                          _NeumorphTabItem(
                            icon: Icons.grid_view_outlined,
                            activeIcon: Icons.grid_view_rounded,
                            label: 'New',
                            isSelected: _isDragging
                                ? _hoverIndex == 1
                                : widget.selectedIndex == 1,
                            isMagnified: _isDragging && _hoverIndex == 1,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(1);
                            },
                          ),
                          _NeumorphTabItem(
                            icon: Icons.sensors_outlined,
                            activeIcon: Icons.sensors_rounded,
                            label: 'Radio',
                            isSelected: _isDragging
                                ? _hoverIndex == 2
                                : widget.selectedIndex == 2,
                            isMagnified: _isDragging && _hoverIndex == 2,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(2);
                            },
                          ),
                          _NeumorphTabItem(
                            icon: Icons.library_music_outlined,
                            activeIcon: Icons.library_music_rounded,
                            label: 'Library',
                            isSelected: _isDragging
                                ? _hoverIndex == 3
                                : widget.selectedIndex == 3,
                            isMagnified: _isDragging && _hoverIndex == 3,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(3);
                            },
                          ),
                          _NeumorphTabItem(
                            icon: Icons.search_outlined,
                            activeIcon: Icons.search_rounded,
                            label: 'Search',
                            isSelected: _isDragging
                                ? _hoverIndex == 4
                                : widget.selectedIndex == 4,
                            isMagnified: _isDragging && _hoverIndex == 4,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(4);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular Glass Button for the Dock (Screenshot 3)
class _DockCircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final double sigma;
  final double alpha;
  final VoidCallback onTap;

  const _DockCircleButton({
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.sigma,
    required this.alpha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma > 0 ? sigma : 0.001, sigmaY: sigma > 0 ? sigma : 0.001),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF14141E).withValues(alpha: alpha)
                    : Colors.white.withValues(alpha: alpha),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact Mini Player Capsule in Dock Mode (Screenshot 3)
class _DockMiniPlayerCapsule extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isDark;
  final double sigma;
  final double alpha;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _DockMiniPlayerCapsule({
    required this.track,
    required this.isPlaying,
    required this.isDark,
    required this.sigma,
    required this.alpha,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma > 0 ? sigma : 0.001, sigmaY: sigma > 0 ? sigma : 0.001),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF14141E).withValues(alpha: alpha)
                    : Colors.white.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Mini Artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: track.albumArtUrl != null
                          ? CachedNetworkImage(
                              imageUrl: track.albumArtUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF202028),
                                child: const Icon(Icons.music_note, color: Colors.white24, size: 18),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF202028),
                              child: const Icon(Icons.music_note, color: Colors.white24, size: 18),
                            ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Track Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onPlayPause,
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

/// Navigation tab item with animated scale + magnifying lens effect
class _NeumorphTabItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isMagnified;
  final bool isDark;
  final bool hasGlow;
  final VoidCallback onTap;

  const _NeumorphTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.isMagnified = false,
    required this.isDark,
    this.hasGlow = false,
    required this.onTap,
  });

  @override
  State<_NeumorphTabItem> createState() => _NeumorphTabItemState();
}

class _NeumorphTabItemState extends State<_NeumorphTabItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
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
    const appleRed = Color(0xFFFA2D48);
    final selectedColor = widget.isSelected
        ? appleRed
        : (widget.isDark ? Colors.white60 : Colors.black54);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            scale: widget.isMagnified ? 1.20 : 1.0,
            child: SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.isSelected ? widget.activeIcon : widget.icon,
                          key: ValueKey(widget.isSelected),
                          size: 22,
                          color: selectedColor,
                        ),
                      ),
                      if (widget.hasGlow && widget.isSelected)
                        Positioned(
                          top: -2,
                          right: -3,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: appleRed,
                              boxShadow: [
                                BoxShadow(
                                  color: appleRed.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: selectedColor,
                      letterSpacing: -0.2,
                    ),
                    child: Text(widget.label),
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
