import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: soft orange derived from the company brand color #E73E0C,
/// on warm neutrals. One set per brightness ([light] / [dark]); widgets read
/// the active one with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primaryFill,
    required this.primarySoft,
    required this.secondary,
    required this.muted,
    required this.mutedForeground,
    required this.success,
    required this.successSoft,
    required this.accent,
    required this.accentSoft,
    required this.destructive,
    required this.destructiveSoft,
    required this.border,
    required this.input,
    required this.sidebar,
    required this.tabTrack,
    required this.tabIndicator,
    required this.navIndicator,
    required this.brandGradient,
    required this.blobs,
  });

  final Color background;
  final Color foreground;
  final Color card;

  /// Brand orange for accents: focus rings, selected borders, icons.
  final Color primary;

  /// Non-text orange graphics that must stay >= 3:1 on [card]: progress bars,
  /// checked checkbox / radio indicators. Too light for white text.
  final Color primaryDark;

  /// Orange text on [card] or [primarySoft] (badges, selected nav labels):
  /// passes WCAG AA in both modes. Not for fills behind white text; use
  /// [primaryFill].
  final Color primaryDeep;

  /// Solid orange behind white text (buttons, FAB): 4.7:1. The same in both
  /// modes, since white text needs the dark orange even on a dark page.
  final Color primaryFill;
  final Color primarySoft;
  final Color secondary;
  final Color muted;
  final Color mutedForeground;

  /// 已完成 / 已回覆.
  final Color success;
  final Color successSoft;

  /// 待完成 / 未回覆: blue so it never reads as the brand orange.
  final Color accent;
  final Color accentSoft;
  final Color destructive;
  final Color destructiveSoft;
  final Color border;
  final Color input;
  final Color sidebar;

  /// [SegmentedTabs]: the groove and the sliding pill on it. The pill must be
  /// lighter than the groove in both modes, or the selection disappears.
  final Color tabTrack;
  final Color tabIndicator;

  /// Pill behind the selected item of the bottom navigation bar.
  final Color navIndicator;

  /// Soft orange used by page headers and the login backdrop; dimmer in dark
  /// mode so large orange areas don't glare.
  final LinearGradient brandGradient;

  /// The three soft color blobs floating behind the pages.
  final List<Color> blobs;

  static const light = AppColors(
    background: Color(0xFFFFF8F4),
    foreground: Color(0xFF2B2522),
    card: Colors.white,
    primary: Color(0xFFF4782F),
    primaryDark: Color(0xFFE8661F),
    primaryDeep: Color(0xFFC4501A),
    primaryFill: Color(0xFFC4501A),
    primarySoft: Color(0xFFFFEFE4),
    secondary: Color(0xFFF7F3F1),
    muted: Color(0xFFF1ECE9),
    mutedForeground: Color(0xFF6E625C),
    success: Color(0xFF1F7F60),
    successSoft: Color(0xFFEAF6F1),
    accent: Color(0xFF2A5DB8),
    accentSoft: Color(0xFFE8F0FC),
    destructive: Color(0xFFD32822),
    destructiveSoft: Color(0xFFFCEAEA),
    border: Color(0xFFEADFD9),
    input: Color(0xFFD6C8C0),
    sidebar: Color(0xFFFFFBF8),
    tabTrack: Color(0xFFF1ECE9),
    tabIndicator: Colors.white,
    navIndicator: Color(0xFFFFEFE4),
    brandGradient: AppGradients.brand,
    blobs: [Color(0xCCFFC9A3), Color(0xFFFFE0C2), Color(0xCCFFD6D0)],
  );

  /// Warm near-black neutrals so the orange still feels at home. Every text
  /// color keeps >= 4.5:1 on [card].
  static const dark = AppColors(
    background: Color(0xFF26201D),
    foreground: Color(0xFFF3ECE8),
    card: Color(0xFF302926),
    primary: Color(0xFFF4782F),
    primaryDark: Color(0xFFFF8A45),
    primaryDeep: Color(0xFFFF9A5C),
    primaryFill: Color(0xFFC4501A),
    primarySoft: Color(0xFF48301F),
    secondary: Color(0xFF362E2B),
    muted: Color(0xFF3A322E),
    mutedForeground: Color(0xFFA89A92),
    success: Color(0xFF4CC79A),
    successSoft: Color(0xFF1D3A31),
    accent: Color(0xFF7AA7F0),
    accentSoft: Color(0xFF22314A),
    destructive: Color(0xFFFF6B63),
    destructiveSoft: Color(0xFF47241F),
    border: Color(0xFF4A403B),
    input: Color(0xFF625550),
    sidebar: Color(0xFF2B2421),
    tabTrack: Color(0xFF2B2421),
    tabIndicator: Color(0xFF564C46),
    navIndicator: Color(0xFF5A3820),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD9622A), Color(0xFFA8441A)],
    ),
    blobs: [Color(0x33F4782F), Color(0x26C4501A), Color(0x26D32822)],
  );

  /// Falls back to [light] when the theme has no [AppColors], e.g. in tests
  /// that pump a bare MaterialApp.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: c(background, other.background),
      foreground: c(foreground, other.foreground),
      card: c(card, other.card),
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      primaryDeep: c(primaryDeep, other.primaryDeep),
      primaryFill: c(primaryFill, other.primaryFill),
      primarySoft: c(primarySoft, other.primarySoft),
      secondary: c(secondary, other.secondary),
      muted: c(muted, other.muted),
      mutedForeground: c(mutedForeground, other.mutedForeground),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      destructive: c(destructive, other.destructive),
      destructiveSoft: c(destructiveSoft, other.destructiveSoft),
      border: c(border, other.border),
      input: c(input, other.input),
      sidebar: c(sidebar, other.sidebar),
      tabTrack: c(tabTrack, other.tabTrack),
      tabIndicator: c(tabIndicator, other.tabIndicator),
      navIndicator: c(navIndicator, other.navIndicator),
      brandGradient: LinearGradient.lerp(
        brandGradient,
        other.brandGradient,
        t,
      )!,
      blobs: [
        for (var i = 0; i < blobs.length; i++) c(blobs[i], other.blobs[i]),
      ],
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The active [AppColors] (light or dark).
  AppColors get colors => AppColors.of(this);
}

