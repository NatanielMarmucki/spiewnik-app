import 'package:flutter/material.dart';

/// Font families from assets (see pubspec.yaml and tools/build_fonts.py).
class AppFonts {
  /// Newsreader: song text, titles, numbers.
  static const String serif = 'Newsreader';

  /// Schibsted Grotesk: interface, labels, buttons, navigation.
  static const String ui = 'SchibstedGrotesk';

  /// IBM Plex Mono: song numbers in song lists, e.g. „4 · 8 · 12”.
  static const String mono = 'IBMPlexMono';

  const AppFonts._();
}

/// Tabular figures: song numbers must stay aligned in a column.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// Interface scale from docs/DESIGN-SYSTEM.md, section 2, mapped to Material roles.
///
/// | role in the document | TextTheme slot |
/// |---|---|
/// | screen title 20 / 1.05 Newsreader | titleLarge |
/// | song title in the list 17 / 1.2 Newsreader | titleMedium |
/// | number in the list 15 / 1 Newsreader, tabular | titleSmall |
/// | dialog title 19 / 1.3 Grotesk 500 | headlineSmall |
/// | dialog body, sheet, empty state 15 / 1.5 Grotesk 400 | bodyMedium |
/// | text button 15 / 1.2 Grotesk 600 | labelLarge |
/// | tab label 10.5 / 1 Grotesk 500 | labelSmall |
/// | section uppercase label 8.5 + letter spacing 0.26 em Grotesk 500 | labelMedium |
TextTheme buildAppTextTheme(ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  return TextTheme(
    titleLarge: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 20.0,
      height: 1.05,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 17.0,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 15.0,
      height: 1.0,
      fontWeight: FontWeight.w400,
      fontFeatures: tabularFigures,
      color: onSurfaceVariant,
    ),
    headlineSmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 19.0,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 17.0,
      height: 1.62,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 15.0,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 13.0,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 15.0,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 8.5,
      height: 1.0,
      fontWeight: FontWeight.w500,
      letterSpacing: 8.5 * 0.26, // 0.26 em
      color: onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 10.5,
      height: 1.0,
      fontWeight: FontWeight.w500,
      color: onSurfaceVariant,
    ),
  );
}
