import 'package:spiewnik/data/repositories/playlist_repository.dart';
import 'package:spiewnik/model/playlist_model.dart';

/// In-memory [PlaylistRepository] for tests of view models and views.
class FakePlaylistRepository implements PlaylistRepository {
  final List<Playlist> playlists = [];
  final Map<int, List<SongRef>> songs = {};
  int _nextId = 1;

  @override
  List<Playlist> all() => List.of(playlists);

  @override
  void save(Playlist playlist) {
    if (playlist.id == 0) {
      playlist.id = _nextId++;
    }
    playlists
      ..removeWhere((stored) => stored.id == playlist.id)
      ..add(playlist);
  }

  @override
  void delete(int id) {
    playlists.removeWhere((playlist) => playlist.id == id);
    songs.remove(id);
  }

  @override
  List<SongRef> songsOf(int playlistId) => List.of(songs[playlistId] ?? const []);

  @override
  void setSongs(int playlistId, List<SongRef> refs) => songs[playlistId] = List.of(refs);
}
