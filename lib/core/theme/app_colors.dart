import 'package:flutter/material.dart';

/// Core color palette for Aniwhere
/// Ultra-sleek Monochrome (Black & White) glassmorphism design
class AppColors {
  AppColors._();

  // Monochrome Primary Brand Colors (Pure White / Silver / Charcoal)
  static const Color primary = Color(0xFFFFFFFF); // Pure White
  static const Color primaryLight = Color(0xFFF4F4F5);
  static const Color primaryDark = Color(0xFFA1A1AA);

  // Accent Colors — Crisp Monochrome Slate
  static const Color accent = Color(0xFFE4E4E7);
  static const Color accentLight = Color(0xFFFFFFFF);
  static const Color accentDark = Color(0xFF71717A);

  // Dark Theme Colors — Pure OLED Black & Obsidian
  static const Color bgDark = Color(0xFF000000);         // True OLED Pitch Black
  static const Color surfaceDark = Color(0xFF0A0A0A);    // Deep Obsidian Surface
  static const Color cardDark = Color(0xFF141414);       // Sleek Monochrome Card
  static const Color borderDark = Color(0xFF222222);     // Subtle Mono Border
  static const Color glassBorderDark = Color(0x2EFFFFFF);// Crisp White 18% Glass Border

  // Light Theme Colors — Clean Minimalist Studio White
  static const Color bgLight = Color(0xFFF8F8F8);        // Clean Studio Off-White
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color glassBorderLight = Color(0x18000000);// 9% Black Glass Border

  // Text Colors - Dark Theme (High Contrast Monochrome)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textTertiaryDark = Color(0xFF71717A);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF0A0A0A);
  static const Color textSecondaryLight = Color(0xFF52525B);
  static const Color textTertiaryLight = Color(0xFF8E8E93);

  // Status Colors (Subtle, refined)
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFFFFFFFF);

  // Media Type Colors (Minimalist badges)
  static const Color manga = Color(0xFFE4E4E7);
  static const Color anime = Color(0xFFFFFFFF);
  static const Color novel = Color(0xFFA1A1AA);

  // Gradients
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
}
