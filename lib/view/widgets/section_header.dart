import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Uppercase section label with a hairline and an optional count, e.g. „I · DUCH ŚWIĘTY ——— 37”.
/// Styled like the „Refren” label of a song, in the accent.
class SectionHeader extends StatelessWidget {
  final String label;
  final int? count;

  const SectionHeader({super.key, required this.label, this.count});

  static TextStyle style(BuildContext context) => Theme.of(context).textTheme.labelMedium!.copyWith(
        fontSize: 10.0,
        letterSpacing: 10.0 * 0.2,
        height: 1.3,
        color: context.appColors.accent,
      );

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Semantics(
      header: true,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
        child: Row(
          children: [
            Flexible(child: Text(label.toUpperCase(), style: style(context))),
            const SizedBox(width: 12.0),
            Expanded(child: Container(height: 1.0, color: appColors.line)),
            if (count != null) ...[
              const SizedBox(width: 12.0),
              Text('$count', style: style(context).copyWith(color: appColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
