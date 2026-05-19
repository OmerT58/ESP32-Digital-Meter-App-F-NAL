/// app_theme.dart — Soft UI design system with full Light + Dark support
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();
  // ── Soft card surfaces ─────────────────────────────────────
  static const Color cardBg       = Color(0xEEFFFFFF);
  static const Color cardWarm     = Color(0xEDFAF7F2);
  static const Color sheetBg      = Color(0xF8FEFEFE);
  static const Color background   = Color(0xFF0F1117);

  // ── Dark-mode surfaces ─────────────────────────────────────
  static const Color darkSurface  = Color(0xFF161821);
  static const Color darkSheet    = Color(0xFF0F1117);
  static const Color darkCard     = Color(0xFF1C1E2A);

  // ── Status ─────────────────────────────────────────────────
  static const Color connected    = Color(0xFF34C759);
  static const Color offline      = Color(0xFFFF3B30);
  static const Color scanning     = Color(0xFF007AFF);

  // ── Accents ────────────────────────────────────────────────
  static const Color accent       = Color(0xFF007AFF);
  static const Color accentWarm   = Color(0xFFE07A5F);
  static const Color accentGreen  = Color(0xFF30D158);

  // ── Laser presets (overridden via SettingsProvider) ────────
  static const Color laserRed     = Color(0xFFFF3B30);
  static const Color laserGreen   = Color(0xFF30D158);
  static const Color laserBlue    = Color(0xFF007AFF);
  static const Color laserYellow  = Color(0xFFFFCC00);

  // ── Text (light mode) ──────────────────────────────────────
  static const Color textPrimary  = Color(0xFF1C1C1E);
  static const Color textSecondary= Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFC7C7CC);

  // ── Text (dark mode) ───────────────────────────────────────
  static const Color darkTextPrimary   = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF98989D);
  static const Color darkTextTertiary  = Color(0xFF636366);

  // ── Shadows ────────────────────────────────────────────────
  static const Color shadow       = Color(0x14000000);
  static const Color shadowStrong = Color(0x28000000);

  // ── Legacy aliases (used in existing painters) ─────────────
  static const Color neonRed      = laserRed;
  static const Color neonGreen    = laserGreen;
  static const Color neonCyan     = Color(0xFF32ADE6);
  static const Color neonRedDim   = Color(0x66FF3B30);
  static const Color neonRedGlow  = Color(0x22FF3B30);
  static const Color neonGreenDim = Color(0x6630D158);
  static const Color neonGreenGlow= Color(0x2230D158);
  static const Color glassWhite   = Color(0x0AFFFFFF);
  static const Color glassBorder  = Color(0x22FFFFFF);
  static const Color divider      = Color(0x1A000000);
  static const Color surfaceCard  = Color(0xFFFFFFFF);
  static const Color surface      = Color(0xFFF5F5F5);
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle inter({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size, fontWeight: weight,
        color: color, letterSpacing: letterSpacing,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    colorScheme: const ColorScheme.light(
      surface: AppColors.cardBg,
      primary: AppColors.accent,
      secondary: AppColors.accentWarm,
      tertiary: AppColors.accentGreen,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme()
        .apply(bodyColor: AppColors.textPrimary,
               displayColor: AppColors.textPrimary),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkSheet,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.darkSurface,
      primary: AppColors.accent,
      secondary: AppColors.accentWarm,
      tertiary: AppColors.accentGreen,
      onPrimary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme()
        .apply(bodyColor: AppColors.darkTextPrimary,
               displayColor: AppColors.darkTextPrimary),
  );
}

// ── Soft card decoration helper ─────────────────────────────────
BoxDecoration softCard({
  Color color = AppColors.cardWarm,
  double radius = 20,
  bool warm = true,
  bool dark = false,
}) =>
    BoxDecoration(
      color: dark
          ? AppColors.darkCard
          : (warm ? AppColors.cardWarm : AppColors.cardBg),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: dark ? Colors.black26 : AppColors.shadow,
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(
        color: dark
            ? const Color(0x22FFFFFF)
            : const Color(0x10000000),
        width: 0.5,
      ),
    );
