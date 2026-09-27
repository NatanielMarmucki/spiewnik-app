import 'package:objectbox/objectbox.dart';

/// Colors a list can have; the color lives only in its icon and in the color picker.
enum PlaylistColor { saffron, rose, sage, sky, lilac, clay }

/// Icons a list can have.
enum PlaylistIcon { cross, note, rings, book, star, candle }

/// A list of songs made by the user, e.g. for a service or a wedding, in the order they will be sung.
@Entity()
class Playlist {
  @Id()
  int id;

  /// Required, at most [maxNameLength] characters.
  String name;

  /// The day at midnight UTC, so a change of time zone does not move it to another day; see [date].
  @Property(type: PropertyType.date)
  DateTime? dateUtc;

  /// [PlaylistColor.name]; an unknown one reads as saffron.
  String colorKey;

  /// [PlaylistIcon.name]; an unknown one reads as a note.
  String iconKey;

  @Property(type: PropertyType.dateNano)
  DateTime createdAt;

  /// Changes with the name, date, color, icon and the songs, for the „Bez daty” (Undated) order.
  @Property(type: PropertyType.dateNano)
  DateTime updatedAt;

  Playlist({
    this.id = 0,
    required this.name,
    this.dateUtc,
    this.colorKey = 'saffron',
    this.iconKey = 'note',
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxNameLength = 60;

  /// The day only, as a local date at midnight.
  @Transient()
  DateTime? get date {
    final utc = dateUtc?.toUtc();
    return utc == null ? null : DateTime(utc.year, utc.month, utc.day);
  }

  set date(DateTime? day) => dateUtc = day == null ? null : DateTime.utc(day.year, day.month, day.day);

  @Transient()
  PlaylistColor get color => PlaylistColor.values.asNameMap()[colorKey] ?? PlaylistColor.saffron;

  set color(PlaylistColor value) => colorKey = value.name;

  @Transient()
  PlaylistIcon get icon => PlaylistIcon.values.asNameMap()[iconKey] ?? PlaylistIcon.note;

  set icon(PlaylistIcon value) => iconKey = value.name;
}

/// A song on a [Playlist], at [position] (0 first). Points at a songbook song by [songNumber] — the same
/// identification favorites use — or at a user song by [mySongId]; the other one is 0.
@Entity()
class PlaylistItem {
  @Id()
  int id;

  @Index()
  int playlistId;

  int songNumber;

  @Index()
  int mySongId;

  int position;

  PlaylistItem({
    this.id = 0,
    required this.playlistId,
    this.songNumber = 0,
    this.mySongId = 0,
    required this.position,
  });

  SongRef get ref => mySongId != 0 ? SongRef.mine(mySongId) : SongRef.songbook(songNumber);
}

/// Which song: a songbook one by number or a user one by id.
class SongRef {
  final int songNumber;
  final int mySongId;

  const SongRef.songbook(int number)
      : songNumber = number,
        mySongId = 0;

  const SongRef.mine(int id)
      : songNumber = 0,
        mySongId = id;

  bool get isMine => mySongId != 0;

  @override
  bool operator ==(Object other) => other is SongRef && other.songNumber == songNumber && other.mySongId == mySongId;

  @override
  int get hashCode => Object.hash(songNumber, mySongId);

  @override
  String toString() => isMine ? 'SongRef.mine($mySongId)' : 'SongRef.songbook($songNumber)';
}
