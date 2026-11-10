import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/music/mini_player.dart';
import '../../features/music/music_providers.dart';

/// Main screen with iOS 27 Fluid Optical Liquid Glass navigation bar
/// and unclipped magnifying droplet lens on left/right pull.
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
    final miniPlayerBottom = navBottomMargin + _navBarHeight + 12.0;

    return Scaffold(
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          child,

          // Floating Mini Player stays cleanly above the 5-tab Liquid Glass bar (never overlaps on scroll)
          if (playerState.hasTrack)
            Positioned(
              left: 0,
              right: 0,
              bottom: miniPlayerBottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                offset: isBarVisible ? Offset.zero : const Offset(0, 1.8),
                child: IgnorePointer(
                  ignoring: !isBarVisible,
                  child: const MiniPlayer(),
                ),
              ),
            ),

          // Bottom Liquid Glass Navigation Bar placed directly in Stack (no Opacity layer)
          // so BackdropFilter and RawMagnifier sample the live background directly.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              offset: isBarVisible ? Offset.zero : const Offset(0, 1.6),
              child: IgnorePointer(
                ignoring: !isBarVisible,
                child: _LiquidGlassNavBar(
                  selectedIndex: selectedIndex,
                  isDark: isDark,
                  onTabSelected: (index) => _onItemTapped(context, ref, index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRouter.music) return 0;
    if (location == AppRouter.search) return 1;
    if (location == AppRouter.browse) return 2;
    if (location == AppRouter.home || location == AppRouter.library) return 3;
    if (location == AppRouter.settings) return 4;
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
        context.go(AppRouter.search);
        break;
      case 2:
        context.go(AppRouter.browse);
        break;
      case 3:
        context.go(AppRouter.home);
        break;
      case 4:
        context.go(AppRouter.settings);
        break;
    }
  }
}

