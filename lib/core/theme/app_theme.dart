import 'package:flutter/material.dart';

import '../design/app_backdrop.dart';

class AppColors {
  static const Color sky = Color(0xFFE8F4FD);
  static const Color teal = Color(0xFF2A9D8F);
  static const Color sun = Color(0xFFF4B942);
  static const Color rose = Color(0xFFE76F8B);
  static const Color leaf = Color(0xFF6BBF59);
  static const Color ink = Color(0xFF1E2833);
}

/// خطوط التطبيق: Lalezar للعناوين والكلمات الكبيرة، وTajawal للنص (تُنزَّل في CI؛ وإلا الخط الافتراضي).
class AppText {
  static const String bodyFont = 'Tajawal';
  static const String displayFont = 'Lalezar';

  /// نص عناوين بخط Lalezar (وزن واحد، لا نستخدم bold حتى لا يُزوَّر الخط).
  static TextStyle display(double size, {Color color = AppColors.ink}) => TextStyle(
        fontFamily: displayFont,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.15,
        color: color,
      );
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppText.bodyFont,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: BackdropPageTransitions(),
        TargetPlatform.iOS: BackdropPageTransitions(),
        TargetPlatform.linux: BackdropPageTransitions(),
        TargetPlatform.macOS: BackdropPageTransitions(),
        TargetPlatform.windows: BackdropPageTransitions(),
      }),
      // شفاف: خلفية التطبيق (AppBackdrop) تظهر خلف كل الشاشات.
      scaffoldBackgroundColor: Colors.transparent,
      // نص سميك وغامق دائمًا: الوزن الخفيف لـTajawal يبدو باهتًا على الموبايل.
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: AppText.displayFont,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: AppText.displayFont,
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: AppText.display(28),
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
