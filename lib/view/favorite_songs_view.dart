import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/model/song_model.dart';

class FavoriteSongsView extends StatelessWidget {
  final SongViewModel viewModel;

  /// For „Dodaj do listy” (Add to list) in an opened song.
  final PlaylistViewModel? playlistViewModel;

  const FavoriteSongsView({super.key, required this.viewModel, this.playlistViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<List<Song>>(
            valueListenable: viewModel.favoriteSongsNotifier,
            builder: (context, favoriteSongs, _) {
              if (favoriteSongs.isEmpty) {
                return const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Brak ulubionych',
                  message: 'Otwórz pieśń i dotknij serca w pasku, żeby trzymać ją pod ręką.',
                );
              }
              return ValueListenableBuilder<Set<int>?>(
                valueListenable: viewModel.selectionNotifier,
                builder: (context, selection, _) => ListView.builder(
                  itemCount: favoriteSongs.length,
                  itemBuilder: (context, index) {
                    final song = favoriteSongs[index];
                    return SongListTile(
                      title: song.title,
                      number: song.number,
                      isFavorite: true,
                      selectable: selection != null,
                      isChecked: selection?.contains(song.number) ?? false,
                      onLongPress: () => selection == null
                          ? viewModel.startSelection(song.number)
                          : viewModel.toggleSelected(song.number),
                      onTap: selection != null
                          ? () => viewModel.toggleSelected(song.number)
                          : () => openSong(context, song, viewModel, playlistViewModel),
                    );
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
