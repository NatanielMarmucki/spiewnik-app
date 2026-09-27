import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_categories.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

const categories = SongCategories([
  SongCategory(id: 'I', name: 'Bóg', subcategories: [
    SongSubcategory(id: 1, categoryId: 'I', name: 'Chwała', songs: [1, 2, 5]),
    SongSubcategory(id: 4, categoryId: 'I', name: 'Duch Święty', songs: [3, 5]),
  ]),
  SongCategory(id: 'II', name: 'Droga', subcategories: [
    SongSubcategory(id: 7, categoryId: 'II', name: 'Wezwanie', songs: [4]),
  ]),
]);

void main() {
  SongViewModel open() => SongViewModel(
        FakeSongRepository([
          for (var n = 1; n <= 6; n++)
            Song(number: n, title: n == 5 ? 'Źródło' : 'Pieśń $n', content: 'treść', favorite: false),
        ]),
        categories: categories,
      );

  List<int> numbers(List<Song> songs) => songs.map((song) => song.number).toList();

  test('without a filter lists every song, also those without a category', () {
    expect(numbers(open().filteredSongsNotifier.value), [1, 2, 3, 4, 5, 6]);
  });

  test('joins the selected subcategories with OR', () {
    final viewModel = open()..subcategoryFilter = {4, 7};

    expect(numbers(viewModel.filteredSongsNotifier.value), [3, 4, 5]);
    expect(viewModel.songCountIn({4, 7}), 3);
    expect(viewModel.songCountIn({1, 4}), 4);
    expect(viewModel.songCountIn({}), 6);
  });

  test('joins the filter and the search with AND', () {
    final viewModel = open()
      ..subcategoryFilter = {1}
      ..searchText = 'zrodlo';
    expect(numbers(viewModel.filteredSongsNotifier.value), [5]);

    viewModel.subcategoryFilter = {7};
    expect(viewModel.filteredSongsNotifier.value, isEmpty);
  });

  test('groups into sections in book order; a song in two sections is in both', () {
    final viewModel = open()..subcategoryFilter = {4, 1};

    final sections = viewModel.sections(viewModel.filteredSongsNotifier.value);

    expect(sections.map((s) => s.subcategory.id), [1, 4]);
    expect(numbers(sections[0].songs), [1, 2, 5]);
    expect(numbers(sections[1].songs), [3, 5]);
  });

  test('removing the last subcategory clears the filter', () {
    final viewModel = open()..subcategoryFilter = {7};

    viewModel.removeFromSubcategoryFilter(7);

    expect(viewModel.subcategoryFilter, isEmpty);
    expect(viewModel.filteredSongsNotifier.value, hasLength(6));
  });
}
