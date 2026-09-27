import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/objectbox.g.dart';

/// Stored user songs. The only way for view models to reach the database.
abstract class MySongRepository {
  /// All user songs, see [compareMySongs] for the order.
  List<MySong> all();

  /// Stores a new song or the changes of an existing one.
  void save(MySong song);

  /// Deletes the song, also from every song list.
  void delete(int id);
}

/// Polish alphabetical order of titles, ignoring letter case, like the old iOS app.
/// Songs with the same title keep a stable order: lower id first.
int compareMySongs(MySong a, MySong b) {
  final byTitle = comparePolish(a.title, b.title);
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

class ObjectBoxMySongRepository implements MySongRepository {
  final Store _store;

  ObjectBoxMySongRepository(this._store);

  @override
  List<MySong> all() => _store.box<MySong>().getAll()..sort(compareMySongs);

  @override
  void save(MySong song) => _store.box<MySong>().put(song);

  @override
  void delete(int id) {
    _store.runInTransaction(TxMode.write, () {
      final query = _store.box<PlaylistItem>().query(PlaylistItem_.mySongId.equals(id)).build();
      try {
        query.remove();
      } finally {
        query.close();
      }
      _store.box<MySong>().remove(id);
    });
  }
}
