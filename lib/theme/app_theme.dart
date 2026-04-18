import 'package:flutter/material.dart';

class C0Theme {
  // --- Muted Palette (Non-Neon) ---
  static const Color sageGreen = Color(0xFF789682);
  static const Color deepSage = Color(0xFF4F6355);
  static const Color oatmealWhite = Color(
    0xFFF5F5F0,
  ); // Anti-glare for high brightness
  static const Color charcoal = Color(0xFF1A1C1E); // Softer than pure black
  static const Color slateGrey = Color(0xFF708090);

  // Results Colors (Muted versions)
  static const Color successGreen = Color(0xFF8BB381);
  static const Color warningRed = Color(0xFFD67A7A);

  // --- Light Mode (Daylight) ---
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: deepSage,
    scaffoldBackgroundColor: oatmealWhite, // Prevents "flashlight" effect
    colorScheme: const ColorScheme.light(
      primary: deepSage,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: charcoal,
      error: warningRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: oatmealWhite,
      foregroundColor: charcoal,
      elevation: 0,
    ),
  );

  // --- Dark Mode (Nighttime) ---
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: sageGreen,
    scaffoldBackgroundColor: charcoal,
    colorScheme: const ColorScheme.dark(
      primary: sageGreen,
      onPrimary: charcoal,
      surface: Color(0xFF252729), // Slightly lighter charcoal for cards
      onSurface: Colors.white,
      error: warningRed,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: charcoal, elevation: 0),
  );
}
