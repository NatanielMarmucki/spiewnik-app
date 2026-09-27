import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/widgets/outlined_pill_button.dart';

/// Empty state from docs/DESIGN-SYSTEM.md, section 5: a 26 dp line icon in the line color,
/// a Newsreader 21 heading, a 14/1.55 sentence saying what to do and optionally one way out
/// as a pill button. Never a large illustration.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Optional way out, e.g. „Wyczyść wyszukiwanie” (Clear search).
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional second way out below the first, as an outlined pill, e.g. „Usuń filtry” (Remove filters).
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// A quiet hint below the ways out, in tertiary text.
  final String? footnote;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.footnote,
  });

  static const double iconSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The icon is decorative only: the heading and the sentence below it carry all the content.
            ExcludeSemantics(child: Icon(icon, size: iconSize, color: appColors.line)),
            const SizedBox(height: 16.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 21.0,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14.0,
                height: 1.55,
                color: appColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24.0),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48.0),
                child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12.0),
              OutlinedPillButton(label: secondaryActionLabel!, onPressed: onSecondaryAction),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 16.0),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13.0, height: 1.5, color: appColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
    // Centered in the space it gets, and scrolling when a large system font does not fit in it.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SingleChildScrollView(
              child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: content),
            )
          : content,
    );
  }
}
