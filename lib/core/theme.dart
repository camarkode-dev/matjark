import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF0D47A1);
  static const Color accent = Color(0xFFFFC107);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFF6F00);
  static const Color info = Color(0xFF0288D1);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFEEEEEE);

  static const double spacing2 = 2.0, spacing4 = 4.0, spacing8 = 8.0, spacing12 = 12.0, spacing16 = 16.0, spacing20 = 20.0, spacing24 = 24.0, spacing32 = 32.0;
  static const double radiusSmall = 8.0, radiusInput = 12.0, radiusButton = 12.0, radiusMedium = 12.0, radiusCard = 16.0, radiusLarge = 20.0;
  static const double elevationSmall = 2.0, elevationMedium = 4.0, elevationLarge = 8.0;

  static List<BoxShadow> get shadowSmall => [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))];
  static List<BoxShadow> get shadowMedium => [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))];
  static List<BoxShadow> get shadowLarge => [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8))];

  static const Duration animationFast = Duration(milliseconds: 200), animationNormal = Duration(milliseconds: 250), animationSlow = Duration(milliseconds: 350);

  static final RoundedRectangleBorder _cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard));

  static const TextStyle _darkDisplayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkDisplayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkDisplaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkHeadlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkHeadlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _darkHeadlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _darkTitleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _darkTitleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _darkTitleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _darkBodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkBodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _darkBodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary);
  static const TextStyle _darkLabelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _darkLabelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _darkLabelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary);

  static const TextStyle _lightDisplayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightDisplayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightDisplaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightHeadlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightHeadlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _lightHeadlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _lightTitleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _lightTitleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle _lightTitleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _lightBodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightBodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary);
  static const TextStyle _lightBodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary);
  static const TextStyle _lightLabelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _lightLabelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle _lightLabelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF1E1E1E), elevation: elevationSmall, centerTitle: true, titleTextStyle: _darkTitleLarge, iconTheme: const IconThemeData(color: Colors.white)),
    cardTheme: CardThemeData(color: const Color(0xFF1E1E1E), elevation: elevationSmall, shape: _cardShape),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      contentPadding: const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: divider, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: divider, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color:primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: error, width: 1)),
      hintStyle: _darkBodyMedium.copyWith(color: textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)), textStyle: _darkBodyLarge.copyWith(fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: primary, side: const BorderSide(color: primary, width: 1), padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)), textStyle: _darkBodyLarge.copyWith(fontWeight: FontWeight.w500))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary, padding: const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing8), textStyle: _darkBodyLarge.copyWith(fontWeight: FontWeight.w500))),
    textTheme: TextTheme(displayLarge: _darkDisplayLarge, displayMedium: _darkDisplayMedium, displaySmall: _darkDisplaySmall, headlineLarge: _darkHeadlineLarge, headlineMedium: _darkHeadlineMedium, headlineSmall: _darkHeadlineSmall, titleLarge: _darkTitleLarge, titleMedium: _darkTitleMedium, titleSmall: _darkTitleSmall, bodyLarge: _darkBodyLarge, bodyMedium: _darkBodyMedium, bodySmall: _darkBodySmall, labelLarge: _darkLabelLarge, labelMedium: _darkLabelMedium, labelSmall: _darkLabelSmall),
    colorScheme: ColorScheme.dark(primary: primary, secondary: secondary, tertiary: accent, surface: const Color(0xFF1E1E1E), error: error),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(backgroundColor: surface, elevation: elevationSmall, centerTitle: true, titleTextStyle: _lightTitleLarge, iconTheme: const IconThemeData(color: textPrimary)),
    cardTheme: CardThemeData(color: surface, elevation: elevationSmall, shape: _cardShape),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: borderLight, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: borderLight, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusInput), borderSide: const BorderSide(color: error, width: 1)),
      hintStyle: _lightBodyMedium.copyWith(color: textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)), textStyle: _lightBodyLarge.copyWith(fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: primary, side: const BorderSide(color: primary, width: 1), padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)), textStyle: _lightBodyLarge.copyWith(fontWeight: FontWeight.w500))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary, padding: const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing8), textStyle: _lightBodyLarge.copyWith(fontWeight: FontWeight.w500))),
    textTheme: TextTheme(displayLarge: _lightDisplayLarge, displayMedium: _lightDisplayMedium, displaySmall: _lightDisplaySmall, headlineLarge: _lightHeadlineLarge, headlineMedium: _lightHeadlineMedium, headlineSmall: _lightHeadlineSmall, titleLarge: _lightTitleLarge, titleMedium: _lightTitleMedium, titleSmall: _lightTitleSmall, bodyLarge: _lightBodyLarge, bodyMedium: _lightBodyMedium, bodySmall: _lightBodySmall, labelLarge: _lightLabelLarge, labelMedium: _lightLabelMedium, labelSmall: _lightLabelSmall),
    colorScheme: ColorScheme.light(primary: primary, secondary: secondary, tertiary: accent, surface: surface, error: error),
  );
}
