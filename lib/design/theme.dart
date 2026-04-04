import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black, // fallback to prevent grey screen

      // ----- Color scheme -----
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emerald,
        secondary: AppColors.cyan,
        surface: AppColors.baseDark2,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),

      // ----- App bar -----
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ----- Bottom nav -----
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.emerald,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
      ),

      // ----- Input fields -----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.emerald),
        ),
        hintStyle: AppTextStyles.body.copyWith(
          color: AppColors.textQuaternary,
        ),
        labelStyle: AppTextStyles.caption,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),

      // ----- Elevated buttons -----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          textStyle: AppTextStyles.bodySemiBold,
        ),
      ),

      // ----- Text buttons -----
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emerald,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          textStyle: AppTextStyles.bodyMedium,
        ),
      ),

      // ----- Card theme -----
      cardTheme: const CardThemeData(
        color: AppColors.glassBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.xxl)),
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),

      // ----- Switch theme -----
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.emerald;
          return AppColors.textQuaternary;
        }),
      ),

      // ----- Text theme -----
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineLarge: AppTextStyles.h2,
        headlineMedium: AppTextStyles.h3,
        headlineSmall: AppTextStyles.bodySemiBold,
        titleLarge: AppTextStyles.h3,
        titleMedium: AppTextStyles.bodySemiBold,
        titleSmall: AppTextStyles.bodyMedium,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.bodyMedium,
        labelMedium: AppTextStyles.caption,
        labelSmall: AppTextStyles.label,
      ),
    );
  }
}
