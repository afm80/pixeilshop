import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF282828);
  static const panel = Color(0xFF252525);
  static const panel2 = Color(0xFF343434);
  static const accent = Color(0xFFF39B00);
  static const accent2 = Color(0xFFFFC400);
  static const text = Color(0xFFEDEDED);
  static const muted = Color(0xFF9A9A9A);
  static const danger = Color(0xFFFF5C6C);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.panel,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      elevation: 0,
      centerTitle: true,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      modalBackgroundColor: AppColors.panel,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
