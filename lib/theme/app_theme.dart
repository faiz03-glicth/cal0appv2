import 'package:flutter/material.dart';

class C0Theme {
  static const Color sageGreen = Color(0xFF789682);
  static const Color deepSage = Color(0xFF4F6355);
  static const Color mintyFresh = Color(0xFFB2D8C1);
  static const Color warmerGrey = Color(0xFFECEDE8);
  static const Color oatmealWhite = Color(0xFFF5F5F0);
  static const Color softBeige = Color(0xFFF0EDE5);
  static const Color charcoal = Color(0xFF1A1C1E);
  static const Color lightCharcoal = Color(0xFF252729);
  static const Color slateGrey = Color(0xFF708090);
  static const Color lightWarmGrey = Color(0xFFF8F8F5);
  static const Color lightSlateGrey = Color(0xFFB0C4DE);
  static const Color successGreen = Color(0xFF8BB381);
  static const Color warningRed = Color(0xFFD67A7A);

  static C0Colors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return C0Colors(isDark: isDark);
  }

  // --- Light Mode ---
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: deepSage,
    scaffoldBackgroundColor: slateGrey,
    colorScheme: const ColorScheme.light(
      primary: deepSage,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: charcoal,
      error: warningRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deepSage,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: deepSage,
      selectedItemColor: charcoal,
      unselectedItemColor: warmerGrey,
      elevation: 8,
    ),
  );

  // --- Dark Mode ---
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: sageGreen,
    scaffoldBackgroundColor: charcoal,
    colorScheme: const ColorScheme.dark(
      primary: sageGreen,
      onPrimary: charcoal,
      surface: lightCharcoal,
      onSurface: warmerGrey,
      error: warningRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightCharcoal,
      foregroundColor: warmerGrey,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightCharcoal,
      selectedItemColor: sageGreen,
      unselectedItemColor: slateGrey,
      elevation: 8,
    ),
  );
}

class C0Colors {
  final bool isDark;
  const C0Colors({required this.isDark});

  Color get primary => isDark ? C0Theme.sageGreen : C0Theme.deepSage;
  Color get background => isDark ? C0Theme.charcoal : C0Theme.warmerGrey;
  Color get card => isDark ? C0Theme.lightCharcoal : C0Theme.softBeige;
  Color get textPrimary => isDark ? Colors.white : C0Theme.charcoal;
  Color get textSecondary => isDark ? Colors.white70 : C0Theme.slateGrey;
  Color get header => isDark ? const Color(0xFF2A2C2E) : C0Theme.deepSage;
  Color get headerText => C0Theme.oatmealWhite;
  Color get icon => isDark ? C0Theme.sageGreen : C0Theme.deepSage;
  Color get track =>
      isDark ? Colors.white12 : C0Theme.sageGreen.withValues(alpha: 0.2);
  Color get divider => isDark ? Colors.white12 : C0Theme.lightWarmGrey;
  Color get success => C0Theme.successGreen;
  Color get warning => C0Theme.warningRed;
  Color get slate => C0Theme.slateGrey;
}
