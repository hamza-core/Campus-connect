import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData student() => _build(AppColors.background, AppColors.surface);
  static ThemeData admin() =>
      _build(AdminColors.background, AdminColors.surface);

  static const _field = Color(0xFFEFEBE1);

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
    OutlineInputBorder border([Color? color, double width = 0]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shadowColor: AppColors.clayShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFCFC9B8), width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: border(const Color(0xFFCFC9B8), 1.5),
        enabledBorder: border(const Color(0xFFCFC9B8), 1.5),
        focusedBorder: border(AppColors.primary, 2),
        errorBorder: border(const Color(0xFFB91C1C), 1.5),
        focusedErrorBorder: border(const Color(0xFFB91C1C), 2),
        hintStyle: const TextStyle(color: AppColors.secondaryText),
        labelStyle: const TextStyle(color: AppColors.secondaryText),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        counterStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 12,
        ),
        helperStyle: const TextStyle(color: AppColors.secondaryText),
        errorStyle: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.secondaryText,
        suffixIconColor: AppColors.secondaryText,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: AppColors.primary,
          backgroundColor: surface,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: Color(0xFFCFC9B8), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFCFC9B8), width: 1.5),
        backgroundColor: surface,
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.background,
        showCheckmark: false,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          color: AppColors.background,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        shape: CircleBorder(),
        elevation: 6,
        iconSize: 30,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.background
                : AppColors.text,
          ),
        ),
      ),
    );
  }
}
