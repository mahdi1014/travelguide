import 'package:flutter/material.dart';

// Brand palette
const kCol1 = Color(0xFF3E5F44); // dark
const kCol2 = Color(0xFF5E936C); // mid
const kCol3 = Color(0xFF93DA97); // accent
const kCol4 = Color(0xFFE8FFD7); // light bg

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: kCol2,
    onPrimary: Colors.white,
    secondary: kCol3,
    onSecondary: Colors.black,
    error: Colors.red.shade700,
    onError: Colors.white,
    background: kCol4,
    onBackground: kCol1,
    surface: Colors.white,
    onSurface: kCol1,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kCol4,
    appBarTheme: const AppBarTheme(
      backgroundColor: kCol1,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kCol2,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kCol2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kCol2, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}
