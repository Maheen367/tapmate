import 'package:flutter/material.dart';

class AppColors {
  // --- CUSTOM PALETTE ---
  static const Color dustyPink = Color(0xFFD4BFCD);   // Background
  static const Color wineRed = Color(0xFF5E0B15);     // Primary
  static const Color crimson = Color(0xFF90323D);     // Secondary
  static const Color darkPlum = Color(0xFF4A0628);    // Accent / strong text
  static const Color amber = Color(0xFFFAA613);       // Highlight / buttons
  static const Color navyBlack = Color(0xFF00171F);
  static const Color rosePink = Color(0xFFD4BFCD);
// Dark mode background

  // --- BRANDING ---
  static const Color primary = wineRed;
  static const Color secondary = crimson;
  static const Color accent = amber;

  // --- LIGHT MODE ---
  static const Color lightBg = dustyPink;
  static const Color lightSurface = Colors.white;
  static const Color textMain = darkPlum;

  // --- DARK MODE ---
  static const Color darkBg = navyBlack;
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color textOnDark = dustyPink;

  // --- EXTRA USAGE ---
  static const Color tagColor = amber;       // For tags / chips
  static const Color containerColor = wineRed; // For filled containers
  static const Color headingColor = crimson; // For headings
}
