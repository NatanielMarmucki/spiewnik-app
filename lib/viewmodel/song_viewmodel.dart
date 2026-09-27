import 'package:flutter/foundation.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/song_categories.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_search.dart';
import 'package:flutter/material.dart';

class SongViewModel {
  final SongRepository repository;
  final ValueNotifier<List<Song>> allSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> favoriteSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> filteredSongsNotifier = ValueNotifier([]);
  final SongSearch _search = SongSearch();
  String _searchText = '';

  /// The songbook's table of contents, for the category filter.
  final SongCategories categories;

  /// Ids of the subcategories the list is limited to; empty when there is no filter. Kept for the
  /// session only, across tabs, until the user clears it.
  final ValueNotifier<Set<int>> subcategoryFilterNotifier = ValueNotifier(const {});

  /// Numbers of the songs selected for adding to a list, or null outside the selection mode. Shared by the
  /// songbook and favorites, and kept across searches and filters.
  final ValueNotifier<Set<int>?> selectionNotifier = ValueNotifier(null);

  SongViewModel(this.repository, {this.categories = SongCategories.empty}) {
    _loadAllSongs();
    _loadFavoriteSongs();
    _filterSongs();
  }

  /// Text from the search field. The view asks for it to know whether it shows the full list.
  String get searchText => _searchText;

  set searchText(String value) {
    _searchText = value;
    _filterSongs();
  }

  Set<int> get subcategoryFilter => subcategoryFilterNotifier.value;

  set subcategoryFilter(Set<int> ids) {
    subcategoryFilterNotifier.value = Set.unmodifiable(ids);
    _filterSongs();
  }

  void removeFromSubcategoryFilter(int id) => subcategoryFilter = {...subcategoryFilter}..remove(id);

  /// How many songs of the songbook are in any of [subcategoryIds], or all songs when there are none:
  /// what „Pokaż N pieśni” (Show N songs) promises.
  int songCountIn(Set<int> subcategoryIds) => _inSubcategories(allSongsNotifier.value, subcategoryIds).length;

  List<Song> _inSubcategories(List<Song> songs, Set<int> subcategoryIds) {
    if (subcategoryIds.isEmpty) {
      return songs;
    }
    final numbers = categories.songsIn(subcategoryIds);
    return songs.where((song) => numbers.contains(song.number)).toList();
  }

  /// [songs] grouped by the selected subcategories, in the order of the book, each group ascending by
  /// number. A song in several selected subcategories is in each of their groups.
  List<SongSection> sections(List<Song> songs) {
    final byNumber = {for (final song in songs) song.number: song};
    return [
      for (final category in categories.categories)
        for (final subcategory in category.subcategories)
          if (subcategoryFilter.contains(subcategory.id))
            SongSection(category, subcategory, [
              // SongSubcategory songs are ascending, so each group is too.
              for (final number in subcategory.songs)
                if (byNumber[number] case final song?) song,
            ]),
    ];
  }

  bool get isSelecting => selectionNotifier.value != null;

  /// Enters the selection mode with [number] selected.
  void startSelection(int number) => selectionNotifier.value = {number};

  void toggleSelected(int number) {
    final selected = {...?selectionNotifier.value};
    selected.contains(number) ? selected.remove(number) : selected.add(number);
    selectionNotifier.value = selected;
  }

  /// Unselects everything, staying in the selection mode.
  void clearSelection() => selectionNotifier.value = {};

  void endSelection() => selectionNotifier.value = null;

  /// The selected songs, by number.
  List<Song> get selectedSongs {
    final selected = selectionNotifier.value ?? const {};
    return allSongsNotifier.value.where((song) => selected.contains(song.number)).toList();
  }

  void _loadAllSongs() {
    allSongsNotifier.value = _getAllSongs();
    _filterSongs();
  }

  void _loadFavoriteSongs() {
    favoriteSongsNotifier.value = _getFavoriteSongs();
  }

  /// How many songs the songbook has. Used by the "go to number" dialog and the scrollbar label.
  int get songCount => repository.count();

  /// Looks up the song for what the user typed in the "go to number" dialog.
  /// Accepts numbers from 1 to [songCount], like the hardcoded 1..2000 before,
  /// which is the whole songbook as long as the numbering has no gaps.
  GoToSongResult goToNumber(String input) {
    final number = int.tryParse(input.trim());
    if (number == null || number < 1 || number > songCount) {
      return const GoToSongResult(GoToSongOutcome.invalidNumber);
    }
    final song = findSongByNumber(number);
    return song == null ? const GoToSongResult(GoToSongOutcome.notFound) : GoToSongResult(GoToSongOutcome.found, song);
  }

  // Private on purpose: reads from the repository go only through the notifiers, because a view
  // calling these directly would bypass the list refresh.
  List<Song> _getAllSongs() => repository.all();

  List<Song> _getFavoriteSongs() => repository.favorites();

  Song? findSongByNumber(int number) => repository.byNumber(number);

  void toggleFavoriteStatus(Song song) {
    repository.setFavorite(song, !song.favorite);
    // Both lists, because a favorite changes both the row in the main list and the contents of the favorites list.
    _loadAllSongs();
    _loadFavoriteSongs();
  }

  void _filterSongs() {
    // The filter and the search both apply: a song has to pass each of them.
    final songs = _inSubcategories(allSongsNotifier.value, subcategoryFilter);
    if (_searchText.isEmpty) {
      filteredSongsNotifier.value = List.from(songs);
      return;
    }

    // Diacritics are removed from both sides, so "zrodlo" finds "źródło" and "źródło" finds "zrodlo".
    filteredSongsNotifier.value = _search.filter(songs, _searchText);
  }

  /// Parts of [song]'s title matching the words of the search, with the original letters; empty when
  /// nothing matches. Used by the list to highlight the hits (docs/DESIGN-SYSTEM.md, section 5).
  List<String> titleMatches(Song song) => _searchText.isEmpty ? const [] : _search.titleMatches(song, _searchText);

  Song? findNextSong(int currentNumber) {
    return findSongByNumber(currentNumber + 1);
  }

  Song? findPreviousSong(int currentNumber) {
    return findSongByNumber(currentNumber - 1);
  }
}

/// Songs of one subcategory in the filtered list, under an uppercase header „I · Duch Święty”.
class SongSection {
  final SongCategory category;
  final SongSubcategory subcategory;
  final List<Song> songs;

  const SongSection(this.category, this.subcategory, this.songs);
}

enum GoToSongOutcome {
  /// The song is in the songbook.
  found,

  /// Not a number, or outside 1..[SongViewModel.songCount].
  invalidNumber,

  /// A number inside the range, but there is no song with it.
  notFound,
}

class GoToSongResult {
  final GoToSongOutcome outcome;
  final Song? song;

  const GoToSongResult(this.outcome, [this.song]);
}