class AppGradients {
  /// The light-mode brand gradient. Also the app icon's tile, which stays the
  /// same in dark mode; elsewhere use `context.colors.brandGradient`.
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
  static TextStyle eyebrow(AppColors colors) => TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: colors.primaryDeep,
  );
}

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppText.sans,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: c.primary,
      primary: c.primary,
      onPrimary: Colors.white,
      surface: c.card,
      onSurface: c.foreground,
      error: c.destructive,
    ),
    scaffoldBackgroundColor: c.background,
    extensions: [c],
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: c, width: w),
  );

  final textTheme = base.textTheme.apply(
    fontFamily: AppText.sans,
    bodyColor: c.foreground,
    displayColor: c.foreground,
  );

  return base.copyWith(
    // bodyLarge is what TextField uses for typed text; keep it compact.
    textTheme: textTheme.copyWith(
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: AppText.inputSize),
    ),
    dividerColor: c.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.secondary,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(
        color: c.mutedForeground,
        fontSize: AppText.inputSize,
      ),
      border: border(c.border),
      enabledBorder: border(c.border),
      focusedBorder: border(c.primary, 1.5),
      // Thicker than the resting border so an error never looks like a mere
      // hue shift of the orange focus ring.
      errorBorder: border(c.destructive, 1.5),
      focusedErrorBorder: border(c.destructive, 2),
      errorStyle: TextStyle(color: c.destructive, fontSize: 11),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primaryFill,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.primary.withValues(alpha: 0.45),
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
        foregroundColor: c.foreground,
        backgroundColor: c.secondary,
        side: BorderSide(color: c.border),
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
        foregroundColor: c.foreground,
        textStyle: AppText.button,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.input,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.primaryDark
            : Colors.transparent,
      ),
      side: BorderSide(color: c.input, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primaryFill,
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
    dialogTheme: DialogThemeData(backgroundColor: c.card),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.card),
    popupMenuTheme: PopupMenuThemeData(color: c.card),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.foreground,
      contentTextStyle: TextStyle(
        fontFamily: AppText.sans,
        color: c.background,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );
}
