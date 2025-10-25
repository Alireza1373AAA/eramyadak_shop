import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandYellow = Color(0xFFFFD200);
  static const Color brandBlack = Color(0xFF121212);
  static const Color brandGray = Color(0xFFF4F5F7);

  static ThemeData theme() {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: brandYellow,
        onPrimary: Colors.black,
        secondary: brandBlack,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: brandBlack,
        centerTitle: false,
      ),

      // ✅ اصلاح شد: CardThemeData به جای CardTheme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brandGray,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
