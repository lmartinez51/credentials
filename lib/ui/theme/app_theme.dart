import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundStart = Color(0xFF0F172A); // Slate 900
  static const Color backgroundEnd = Color(0xFF000000);   // Deep Black
  
  static const Color primaryAccent = Color(0xFF3B82F6);   // Blue
  static const Color secondaryAccent = Color(0xFF8B5CF6); // Purple
  static const Color successColor = Color(0xFF10B981);    // Emerald
  static const Color warningColor = Color(0xFFF59E0B);    // Amber
  static const Color errorColor = Color(0xFFEF4444);      // Red
  
  static const Color cardColor = Color(0x1AFFFFFF);       // Semi-transparent white for glass
  static const Color cardBorderColor = Color(0x33FFFFFF);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent, // Background handled by gradient
    primaryColor: primaryAccent,
    fontFamily: 'Inter', // Assuming standard modern sans-serif
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: primaryAccent.withValues(alpha: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: cardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: cardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryAccent, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    ),
  );
}
