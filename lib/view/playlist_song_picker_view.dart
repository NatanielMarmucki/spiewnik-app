import 'package:flutter/material.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/add_to_playlist_sheet.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

/// Picks songs for [playlistId] straight from the list: search by number, title or words, tap to check,
/// „Dodaj N pieśni” to add them at the end. Songs already on the list are shown checked and cannot be
/// picked again. Shows what was added in a snackbar on the list.
Future<void> pickSongsForPlaylist(
  BuildContext context, {
  required int playlistId,
  required PlaylistViewModel playlists,
  required SongViewModel songs,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await Navigator.push<List<PlaylistEntry>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PlaylistSongPickerView(playlistId: playlistId, playlists: playlists, songs: songs),
    ),
  );
  final details = playlists.byId(playlistId);
  if (picked == null || picked.isEmpty || details == null) {
    return;
  }
  final result = playlists.addSongs(details.playlist, [for (final entry in picked) entry.ref]);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(addedMessage(result, details.playlist.name, picked))));
}

class PlaylistSongPickerView extends StatefulWidget {
  final int playlistId;
  final PlaylistViewModel playlists;
  final SongViewModel songs;

  const PlaylistSongPickerView({super.key, required this.playlistId, required this.playlists, required this.songs});

  @override
  State<PlaylistSongPickerView> createState() => _PlaylistSongPickerViewState();
}

class _PlaylistSongPickerViewState extends State<PlaylistSongPickerView> {
  /// A search of its own, so the one in the Śpiewnik tab stays as the user left it.
  late final SongViewModel _search = SongViewModel(widget.songs.repository);
  late final List<MySong> _mySongs = widget.playlists.mySongs.all();
  late final Set<SongRef> _onList = {...?widget.playlists.byId(widget.playlistId)?.refs};

  /// In the order of tapping; the list sorts them when adding.
  final Map<SongRef, PlaylistEntry> _picked = {};
  String _query = '';

  void _toggle(PlaylistEntry entry) {
    setState(() => _picked.remove(entry.ref) == null ? _picked[entry.ref] = entry : null);
  }

  List<MySong> get _matchingMySongs {
    final query = removePolishDiacritics(_query.trim().toLowerCase());
    return [
      for (final song in _mySongs)
        if (removePolishDiacritics(song.title.toLowerCase()).contains(query)) song,
    ];
  }

  Widget _tile(PlaylistEntry entry, {List<String> highlights = const []}) {
    final onList = _onList.contains(entry.ref);
    return SongListTile(
      title: entry.title,
      number: entry.number,
      badge: entry.number == null ? 'MOJA' : null,
      highlights: highlights,
      selectable: true,
      isChecked: onList || _picked.containsKey(entry.ref),
      // Already on the list: shown checked, but there is nothing to change.
      onTap: onList ? null : () => _toggle(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final name = widget.playlists.byId(widget.playlistId)?.playlist.name ?? '';
    final mine = _matchingMySongs;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Anuluj', onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: Text('Dodaj do „$name”', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: TextField(
              autofocus: true,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Numer, tytuł albo słowa',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                prefixIcon: Icon(Icons.search, size: 15.0, color: appColors.textSecondary),
                prefixIconConstraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              ),
              onChanged: (value) => setState(() {
                _query = value;
                _search.searchText = value.trim();
              }),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Song>>(
              valueListenable: _search.filteredSongsNotifier,
              builder: (context, songs, _) {
                final rows = <Object>[
                  if (mine.isNotEmpty) ...['Moje pieśni', ...mine, 'Śpiewnik'],
                  ...songs,
                ];
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => switch (rows[index]) {
                    final String header => SectionHeader(label: header),
                    final MySong song => _tile(PlaylistEntry.mine(song)),
                    final Song song => _tile(PlaylistEntry.songbook(song), highlights: _search.titleMatches(song)),
                    _ => const SizedBox.shrink(),
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border(top: BorderSide(color: appColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48.0),
              child: ElevatedButton.icon(
                onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.values.toList()),
                icon: const Icon(Icons.add, size: 18.0),
                label: Text(_picked.isEmpty ? 'Zaznacz pieśni' : 'Dodaj ${songsCount(_picked.length)}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
