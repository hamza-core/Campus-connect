import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData student() => _build(AppColors.background, AppColors.surface);
  static ThemeData admin() =>
      _build(AdminColors.background, AdminColors.surface);

  static ThemeData _build(Color background, Color surface) {
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.background,
      surface: surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.secondaryText,
      outline: AppColors.border,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
    );
    return theme.copyWith(
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
