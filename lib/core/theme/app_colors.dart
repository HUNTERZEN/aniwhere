import 'package:flutter/material.dart';

/// Core color palette for Aniwhere
/// Neumorphism design — soft extruded/inset shadows on a tinted dark surface
class AppColors {
  AppColors._();

  // ── Neumorphic Accent (used for active/selected indicators) ──
  static const Color accent = Color(0xFF7C5CFC);       // Soft violet accent
  static const Color accentLight = Color(0xFFA78BFA);   // Lighter violet
  static const Color accentDark = Color(0xFF5B3FD9);    // Deeper violet

  // Primary Brand Colors (High-contrast in both Dark and Light themes — never pure white)
  static const Color primary = Color(0xFF7C5CFC);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF5B3FD9);

  // ── Dark Theme — AMOLED Glassmorphism Base ──
  static const Color bgDark = Color(0xFF000000);           // Pure OLED/AMOLED Black
  static const Color surfaceDark = Color(0xFF000000);      // Pure AMOLED Black surface
  static const Color cardDark = Color(0xFF0A0A0E);         // Deep AMOLED dark card surface
  static const Color borderDark = Color(0x00000000);       // Borderless
  static const Color glassBorderDark = Color(0x00000000);  // Borderless

  // ── Glassmorphism & Depth Shadow Colors (Dark Mode) ──
  static const Color neumorphLightDark = Color(0x14FFFFFF);  // Specular top highlight
  static const Color neumorphShadowDark = Color(0x99000000); // Deep AMOLED shadow

  // ── Light Theme — Base ──
  static const Color bgLight = Color(0xFFF6F6F9);          // Clean iOS light
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0x00000000);
  static const Color glassBorderLight = Color(0x00000000);

  // ── Shadow Colors (Light Mode) ──
  static const Color neumorphLightLight = Color(0xFFFFFFFF);
  static const Color neumorphShadowLight = Color(0x22000000);

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textTertiaryDark = Color(0xFF71717A);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF0A0A0A);
  static const Color textSecondaryLight = Color(0xFF52525B);
  static const Color textTertiaryLight = Color(0xFF8E8E93);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF7C5CFC);

  // Media Type Colors
  static const Color manga = Color(0xFF7C5CFC);
  static const Color anime = Color(0xFFFA2D48);
  static const Color novel = Color(0xFF10B981);

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient monoGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Color(0x88000000), Colors.transparent, Color(0xD8000000)],
    stops: [0.0, 0.35, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Neumorphic Decoration Helpers ──

  /// Raised (extruded) neumorphic box for dark mode
  static List<BoxShadow> neumorphRaisedDark({double blur = 12, double offset = 4}) => [
    BoxShadow(
      color: neumorphLightDark,
      blurRadius: blur,
      offset: Offset(-offset, -offset),
    ),
    BoxShadow(
      color: neumorphShadowDark,
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
  ];

  /// Pressed (inset) neumorphic shadows for dark mode — simulated with gradient
  static List<BoxShadow> neumorphPressedDark({double blur = 8, double offset = 3}) => [
    BoxShadow(
      color: neumorphShadowDark,
      blurRadius: blur,
      offset: Offset(-offset, -offset),
    ),
    BoxShadow(
      color: neumorphLightDark,
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
  ];

  /// Raised neumorphic box for light mode
  static List<BoxShadow> neumorphRaisedLight({double blur = 12, double offset = 4}) => [
    BoxShadow(
      color: neumorphLightLight,
      blurRadius: blur,
      offset: Offset(-offset, -offset),
    ),
    BoxShadow(
      color: neumorphShadowLight,
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
  ];

  /// Pressed neumorphic box for light mode
  static List<BoxShadow> neumorphPressedLight({double blur = 8, double offset = 3}) => [
    BoxShadow(
      color: neumorphShadowLight,
      blurRadius: blur,
      offset: Offset(-offset, -offset),
    ),
    BoxShadow(
      color: neumorphLightLight,
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
  ];

  /// Get raised shadows for current brightness
  static List<BoxShadow> neumorphRaised(bool isDark, {double blur = 12, double offset = 4}) =>
      isDark ? neumorphRaisedDark(blur: blur, offset: offset) : neumorphRaisedLight(blur: blur, offset: offset);

  /// Get pressed shadows for current brightness
  static List<BoxShadow> neumorphPressed(bool isDark, {double blur = 8, double offset = 3}) =>
      isDark ? neumorphPressedDark(blur: blur, offset: offset) : neumorphPressedLight(blur: blur, offset: offset);

  // ── Apple Music Liquid Glassmorphism Helpers ──

  /// Apple Music frosted liquid glass container decoration
  static BoxDecoration appleGlassDecoration({
    required bool isDark,
    double radius = 20,
    bool isSelected = false,
    bool isPressed = false,
    Color? customTint,
    double? opacity,
    double? intensity,
  }) {
    final alpha = opacity ?? 0.35;
    final blur = intensity ?? 25.0;

    if (isDark) {
      final baseColor = customTint ??
          (isSelected
              ? const Color(0xFFFA2D48).withValues(alpha: 0.28)
              : (isPressed
                  ? const Color(0xFF1E1E28).withValues(alpha: (alpha * 1.3).clamp(0.0, 0.95))
                  : const Color(0xFF14141E).withValues(alpha: alpha)));

      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFA2D48).withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: isPressed ? 6 : (12 + (blur * 0.25)),
            offset: Offset(0, isPressed ? 2 : 4),
          ),
        ],
      );
    } else {
      final baseColor = customTint ??
          (isSelected
              ? const Color(0xFFFA2D48).withValues(alpha: 0.16)
              : (isPressed
                  ? Colors.black.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.05)));

      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
      );
    }
  }

  /// Apple Music glass circle button decoration
  static BoxDecoration appleGlassCircle({
    required bool isDark,
    bool isSelected = false,
    bool isPressed = false,
    double? opacity,
    double? intensity,
  }) {
    return appleGlassDecoration(
      isDark: isDark,
      radius: 999,
      isSelected: isSelected,
      isPressed: isPressed,
      opacity: opacity,
      intensity: intensity,
    );
  }
}
