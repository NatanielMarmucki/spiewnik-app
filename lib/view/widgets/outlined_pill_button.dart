import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Outlined pill button, the secondary action next to a filled one.
class OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// The main action of a screen, still without a fill: text and outline in the accent.
  final bool accent;

  const OutlinedPillButton({super.key, required this.label, this.icon, required this.onPressed, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final style = OutlinedButton.styleFrom(
      foregroundColor: accent ? appColors.accent : Theme.of(context).colorScheme.onSurface,
      disabledForegroundColor: appColors.textTertiary,
      side: BorderSide(
        color: onPressed == null ? appColors.line : (accent ? appColors.accent : appColors.textTertiary),
      ),
      shape: const StadiumBorder(),
      minimumSize: const Size(0.0, 48.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18.0), label: Text(label));
  }
}
