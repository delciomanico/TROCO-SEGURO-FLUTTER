import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark theme using dark background and gold accents
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryGold,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGold,
        secondary: AppColors.secondaryGold,
        surface: AppColors.darkCard,
        onPrimary: AppColors.textDark,
        onSurface: AppColors.textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primaryGold)),
      iconTheme: const IconThemeData(color: AppColors.primaryGold),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: AppColors.darkBackground, indicatorColor: AppColors.primaryGold),
      textTheme: GoogleFonts.sairaTextTheme(
        TextTheme(
          displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textLight, letterSpacing: -0.5),
          displayMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textLight, letterSpacing: -0.3),
          bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textLight),
          bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textLight),
          bodySmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textLight.withValues(alpha: 0.85), letterSpacing: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
