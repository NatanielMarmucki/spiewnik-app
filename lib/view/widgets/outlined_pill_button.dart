import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Outlined pill button: text and outline in the accent, no fill.
class OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const OutlinedPillButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final style = OutlinedButton.styleFrom(
      foregroundColor: appColors.accent,
      disabledForegroundColor: appColors.textTertiary,
      side: BorderSide(
        color: onPressed == null ? appColors.line : appColors.accent,
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
