import 'package:flutter/material.dart';

/// Thai-first, elderly-friendly theme: big type, high contrast, Sarabun.
class AppTheme {
  AppTheme._();

  static const Color sosRed = Color(0xFFD32F2F);
  static const Color sosRedDark = Color(0xFFB71C1C);
  static const Color okGreen = Color(0xFF2E7D32);
  static const Color surfaceDark = Color(0xFF1C1B1F);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sosRed,
        primary: sosRed,
      ),
      fontFamily: 'Sarabun',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Sarabun',
        bodyColor: const Color(0xFF212121),
        displayColor: const Color(0xFF212121),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      ),
    );
  }
}
