import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF0F5132); // deep financial-green, evokes "money/growth" without being garish
  static const primaryDark = Color(0xFF0A3622);
  static const accent = Color(0xFFC9A227); // muted gold, nods to the Gold-Mining Project without being literal
  static const danger = Color(0xFFB3261E);
  static const surface = Color(0xFFF7F8FA);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: primary, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(52), // large touch-friendly controls (Section 25)
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    );
  }

  static const profitColor = Color(0xFF0F5132);
  static const lossColor = danger;
}
