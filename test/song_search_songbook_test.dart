import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_search.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

/// Search on the real songbook from the asset, not on made-up strings.
void main() {
  late List<Song> songbook;
  late SongViewModel viewModel;

  setUp(() {
    songbook = SongsData.fromJsonString(File('assets/songs_data.json').readAsStringSync()).songs;
    viewModel = SongViewModel(FakeSongRepository(songbook));
  });

  /// Every match, ranked; the list in the app shows at most [SongViewModel.searchResultLimit] of them.
  List<int> search(String query) => [for (final song in SongSearch().filter(songbook, query)) song.number];

  group('several words', () {
    // Independent of the search code: word starts found with a regular expression on the plain text.
    List<int> containingAll(List<String> wordStarts) => [
          for (final song in songbook)
            if (wordStarts.every((start) => RegExp('(?<![a-z])$start')
                .hasMatch(removePolishDiacritics('${song.title} ${song.content}'.toLowerCase()))))
              song.number,
        ];

    test('finds a song by words in a different order than in the text', () {
      // Song 9: "Chwałę daj Panu, o duszo moja!" - the phrase "duszo chwałę" appears in no song.
      expect(search('duszo chwałę'), contains(9));
    });

    test('every word must occur, not any of them', () {
      // "duszo" and "chwałę" are searched by their stems "dusz" and "chwal" (see "inflected forms").
      expect(search('duszo chwałę'), unorderedEquals(containingAll(['dusz', 'chwal'])));
      expect(search('duszo chwałę').length, lessThan(containingAll(['dusz']).length));
    });

    test('extra spaces between the words do not matter', () {
      expect(search('  duszo    chwałę '), search('duszo chwałę'));
    });

    test('highlights every word found in the title, with its original letters', () {
      viewModel.searchText = 'panu chwałę';
      final song = viewModel.filteredSongsNotifier.value.firstWhere((song) => song.number == 9);

      expect(viewModel.titleMatches(song), ['Panu', 'Chwałę']);
    });

    test('punctuation in the query is ignored, as in the text', () {
      expect(search('alleluja!'), search('alleluja'));
      expect(search('alleluja!'), hasLength(84));
    });
  });

  group('ranking', () {
    bool before(List<int> results, int first, int second) => results.indexOf(first) < results.indexOf(second);

    test('a song with the word in its title comes before one with it only in its last verse', () {
      // 52 "Na krzyżu Jezu zmarłeś" vs 28 "Jak mam powitać", which has "krzyż" only in its last verse.
      final results = search('krzyż');
      expect(results, containsAll([28, 52]));
      expect(before(results, 52, 28), isTrue);
    });

    test('the exact form comes before a form found by its stem', () {
      // 35 "Chwała Bogu chwała" vs 1 "Alleluja, chwalcie Pana": both match "chwał" in the title.
      final results = search('chwała');
      expect(before(results, 35, 1), isTrue);
    });

    test('words next to each other, in the order of the query, come before scattered ones', () {
      // 11 "Dajcie Panu chwałę" has them in order; 9 "Chwałę daj Panu" has them the other way round.
      final results = search('panu chwałę');
      expect(before(results, 11, 9), isTrue);
    });

    test('equal matches keep the order of numbers', () {
      // All four have the exact word "chwała" in the title and nothing else ranks them apart.
      final results = search('chwała');
      final equal = results.where([35, 374, 876, 1030].contains).toList();
      expect(equal, [35, 374, 876, 1030]);
    });

    test('a query of digits keeps the order of numbers', () {
      final results = search('12');
      expect(results, [...results]..sort());
      expect(results.first, 12);
    });

    test('without a query the list is the whole songbook in the order of numbers', () {
      expect(search(''), [for (final song in songbook) song.number]..sort());
    });
  });

  group('inflected forms', () {
    test('"chwała" finds a song that only has "chwały"', () {
      // Song 3 "Bądź Panu cześć": "chwały", no form of "chwała" that contains it.
      expect(search('chwała'), contains(3));
      expect(search('chwala'), contains(3));
    });

    test('"matko" finds a song that only has "matka"', () {
      expect(search('matko'), contains(1000)); // "Pewna matka bardzo"
    });

    test('"zbawien" finds "zbawienia"', () {
      expect(search('zbawien'), contains(3));
    });

    test('a word matches the beginning of words in the text, not their middle', () {
      // Song 24 has "pan" only inside "wspaniałości".
      expect(search('pan'), isNot(contains(24)));
      expect(search('pan'), contains(9)); // "Chwałę daj Panu"
    });

    test('a one- or two-letter word matches whole words only, so it does not return everything', () {
      expect(search('o'), contains(9)); // "o duszo moja"
      expect(search('o').length, lessThan(songbook.length ~/ 2));
    });
  });

  group('what the content is split on (#49)', () {
    test('verse numbers from 10 up leave no lone 0 behind: "0" finds songs by number only', () {
      final found = search('0');
      expect(found, isNotEmpty);
      expect(found.where((number) => !'$number'.contains('0')), isEmpty);
    });

    test('the x of repeat markers (/x3, 3x) is not a word; only a title with „(X)” matches', () {
      expect(search('x'), [870]);
    });

    test('a hyphen separates words instead of gluing them: "Wiesz-li" is "wiesz li"', () {
      expect(search('wiesz li'), contains(1863));
      expect(search('wiesz-li'), contains(1863));
    });

    test('a word right after a repeat marker still matches from its start', () {
      expect(search('jerycho'), contains(1013));
    });
  });

  group('long results (#52)', () {
    test('a common word shows the best 100 of its matches and says how many there are', () {
      viewModel.searchText = 'pan';

      expect(viewModel.filteredSongsNotifier.value, hasLength(SongViewModel.searchResultLimit));
      expect(viewModel.matchCount, search('pan').length);
      expect(viewModel.filteredSongsNotifier.value.map((song) => song.number), search('pan').take(100));
    });

    test('a search by number is not cut, so no number disappears from the middle', () {
      viewModel.searchText = '19';

      expect(viewModel.filteredSongsNotifier.value.length, greaterThan(SongViewModel.searchResultLimit));
      expect(viewModel.matchCount, viewModel.filteredSongsNotifier.value.length);
    });

    test('a narrow search is not affected', () {
      viewModel.searchText = 'matko';

      expect(viewModel.filteredSongsNotifier.value.length, viewModel.matchCount);
    });
  });
}
