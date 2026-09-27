import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/export/playlist_pdf.dart';
import 'package:spiewnik/model/polish_date.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/confirmation_dialog.dart';
import 'package:spiewnik/view/playlist_form_dialog.dart';
import 'package:spiewnik/view/playlist_song_picker_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/widgets/playlist_icon.dart';
import 'package:spiewnik/view/widgets/playlist_row.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

/// Opens the list [id] on top of the current screen.
Future<void> openPlaylist(
  BuildContext context, {
  required int id,
  required PlaylistViewModel playlists,
  required SongViewModel songs,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => PlaylistDetailView(playlistId: id, viewModel: playlists, songs: songs)),
  );
}

/// One song list: its name and date, the songs in their order — rearranged by dragging the handle or with
/// the row menu — and „Śpiewaj po kolei” (Sing in order).
class PlaylistDetailView extends StatefulWidget {
  final int playlistId;
  final PlaylistViewModel viewModel;
  final SongViewModel songs;

  const PlaylistDetailView({super.key, required this.playlistId, required this.viewModel, required this.songs});

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  /// Anchor for the share sheet on iPad.
  final GlobalKey _shareButtonKey = GlobalKey();

  PlaylistViewModel get _viewModel => widget.viewModel;

  PlaylistDetails? get _details => _viewModel.byId(widget.playlistId);

