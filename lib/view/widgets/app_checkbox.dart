import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// A 20 dp checkbox drawing: an outline when empty, the accent with a dark tick when checked and with a
/// dash when partly checked ([value] null). Only a drawing: the row around it is the touch target and
/// carries the semantics.
class AppCheckbox extends StatelessWidget {
  /// true checked, false empty, null partly checked.
  final bool? value;

  const AppCheckbox({super.key, required this.value});

  static const double size = 20.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final filled = value != false;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? appColors.accent : null,
          border: filled ? null : Border.all(color: appColors.textSecondary, width: 1.5),
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: filled
            ? Icon(value == true ? Icons.check : Icons.remove, size: 16.0, color: appColors.onAccent)
            : null,
      ),
    );
  }
}
