import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/objectbox.g.dart';

/// Stored song lists. The only way for view models to reach the database.
abstract class PlaylistRepository {
  List<Playlist> all();

  /// Stores a new list or the changes of an existing one.
  void save(Playlist playlist);

  /// Deletes the list together with its songs.
  void delete(int id);

  /// Songs of the list, in their order.
  List<SongRef> songsOf(int playlistId);

  /// Replaces the songs of the list with [songs], in this order.
  void setSongs(int playlistId, List<SongRef> songs);
}

class ObjectBoxPlaylistRepository implements PlaylistRepository {
  final Store _store;

  ObjectBoxPlaylistRepository(this._store);

  Box<PlaylistItem> get _items => _store.box<PlaylistItem>();

  @override
  List<Playlist> all() => _store.box<Playlist>().getAll();

  @override
  void save(Playlist playlist) => _store.box<Playlist>().put(playlist);

  @override
  void delete(int id) {
    _store.runInTransaction(TxMode.write, () {
      _items.removeMany(_itemIdsOf(id));
      _store.box<Playlist>().remove(id);
    });
  }

  @override
  List<SongRef> songsOf(int playlistId) {
    final query = (_items.query(PlaylistItem_.playlistId.equals(playlistId))..order(PlaylistItem_.position)).build();
    try {
      return [for (final item in query.find()) item.ref];
    } finally {
      query.close();
    }
  }

  @override
  void setSongs(int playlistId, List<SongRef> songs) {
    _store.runInTransaction(TxMode.write, () {
      _items.removeMany(_itemIdsOf(playlistId));
      _items.putMany([
        for (final (position, song) in songs.indexed)
          PlaylistItem(
            playlistId: playlistId,
            songNumber: song.songNumber,
            mySongId: song.mySongId,
            position: position,
          ),
      ]);
    });
  }

  List<int> _itemIdsOf(int playlistId) {
    final query = _items.query(PlaylistItem_.playlistId.equals(playlistId)).build();
    try {
      return query.findIds();
    } finally {
      query.close();
    }
  }
}
