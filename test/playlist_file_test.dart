import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/export/playlist_file.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

void main() {
  final details = PlaylistDetails(
    Playlist(name: 'Ślub', createdAt: DateTime(2026), updatedAt: DateTime(2026))
      ..date = DateTime(2026, 10, 4)
      ..color = PlaylistColor.lilac
      ..icon = PlaylistIcon.rings,
    [
      PlaylistEntry.songbook(Song(number: 640, title: 'Pieśń ślubna', content: 'treść', favorite: false)),
      PlaylistEntry.mine(
          MySong(id: 7, title: 'Nasza', content: 'Zostań z nami', createdAt: DateTime(2026), updatedAt: DateTime(2026))),
    ],
  );

  test('round trip: songbook songs by number, user songs with their text', () {
    final file = PlaylistFile.decode(PlaylistFile.encode(details));

    expect(file.draft, (name: 'Ślub', date: DateTime(2026, 10, 4), color: PlaylistColor.lilac, icon: PlaylistIcon.rings));
    expect(file.songs, [
      (number: 640, title: null, content: null),
      (number: null, title: 'Nasza', content: 'Zostań z nami'),
    ]);
  });

  test('unknown color and icon fall back to the defaults', () {
    final file = PlaylistFile.decode('{"version":1,"name":"A","date":null,"colorKey":"gold","iconKey":"x","songs":[]}');

    expect((file.draft.color, file.draft.icon, file.draft.date), (PlaylistColor.saffron, PlaylistIcon.note, null));
  });

  test('rejects what is not a song list', () {
    for (final json in ['[]', '{"version":2,"name":"A","songs":[]}', '{"version":1,"name":" ","songs":[]}', 'x']) {
      expect(() => PlaylistFile.decode(json), throwsFormatException, reason: json);
    }
  });
}
