import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/add_to_playlist_sheet.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/view/playlists_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

/// The „Moje” tab: „Pieśni” (the user's songs, unchanged) and „Listy” (song lists), switched by a text
/// tab bar. The last choice is remembered.
class MyTabView extends StatelessWidget {
  final MySongViewModel mySongs;
  final PlaylistViewModel playlists;
  final SongViewModel songs;

  const MyTabView({super.key, required this.mySongs, required this.playlists, required this.songs});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: playlists.showListsNotifier,
      builder: (context, showLists, _) => Column(
        children: [
          ValueListenableBuilder(
            valueListenable: playlists.playlistsNotifier,
            builder: (context, lists, _) => _SubviewTabs(
              showLists: showLists,
              listCount: lists.length,
              onChanged: playlists.setShowLists,
            ),
          ),
          Expanded(
            child: showLists
                ? PlaylistsView(viewModel: playlists, songs: songs)
                : MySongsView(
                    viewModel: mySongs,
                    onAdd: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MySongFormView(viewModel: mySongs)),
                    ),
                    onAddToPlaylist: (context, song) => showAddToPlaylistSheet(
                      context,
                      viewModel: playlists,
                      songs: [PlaylistEntry.mine(song)],
                      onOpen: (id) => openPlaylist(context, id: id, playlists: playlists, songs: songs),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubviewTabs extends StatelessWidget {
  final bool showLists;
  final int listCount;
  final ValueChanged<bool> onChanged;

  const _SubviewTabs({required this.showLists, required this.listCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.appColors.line))),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Flexible(child: _Tab(label: 'Pieśni', selected: !showLists, onTap: () => onChanged(false))),
          Flexible(child: _Tab(label: 'Listy', count: listCount, selected: showLists, onTap: () => onChanged(true))),
        ],
      ),
    );
  }
}

/// A text tab; the active one is underlined with the accent, 2 dp, like the bottom navigation.
class _Tab extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.label, this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.onSurface : appColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48.0, minWidth: 64.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? appColors.accent : Colors.transparent, width: 2.0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6.0),
                Text('$count', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13.0, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
