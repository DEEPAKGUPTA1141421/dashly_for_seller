import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class AppTheme {
  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double sp2  = 2;
  static const double sp4  = 4;
  static const double sp6  = 6;
  static const double sp8  = 8;
  static const double sp10 = 10;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp40 = 40;
  static const double sp48 = 48;

  // ── Border radii ─────────────────────────────────────────────────────────
  static const double r4  = 4;
  static const double r6  = 6;
  static const double r8  = 8;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  // ── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glowWhite => [
    BoxShadow(
      color: AppColors.white.withOpacity(0.15),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // ── Typography ───────────────────────────────────────────────────────────
  static const TextStyle displayLg = TextStyle(
    color: AppColors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1,
  );
  static const TextStyle displayMd = TextStyle(
    color: AppColors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5,
  );
  static const TextStyle headingLg = TextStyle(
    color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3,
  );
  static const TextStyle headingMd = TextStyle(
    color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700,
  );
  static const TextStyle headingSm = TextStyle(
    color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyLg = TextStyle(
    color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMd = TextStyle(
    color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w400,
  );
  static const TextStyle bodySm = TextStyle(
    color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w400,
  );
  static const TextStyle labelLg = TextStyle(
    color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500,
  );
  static const TextStyle labelMd = TextStyle(
    color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3,
  );
  static const TextStyle mono = TextStyle(
    color: AppColors.white, fontSize: 13, fontFamily: 'monospace',
  );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.white,
      onPrimary: AppColors.bg,
      error: AppColors.error,
      onError: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.white),
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 0,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: AppColors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: labelLg,
      labelStyle: labelLg,
      contentPadding: const EdgeInsets.symmetric(horizontal: sp16, vertical: sp14),
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.white,
      unselectedItemColor: AppColors.grey,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.white,
      labelStyle: bodySm.copyWith(color: AppColors.white),
      padding: const EdgeInsets.symmetric(horizontal: sp8, vertical: sp4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: bodyMd,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r12)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? AppColors.bg : AppColors.grey),
      trackColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? AppColors.white : AppColors.surface3),
    ),
  );

  // convenience — used inside inputDecorationTheme where const is required
  static const double sp14 = 14;
}
