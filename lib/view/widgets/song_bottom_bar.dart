import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/widgets/go_to_number_icon.dart';

/// The bar below the song content from docs/DESIGN-SYSTEM.md, section 5: a left arrow with the
/// previous song's number, a magnifying glass with digits in the lens as the widest target in the
/// middle, and a right arrow with the next song's number. The current song's number is not here —
/// it sits in the top bar, next to the title.
///
/// The arrows **always stay in the same place**, also at the ends of the songbook: there they are
/// dimmed and inactive, so the bar does not jump. The height is a minimum, so it grows with the
/// system font.
class SongBottomBar extends StatelessWidget {
  /// Number of the previous song, or null when there is nowhere to go back to.
  final int? previousNumber;

  /// Number of the next song, or null.
  final int? nextNumber;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onGoToNumber;

  /// In a song list: the numbers are positions on the list, shown as „2/7”, and this is its length.
  final int? total;

  const SongBottomBar({
    super.key,
    required this.previousNumber,
    required this.nextNumber,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToNumber,
    this.total,
  });

  static const double minHeight = 48.0;
  static const double iconSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              _Arrow(
                icon: Icons.chevron_left,
                label: 'Poprzednia pieśń',
                number: previousNumber,
                total: total,
                onTap: onPrevious,
              ),
              Expanded(child: _GoToNumber(onTap: onGoToNumber)),
              _Arrow(
                icon: Icons.chevron_right,
                label: 'Następna pieśń',
                number: nextNumber,
                total: total,
                onTap: onNext,
                numberFirst: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? number;
  final int? total;
  final VoidCallback? onTap;
  final bool numberFirst;

  const _Arrow({
    required this.icon,
    required this.label,
    required this.number,
    this.total,
    required this.onTap,
    this.numberFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final enabled = number != null && onTap != null;
    // An inactive arrow has to stay visible (3:1), hence tertiary text instead of the line color,
    // which gave 1.24:1. That it is inactive shows from the missing number next to it.
    final color = enabled ? appColors.textSecondary : appColors.textTertiary;
    final numberText = Text(
      number == null ? '' : (total == null ? '$number' : '$number/$total'),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
    );
    final arrow = Icon(icon, size: SongBottomBar.iconSize, color: color);

    return Semantics(
      button: true,
      enabled: enabled,
      label: number == null ? label : (total == null ? '$label, numer $number' : '$label, $number z $total'),
      onTap: enabled ? onTap : null,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          // Touch target at least 56 x 48 dp, above the 40 x 48 dp minimum (section 6 of the document).
          constraints: const BoxConstraints(minWidth: 56.0, minHeight: SongBottomBar.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: numberFirst
                  ? [arrow, const SizedBox(width: 4.0), numberText]
                  : [numberText, const SizedBox(width: 4.0), arrow],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoToNumber extends StatelessWidget {
  final VoidCallback onTap;

  const _GoToNumber({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Semantics(
      button: true,
      label: 'Przejdź do pieśni',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SongBottomBar.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            // Magnifying glass with digits in the lens: a sign that you search by number.
            // Both factors: without heightFactor, Center takes all the height it gets
            // from the Scaffold, and the bar eats the screen.
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: GoToNumberIcon(color: appColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
