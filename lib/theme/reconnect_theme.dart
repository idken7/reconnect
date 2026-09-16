import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the "Reconnect Redesign" look: a warm, single visual
/// language shared by iOS and Android alike (no more platform-specific
/// Cupertino/Material split — see `adaptive_scaffold.dart`).
class ReconnectColors {
  ReconnectColors._();

  static const background = Color(0xFFEFE9E1);
  static const surface = Color(0xFFFAF6F1);
  static const ink = Color(0xFF2B2622);
  static const accent = Color(0xFFD9683F);
  static const mutedText = Color(0xFFA99B8C);
  static const mutedTextStrong = Color(0xFFB9AC9C);
  static const hairline = Color(0xFFECE1D3);
  static const hairlineSoft = Color(0xFFF1ECE3);
  static const chipBackground = Color(0xFFF4EDE3);
  static const chipForeground = Color(0xFF8A7C6B);
}

/// One color trio per [ReconnectPreference] tier, used by the Contacts
/// drag-and-drop lanes, the spin wheel slices, and anywhere else a tier
/// needs to read visually. The mockup only shows 4 tiers (love/like/neutral/
/// avoid); "dislike" is a 5th tier this app's data model already has, styled
/// to sit naturally between neutral and avoid.
class TierStyle {
  const TierStyle({required this.color, required this.background, required this.border});

  final Color color;
  final Color background;
  final Color border;
}

const tierStyleLove = TierStyle(
  color: Color(0xFFD9683F),
  background: Color(0xFFFFF5EE),
  border: Color(0xFFF1D9C6),
);
const tierStyleLike = TierStyle(
  color: Color(0xFFC99A4A),
  background: Color(0xFFFDF7EC),
  border: Color(0xFFF0E3C6),
);
const tierStyleNeutral = TierStyle(
  color: Color(0xFF9C9488),
  background: Color(0xFFF6F4F1),
  border: Color(0xFFE6E1D8),
);
const tierStyleDislike = TierStyle(
  color: Color(0xFFA5768A),
  background: Color(0xFFF9F1F5),
  border: Color(0xFFECDCE4),
);
const tierStyleAvoid = TierStyle(
  color: Color(0xFF8A6A80),
  background: Color(0xFFF8F1F5),
  border: Color(0xFFE9D9E3),
);

/// Builds the single [ThemeData] used on every platform. Material3, seeded
/// with [ReconnectColors.accent], with Quicksand for display/headline/title
/// text (the mockup's 'Quicksand' font) and Nunito everywhere else (the
/// mockup's 'Nunito' font, the base `font-family` on `body`).
ThemeData buildReconnectTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ReconnectColors.accent,
      primary: ReconnectColors.accent,
      surface: ReconnectColors.surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: ReconnectColors.background,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );

  final nunito = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: ReconnectColors.ink,
    displayColor: ReconnectColors.ink,
  );
  final quicksand = GoogleFonts.quicksandTextTheme(base.textTheme);

  final textTheme = nunito.copyWith(
    displayLarge: quicksand.displayLarge?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    displayMedium: quicksand.displayMedium?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    displaySmall: quicksand.displaySmall?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    headlineLarge: quicksand.headlineLarge?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    headlineMedium: quicksand.headlineMedium?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    headlineSmall: quicksand.headlineSmall?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    titleLarge: quicksand.titleLarge?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    titleMedium: quicksand.titleMedium?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    titleSmall: quicksand.titleSmall?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: ReconnectColors.background,
      foregroundColor: ReconnectColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: quicksand.titleLarge?.copyWith(color: ReconnectColors.ink, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ReconnectColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ReconnectColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ReconnectColors.mutedText.withValues(alpha: 0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: quicksand.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ReconnectColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ReconnectColors.mutedText.withValues(alpha: 0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: quicksand.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ReconnectColors.ink,
        side: const BorderSide(color: ReconnectColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: quicksand.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ReconnectColors.accent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ReconnectColors.chipBackground,
      selectedColor: ReconnectColors.accent.withValues(alpha: 0.18),
      labelStyle: const TextStyle(color: ReconnectColors.chipForeground, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(color: ReconnectColors.hairline, space: 1),
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: ReconnectColors.ink,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: ReconnectColors.chipForeground,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: ReconnectColors.accent,
      inactiveTrackColor: ReconnectColors.hairline,
      thumbColor: ReconnectColors.accent,
      overlayColor: ReconnectColors.accent.withValues(alpha: 0.15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ReconnectColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ReconnectColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ReconnectColors.accent, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ReconnectColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ReconnectColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ReconnectColors.surface,
      indicatorColor: ReconnectColors.accent.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
