import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Bottom navigation from docs/DESIGN-SYSTEM.md, section 5.
///
/// Three tabs, a 17 dp line icon and a single-line label. Active: a 2 dp accent line above the
/// item, accent icon, label in the text color at weight 600. Inactive: tertiary text.
///
/// The height is a **minimum** of 48 dp, not a fixed value: the label grows with the system
/// font scaling (rule 1 in section 7 of the document).
class AppNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppNavigationBar({super.key, required this.selectedIndex, required this.onSelected});

  static const double minHeight = 48.0;
  static const double iconSize = 17.0;
  static const double indicatorHeight = 2.0;

  static const List<({IconData icon, String label})> destinations = [
    (icon: Icons.menu_book, label: 'Śpiewnik'),
    (icon: Icons.favorite, label: 'Ulubione'),
    (icon: Icons.edit_note, label: 'Moje'),
  ];

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _Destination(
                    destination: destinations[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  final ({IconData icon, String label}) destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _Destination({required this.destination, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 10.5,
      height: 1.2,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      color: isSelected ? colors.onSurface : appColors.textTertiary,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      // The action has to be on the node: excludeSemantics strips it from the InkWell, and the screen
      // reader would then activate nothing.
      onTap: onTap,
      // One node per tab: the screen reader reads the label once, not the icon and the text separately.
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicator line of the active tab; an inactive tab keeps the same height so nothing jumps.
            Container(
              height: AppNavigationBar.indicatorHeight,
              color: isSelected ? appColors.accent : colors.surface,
            ),
            const SizedBox(height: 6.0),
            Icon(
              destination.icon,
              size: AppNavigationBar.iconSize,
              color: isSelected ? appColors.accent : appColors.textTertiary,
            ),
            const SizedBox(height: 4.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                destination.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6.0),
          ],
        ),
      ),
    );
  }
}
