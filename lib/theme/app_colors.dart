import 'package:flutter/material.dart';
import 'package:spiewnik/model/playlist_model.dart';

/// Colors from docs/DESIGN-SYSTEM.md that have no role of their own in Material.
///
/// Views get them through `Theme.of(context).extension<AppColors>()!` or, shorter,
/// through [AppColorsContext.appColors]. Views must not use color literals
/// or check the theme brightness (rule 4 from section 7 of the document).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Saffron: drop cap, uppercase labels, repeat marks, active tab.
  final Color accent;

  /// Text and icons on top of [accent].
  final Color onAccent;

  /// Destructive action (deleting).
  final Color destructive;

  /// Heart of a favorite song.
  final Color favorite;

  /// Hairline 1 dp.
  final Color line;

  /// Dotted leader line in a list row.
  final Color indexDots;

  /// Row background in response to a tap.
  final Color pressedSurface;

  /// Secondary text: song number, descriptions.
  final Color textSecondary;

  /// Tertiary text: inactive tab.
  final Color textTertiary;

  /// Colors of song lists, in the order of [PlaylistColor]; only for a list's icon and the color picker.
  /// At least 4.5:1 against the background, the surface and surface +2.
  final List<Color> playlistColors;

  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.destructive,
    required this.favorite,
    required this.line,
    required this.indexDots,
    required this.pressedSurface,
    required this.textSecondary,
    required this.textTertiary,
    required this.playlistColors,
  });

  Color playlistColor(PlaylistColor color) => playlistColors[color.index];

  /// Dark theme, against the #191A1D background.
  static const AppColors dark = AppColors(
    accent: Color(0xFFE2B872),
    onAccent: Color(0xFF191A1D),
    destructive: Color(0xFFF29186),
    favorite: Color(0xFFE39AAF),
    line: Color(0xFF2E3138),
    indexDots: Color(0xFF45494F),
    pressedSurface: Color(0xFF212328),
    textSecondary: Color(0xFFA8A29B),
    textTertiary: Color(0xFF938F87),
    // saffron, rose, sage, sky, lilac, clay
    playlistColors: [
      Color(0xFFE2B872),
      Color(0xFFE39AAF),
      Color(0xFFA9C79A),
      Color(0xFF9FBCE8),
      Color(0xFFC3AEE6),
      Color(0xFFE6A57E),
    ],
  );

  /// Light theme, against the #F7F4EE background.
  static const AppColors light = AppColors(
    accent: Color(0xFF7A5518),
    onAccent: Color(0xFFFFFDF8),
    destructive: Color(0xFFA3231B),
    favorite: Color(0xFF8C2F4F),
    line: Color(0xFFE2DCD1),
    indexDots: Color(0xFFC9C2B5),
    pressedSurface: Color(0xFFEFEAE0),
    textSecondary: Color(0xFF5C5852),
    textTertiary: Color(0xFF6E6A62),
    // saffron, rose, sage, sky, lilac, clay
    playlistColors: [
      Color(0xFF7A5518),
      Color(0xFF8C2F4F),
      Color(0xFF3F6630),
      Color(0xFF2D5B94),
      Color(0xFF66479A),
      Color(0xFF9A4520),
    ],
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? destructive,
    Color? favorite,
    Color? line,
    Color? indexDots,
    Color? pressedSurface,
    Color? textSecondary,
    Color? textTertiary,
    List<Color>? playlistColors,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      destructive: destructive ?? this.destructive,
      favorite: favorite ?? this.favorite,
      line: line ?? this.line,
      indexDots: indexDots ?? this.indexDots,
      pressedSurface: pressedSurface ?? this.pressedSurface,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      playlistColors: playlistColors ?? this.playlistColors,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      line: Color.lerp(line, other.line, t)!,
      indexDots: Color.lerp(indexDots, other.indexDots, t)!,
      pressedSurface: Color.lerp(pressedSurface, other.pressedSurface, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      playlistColors: [
        for (var i = 0; i < playlistColors.length; i++) Color.lerp(playlistColors[i], other.playlistColors[i], t)!,
      ],
    );
  }
}

extension AppColorsContext on BuildContext {
  /// Shortcut to the colors outside ColorScheme.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
