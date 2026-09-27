import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Outlined pill button, the secondary action next to a filled one.
class OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const OutlinedPillButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final style = OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      disabledForegroundColor: appColors.textTertiary,
      side: BorderSide(color: onPressed == null ? appColors.line : appColors.textTertiary),
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
