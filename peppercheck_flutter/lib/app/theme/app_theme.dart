import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentBlue,
        surface: AppColors.backgroundWhite,
        error: AppColors.textError,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundWhite,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.backgroundWhite,
        hourMinuteTextColor: AppColors.textPrimary,
        hourMinuteColor: AppColors.backgroundLight,
        dialHandColor: AppColors.accentBlueLight,
        dialBackgroundColor: AppColors.backgroundLight,
        dialTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.accentBlue,
        dayPeriodTextColor: AppColors.textPrimary,
        dayPeriodColor: AppColors.backgroundLight,
        helpTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.backgroundWhite,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.accentBlue,
        headerForegroundColor: Colors.white,
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return null;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.accentBlue;
        }),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
