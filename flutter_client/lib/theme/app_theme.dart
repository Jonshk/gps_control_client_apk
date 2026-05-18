import 'package:flutter/material.dart';

class AppTheme {
  static const Color red       = Color(0xFFE8232A);
  static const Color redHover  = Color(0xFFC91E24);
  static const Color teal      = Color(0xFF00D4A0);
  static const Color dark      = Color(0xFF0A1628);
  static const Color dark2     = Color(0xFF0F1F36);
  static const Color textLight = Color(0xFFF0F6FF);
  static const Color muted     = Color(0xFF5A6472);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: dark,
    colorScheme: const ColorScheme.dark(
      primary: red, secondary: teal,
      surface: dark2, onSurface: textLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: dark, foregroundColor: textLight,
      elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(
        color: textLight, fontSize: 17,
        fontWeight: FontWeight.w700, letterSpacing: -0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: dark2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: red, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
  );
}
