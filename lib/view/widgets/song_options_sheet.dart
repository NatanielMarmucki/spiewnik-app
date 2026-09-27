import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Options sheet from docs/DESIGN-SYSTEM.md, section 5: a 34 × 3 dp handle, 52 dp items,
/// the destructive section set off by a hairline.
///
/// The item height is a **minimum**, so it grows with the system font.
class SongOptionsSheet extends StatelessWidget {
  final List<SongOption> options;

  const SongOptionsSheet({super.key, required this.options});

  static const double handleWidth = 34.0;
  static const double handleHeight = 3.0;
  static const double minItemHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          for (var i = 0; i < options.length; i++) ...[
            // A hairline sets the destructive section off from the rest, so deleting does not sit in
            // one run with sharing.
            if (options[i].destructive && (i == 0 || !options[i - 1].destructive))
              Divider(color: appColors.line, height: 1.0),
            SongOptionTile(option: options[i]),
          ],
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}

/// Sheet item: icon, title and an optional value on the right (e.g. the current text size).
class SongOption {
  final IconData icon;
  final String label;
  final String? value;

  /// A line below the label, e.g. the numbers that „Kopiuj numery” (Copy numbers) will copy.
  final String? subtitle;
  final TextStyle? subtitleStyle;

  /// Irreversible action: the destructive color and a hairline setting it off from the rest.
  final bool destructive;

  final VoidCallback onTap;

  const SongOption({
    required this.icon,
    required this.label,
    this.value,
    this.subtitle,
    this.subtitleStyle,
    this.destructive = false,
    required this.onTap,
  });
}

/// One item of an options sheet.
class SongOptionTile extends StatelessWidget {
  final SongOption option;

  const SongOptionTile({super.key, required this.option});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final color = option.destructive ? appColors.destructive : null;

    return Semantics(
      button: true,
      label: [option.label, if (option.value != null) option.value!, if (option.subtitle != null) option.subtitle!]
          .join(', '),
      onTap: option.onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: option.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SongOptionsSheet.minItemHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(option.icon, size: 17.0, color: color ?? appColors.textSecondary),
                const SizedBox(width: 16.0),
                Expanded(
                  child: option.subtitle == null
                      ? Text(option.label, style: textTheme.bodyMedium?.copyWith(color: color))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.label, style: textTheme.bodyMedium?.copyWith(color: color)),
                            Text(
                              option.subtitle!,
                              style: option.subtitleStyle ??
                                  textTheme.bodySmall?.copyWith(color: appColors.textTertiary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
                if (option.value != null)
                  Text(option.value!, style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 34 × 3 dp handle at the top of a sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        width: SongOptionsSheet.handleWidth,
        height: SongOptionsSheet.handleHeight,
        decoration: BoxDecoration(color: context.appColors.line, borderRadius: BorderRadius.circular(3.0)),
      ),
    );
  }
}
