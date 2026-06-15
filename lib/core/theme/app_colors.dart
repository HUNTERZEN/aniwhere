import 'package:flutter/material.dart';

/// Core color palette for Aniwhere
/// Glass-first design with Deep Purple accent
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF7C3AED); // Deep Purple
  static const Color primaryLight = Color(0xFF9F67FF);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Accent Colors
  static const Color accent = Color(0xFFE879F9); // Light purple accent
  static const Color accentLight = Color(0xFFF0ABFC);
  static const Color accentDark = Color(0xFFC026D3);

  // Dark Theme Colors — softer dark, not pitch black
  static const Color bgDark = Color(0xFF0F0F16);       // Rich, deep midnight slate
  static const Color surfaceDark = Color(0xFF161622);   // Dark surface with blue/violet tint
  static const Color cardDark = Color(0xFF1E1E2F);      // Slightly lighter card surface
  static const Color borderDark = Color(0xFF2A2A40);    // Subtle glass border
  static const Color glassBorderDark = Color(0x1BFFFFFF); // White 11% for glass borders

  // Light Theme Colors
  static const Color bgLight = Color(0xFFF5F6FA);       // Soft warm off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color glassBorderLight = Color(0x12000000); // Black 7% for light glass borders

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0C0);
  static const Color textTertiaryDark = Color(0xFF606080);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Media Type Colors
  static const Color manga = Color(0xFFFF6B6B);
  static const Color anime = Color(0xFF4ECDC4);
  static const Color novel = Color(0xFFFFE66D);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
