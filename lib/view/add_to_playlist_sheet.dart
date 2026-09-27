import 'package:flutter/material.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/playlist_form_dialog.dart';
import 'package:spiewnik/view/widgets/playlist_icon.dart';
import 'package:spiewnik/view/widgets/playlist_row.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

/// The „Dodaj N pieśni do listy” (Add N songs to a list) sheet: a new list from [songs], or one of the
/// existing lists — upcoming first, then undated, past last. After adding, a snackbar says what happened
/// and offers „Otwórz” (Open), which calls [onOpen].
///
/// Returns true when the songs went to a list, false when the user backed out.
Future<bool> showAddToPlaylistSheet(
  BuildContext context, {
  required PlaylistViewModel viewModel,
  required List<PlaylistEntry> songs,
  required void Function(int playlistId) onOpen,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddToPlaylistSheet(viewModel: viewModel, songs: songs),
  );
  if (choice == null || !context.mounted) {
    return false;
  }
  final refs = [for (final song in songs) song.ref];

  final Playlist playlist;
  final AddSongsResult result;
  if (choice.playlist == null) {
    final draft = await showPlaylistFormDialog(context);
    if (draft == null) {
      return false;
    }
    playlist = viewModel.create(draft, songs: refs);
    result = (added: refs.toSet().length, skipped: 0);
  } else {
    playlist = choice.playlist!;
    result = viewModel.addSongs(playlist, refs);
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(addedMessage(result, playlist.name, songs)),
        action: SnackBarAction(label: 'Otwórz', onPressed: () => onOpen(playlist.id)),
      ),
    );
  return true;
}

/// „Dodano 2 pieśni do „Nazwa””, with a note about songs that were on the list already.
String addedMessage(AddSongsResult result, String name, List<PlaylistEntry> songs) {
  if (result.added == 0) {
    return songs.length == 1 ? '„${songs.single.title}” już jest na „$name”' : 'Wszystkie już są na „$name”';
  }
  final added = 'Dodano ${songsCount(result.added)} do „$name”';
  return result.skipped == 0 ? added : '$added · ${plural(result.skipped, 'już była', 'już były', 'już było')}';
}

/// What was tapped: a list, or „Nowa lista z zaznaczonych” (null [playlist]).
class _Choice {
  final Playlist? playlist;

  const _Choice(this.playlist);
}

class _AddToPlaylistSheet extends StatelessWidget {
  final PlaylistViewModel viewModel;
  final List<PlaylistEntry> songs;

  const _AddToPlaylistSheet({required this.viewModel, required this.songs});

  String? _alreadyText(Playlist playlist) {
    final already = viewModel.alreadyOn(playlist, [for (final song in songs) song.ref]);
    if (already == 0) {
      return null;
    }
    if (songs.length == 1) {
      return '„${songs.single.title}” już jest';
    }
    return '$already z ${songs.length} ${already == 1 ? 'już jest' : 'już są'}';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final groups = viewModel.groups();
    final numbers = songs.map((song) => song.number?.toString() ?? '„${song.title}”').join(' · ');

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Center(child: SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Dodaj ${songsCount(songs.length)} do listy', style: textTheme.headlineSmall),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    numbers,
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13.0, color: appColors.accent),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: songs.length == 1 ? 'Nowa lista z tą pieśnią' : 'Nowa lista z zaznaczonych',
              onTap: () => Navigator.pop(context, const _Choice(null)),
              container: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => Navigator.pop(context, const _Choice(null)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const PlaylistTile(icon: PlaylistIcon.note, color: PlaylistColor.saffron, dashed: true),
                        const SizedBox(width: 14.0),
                        Expanded(
                          child: Text(
                            songs.length == 1 ? 'Nowa lista z tą pieśnią' : 'Nowa lista z zaznaczonych',
                            style: textTheme.titleMedium?.copyWith(color: appColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final (group, lists) in groups)
              for (final details in lists)
                PlaylistRow(
                  playlist: details.playlist,
                  songCount: details.entries.length,
                  past: group == PlaylistGroup.past,
                  subtitle: [
                    PlaylistRow.dateText(details.playlist, now) ?? 'bez daty',
                    songsCount(details.entries.length),
                    if (_alreadyText(details.playlist) case final already?) already,
                  ].join(' · '),
                  onTap: () => Navigator.pop(context, _Choice(details.playlist)),
                ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}
