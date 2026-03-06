import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6C98FF);
  static const Color secondary = Color(0xFF2A58BC);
  static const Color accent = Color(0xFF40D5C6);
  static const Color background = Color(0xFF090F1F);
  static const Color surface = Color(0xFF111A2E);
  static const Color surfaceSoft = Color(0xFF1A2440);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF31C48D);
  static const Color warning = Color(0xFFFFB020);
  static const Color info = Color(0xFF0288D1);
  static const Color textPrimary = Color(0xFFF5F8FF);
  static const Color textSecondary = Color(0xFFA6B4D3);
  static const Color textHint = Color(0xFF6F7FA5);
  static const Color divider = Color(0xFF24324F);
  static const Color borderLight = Color(0xFF2D3B5C);

  static const double spacing2 = 2.0,
      spacing4 = 4.0,
      spacing8 = 8.0,
      spacing12 = 12.0,
      spacing16 = 16.0,
      spacing20 = 20.0,
      spacing24 = 24.0,
      spacing32 = 32.0;
  static const double radiusSmall = 8.0,
      radiusInput = 12.0,
      radiusButton = 12.0,
      radiusMedium = 12.0,
      radiusCard = 16.0,
      radiusLarge = 20.0;
  static const double elevationSmall = 2.0,
      elevationMedium = 4.0,
      elevationLarge = 8.0;

  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static const Duration animationFast = Duration(milliseconds: 200),
      animationNormal = Duration(milliseconds: 250),
      animationSlow = Duration(milliseconds: 350);

  static final RoundedRectangleBorder _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusCard),
  );

  static const TextStyle _darkDisplayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkDisplayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkDisplaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkHeadlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkHeadlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  static const TextStyle _darkHeadlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  static const TextStyle _darkTitleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  static const TextStyle _darkTitleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  static const TextStyle _darkTitleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle _darkBodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkBodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle _darkBodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const TextStyle _darkLabelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle _darkLabelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle _darkLabelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildLightTheme();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffold(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color panel(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color panelSoft(BuildContext context) =>
      isDark(context) ? surfaceSoft : const Color(0xFFF0F3FA);

  static Color border(BuildContext context) =>
      isDark(context) ? borderLight : const Color(0xFFD3DBEA);

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? textSecondary : const Color(0xFF5F6C89);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _darkTitleLarge,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: elevationSmall,
        shape: _cardShape,
      ),
      dividerTheme: const DividerThemeData(color: divider),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: _darkBodyMedium.copyWith(color: textHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: textHint);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF041229),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: _darkBodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderLight),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing16,
            vertical: spacing8,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: _darkDisplayLarge,
        displayMedium: _darkDisplayMedium,
        displaySmall: _darkDisplaySmall,
        headlineLarge: _darkHeadlineLarge,
        headlineMedium: _darkHeadlineMedium,
        headlineSmall: _darkHeadlineSmall,
        titleLarge: _darkTitleLarge,
        titleMedium: _darkTitleMedium,
        titleSmall: _darkTitleSmall,
        bodyLarge: _darkBodyLarge,
        bodyMedium: _darkBodyMedium,
        bodySmall: _darkBodySmall,
        labelLarge: _darkLabelLarge,
        labelMedium: _darkLabelMedium,
        labelSmall: _darkLabelSmall,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: Color(0xFF041229),
        onSurface: textPrimary,
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    const lightBackground = Color(0xFFF7F8FC);
    const lightSurface = Colors.white;
    const lightSurfaceSoft = Color(0xFFF0F3FA);
    const lightTextPrimary = Color(0xFF182033);
    const lightTextSecondary = Color(0xFF5F6C89);
    const lightTextHint = Color(0xFF7E8AA6);
    const lightDivider = Color(0xFFD7DFEF);
    const lightBorder = Color(0xFFD3DBEA);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: elevationSmall,
        shape: _cardShape,
      ),
      dividerTheme: const DividerThemeData(color: lightDivider),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: const TextStyle(color: lightTextHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primary,
        unselectedItemColor: lightTextHint,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primary.withValues(alpha: 0.12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: lightTextPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: lightTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: lightTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: lightTextPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightTextPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightTextPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: lightTextSecondary,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
    );
  }
}