/// iOS 27 Floating Liquid Glass Navigation Bar:
/// - Pure translucent Liquid Glass pill (no rainbow effect, no white borders)
/// - Slides 1:1 with finger when dragging left & right, swelling into a
///   liquid glass lens that magnifies tab icons as it glides across them.
class _LiquidGlassNavBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTabSelected;

  const _LiquidGlassNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.onTabSelected,
  });

  @override
  ConsumerState<_LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends ConsumerState<_LiquidGlassNavBar>
    with TickerProviderStateMixin {
  static const int _tabCount = 5;
  static const double _barHeight = 66.0;

  late final AnimationController _positionController;
  late final AnimationController _lensController;

  bool _isInteracting = false;
  bool _hasDragged = false;
  double _downX = 0.0;
  double _velocityX = 0.0;
  int _hoverIndex = 0;
  int? _activePointer;
  DateTime? _pointerDownTime;

  @override
  void initState() {
    super.initState();
    _hoverIndex = widget.selectedIndex.clamp(0, _tabCount - 1);

    // Continuous normalized tab coordinate (0.0 .. 4.0) with unbounded bouncy spring support
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: _hoverIndex.toDouble(),
    )..addListener(() => setState(() {}));

    // Unbounded bouncy spring controller for droplet swell (0.0 = resting frosted pillow, 1.0 = clear magnifying droplet)
    _lensController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInteracting && oldWidget.selectedIndex != widget.selectedIndex) {
      final target = widget.selectedIndex.clamp(0, _tabCount - 1);
      _hoverIndex = target;
      _springToIndex(target.toDouble());
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _lensController.dispose();
    super.dispose();
  }

  void _springToIndex(double targetIndex, {double? velocity}) {
    final reduceAnim = ref.read(reduceAnimationProvider);
    if (reduceAnim) {
      _positionController.value = targetIndex;
      return;
    }
    // Under-damped bouncy iOS spring so the pill overshoots and bounces into place
    const bouncySpring = SpringDescription(mass: 1.0, stiffness: 235, damping: 14.2);
    _positionController.animateWith(
      SpringSimulation(
        bouncySpring,
        _positionController.value,
        targetIndex,
        velocity ?? _positionController.velocity,
      ),
    );
  }

  void _springLensTo(double target) {
    final reduceAnim = ref.read(reduceAnimationProvider);
    if (reduceAnim) {
      _lensController.value = target;
      return;
    }
    const lensSpring = SpringDescription(mass: 1.0, stiffness: 270, damping: 14.5);
    _lensController.animateWith(
      SpringSimulation(
        lensSpring,
        _lensController.value,
        target,
        _lensController.velocity,
      ),
    );
  }

  double _xToTabPosition(double dx, double totalWidth) {
    final tabWidth = totalWidth / _tabCount;
    return ((dx - tabWidth / 2) / tabWidth).clamp(-0.18, (_tabCount - 1) + 0.18);
  }

  void _handlePointerDown(PointerDownEvent event, double totalWidth) {
    _activePointer = event.pointer;
    _pointerDownTime = DateTime.now();
    _downX = event.localPosition.dx;
    _hasDragged = false;

    final pos = _xToTabPosition(event.localPosition.dx, totalWidth);
    final newHover = pos.round().clamp(0, _tabCount - 1);

    setState(() {
      _isInteracting = true;
      _hoverIndex = newHover;
      _velocityX = 0.0;
    });

    _springLensTo(1.0);

    // If touching on/near the current pill, lock 1:1 immediately so dragging starts with zero lag.
    // If touching a distant tab, launch a single spring toward that tab (never reset on jitter!).
    if ((pos - _positionController.value).abs() <= 0.65) {
      _positionController.stop();
      _positionController.value = pos;
    } else {
      _springToIndex(pos);
    }
    HapticFeedback.selectionClick();
  }

  void _handlePointerMove(PointerMoveEvent event, double totalWidth) {
    if (_activePointer != null && event.pointer != _activePointer) return;

    // Ignore micro-jitter (< 1.5px) until intentional finger drag begins so a tap spring isn't cancelled
    if (!_hasDragged && (event.localPosition.dx - _downX).abs() < 1.5) {
      return;
    }
    _hasDragged = true;

    final pos = _xToTabPosition(event.localPosition.dx, totalWidth);
    final newHover = pos.round().clamp(0, _tabCount - 1);
    if (newHover != _hoverIndex) {
      HapticFeedback.selectionClick();
    }

    _velocityX = (_velocityX * 0.55) + (event.delta.dx * 0.45);
    _hoverIndex = newHover;

    // Set controller value directly for 1:1 immediate finger tracking (never call animateWith on every move frame!)
    if (_positionController.isAnimating) {
      _positionController.stop();
    }
    _positionController.value = pos;
  }

  void _handlePointerUp(PointerUpEvent event, double totalWidth) {
    if (_activePointer != null && event.pointer != _activePointer) return;
    _activePointer = null;
    final pos = _xToTabPosition(event.localPosition.dx, totalWidth);
    final targetIndex = pos.round().clamp(0, _tabCount - 1);
    final holdMs = _pointerDownTime != null
        ? DateTime.now().difference(_pointerDownTime!).inMilliseconds
        : 300;
    final tabWidth = totalWidth / _tabCount;
    final releaseVelocity = (_velocityX / tabWidth) * 14.0;

    setState(() {
      _isInteracting = false;
      _hasDragged = false;
      _hoverIndex = targetIndex;
      _velocityX = 0.0;
    });

    // If it was a quick tap, let the bouncy magnifying droplet swell briefly while flying
    // to the target tab, then bounce back into the resting frosted pill.
    if (holdMs < 160) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_isInteracting) {
          _springLensTo(0.0);
        }
      });
    } else {
      _springLensTo(0.0);
    }

    _springToIndex(targetIndex.toDouble(), velocity: releaseVelocity);
    HapticFeedback.lightImpact();
    widget.onTabSelected(targetIndex);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != null && event.pointer != _activePointer) return;
    _activePointer = null;
    final targetIndex = _hoverIndex.clamp(0, _tabCount - 1);
    setState(() {
      _isInteracting = false;
      _hasDragged = false;
      _velocityX = 0.0;
    });
    _springLensTo(0.0);
    _springToIndex(targetIndex.toDouble());
    widget.onTabSelected(targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final marginBottom = bottomPadding > 0 ? bottomPadding : 16.0;

    final glassEnabled = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);

    // Rich, creamy frosted blur like Picture 1 & 2 (sigma ~ 28, low dark tint so colors bloom through)
    final sigma = glassEnabled ? intensity.clamp(24.0, 36.0) : 24.0;
    final alpha = glassEnabled ? opacity.clamp(0.24, 0.38) : 0.32;

    final glassColor = isDark
        ? Colors.black.withValues(alpha: alpha)
        : Colors.white.withValues(alpha: alpha.clamp(0.68, 0.82));

    return _buildExpandedNavBar(
      context,
      marginBottom,
      isDark,
      glassColor,
      sigma,
    );
  }

  /// Full 5-Tab Bar matching Picture 1 (Frosted Blur + Concentric Glowing Pill at rest)
  /// and Picture 2 (Unclipped Clear Magnifying Droplet with Bouncy Spring Physics on slide/tap).
  Widget _buildExpandedNavBar(
    BuildContext context,
    double marginBottom,
    bool isDark,
    Color glassColor,
    double sigma,
  ) {
    // Allow unbounded spring overshoot for bouncy droplet animation
    final lensSpringVal = _lensController.value;
    final clampedLens = lensSpringVal.clamp(0.0, 1.0);

    const tabs = [
      _TabSpec(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _TabSpec(Icons.search_outlined, Icons.search_rounded, 'Search'),
      _TabSpec(Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Manga'),
      _TabSpec(Icons.video_library_outlined, Icons.video_library_rounded, 'Library'),
      _TabSpec(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    ];

    return Container(
      key: const ValueKey('expanded_navbar'),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: marginBottom,
      ),
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / _tabCount;

          // Combine finger drag velocity + spring velocity for bouncy jelly squash & stretch
          final springSpeed = (_positionController.velocity * 3.2).abs();
          final dragSpeed = (_velocityX.abs() * 1.9);
          final stretchX = (springSpeed + dragSpeed).clamp(0.0, 26.0);

          // At rest (Picture 1): concentric frosted pill (height: 58 inside 66px bar -> 4px uniform inset).
          // When sliding/bouncing (Picture 2): swells to height 84px (overflowing 9px above & below bar)
          // and stretches horizontally with velocity.
          final restWidth = tabWidth + 2.0;
          final restHeight = _barHeight - 8.0; // 58px -> 4px inset top/bottom
          final activeDropletWidth = 86.0 + stretchX;
          final activeDropletHeight = 84.0 - (stretchX * 0.22);

          final pillWidth = lerpDouble(restWidth, activeDropletWidth, lensSpringVal)!
              .clamp(48.0, 140.0);
          final pillHeight = lerpDouble(restHeight, activeDropletHeight, lensSpringVal)!
              .clamp(44.0, 104.0);

          final currentTabPos = _positionController.value;
          final centerX = (currentTabPos + 0.5) * tabWidth;
          // At rest, clamp with a 4px inset so the leftmost/rightmost pill curve is concentric with the bar's 33px curve
          final minLeft = lerpDouble(4.0, -6.0, clampedLens)!;
          final maxLeft = lerpDouble(
            totalWidth - pillWidth - 4.0,
            totalWidth - pillWidth + 6.0,
            clampedLens,
          )!;
          final pillLeft = (centerX - pillWidth / 2).clamp(minLeft, maxLeft);
          final pillTop = (_barHeight - pillHeight) / 2;
          final dropletRect = Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight);

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _handlePointerDown(e, totalWidth),
            onPointerMove: (e) => _handlePointerMove(e, totalWidth),
            onPointerUp: (e) => _handlePointerUp(e, totalWidth),
            onPointerCancel: _handlePointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (_) {},
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ── 1. Creamy Frosted Blur Bar Capsule (punches out blur inside the clear droplet when sliding, like Picture 2) ──
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                            blurRadius: 24,
                            blurStyle: BlurStyle.outer,
                          ),
                        ],
                      ),
                      child: ClipPath(
                        clipper: _BarMinusDropletClipper(
                          barRadius: _barHeight / 2,
                          dropletRect: dropletRect,
                          punchFactor: clampedLens,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: sigma,
                            sigmaY: sigma,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_barHeight / 2),
                              color: glassColor,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                        Colors.white.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0.03),
                                        Colors.black.withValues(alpha: 0.18),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.55),
                                        Colors.white.withValues(alpha: 0.25),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── 1b. Outer Bar Specular Glass Rim (Picture 1 & 2) ──
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _OuterCapsuleRimPainter(isDark: isDark),
                      ),
                    ),
                  ),

                  // ── 2. Bouncy Pill / Clear Magnifying Liquid Droplet (Placed BEHIND Tab Icons Row!) ──
                  Positioned(
                    left: pillLeft,
                    top: pillTop,
                    width: pillWidth,
                    height: pillHeight,
                    child: IgnorePointer(
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          // When sliding/bouncing (Picture 2): Real optical RawMagnifier reveals the sharp,
                          // unblurred, magnified background through the frosted bar!
                          if (clampedLens > 0.02)
                            Opacity(
                              opacity: (clampedLens * 1.25).clamp(0.0, 1.0),
                              child: RawMagnifier(
                                size: Size(pillWidth, pillHeight),
                                magnificationScale: 1.0 + (0.22 * clampedLens),
                                decoration: MagnifierDecoration(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(pillHeight / 2),
                                  ),
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.38 * clampedLens),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Resting Frosted Pillow (Picture 1) morphing into Clear Droplet Rim (Picture 2)
                          CustomPaint(
                            painter: _LiquidGlassPillPainter(
                              isDark: isDark,
                              dropletFactor: clampedLens,
                              velocityX: _velocityX + _positionController.velocity * 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 3. All 5 Tab Destinations (Rendered ON TOP of the Droplet in crisp white, matching Picture 1 & 2) ──
                  Row(
                    children: List.generate(_tabCount, (i) {
                      final dist = (currentTabPos - i).abs();
                      final proximity = (1.0 - dist).clamp(0.0, 1.0);
                      // Bouncy magnification as the pill/droplet glides under each tab
                      final magnifyScale = 1.0 + (proximity * (0.05 + 0.10 * clampedLens));
                      final isSelected = proximity > 0.45;
                      return Expanded(
                        child: Transform.scale(
                          scale: magnifyScale,
                          child: _TabDestinationItem(
                            spec: tabs[i],
                            isSelected: isSelected,
                            proximity: proximity,
                            isDark: isDark,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabSpec(this.icon, this.activeIcon, this.label);
}

class _TabDestinationItem extends StatelessWidget {
  final _TabSpec spec;
  final bool isSelected;
  final double proximity;
  final bool isDark;

  const _TabDestinationItem({
    required this.spec,
    required this.isSelected,
    required this.proximity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.65);
    final color = Color.lerp(inactiveColor, activeColor, proximity)!;

    return SizedBox(
      height: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? spec.activeIcon : spec.icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 3),
          Text(
            spec.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips the outer bar to its capsule RRect, and when the magnifying droplet is active
/// (Picture 2), subtracts the droplet oval so the area inside the droplet is unblurred!
class _BarMinusDropletClipper extends CustomClipper<Path> {
  final double barRadius;
  final Rect dropletRect;
  final double punchFactor;

  const _BarMinusDropletClipper({
    required this.barRadius,
    required this.dropletRect,
    required this.punchFactor,
  });

  @override
  Path getClip(Size size) {
    final barPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(barRadius)),
      );
    if (punchFactor <= 0.08) {
      return barPath;
    }
    // Smoothly expand the clear unblurred hole inside the droplet
    final holeRect = Rect.fromCenter(
      center: dropletRect.center,
      width: dropletRect.width * punchFactor.clamp(0.0, 1.0),
      height: dropletRect.height * punchFactor.clamp(0.0, 1.0),
    );
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(holeRect, Radius.circular(holeRect.height / 2)),
      );
    return Path.combine(PathOperation.difference, barPath, holePath);
  }

  @override
  bool shouldReclip(covariant _BarMinusDropletClipper old) =>
      old.barRadius != barRadius ||
      old.dropletRect != dropletRect ||
      old.punchFactor != punchFactor;
}

/// Paints the delicate directional glass specular edge around the outer capsule bar (Picture 1 & 2)
class _OuterCapsuleRimPainter extends CustomPainter {
  final bool isDark;
  const _OuterCapsuleRimPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.38),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.30),
              ]
            : [
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.12),
              ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _OuterCapsuleRimPainter old) => old.isDark != isDark;
}

/// Paints:
/// - At rest (`dropletFactor == 0`): the luminous frosted milky-glass pillow (Picture 1)
/// - When dragging/bouncing (`dropletFactor -> 1`): the crystal-clear optical lens bevel & meniscus rim (Picture 2)
class _LiquidGlassPillPainter extends CustomPainter {
  final bool isDark;
  final double dropletFactor;
  final double velocityX;

  const _LiquidGlassPillPainter({
    required this.isDark,
    required this.dropletFactor,
    required this.velocityX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final restAlpha = (1.0 - dropletFactor).clamp(0.0, 1.0);

    // ── A. Resting Luminous Frosted Glass Pillow (Picture 1) ──
    if (restAlpha > 0.01) {
      if (isDark) {
        // Radial inner frosted glow (brighter around the pillow edge, soft translucent center)
        final radialPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.15, -0.2),
            radius: 0.78,
            colors: [
              Colors.white.withValues(alpha: 0.12 * restAlpha),
              Colors.white.withValues(alpha: 0.22 * restAlpha),
              Colors.white.withValues(alpha: 0.32 * restAlpha),
            ],
            stops: const [0.0, 0.68, 1.0],
          ).createShader(rect);
        canvas.drawRRect(rrect, radialPaint);

        // Top-left to bottom-right milky glass sheen
        final sheenPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.24 * restAlpha),
              Colors.white.withValues(alpha: 0.06 * restAlpha),
              Colors.white.withValues(alpha: 0.16 * restAlpha),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect);
        canvas.drawRRect(rrect, sheenPaint);

        // Crisp frosted pillow rim
        final restRimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.45 * restAlpha),
              Colors.white.withValues(alpha: 0.12 * restAlpha),
              Colors.white.withValues(alpha: 0.28 * restAlpha),
            ],
          ).createShader(rect);
        canvas.drawRRect(rrect.deflate(0.5), restRimPaint);
      } else {
        // Light mode: delicate translucent frosted glass pillow (never a solid white blob)
        final lightPillowPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.15, -0.2),
            radius: 0.80,
            colors: [
              Colors.black.withValues(alpha: 0.05 * restAlpha),
              Colors.black.withValues(alpha: 0.09 * restAlpha),
              Colors.black.withValues(alpha: 0.13 * restAlpha),
            ],
            stops: const [0.0, 0.70, 1.0],
          ).createShader(rect);
        canvas.drawRRect(rrect, lightPillowPaint);

        final lightRimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.75 * restAlpha),
              Colors.black.withValues(alpha: 0.06 * restAlpha),
              Colors.black.withValues(alpha: 0.12 * restAlpha),
            ],
          ).createShader(rect);
        canvas.drawRRect(rrect.deflate(0.5), lightRimPaint);
      }
    }

    // ── B. Active Clear Magnifying Liquid Droplet Bevel & Rim (Picture 2) ──
    if (dropletFactor > 0.01) {
      // Peripheral glass lens refraction bevel (center 0.0..0.76 is 100% clear so the magnified image is sharp)
      final bevelPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.52,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22 * dropletFactor),
            Colors.white.withValues(alpha: 0.26 * dropletFactor),
          ],
          stops: const [0.0, 0.76, 0.91, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, bevelPaint);

      // Crisp specular glass meniscus arc at top and bottom of the droplet (matching Picture 2)
      final tilt = (velocityX * 0.015).clamp(-0.25, 0.25);
      final dropletRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..shader = LinearGradient(
          begin: Alignment(-tilt, -1.0),
          end: Alignment(tilt, 1.0),
          colors: [
            Colors.white.withValues(alpha: 0.68 * dropletFactor),
            Colors.white.withValues(alpha: 0.12 * dropletFactor),
            Colors.white.withValues(alpha: 0.12 * dropletFactor),
            Colors.white.withValues(alpha: 0.52 * dropletFactor),
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect.deflate(0.6), dropletRimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPillPainter old) =>
      old.isDark != isDark ||
      old.dropletFactor != dropletFactor ||
      old.velocityX != velocityX;
}

