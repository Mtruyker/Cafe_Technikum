import 'package:flutter/material.dart';

/// Единая шкала отступов: 4 · 8 · 12 · 16 · 24 · 32.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppColors {
  // Seed colors
  static const Color studentSeed = Color(0xFFCC5A0B);
  static const Color adminSeed = Color(0xFF274B3A);

  // Scaffold & backgrounds
  static const Color scaffoldBg = Color(0xFFF7F3EE);
  static const Color placeholderBg = Colors.black12;
  static const Color qrBackground = Colors.white;

  // Semantic colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFF8A5A00);
  static const Color info = Color(0xFF005EA8);
  static const Color neutral = Color(0xFF5F6368);
}

abstract final class AppTheme {
  static ThemeData student() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.studentSeed,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.scaffoldBg,
      ),
      textTheme: _buildTextTheme(),
    );
  }

  static ThemeData admin() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.adminSeed,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      textTheme: _buildTextTheme(),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    );
  }
}
