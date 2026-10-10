import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/music/mini_player.dart';
import '../../features/music/music_providers.dart';

/// Main screen with unified BitChord Liquid Glass navigation bar and fluid auto-hide on scroll
class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({
    super.key,
    required this.child,
  });

  static const double _navBarHeight = 62.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final playerState = ref.watch(musicPlayerProvider);
    final isBarVisible = ref.watch(isBottomBarVisibleProvider);

    final navBottomMargin = bottomPadding > 0 ? bottomPadding : 16.0;
    // Mini player floats cleanly above the bottom navigation bar with 10px spacing
    final miniPlayerBottom = navBottomMargin + _navBarHeight + 10.0;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            // User scrolling down -> content moving up -> hide player & nav bar
            if (ref.read(isBottomBarVisibleProvider)) {
              ref.read(isBottomBarVisibleProvider.notifier).state = false;
            }
          } else if (notification.direction == ScrollDirection.forward) {
            // User scrolling up -> content moving down -> restore player & nav bar
            if (!ref.read(isBottomBarVisibleProvider)) {
              ref.read(isBottomBarVisibleProvider.notifier).state = true;
            }
          }
          return false;
        },
        child: Stack(
          children: [
            child,

            // Floating Liquid Glass Mini Player (fluidly slides down on scroll down)
            if (playerState.hasTrack)
              Positioned(
                left: 0,
                right: 0,
                bottom: miniPlayerBottom,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  offset: isBarVisible ? Offset.zero : const Offset(0, 2.8),
                  child: const MiniPlayer(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        offset: isBarVisible ? Offset.zero : const Offset(0, 1.5),
        child: _BitChordLiquidGlassNavBar(
          selectedIndex: selectedIndex,
          isDark: isDark,
          isPlaying: playerState.isPlaying,
          onTabSelected: (index) => _onItemTapped(context, ref, index),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRouter.music) return 0;
    if (location == AppRouter.home || location == AppRouter.library) return 1;
    if (location == AppRouter.browse) return 2;
    if (location == AppRouter.settings) return 3;
    if (location == AppRouter.search) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
    // Restore bottom bar visibility on tab switch
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
        context.go(AppRouter.home);
        break;
      case 2:
        context.go(AppRouter.browse);
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

/// Unified BitChord Liquid Glass Floating Navigation Bar (5 tabs in one pill)
/// Features translucent frosted glass blur, specular edge highlight,
/// and liquid stretch/squash traveling lens indicator with spring physics.
class _BitChordLiquidGlassNavBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final bool isDark;
  final bool isPlaying;
  final ValueChanged<int> onTabSelected;

  const _BitChordLiquidGlassNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.isPlaying,
    required this.onTabSelected,
  });

  @override
  ConsumerState<_BitChordLiquidGlassNavBar> createState() => _BitChordLiquidGlassNavBarState();
}

class _BitChordLiquidGlassNavBarState extends ConsumerState<_BitChordLiquidGlassNavBar> {
  static const int _tabCount = 5;
  static const double _stretch = 0.16;
  static const double _squash = 0.50;

  bool _isDragging = false;
  double _dragX = 0.0;
  int _hoverIndex = 0;

  @override
  void initState() {
    super.initState();
    _hoverIndex = widget.selectedIndex.clamp(0, _tabCount - 1);
  }

  @override
  void didUpdateWidget(covariant _BitChordLiquidGlassNavBar oldWidget) {
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

    final useGlass = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);
    final reduceAnim = ref.watch(reduceAnimationProvider);

    // Liquid surface background tint
    final glassColor = isDark
        ? Color(0xFF101014).withValues(alpha: opacity.clamp(0.15, 0.65))
        : Colors.white.withValues(alpha: (opacity * 1.3).clamp(0.20, 0.75));

    final solidColor = isDark ? const Color(0xFF18181C) : Colors.white;

    return Container(
      margin: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: marginBottom,
      ),
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: useGlass ? intensity : 0.01,
            sigmaY: useGlass ? intensity : 0.01,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: useGlass ? glassColor : solidColor,
              borderRadius: BorderRadius.circular(31),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final tabWidth = totalWidth / _tabCount;
                const pillWidth = 54.0;
                const pillHeight = 46.0;

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
                      // ── Liquid Glass Active Lens (Travelling Pill) ──
                      AnimatedPositioned(
                        duration: (_isDragging || reduceAnim)
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        left: activePillLeft,
                        width: pillWidth * (1.0 + (_isDragging ? _stretch : 0.0)),
                        height: pillHeight * (1.0 - (_isDragging ? _stretch * _squash : 0.0)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      Colors.white.withValues(alpha: 0.22),
                                      Colors.white.withValues(alpha: 0.08),
                                    ]
                                  : [
                                      Colors.black.withValues(alpha: 0.12),
                                      Colors.black.withValues(alpha: 0.04),
                                    ],
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── All 5 Tab Destinations ──
                      Row(
                        children: [
                          _LiquidTabItem(
                            icon: Icons.music_note_outlined,
                            activeIcon: Icons.music_note_rounded,
                            label: 'Music',
                            isSelected: _isDragging
                                ? _hoverIndex == 0
                                : widget.selectedIndex == 0,
                            isDark: isDark,
                            hasGlow: widget.isPlaying,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(0);
                            },
                          ),
                          _LiquidTabItem(
                            icon: Icons.collections_bookmark_outlined,
                            activeIcon: Icons.collections_bookmark_rounded,
                            label: 'Library',
                            isSelected: _isDragging
                                ? _hoverIndex == 1
                                : widget.selectedIndex == 1,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(1);
                            },
                          ),
                          _LiquidTabItem(
                            icon: Icons.explore_outlined,
                            activeIcon: Icons.explore_rounded,
                            label: 'Browse',
                            isSelected: _isDragging
                                ? _hoverIndex == 2
                                : widget.selectedIndex == 2,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(2);
                            },
                          ),
                          _LiquidTabItem(
                            icon: Icons.tune_outlined,
                            activeIcon: Icons.tune_rounded,
                            label: 'Settings',
                            isSelected: _isDragging
                                ? _hoverIndex == 3
                                : widget.selectedIndex == 3,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTabSelected(3);
                            },
                          ),
                          _LiquidTabItem(
                            icon: Icons.search_outlined,
                            activeIcon: Icons.search_rounded,
                            label: 'Search',
                            isSelected: _isDragging
                                ? _hoverIndex == 4
                                : widget.selectedIndex == 4,
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

/// Navigation item inside the fluid liquid glass bar
class _LiquidTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final bool hasGlow;
  final VoidCallback onTap;

  const _LiquidTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    this.hasGlow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark ? Colors.white : Colors.black;
    final unselectedColor = isDark ? Colors.white60 : Colors.black54;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 22,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                  if (hasGlow && isSelected)
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.8),
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : unselectedColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
