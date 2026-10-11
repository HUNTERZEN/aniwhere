import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/music/music_providers.dart';

/// Universal Apple-style Liquid Glass Container
/// Dynamically updates blur sigma, surface tint opacity, and specular reflection
/// based on the user's settings (liquidGlassProvider, liquidGlassIntensityProvider, liquidGlassOpacityProvider).
class LiquidGlassContainer extends ConsumerWidget {
  final Widget child;
  final double radius;
  final bool isCircle;
  final bool isSelected;
  final bool isPressed;
  final Color? customTint;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? customShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 20,
    this.isCircle = false,
    this.isSelected = false,
    this.isPressed = false,
    this.customTint,
    this.borderColor,
    this.borderWidth,
    this.customShadow,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider); // 5.0 to 45.0
    final opacity = ref.watch(liquidGlassOpacityProvider); // 0.15 to 0.70

    final sigma = glassEnabled ? intensity : 0.0;
    final tintAlpha = glassEnabled ? opacity : 0.85;

    // Base glass color
    final Color baseColor;
    if (customTint != null) {
      baseColor = customTint!;
    } else if (isDark) {
      if (isSelected) {
        baseColor = const Color(0xFFFA2D48).withValues(alpha: 0.28);
      } else if (isPressed) {
        baseColor = const Color(0xFF1E1E28).withValues(alpha: (tintAlpha * 1.3).clamp(0.0, 0.95));
      } else {
        baseColor = const Color(0xFF101018).withValues(alpha: tintAlpha);
      }
    } else {
      if (isSelected) {
        baseColor = const Color(0xFFFA2D48).withValues(alpha: 0.18);
      } else if (isPressed) {
        baseColor = Colors.grey.shade300.withValues(alpha: (tintAlpha * 1.2).clamp(0.0, 0.95));
      } else {
        baseColor = Colors.white.withValues(alpha: tintAlpha);
      }
    }

    // Crisp frosted glass border with specular highlight
    final Color resolvedBorderColor;
    if (borderColor != null) {
      resolvedBorderColor = borderColor!;
    } else if (isSelected) {
      resolvedBorderColor = const Color(0xFFFA2D48).withValues(alpha: 0.65);
    } else if (isDark) {
      resolvedBorderColor = Colors.white.withValues(alpha: isPressed ? 0.32 : (0.14 + (tintAlpha * 0.12)));
    } else {
      resolvedBorderColor = Colors.black.withValues(alpha: isPressed ? 0.20 : 0.09);
    }

    final resolvedBorderWidth = borderWidth ?? (isSelected ? 1.2 : 0.85);

    // Liquid shadow
    final resolvedShadows = customShadow ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? (0.35 + tintAlpha * 0.2) : 0.08),
        blurRadius: isPressed ? 6 : (12 + (intensity * 0.3)),
        offset: Offset(0, isPressed ? 2 : 5),
      ),
      if (isSelected)
        BoxShadow(
          color: const Color(0xFFFA2D48).withValues(alpha: 0.32),
          blurRadius: 16,
          spreadRadius: 1,
        ),
    ];

    final borderRadius = isCircle ? BorderRadius.circular(999) : BorderRadius.circular(radius);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: borderRadius,
        border: Border.all(color: resolvedBorderColor, width: resolvedBorderWidth),
        boxShadow: resolvedShadows,
      ),
      child: child,
    );

    if (glassEnabled && sigma > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: behavior,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
