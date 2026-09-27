import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_playlist_repository.dart';
import 'support/fakes/fake_song_repository.dart';

void main() {
  late FakePlaylistRepository repository;
  late FakeMySongRepository mySongs;
  late DateTime now;
  late PlaylistViewModel viewModel;

  PlaylistDraft draft(String name, {DateTime? date}) =>
      (name: name, date: date, color: PlaylistColor.sky, icon: PlaylistIcon.star);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakePlaylistRepository();
    mySongs = FakeMySongRepository([
      MySong(title: 'Moja', content: 'moja treść', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    ]);
    now = DateTime(2026, 9, 27, 18);
    viewModel = PlaylistViewModel(
      repository,
      songs: FakeSongRepository([
        for (final n in [4, 8, 12, 114]) Song(number: n, title: 'Pieśń $n', content: 'treść $n', favorite: false),
      ]),
      mySongs: mySongs,
      now: () => now,
    );
  });

  List<SongRef> refsOf(Playlist playlist) => viewModel.byId(playlist.id)!.refs;

  test('creates a list with songs sorted by number, user songs last, without duplicates', () {
    final list = viewModel.create(
      draft('  Niedziela  '),
      songs: const [SongRef.mine(1), SongRef.songbook(12), SongRef.songbook(4), SongRef.songbook(12)],
    );

    expect(list.name, 'Niedziela');
    expect(refsOf(list), const [SongRef.songbook(4), SongRef.songbook(12), SongRef.mine(1)]);
    expect(viewModel.byId(list.id)!.entries.map((e) => e.title), ['Pieśń 4', 'Pieśń 12', 'Moja']);
  });

  test('adding skips songs already on the list and reports how many', () {
    final list = viewModel.create(draft('A'), songs: const [SongRef.songbook(8)]);

    final result = viewModel.addSongs(list, const [SongRef.songbook(12), SongRef.songbook(8), SongRef.songbook(4)]);

    expect(result, (added: 2, skipped: 1));
    expect(refsOf(list), const [SongRef.songbook(8), SongRef.songbook(4), SongRef.songbook(12)]);
    expect(viewModel.alreadyOn(list, const [SongRef.songbook(8), SongRef.songbook(114)]), 1);
  });

  test('moves, removes and undoes a removal', () {
    final list = viewModel.create(
      draft('A'),
      songs: const [SongRef.songbook(4), SongRef.songbook(8), SongRef.songbook(12)],
    );

    viewModel.move(list, 0, 2);
    expect(refsOf(list), const [SongRef.songbook(8), SongRef.songbook(12), SongRef.songbook(4)]);

    final removed = viewModel.removeAt(list, 1);
    expect(refsOf(list), const [SongRef.songbook(8), SongRef.songbook(4)]);

    viewModel.insert(list, 1, removed);
    expect(refsOf(list), const [SongRef.songbook(8), SongRef.songbook(12), SongRef.songbook(4)]);
  });

  test('a change of songs updates updatedAt', () {
    final list = viewModel.create(draft('A'));
    now = DateTime(2026, 9, 28);

    viewModel.addSongs(list, const [SongRef.songbook(4)]);

    expect(list.updatedAt, DateTime(2026, 9, 28));
  });

  test('groups: upcoming from the nearest, undated from the last changed, past from the most recent', () {
    viewModel.create(draft('za tydzień', date: DateTime(2026, 10, 4)));
    viewModel.create(draft('dziś', date: DateTime(2026, 9, 27)));
    viewModel.create(draft('bez daty, starsza'));
    now = DateTime(2026, 9, 27, 19);
    viewModel.create(draft('bez daty, nowsza'));
    viewModel.create(draft('dawno', date: DateTime(2026, 1, 1)));
    viewModel.create(draft('wczoraj', date: DateTime(2026, 9, 26)));

    final groups = viewModel.groups();

    expect(groups.map((g) => g.$1), [PlaylistGroup.upcoming, PlaylistGroup.undated, PlaylistGroup.past]);
    expect(groups.map((g) => g.$2.map((d) => d.playlist.name).toList()), [
      ['dziś', 'za tydzień'],
      ['bez daty, nowsza', 'bez daty, starsza'],
      ['wczoraj', 'dawno'],
    ]);
  });

  test('duplicating copies the songs and moves the date by a week', () {
    final list =
        viewModel.create(draft('Nabożeństwo', date: DateTime(2026, 10, 4)), songs: const [SongRef.songbook(8)]);

    final copy = viewModel.duplicate(list);

    expect(copy.name, 'Nabożeństwo (kopia)');
    expect(copy.date, DateTime(2026, 10, 11));
    expect(copy.color, PlaylistColor.sky);
    expect(refsOf(copy), const [SongRef.songbook(8)]);
    expect(viewModel.duplicate(viewModel.create(draft('x' * 60))).name.length, Playlist.maxNameLength);
  });

  test('a deleted user song disappears from the list after a reload', () {
    final list = viewModel.create(draft('A'), songs: const [SongRef.mine(1), SongRef.songbook(4)]);

    mySongs.delete(1);
    viewModel.reload();

    expect(viewModel.byId(list.id)!.entries.map((e) => e.title), ['Pieśń 4']);
  });

  test('share texts', () {
    final list = viewModel.create(
      draft('Nabożeństwo niedzielne', date: DateTime(2026, 10, 4)),
      songs: const [SongRef.songbook(8), SongRef.songbook(114), SongRef.mine(1)],
    );
    viewModel.move(list, 2, 0);
    final details = viewModel.byId(list.id)!;

    expect(PlaylistViewModel.numbersText(details), '„Moja” · 8 · 114');
    expect(
      PlaylistViewModel.shareText(details),
      'Nabożeństwo niedzielne — niedziela, 4 października 2026\n1. Moja\n2. Pieśń 8 (8)\n3. Pieśń 114 (114)',
    );
  });

  test('remembers the chosen subview and the reorder hint', () async {
    await viewModel.loaded;
    await viewModel.setShowLists(true);
    await viewModel.markReorderHintSeen();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PlaylistViewModel.showListsKey), isTrue);
    expect(prefs.getBool(PlaylistViewModel.reorderHintSeenKey), isTrue);
  });
}
