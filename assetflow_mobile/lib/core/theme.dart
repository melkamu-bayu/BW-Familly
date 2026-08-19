import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const navy = Color(0xFF0B2A66);
  static const blue = Color(0xFF0878E8);
  static const cyan = Color(0xFF18C9F4);
  static const green = Color(0xFF35C759);
  static const lime = Color(0xFF9BEA2F);
  static const purple = Color(0xFF7C4DFF);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFE94B5F);
  static const ink = Color(0xFF17213A);
  static const muted = Color(0xFF667085);
  static const background = Color(0xFFF7F9FC);
  static const surface = Colors.white;
  static const danger = Color(0xFFD92D20);

  // Backward-compatible aliases used by the existing feature screens.
  static const primary = blue;
  static const primaryDark = navy;
  static const accent = lime;

  static const profitColor = green;
  static const lossColor = danger;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: green,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        height: 72,
        indicatorColor: blue.withOpacity(.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? blue : muted,
          );
        }),
      ),
    );
  }
}
