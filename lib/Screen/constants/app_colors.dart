// lib/Screen/constants/app_colors.dart - PREMIUM ELEGANT SCHEME
import 'package:flutter/material.dart';

class AppColors {
  // ✅ PREMIUM ELEGANT COLOR SCHEME (Given Colors)
  static const Color shadowGrey = Color(0xFF1A1423);    // Dark elegant grey
  static const Color vintageGrape = Color(0xFF3D314A);  // Deep purple
  static const Color mauveShadow = Color(0xFF684756);   // Mauve purple
  static const Color fadedCopper = Color(0xFF96705B);   // Warm copper
  static const Color dustyTaupe = Color(0xFFAB8476);    // Soft taupe

  // ✅ ASSIGNING TO ROLES (Smart grouping)
  static const Color primary = vintageGrape;    // Main brand color
  static const Color secondary = mauveShadow;   // Secondary color
  static const Color accent = fadedCopper;      // Accent/warm color
  static const Color action = dustyTaupe;       // Action/button color
  static const Color darkBackground = shadowGrey; // Dark mode background

  // ✅ COMPATIBILITY ALIASES
  static const Color primaryColor = primary;
  static const Color secondaryColor = secondary;
  static const Color darkPurple = vintageGrape; // For existing code

  // ✅ LIGHT THEME COLORS (Based on given palette)
  static const Color lightBackground = Color(0xFFFAF7F5); // Off-white with warm tint
  static const Color lightSurface = Color(0xFFFFFFFF);    // Pure white
  static const Color lightCard = Color(0xFFF5F1EE);       // Warm light grey

  // ✅ DARK THEME COLORS
  static const Color darkSurface = Color(0xFF251E2C);     // Lighter than shadowGrey
  static const Color darkSurfaceLight = Color(0xFF322A3A); // Medium dark
  static const Color cardBackground = Color(0xFF2D2536);  // Card background

  // ✅ TEXT COLORS
  static const Color textPrimary = Color(0xFF2D2536);     // Dark text
  static const Color textSecondary = Color(0xFF5A4D5D);   // Medium text
  static const Color textLight = Color(0xFFAB9BAB);       // Light text
  static const Color textOnDark = Color(0xFFE6DFE6);      // Text on dark backgrounds

  // ✅ SEMANTIC COLORS (Matching the palette)
  static const Color success = Color(0xFF7A9E7E);         // Muted green
  static const Color error = Color(0xFFC46D6D);           // Muted red
  static const Color warning = Color(0xFFD4A96A);         // Muted orange
  static const Color info = Color(0xFF6D8EC4);            // Muted blue

  // ✅ GRADIENTS (Using given colors beautifully)
  static const Gradient primaryGradient = LinearGradient(
    colors: [shadowGrey, vintageGrape, mauveShadow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient warmGradient = LinearGradient(
    colors: [fadedCopper, dustyTaupe],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient darkGradient = LinearGradient(
    colors: [shadowGrey, Color(0xFF251E2C), Color(0xFF322A3A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient lightGradient = LinearGradient(
    colors: [Color(0xFFFAF7F5), Color(0xFFF5F1EE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}