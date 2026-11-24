import 'package:flutter/material.dart';

class AppColors {
  // هوية براق
  static const Color navy = Color(0xFF0E1630);
  static const Color cream = Color(0xFFFBF3E4);
  static const Color gold = Color(0xFFDDAF68);
  static const Color terracotta = Color(0xFFCC6E4C);

  // ألوان الأقسام (تُراجَع في المرحلة 1 لتوحيدها مع الهوية)
  static const Color sky = Color(0xFFE8F4FD);
  static const Color teal = Color(0xFF2A9D8F);
  static const Color sun = Color(0xFFF4B942);
  static const Color rose = Color(0xFFE76F8B);
  static const Color leaf = Color(0xFF6BBF59);
  static const Color ink = navy;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      tertiary: AppColors.terracotta,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
