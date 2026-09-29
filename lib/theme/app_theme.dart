import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: soft orange derived from the company brand color #E73E0C,
/// on warm neutrals.
class AppColors {
  static const background = Color(0xFFFFF8F4);
  static const foreground = Color(0xFF2B2522);
  static const card = Colors.white;

  /// Brand orange for accents: focus rings, selected borders, icons.
  static const primary = Color(0xFFF4782F);

  /// Non-text orange graphics that must stay >= 3:1 on white: progress bars,
  /// checked checkbox / radio indicators. Too light for white text (3.3:1).
  static const primaryDark = Color(0xFFE8661F);

  /// Orange text on white or [primarySoft] (badges, selected nav labels), and
  /// solid fills behind white text (buttons, FAB): 4.7:1, passes WCAG AA.
  static const primaryDeep = Color(0xFFC4501A);
  static const primarySoft = Color(0xFFFFEFE4);
  static const secondary = Color(0xFFF7F3F1);
  static const muted = Color(0xFFF1ECE9);
  static const mutedForeground = Color(0xFF6E625C);

  /// 已完成 / 已回覆.
  static const success = Color(0xFF1F7F60);
  static const successSoft = Color(0xFFEAF6F1);

  /// 待完成 / 未回覆: blue so it never reads as the brand orange.
  static const accent = Color(0xFF2A5DB8);
  static const accentSoft = Color(0xFFE8F0FC);
  static const destructive = Color(0xFFD32822);
  static const destructiveSoft = Color(0xFFFCEAEA);
  static const border = Color(0xFFEADFD9);
  static const input = Color(0xFFD6C8C0);
  static const sidebar = Color(0xFFFFFBF8);
  static const shellTint = Color(0xFFFFF1E8);
}

class AppGradients {
  /// Soft orange used by page headers and the login backdrop.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB27A), Color(0xFFF4782F)],
  );
}

class AppRadius {
  static const double base = 14;
  static const double sm = 10;
}

/// Getters (not static finals) so hot reload picks up style changes.
class AppText {
  /// The one font family used for all UI text ("Noto Sans TC").
  ///
  /// Every style must use this exact family. `GoogleFonts.notoSansTc(
  /// fontWeight: ...)` registers a *different* family per weight file, which
  /// makes labels render with visibly different glyphs from body text.
  static String get sans => GoogleFonts.notoSansTc().fontFamily!;

  /// Numbers only (progress, question numbers); has no Chinese glyphs.
  static TextStyle get mono => GoogleFonts.dmMono();

  /// Text typed into fields, and their hints.
  static const double inputSize = 13;

  /// Shared by every button type so their labels look identical.
  static TextStyle get button =>
      TextStyle(fontFamily: sans, fontSize: 12, fontWeight: FontWeight.w600);

  /// Small uppercase label, e.g. "OVERVIEW / 表單管理".
  static TextStyle get eyebrow => TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.primaryDeep,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: AppText.sans,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.foreground,
      error: AppColors.destructive,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: c, width: w),
  );

  final textTheme = base.textTheme.apply(
    fontFamily: AppText.sans,
    bodyColor: AppColors.foreground,
    displayColor: AppColors.foreground,
  );

  return base.copyWith(
    // bodyLarge is what TextField uses for typed text; keep it compact.
    textTheme: textTheme.copyWith(
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: AppText.inputSize),
    ),
    dividerColor: AppColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.secondary,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(
        color: AppColors.mutedForeground,
        fontSize: AppText.inputSize,
      ),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
      // Thicker than the resting border so an error never looks like a mere
      // hue shift of the orange focus ring.
      errorBorder: border(AppColors.destructive, 1.5),
      focusedErrorBorder: border(AppColors.destructive, 2),
      errorStyle: const TextStyle(color: AppColors.destructive, fontSize: 11),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryDeep,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.foreground,
        backgroundColor: AppColors.secondary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.foreground,
        textStyle: AppText.button,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.input,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primaryDark
            : Colors.transparent,
      ),
      side: const BorderSide(color: AppColors.input, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryDeep,
      foregroundColor: Colors.white,
      elevation: 3,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 36),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
      extendedIconLabelSpacing: 6,
      extendedTextStyle: AppText.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.foreground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );
}
