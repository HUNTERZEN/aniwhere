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

/// Main screen with Neumorphic navigation bar and fluid auto-hide on scroll
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

    final navBottomMargin = bottomPadding > 0 ? bottomPadding : 16.0;
    final miniPlayerBottom = navBottomMargin + _navBarHeight + 10.0;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            if (ref.read(isBottomBarVisibleProvider)) {
              ref.read(isBottomBarVisibleProvider.notifier).state = false;
            }
          } else if (notification.direction == ScrollDirection.forward) {
            if (!ref.read(isBottomBarVisibleProvider)) {
              ref.read(isBottomBarVisibleProvider.notifier).state = true;
            }
          }
          return false;
        },
        child: Stack(
          children: [
            child,

            // Floating Neumorphic Mini Player
            if (playerState.hasTrack)
              Positioned(
                left: 0,
                right: 0,
                bottom: miniPlayerBottom,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  offset: isBarVisible ? Offset.zero : const Offset(0, 2.8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isBarVisible ? 1.0 : 0.0,
                    child: const MiniPlayer(),
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
            onTabSelected: (index) => _onItemTapped(context, ref, index),
          ),
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

/// Neumorphic Floating Navigation Bar with spring-physics traveling indicator
class _NeumorphicNavBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final bool isDark;
  final bool isPlaying;
  final ValueChanged<int> onTabSelected;

  const _NeumorphicNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.isPlaying,
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

    // AMOLED Liquid Glass base color
    final glassColor = isDark
        ? const Color(0x99101014)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
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
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(33),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final tabWidth = totalWidth / _tabCount;
                const pillWidth = 52.0;
                const pillHeight = 44.0;

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
                      // ── Liquid Glass Active Indicator ──
                      AnimatedPositioned(
                        duration: _isDragging
                            ? const Duration(milliseconds: 30)
                            : (reduceAnim ? Duration.zero : const Duration(milliseconds: 380)),
                        curve: _isDragging ? Curves.linear : Curves.easeOutBack,
                        left: activePillLeft,
                        width: pillWidth,
                        height: pillHeight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.12),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.30),
                                blurRadius: 12,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),

                // ── All 5 Tab Destinations ──
                Row(
                  children: [
                    _NeumorphTabItem(
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
                    _NeumorphTabItem(
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
                    _NeumorphTabItem(
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
                    _NeumorphTabItem(
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
                    _NeumorphTabItem(
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

/// Navigation tab item with animated scale + color transitions
class _NeumorphTabItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final bool hasGlow;
  final VoidCallback onTap;

  const _NeumorphTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
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
    final accentColor = AppColors.accent;
    final selectedColor = widget.isSelected ? accentColor : (widget.isDark ? Colors.white60 : Colors.black54);

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
                            color: accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.8),
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
    );
  }
}
