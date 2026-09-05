import 'package:flutter/material.dart';

class DhakkerColors {
  static const bg = Color(0xFF0B0D10);
  static const card = Color(0xFF303030);
  static const gold = Color(0xFFD4AF37);
  static const gold2 = Color(0xFFB98B2E);
  static const muted = Color(0xFF9AA4B2);
  static const darkText = Color(0xFF14171C);

  static const lightBg = Color(0xFFF7F7F8);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF121316);
  static const lightMuted = Color(0xFF667085);
}

// انتقالات صفحات بإحساس iOS (انزلاق أفقي ناعم) على كل المنصّات.
const PageTransitionsTheme _kSmoothPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

ThemeData dhakkerDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DhakkerColors.bg,
    fontFamily: 'AlamirReg',
    pageTransitionsTheme: _kSmoothPageTransitions,
    colorScheme: const ColorScheme.dark(
      primary: DhakkerColors.gold,
      secondary: DhakkerColors.gold2,
      surface: DhakkerColors.card,
      onSurface: Colors.white,
      onPrimary: DhakkerColors.darkText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DhakkerColors.card,
      hintStyle: TextStyle(color: DhakkerColors.muted.withOpacity(.85)),
      labelStyle: TextStyle(color: DhakkerColors.muted.withOpacity(.9)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: DhakkerColors.gold.withOpacity(.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: DhakkerColors.gold.withOpacity(.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: DhakkerColors.gold.withOpacity(.55), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

ThemeData dhakkerLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: DhakkerColors.lightBg,
    fontFamily: 'AlamirReg',
    pageTransitionsTheme: _kSmoothPageTransitions,
    colorScheme: const ColorScheme.light(
      primary: DhakkerColors.gold2,
      secondary: DhakkerColors.gold,
      surface: DhakkerColors.lightCard,
      onSurface: DhakkerColors.lightText,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DhakkerColors.lightBg,
      foregroundColor: DhakkerColors.lightText,
      elevation: 0,
      centerTitle: true,
    ),
    dividerColor: const Color(0xFFE6E8EC),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DhakkerColors.lightCard,
      hintStyle: const TextStyle(color: DhakkerColors.lightMuted),
      labelStyle: const TextStyle(color: DhakkerColors.lightMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DhakkerColors.gold2, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}
