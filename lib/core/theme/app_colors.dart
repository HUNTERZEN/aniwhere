import 'package:flutter/material.dart';

/// Core color palette for Aniwhere
/// Neumorphism design — soft extruded/inset shadows on a tinted dark surface
class AppColors {
  AppColors._();

  // ── Neumorphic Accent (used for active/selected indicators) ──
  static const Color accent = Color(0xFF7C5CFC);       // Soft violet accent
  static const Color accentLight = Color(0xFFA78BFA);   // Lighter violet
  static const Color accentDark = Color(0xFF5B3FD9);    // Deeper violet

  // Monochrome Primary Brand Colors
  static const Color primary = Color(0xFFFFFFFF);       // Pure White (text/icons)
  static const Color primaryLight = Color(0xFFF4F4F5);
  static const Color primaryDark = Color(0xFFA1A1AA);

  // ── Dark Theme — AMOLED Glassmorphism Base ──
  static const Color bgDark = Color(0xFF000000);           // Pure OLED/AMOLED Black
  static const Color surfaceDark = Color(0xFF0D0D12);      // Deep translucent glass surface
  static const Color cardDark = Color(0xFF121218);         // Translucent dark card surface
  static const Color borderDark = Color(0x2EFFFFFF);       // Crisp frosted glass border
  static const Color glassBorderDark = Color(0x33FFFFFF);  // Apple Music glass outline

  // ── Glassmorphism & Depth Shadow Colors (Dark Mode) ──
  static const Color neumorphLightDark = Color(0x24FFFFFF);  // Specular top highlight
  static const Color neumorphShadowDark = Color(0x99000000); // Deep AMOLED shadow

  // ── Light Theme — Base ──
  static const Color bgLight = Color(0xFFF6F6F9);          // Clean iOS light
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0x18000000);
  static const Color glassBorderLight = Color(0x22000000);

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
  static const Color manga = Color(0xFFE4E4E7);
  static const Color anime = Color(0xFFFFFFFF);
  static const Color novel = Color(0xFFA1A1AA);

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFA1A1AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient monoGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFF71717A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
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
              ? const Color(0xFFFA2D48).withValues(alpha: 0.30)
              : (isPressed
                  ? const Color(0xFF1E1E28).withValues(alpha: (alpha * 1.3).clamp(0.0, 0.95))
                  : const Color(0xFF14141E).withValues(alpha: alpha)));
      final borderColor = isSelected
          ? const Color(0xFFFA2D48).withValues(alpha: 0.65)
          : Colors.white.withValues(alpha: isPressed ? 0.32 : (0.14 + (alpha * 0.12)));

      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: isSelected ? 1.2 : 0.85),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFA2D48).withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.40),
            blurRadius: isPressed ? 6 : (12 + (blur * 0.25)),
            offset: Offset(0, isPressed ? 2 : 4),
          ),
          if (isSelected)
            BoxShadow(
              color: const Color(0xFFFA2D48).withValues(alpha: 0.20),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      );
    } else {
      final baseColor = customTint ??
          (isSelected
              ? const Color(0xFFFA2D48).withValues(alpha: 0.18)
              : (isPressed ? Colors.grey.shade200 : Colors.white.withValues(alpha: alpha)));
      final borderColor = isSelected
          ? const Color(0xFFFA2D48).withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.08);

      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: isSelected ? 1.2 : 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: isPressed ? 4 : (8 + (blur * 0.2)),
            offset: Offset(0, isPressed ? 1 : 3),
          ),
        ],
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
