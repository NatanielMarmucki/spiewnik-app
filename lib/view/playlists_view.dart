import 'package:flutter/material.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/view/playlist_form_dialog.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/widgets/playlist_row.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

/// Asks for the name, date, color and icon of a new, empty list, creates it and opens it.
Future<void> createPlaylist(BuildContext context, PlaylistViewModel playlists, SongViewModel songs) async {
  final draft = await showPlaylistFormDialog(context);
  if (draft == null || !context.mounted) {
    return;
  }
  final playlist = playlists.create(draft);
  await openPlaylist(context, id: playlist.id, playlists: playlists, songs: songs);
}

/// „Moje › Listy” (Mine › Lists): the user's song lists in three groups — upcoming, undated, past.
class PlaylistsView extends StatelessWidget {
  final PlaylistViewModel viewModel;
  final SongViewModel songs;

  const PlaylistsView({super.key, required this.viewModel, required this.songs});

  static const Map<PlaylistGroup, String> _groupNames = {
    PlaylistGroup.upcoming: 'Nadchodzące',
    PlaylistGroup.undated: 'Bez daty',
    PlaylistGroup.past: 'Minione',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PlaylistDetails>>(
      valueListenable: viewModel.playlistsNotifier,
      builder: (context, playlists, _) {
        if (playlists.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              icon: Icons.format_list_numbered,
              title: 'Brak list',
              message: 'Zbierz pieśni pod nabożeństwo, ślub czy próbę chóru — w kolejności, w jakiej będą śpiewane.',
              secondaryActionLabel: '+ Nowa lista',
              onSecondaryAction: () => createPlaylist(context, viewModel, songs),
              footnote: 'Albo przytrzymaj pieśń w Śpiewniku, zaznacz kilka i dodaj je naraz.',
            ),
          );
        }
        final now = DateTime.now();
        return ListView(
          children: [
            for (final (group, lists) in viewModel.groups()) ...[
              SectionHeader(label: _groupNames[group]!, count: lists.length),
              for (final details in lists)
                PlaylistRow(
                  playlist: details.playlist,
                  songCount: details.entries.length,
                  subtitle: PlaylistRow.dateText(details.playlist, now),
                  past: group == PlaylistGroup.past,
                  onTap: () => openPlaylist(context, id: details.playlist.id, playlists: viewModel, songs: songs),
                ),
            ],
          ],
        );
      },
    );
  }
}
