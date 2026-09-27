import 'package:flutter/material.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/model/song_categories.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/widgets/app_checkbox.dart';
import 'package:spiewnik/view/widgets/outlined_pill_button.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';

/// Opens the „Kategorie” sheet with [selected] checked. Changes are a draft until „Pokaż” (Show):
/// returns the new selection then, and null when the sheet is closed with ✕ or a gesture.
///
/// [songCount] says how many songs a selection shows, for the live „Pokaż N pieśni”.
Future<Set<int>?> showCategoryFilterSheet(
  BuildContext context, {
  required SongCategories categories,
  required Set<int> selected,
  required int Function(Set<int> subcategoryIds) songCount,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: CategoryFilterSheet(categories: categories, selected: selected, songCount: songCount),
    ),
  );
}

class CategoryFilterSheet extends StatefulWidget {
  final SongCategories categories;
  final Set<int> selected;
  final int Function(Set<int> subcategoryIds) songCount;

  const CategoryFilterSheet({super.key, required this.categories, required this.selected, required this.songCount});

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  late final Set<int> _draft = {...widget.selected};

  /// Categories with a selected subcategory start expanded, so the checks are in sight.
  late final Set<String> _expanded = {
    for (final category in widget.categories.categories)
      if (category.subcategories.any((subcategory) => _draft.contains(subcategory.id))) category.id,
  };

  void _toggle(int id) => setState(() => _draft.contains(id) ? _draft.remove(id) : _draft.add(id));

  void _toggleCategory(SongCategory category) {
    final ids = category.subcategories.map((subcategory) => subcategory.id);
    setState(() => ids.every(_draft.contains) ? _draft.removeAll(ids) : _draft.addAll(ids));
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final selected = [
      for (final subcategory in widget.categories.subcategories)
        if (_draft.contains(subcategory.id)) subcategory,
    ];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 8.0),
            child: Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text('Kategorie', style: textTheme.headlineSmall))),
                IconButton(
                  icon: const Icon(Icons.close, size: 18.0),
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (selected.isNotEmpty) ...[
                  SectionHeader(label: 'Wybrane · ${selected.length}'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (final subcategory in selected)
                          SubcategoryChip(label: subcategory.name, onRemove: () => _toggle(subcategory.id)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],
                for (final category in widget.categories.categories) ..._category(category),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: appColors.line))),
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
            child: Row(
              children: [
                OutlinedPillButton(
                  label: 'Wyczyść',
                  onPressed: _draft.isEmpty ? null : () => setState(_draft.clear),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48.0),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _draft),
                      child: Text('Pokaż ${songsCount(widget.songCount(_draft))}', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _category(SongCategory category) {
    final expanded = _expanded.contains(category.id);
    final ids = category.subcategories.map((subcategory) => subcategory.id);
    final checkedCount = ids.where(_draft.contains).length;
    final whole = checkedCount == 0 ? false : (checkedCount == ids.length ? true : null);

    return [
      _CategoryRow(
        category: category,
        songCount: widget.categories.songsIn(ids).length,
        expanded: expanded,
        onTap: () => setState(() => expanded ? _expanded.remove(category.id) : _expanded.add(category.id)),
      ),
      if (expanded) ...[
        _CheckRow(label: 'Cała kategoria', value: whole, onTap: () => _toggleCategory(category)),
        for (final subcategory in category.subcategories)
          _CheckRow(
            label: subcategory.name,
            count: subcategory.songs.length,
            value: _draft.contains(subcategory.id),
            onTap: () => _toggle(subcategory.id),
          ),
      ],
    ];
  }
}

/// A selected subcategory as a pill with ✕; tapping anywhere on it removes it.
class SubcategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const SubcategoryChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Semantics(
      button: true,
      label: 'Usuń filtr: $label',
      onTap: onRemove,
      container: true,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onRemove,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40.0),
            padding: const EdgeInsets.only(left: 14.0, right: 10.0),
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: appColors.accent)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Icon(Icons.close, size: 14.0, color: appColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final SongCategory category;
  final int songCount;
  final bool expanded;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.songCount, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final nameStyle = textTheme.titleMedium?.copyWith(fontSize: 19.0);

    return Semantics(
      button: true,
      expanded: expanded,
      label: '${category.id}, ${category.name}, ${songsCount(songCount)}',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 12.0, 10.0),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 36.0),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      category.id,
                      style: nameStyle?.copyWith(
                        fontFamily: AppFonts.serif,
                        color: expanded ? appColors.accent : appColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LeaderRow(
                    title: Text(category.name, style: nameStyle),
                    trailing: '$songCount',
                    trailingStyle: textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18.0, color: appColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A checkbox row under an expanded category: „Cała kategoria” (three states) or a subcategory.
class _CheckRow extends StatelessWidget {
  final String label;
  final int? count;
  final bool? value;
  final VoidCallback onTap;

  const _CheckRow({required this.label, this.count, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      checked: value == true,
      mixed: value == null,
      label: count == null ? label : '$label, ${songsCount(count!)}',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(52.0, 8.0, 16.0, 8.0),
            child: Row(
              children: [
                AppCheckbox(value: value),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Text(label, style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (count != null) ...[
                  const SizedBox(width: 12.0),
                  Text('$count', style: textTheme.titleSmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The „sliders” button next to the search field. With a filter on: accent icon on the surface and a
/// badge with the number of selected subcategories.
class CategoryFilterButton extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onPressed;

  const CategoryFilterButton({super.key, required this.selectedCount, required this.onPressed});

  static const double size = 48.0;
  static const double badgeSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final active = selectedCount > 0;
    return Semantics(
      button: true,
      label: 'Filtruj według kategorii',
      value: active ? 'wybrano ${plural(selectedCount, 'kategorię', 'kategorie', 'kategorii')}' : null,
      onTap: onPressed,
      container: true,
      excludeSemantics: true,
      child: Material(
        color: active ? Theme.of(context).colorScheme.surfaceContainer : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune, size: 18.0, color: active ? appColors.accent : appColors.textSecondary),
                if (active)
                  Positioned(
                    top: 6.0,
                    right: 6.0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: badgeSize, minHeight: badgeSize),
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: appColors.accent,
                        borderRadius: BorderRadius.circular(badgeSize / 2),
                      ),
                      child: Text(
                        '$selectedCount',
                        style: TextStyle(
                          fontSize: 10.0,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          color: appColors.onAccent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
