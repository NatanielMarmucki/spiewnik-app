import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/data/repositories/playlist_repository.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';

import '../support/test_store.dart';

void main() {
  late TestStore testStore;
  late ObjectBoxPlaylistRepository repository;
  final now = DateTime(2026, 9, 27, 12);

  setUp(() {
    testStore = TestStore.open();
    repository = ObjectBoxPlaylistRepository(testStore.store);
  });
  tearDown(() => testStore.close());

  Playlist playlist(String name) {
    final list = Playlist(name: name, createdAt: now, updatedAt: now);
    repository.save(list);
    return list;
  }

  test('stores a list with its date as a day, color and icon', () {
    final saved = playlist('Ślub')
      ..date = DateTime(2026, 10, 4, 23, 30)
      ..color = PlaylistColor.lilac
      ..icon = PlaylistIcon.rings;
    repository.save(saved);

    final read = repository.all().single;
    expect(read.name, 'Ślub');
    expect(read.date, DateTime(2026, 10, 4));
    expect(read.color, PlaylistColor.lilac);
    expect(read.icon, PlaylistIcon.rings);
  });

  test('keeps the order of songs and replaces them as a whole', () {
    final list = playlist('Niedziela');
    repository.setSongs(list.id, const [SongRef.songbook(8), SongRef.mine(3), SongRef.songbook(4)]);
    expect(repository.songsOf(list.id), const [SongRef.songbook(8), SongRef.mine(3), SongRef.songbook(4)]);

    repository.setSongs(list.id, const [SongRef.songbook(4), SongRef.songbook(8)]);
    expect(repository.songsOf(list.id), const [SongRef.songbook(4), SongRef.songbook(8)]);
  });

  test('songs of one list do not leak into another', () {
    final a = playlist('A');
    final b = playlist('B');
    repository.setSongs(a.id, const [SongRef.songbook(1)]);
    repository.setSongs(b.id, const [SongRef.songbook(2)]);

    expect(repository.songsOf(a.id), const [SongRef.songbook(1)]);
    expect(repository.songsOf(b.id), const [SongRef.songbook(2)]);
  });

  test('deleting a list deletes its songs', () {
    final list = playlist('A');
    repository.setSongs(list.id, const [SongRef.songbook(1)]);

    repository.delete(list.id);

    expect(repository.all(), isEmpty);
    expect(testStore.store.box<PlaylistItem>().count(), 0);
  });

  test('deleting a user song removes it from every list', () {
    final mySongs = ObjectBoxMySongRepository(testStore.store);
    final mine = MySong(title: 'Moja', content: 'treść', createdAt: now, updatedAt: now);
    mySongs.save(mine);
    final a = playlist('A');
    final b = playlist('B');
    repository.setSongs(a.id, [const SongRef.songbook(1), SongRef.mine(mine.id)]);
    repository.setSongs(b.id, [SongRef.mine(mine.id)]);

    mySongs.delete(mine.id);

    expect(repository.songsOf(a.id), const [SongRef.songbook(1)]);
    expect(repository.songsOf(b.id), isEmpty);
    expect(mySongs.all(), isEmpty);
  });
}