  void _openSong(PlaylistDetails details, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailView.inList(
          listContext: SongListContext(name: details.playlist.name, entries: details.entries),
          initialIndex: index,
          viewModel: widget.songs,
          playlistViewModel: _viewModel,
          onOpenPlaylist: (context, id) => openPlaylist(context, id: id, playlists: _viewModel, songs: widget.songs),
        ),
      ),
    );
  }

  void _addSongs() =>
      pickSongsForPlaylist(context, playlistId: widget.playlistId, playlists: _viewModel, songs: widget.songs);

  void _move(PlaylistDetails details, int from, int to) {
    _viewModel.move(details.playlist, from, to);
    _viewModel.markReorderHintSeen();
  }

  void _remove(PlaylistDetails details, int index) {
    final title = details.entries[index].title;
    final removed = _viewModel.removeAt(details.playlist, index);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Usunięto „$title” z listy'),
          action: SnackBarAction(label: 'Cofnij', onPressed: () => _viewModel.insert(details.playlist, index, removed)),
        ),
      );
  }

  Future<void> _showRowMenu(PlaylistDetails details, int index) async {
    final last = details.entries.length - 1;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SongOptionsSheet(
        options: [
          if (index > 0)
            SongOption(
              icon: Icons.arrow_upward,
              label: 'Przesuń wyżej',
              onTap: () {
                Navigator.pop(sheetContext);
                _move(details, index, index - 1);
              },
            ),
          if (index < last)
            SongOption(
              icon: Icons.arrow_downward,
              label: 'Przesuń niżej',
              onTap: () {
                Navigator.pop(sheetContext);
                _move(details, index, index + 1);
              },
            ),
          SongOption(
            icon: Icons.remove_circle_outline,
            label: 'Usuń z listy',
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _remove(details, index);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showOptions(PlaylistDetails details) async {
    final appColors = context.appColors;
    final playlist = details.playlist;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                PlaylistRow(
                  playlist: playlist,
                  songCount: details.entries.length,
                  subtitle: [
                    if (PlaylistRow.dateText(playlist, DateTime.now()) case final date?) date,
                    songsCount(details.entries.length),
                  ].join(' · '),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                const SectionHeader(label: 'Udostępnij'),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.tag,
                    label: 'Kopiuj numery',
                    subtitle: PlaylistViewModel.numbersText(details),
                    subtitleStyle: TextStyle(fontFamily: AppFonts.mono, fontSize: 13.0, color: appColors.accent),
                    onTap: () => close(() => _copyNumbers(details)),
                  ),
                ),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.format_list_numbered,
                    label: 'Tytuły z numerami',
                    subtitle: 'Zwykły tekst do wiadomości',
                    onTap: () => close(() => _shareTitles(details)),
                  ),
                ),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Pełne teksty · PDF',
                    subtitle: 'Strona tytułowa i każda pieśń od nowej strony',
                    onTap: () => close(() => _sharePdf(details)),
                  ),
                ),
                const SectionHeader(label: 'Lista'),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.edit_outlined,
                    label: 'Nazwa, data, kolor i ikona',
                    onTap: () => close(() => _edit(details)),
                  ),
                ),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.copy_all_outlined,
                    label: 'Duplikuj',
                    subtitle: playlist.date == null ? null : 'Np. na kolejną niedzielę — data o tydzień później',
                    onTap: () => close(() => _duplicate(details)),
                  ),
                ),
                Divider(color: appColors.line, height: 1.0),
                SongOptionTile(
                  option: SongOption(
                    icon: Icons.delete_outline,
                    label: 'Usuń listę',
                    destructive: true,
                    onTap: () => close(() => _delete(details)),
                  ),
                ),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyNumbers(PlaylistDetails details) {
    Clipboard.setData(ClipboardData(text: PlaylistViewModel.numbersText(details)));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skopiowano')));
  }

  Future<void> _shareTitles(PlaylistDetails details) async {
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: PlaylistViewModel.shareText(details),
        subject: details.playlist.name,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  /// A file name from the list name, without the characters file systems reject.
  static String fileName(String name, String extension) =>
      '${name.replaceAll(RegExp(r'[\\/:*?"<>|\n]'), '_').trim()}.$extension';

  Future<void> _sharePdf(PlaylistDetails details) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final bytes = await buildPlaylistPdf(details, await PdfFonts.load(DefaultAssetBundle.of(context)));
      final file = File(p.join((await getTemporaryDirectory()).path, fileName(details.playlist.name, 'pdf')));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: details.playlist.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(const SnackBar(content: Text('Nie udało się przygotować PDF')));
    }
  }

  Future<void> _edit(PlaylistDetails details) async {
    final draft = await showPlaylistFormDialog(context, existing: details.playlist);
    if (draft != null) {
      _viewModel.update(details.playlist, draft);
    }
  }

  void _duplicate(PlaylistDetails details) {
    final copy = _viewModel.duplicate(details.playlist);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Utworzono „${copy.name}”'),
          action: SnackBarAction(
            label: 'Otwórz',
            onPressed: () => openPlaylist(context, id: copy.id, playlists: _viewModel, songs: widget.songs),
          ),
        ),
      );
  }

  Future<void> _delete(PlaylistDetails details) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Usunąć listę?',
      message: 'Lista „${details.playlist.name}” zostanie usunięta. Pieśni zostają w śpiewniku.',
      confirmLabel: 'Usuń',
    );
    if (confirmed && mounted) {
      Navigator.pop(context);
      _viewModel.delete(details.playlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PlaylistDetails>>(
      valueListenable: _viewModel.playlistsNotifier,
      builder: (context, _, __) {
        final details = _details;
        if (details == null) {
          // Deleted while open.
          return const Scaffold();
        }
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Dodaj pieśni',
                onPressed: _addSongs,
                icon: const Icon(Icons.add, size: 24.0),
              ),
              IconButton(
                key: _shareButtonKey,
                tooltip: 'Udostępnij listę',
                onPressed: () => _showOptions(details),
                icon: const Icon(Icons.ios_share, size: 22.0),
              ),
              IconButton(
                tooltip: 'Opcje listy',
                onPressed: () => _showOptions(details),
                icon: const Icon(Icons.more_vert, size: 24.0),
              ),
            ],
          ),
          body: details.entries.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(details: details, hint: false),
                    Expanded(
                      child: EmptyState(
                        icon: Icons.queue_music,
                        title: 'Lista jest pusta',
                        message: 'Wybierz pieśni ze śpiewnika albo swoje. Kolejność zmienisz potem, przeciągając je.',
                        actionLabel: 'Dodaj pieśni',
                        onAction: _addSongs,
                      ),
                    ),
                  ],
                )
              : ValueListenableBuilder<bool>(
                  valueListenable: _viewModel.reorderHintSeenNotifier,
                  builder: (context, hintSeen, _) => ReorderableListView.builder(
                    header: _Header(details: details, hint: !hintSeen && details.entries.length > 1),
                    footer: _AddSongsRow(onTap: _addSongs),
                    buildDefaultDragHandles: false,
                    itemCount: details.entries.length,
                    onReorderStart: (_) => HapticFeedback.mediumImpact(),
                    onReorderEnd: (_) => HapticFeedback.selectionClick(),
                    onReorderItem: (from, to) => _move(details, from, to),
                    proxyDecorator: (child, index, animation) => _DraggedRow(child: child),
                    itemBuilder: (context, index) => _EntryRow(
                      key: ValueKey(details.entries[index].ref),
                      index: index,
                      entry: details.entries[index],
                      count: details.entries.length,
                      onTap: () => _openSong(details, index),
                      onMenu: () => _showRowMenu(details, index),
                      onMove: (to) => _move(details, index, to),
                      onRemove: () => _remove(details, index),
                    ),
                  ),
                ),
          bottomNavigationBar: details.entries.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _openSong(details, 0),
                        icon: const Icon(Icons.play_arrow, size: 18.0),
                        label: const Text('Śpiewaj po kolei'),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final PlaylistDetails details;
  final bool hint;

  const _Header({required this.details, required this.hint});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final playlist = details.playlist;
    final date = playlist.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlaylistIconGlyph(icon: playlist.icon, color: appColors.playlistColor(playlist.color)),
              if (date != null) ...[
                const SizedBox(width: 10.0),
                Expanded(child: Text(formatDayHeading(date).toUpperCase(), style: SectionHeader.style(context))),
              ],
            ],
          ),
          const SizedBox(height: 8.0),
          Semantics(
            header: true,
            child: Text(
              playlist.name,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 34.0,
                height: 1.1,
                fontWeight: FontWeight.w300,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12.0,
            children: [
              Text(songsCount(details.entries.length), style: textTheme.bodySmall),
              if (hint)
                Text(
                  'przytrzymaj uchwyt, by przestawić',
                  style: textTheme.bodySmall?.copyWith(color: appColors.textTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A song on the list: position, title, dots, number and the drag handle. The row menu and the screen
/// reader actions do what dragging does, for those who cannot drag.
class _EntryRow extends StatelessWidget {
  final int index;
  final PlaylistEntry entry;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  const _EntryRow({
    super.key,
    required this.index,
    required this.entry,
    required this.count,
    required this.onTap,
    required this.onMenu,
    required this.onMove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${index + 1} z $count, ${entry.title}${entry.number == null ? ', moja' : ', numer ${entry.number}'}',
      onTap: onTap,
      onLongPress: onMenu,
      customSemanticsActions: {
        if (index > 0) const CustomSemanticsAction(label: 'Przesuń wyżej'): () => onMove(index - 1),
        if (index < count - 1) const CustomSemanticsAction(label: 'Przesuń niżej'): () => onMove(index + 1),
        const CustomSemanticsAction(label: 'Usuń z listy'): onRemove,
      },
      container: true,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onMenu,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52.0),
            child: Row(
              children: [
                const SizedBox(width: 16.0),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 28.0),
                  child: Text('${index + 1}', style: textTheme.titleSmall?.copyWith(color: appColors.accent)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: LeaderRow(
                      title: Text(entry.title, style: textTheme.titleMedium),
                      trailing: entry.number == null ? 'MOJA' : '${entry.number}',
                      trailingStyle: entry.number == null ? textTheme.labelMedium : textTheme.titleSmall,
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 44.0,
                    height: 52.0,
                    child: Icon(Icons.drag_handle, size: 18.0, color: appColors.textTertiary),
                  ),
                ),
                const SizedBox(width: 4.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// „+ Dodaj pieśni” below the last song, where the next one would go.
class _AddSongsRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSongsRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.accent;
    return Semantics(
      button: true,
      label: 'Dodaj pieśni',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.add, size: 18.0, color: accent),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text('Dodaj pieśni', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The row while it is dragged: surface +1, a 1 dp accent outline, 12 dp radius. No shadow.
class _DraggedRow extends StatelessWidget {
  final Widget child;

  const _DraggedRow({required this.child});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Material(
      color: appColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: appColors.accent),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
