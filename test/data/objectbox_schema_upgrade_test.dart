import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/data/repositories/playlist_repository.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

import '../support/objectbox_v12.g.dart' as v12;

/// The update from 12.0.0: a database written with the old schema (Song, MySong) opens with the new
/// one (plus Playlist, PlaylistItem), and favorites and user songs come through unchanged.
void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('spiewnik_upgrade_'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('favorites and user songs survive the new schema, and lists can be stored next to them', () {
    final created = DateTime(2025, 5, 1, 10);
    final old = Store(v12.getObjectBoxModel(), directory: directory.path);
    old.box<Song>().putMany([
      Song(number: 1, title: 'Pierwsza', content: 'treść 1', favorite: false),
      Song(number: 8, title: 'Chwalże ma duszo', content: 'treść 8', favorite: true),
    ]);
    old.box<MySong>().put(MySong(title: 'Wieczorna', content: 'Zostań z nami', createdAt: created, updatedAt: created));
    old.close();

    final store = Store(getObjectBoxModel(), directory: directory.path);
    addTearDown(store.close);

    final songs = ObjectBoxSongRepository(store);
    expect(songs.all().map((song) => song.number), [1, 8]);
    expect(songs.favorites().map((song) => song.number), [8]);
    final mine = ObjectBoxMySongRepository(store).all().single;
    expect((mine.title, mine.content, mine.createdAt), ('Wieczorna', 'Zostań z nami', created));

    final playlists = ObjectBoxPlaylistRepository(store);
    expect(playlists.all(), isEmpty);
    final list = Playlist(name: 'Niedziela', createdAt: created, updatedAt: created);
    playlists.save(list);
    playlists.setSongs(list.id, [const SongRef.songbook(8), SongRef.mine(mine.id)]);
    expect(playlists.songsOf(list.id), [const SongRef.songbook(8), SongRef.mine(mine.id)]);
  });
}
