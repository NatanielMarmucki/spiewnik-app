import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_date.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';
import 'package:spiewnik/view/widgets/playlist_icon.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

/// The „Nowa lista” (New list) dialog, or „Edytuj listę” (Edit list) for [existing]: name, optional date,
/// color and icon. Returns what the user chose, or null when they cancel.
Future<PlaylistDraft?> showPlaylistFormDialog(BuildContext context, {Playlist? existing}) {
  return showDialog<PlaylistDraft>(
    context: context,
    builder: (context) => _PlaylistFormDialog(existing: existing),
  );
}

class _PlaylistFormDialog extends StatefulWidget {
  final Playlist? existing;

  const _PlaylistFormDialog({this.existing});

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late DateTime? _date = widget.existing?.date;
  late PlaylistColor _color = widget.existing?.color ?? PlaylistColor.saffron;
  late PlaylistIcon _icon = widget.existing?.icon ?? PlaylistIcon.note;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _submit() {
    if (_valid) {
      Navigator.pop(context, (name: _name.text.trim(), date: _date, color: _color, icon: _icon));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final editing = widget.existing != null;
    final label = textTheme.bodySmall?.copyWith(color: appColors.textSecondary);

    return AlertDialog(
      scrollable: true,
      titlePadding: kDialogTitlePadding,
      contentPadding: kDialogContentPadding,
      title: Row(
        children: [
          PlaylistTile(icon: _icon, color: _color),
          const SizedBox(width: 12.0),
          Expanded(child: Text(editing ? 'Edytuj listę' : 'Nowa lista')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nazwa', style: label),
          ValueListenableBuilder(
            valueListenable: _name,
            builder: (context, _, __) => TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(Playlist.maxNameLength)],
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 26.0,
                height: 1.2,
                fontWeight: FontWeight.w300,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'np. Nabożeństwo niedzielne',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w300,
                  color: appColors.textTertiary,
                ),
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                border: UnderlineInputBorder(borderSide: BorderSide(color: appColors.line)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: appColors.line)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: appColors.accent, width: 1.5)),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 20.0),
          Text('Data · opcjonalnie', style: label),
          _DateRow(date: _date, onPick: _pickDate, onClear: () => setState(() => _date = null)),
          const SizedBox(height: 16.0),
          Text('Kolor', style: label),
          const SizedBox(height: 4.0),
          Wrap(
            children: [
              for (final color in PlaylistColor.values)
                _ColorDot(color: color, selected: color == _color, onTap: () => setState(() => _color = color)),
            ],
          ),
          const SizedBox(height: 16.0),
          Text('Ikona', style: label),
          const SizedBox(height: 4.0),
          Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children: [
              for (final icon in PlaylistIcon.values)
                _IconChoice(
                  icon: icon,
                  color: _color,
                  selected: icon == _icon,
                  onTap: () => setState(() => _icon = icon),
                ),
            ],
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder(
          valueListenable: _name,
          builder: (context, _, __) => DialogActions(
            children: [
              dialogQuietButton(context, label: 'Anuluj', onPressed: () => Navigator.pop(context)),
              dialogAccentButton(context, label: editing ? 'Zapisz' : 'Utwórz', onPressed: _valid ? _submit : null),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateRow({required this.date, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: date == null ? 'Wybierz datę' : 'Data: ${formatDay(date!, withYear: true)}. Zmień',
            onTap: onPick,
            container: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18.0, color: appColors.textSecondary),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        date == null ? 'Bez daty' : formatDay(date!, withYear: true),
                        style: textTheme.bodyMedium?.copyWith(color: date == null ? appColors.textTertiary : null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18.0),
            tooltip: 'Usuń datę',
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// A 26 dp color dot in a 44 dp target; the chosen one has a ring. One of a radio group.
class _ColorDot extends StatelessWidget {
  final PlaylistColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fill = appColors.playlistColor(color);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: 'Kolor ${playlistColorNames[color]}',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22.0,
        child: SizedBox.square(
          dimension: 44.0,
          child: Center(
            child: Container(
              width: 34.0,
              height: 34.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: selected ? Border.all(color: fill, width: 1.5) : null,
              ),
              child: Container(width: 26.0, height: 26.0, decoration: BoxDecoration(color: fill, shape: BoxShape.circle)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44 dp icon button, 12 dp radius; the chosen one has an outline and the icon in the list's color.
class _IconChoice extends StatelessWidget {
  final PlaylistIcon icon;
  final PlaylistColor color;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final radius = BorderRadius.circular(12.0);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: 'Ikona: ${playlistIconNames[icon]}',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: 44.0,
          height: 44.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: selected ? appColors.playlistColor(color) : appColors.line),
          ),
          child: PlaylistIconGlyph(
            icon: icon,
            color: selected ? appColors.playlistColor(color) : appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
