import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/view/widgets/category_filter_sheet.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/view/widgets/song_scroll_bar.dart';
import 'song_detail_view.dart';
import 'package:spiewnik/model/song_model.dart';

@immutable
class SongListView extends StatefulWidget {
  final SongViewModel viewModel;

  /// For „Dodaj do listy” (Add to list) in an opened song.
  final PlaylistViewModel? playlistViewModel;

  const SongListView({
    super.key,
    required this.viewModel,
    this.playlistViewModel,
  });

  @override
  SongListViewState createState() => SongListViewState();
}

class SongListViewState extends State<SongListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        widget.viewModel.searchText = value;
      });
    });
  }

  void _clearSearch() {
    _controller.clear();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    _onSearchChanged('');
  }

  Future<void> _openFilter() async {
    final viewModel = widget.viewModel;
    final selected = await showCategoryFilterSheet(
      context,
      categories: viewModel.categories,
      selected: viewModel.subcategoryFilter,
      songCount: viewModel.songCountIn,
    );
    if (selected != null) {
      _setFilter(selected);
    }
  }

  void _setFilter(Set<int> subcategoryIds) {
    setState(() => widget.viewModel.subcategoryFilter = subcategoryIds);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  String _hint(Set<int> filter) {
    if (widget.viewModel.isSelecting) {
      return 'Szukaj — zaznaczenie zostaje';
    }
    if (filter.isEmpty) {
      return 'Szukaj';
    }
    final count = widget.viewModel.songCountIn(filter);
    return 'Szukaj w $count ${count == 1 ? 'pieśni' : 'pieśniach'}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: widget.viewModel.subcategoryFilterNotifier,
      builder: (context, filter, _) => ValueListenableBuilder<Set<int>?>(
        // Only for the hint of the search field.
        valueListenable: widget.viewModel.selectionNotifier,
        builder: (context, _, __) => Column(
          children: [
            Padding(
              // The search field is always visible (docs/DESIGN-SYSTEM.md, section 5).
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 8.0),
              child: Row(
                children: [
                  Expanded(child: _searchField(context, filter)),
                  if (widget.viewModel.categories.categories.isNotEmpty) ...[
                    const SizedBox(width: 4.0),
                    _FilterButton(selectedCount: filter.length, onPressed: _openFilter),
                  ],
                ],
              ),
            ),
            if (filter.isNotEmpty) _activeFilterChips(filter),
            Expanded(
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: widget.viewModel.filteredSongsNotifier,
                builder: (context, songs, _) => ValueListenableBuilder<Set<int>?>(
                  valueListenable: widget.viewModel.selectionNotifier,
                  builder: (context, selection, _) => songs.isEmpty ? _empty(filter) : _list(songs, filter, selection),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, Set<int> filter) {
    final appColors = context.appColors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44.0),
          child: TextField(
            controller: _controller,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: _hint(filter),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              prefixIcon: Icon(Icons.search, size: 15.0, color: appColors.textSecondary),
              prefixIconConstraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 15.0),
                      // 48 dp touch target, despite the small icon.
                      constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
                      tooltip: 'Wyczyść wyszukiwanie',
                      onPressed: _clearSearch,
                    ),
            ),
            onChanged: _onSearchChanged,
          ),
        );
      },
    );
  }

  /// Chips of the active subcategories, in one row that scrolls sideways; ✕ removes one.
  Widget _activeFilterChips(Set<int> filter) {
    final categories = widget.viewModel.categories;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 4.0),
      child: Row(
        children: [
          for (final subcategory in categories.subcategories)
            if (filter.contains(subcategory.id))
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SubcategoryChip(
                  label: subcategory.name,
                  onRemove: () => _setFilter({...filter}..remove(subcategory.id)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _empty(Set<int> filter) {
    final query = _controller.text.trim();
    if (filter.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Brak wyników',
        message: 'Żadna pieśń nie pasuje do „$query”. Spróbuj innego słowa albo wpisz numer pieśni.',
        actionLabel: 'Wyczyść wyszukiwanie',
        onAction: _clearSearch,
      );
    }
    return EmptyState(
      icon: Icons.search_off,
      title: 'Brak wyników',
      message: query.isEmpty
          ? 'W wybranych kategoriach nie ma pieśni.'
          : 'Żadna pieśń z wybranych kategorii nie pasuje do „$query”.',
      actionLabel: query.isEmpty ? null : 'Wyczyść wyszukiwanie',
      onAction: query.isEmpty ? null : _clearSearch,
      secondaryActionLabel: 'Usuń filtry',
      onSecondaryAction: () => _setFilter(const {}),
    );
  }

  Widget _list(List<Song> songs, Set<int> filter, Set<int>? selection) {
    // With a filter: a header per selected subcategory, then its songs. A song in two of them shows twice.
    final List<Object> rows = filter.isEmpty
        ? songs
        : [
            for (final section in widget.viewModel.sections(songs))
              if (section.songs.isNotEmpty) ...[section, ...section.songs],
          ];
    // itemExtent null: the row grows with the system font scaling.
    return SongScrollBar(
      controller: _scrollController,
      // Thumb only on the full list: search results and categories have nothing to scroll through,
      // and the number label would not match the position anyway.
      enabled: widget.viewModel.searchText.isEmpty && filter.isEmpty,
      labelForIndex: (index) => index < songs.length ? '${songs[index].number}' : null,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is SongSection) {
            return SectionHeader(
              label: '${row.category.id} · ${row.subcategory.name}',
              count: row.songs.length,
            );
          }
          final song = row as Song;
          return SongListTile(
            title: song.title,
            number: song.number,
            isFavorite: song.favorite,
            highlights: widget.viewModel.titleMatches(song),
            selectable: selection != null,
            isChecked: selection?.contains(song.number) ?? false,
            onLongPress: () => selection == null
                ? widget.viewModel.startSelection(song.number)
                : widget.viewModel.toggleSelected(song.number),
            onTap: selection != null
                ? () => widget.viewModel.toggleSelected(song.number)
                : () => openSong(context, song, widget.viewModel, widget.playlistViewModel),
          );
        },
      ),
    );
  }
}

/// The „sliders” button next to the search field. With a filter on: accent icon on the surface and a
/// badge with the number of selected subcategories.
class _FilterButton extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onPressed;

  const _FilterButton({required this.selectedCount, required this.onPressed});

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

/// Opens [song] from a list of the songbook, with „Dodaj do listy” when there is a [playlistViewModel].
void openSong(BuildContext context, Song song, SongViewModel viewModel, PlaylistViewModel? playlistViewModel) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SongDetailView(
        song: song,
        viewModel: viewModel,
        playlistViewModel: playlistViewModel,
        onOpenPlaylist: playlistViewModel == null
            ? null
            : (context, id) => openPlaylist(context, id: id, playlists: playlistViewModel, songs: viewModel),
      ),
    ),
  );
}
