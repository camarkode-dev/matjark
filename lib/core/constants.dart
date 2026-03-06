/// Centralized app constants for colors, strings, durations, etc.
library;

import 'theme.dart';

class AppColors {
  // Use the professional color system from AppTheme
  static const primary = AppTheme.primary;
  static const secondary = AppTheme.secondary;
  static const accent = AppTheme.accent;
  static const background = AppTheme.background;
  static const surface = AppTheme.surface;
  static const error = AppTheme.error;
  static const success = AppTheme.success;
  static const warning = AppTheme.warning;
  static const info = AppTheme.info;

  // Neutral
  static const textPrimary = AppTheme.textPrimary;
  static const textSecondary = AppTheme.textSecondary;
  static const textHint = AppTheme.textHint;
}

class AppStrings {
  static const appTitle = 'Matjark';
  static const adminEmail = String.fromEnvironment(
    'MATJARK_ADMIN_EMAIL',
    defaultValue: 'ca.matjark@gmail.com',
  );
}
