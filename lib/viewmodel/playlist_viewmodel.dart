import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/data/repositories/playlist_repository.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_date.dart';
import 'package:spiewnik/model/song_model.dart';

/// What the list form edits.
typedef PlaylistDraft = ({String name, DateTime? date, PlaylistColor color, PlaylistIcon icon});

/// A song on a list, with the song it points at.
class PlaylistEntry {
  final Song? song;
  final MySong? mySong;

  const PlaylistEntry.songbook(Song this.song) : mySong = null;

  const PlaylistEntry.mine(MySong this.mySong) : song = null;

  SongRef get ref => song != null ? SongRef.songbook(song!.number) : SongRef.mine(mySong!.id);

  String get title => song?.title ?? mySong!.title;

  String get content => song?.content ?? mySong!.content;

  /// Null for a user song.
  int? get number => song?.number;
}

/// A list with its songs.
class PlaylistDetails {
  final Playlist playlist;
  final List<PlaylistEntry> entries;

  const PlaylistDetails(this.playlist, this.entries);

  List<SongRef> get refs => [for (final entry in entries) entry.ref];
}

enum PlaylistGroup { upcoming, undated, past }

/// How adding songs to a list went: duplicates are skipped.
typedef AddSongsResult = ({int added, int skipped});

class PlaylistViewModel {
  static const String showListsKey = 'mySongsShowLists';
  static const String reorderHintSeenKey = 'playlistReorderHintSeen';

  final PlaylistRepository repository;
  final SongRepository songs;
  final MySongRepository mySongs;
  final DateTime Function() _now;

  /// All lists with their songs, in no particular order; see [groups].
  final ValueNotifier<List<PlaylistDetails>> playlistsNotifier = ValueNotifier([]);

  /// Whether the „Moje” tab shows „Listy” (Lists) instead of „Pieśni” (Songs). Remembered.
  final ValueNotifier<bool> showListsNotifier = ValueNotifier(false);

  /// Whether the user has reordered a list once; until then the list suggests how.
  final ValueNotifier<bool> reorderHintSeenNotifier = ValueNotifier(false);

  /// Completes when the remembered settings are read. Useful in tests.
  late final Future<void> loaded;

  PlaylistViewModel(this.repository, {required this.songs, required this.mySongs, DateTime Function()? now})
      : _now = now ?? DateTime.now {
    reload();
    loaded = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    showListsNotifier.value = prefs.getBool(showListsKey) ?? false;
    reorderHintSeenNotifier.value = prefs.getBool(reorderHintSeenKey) ?? false;
  }

  Future<void> setShowLists(bool value) async {
    showListsNotifier.value = value;
    await (await SharedPreferences.getInstance()).setBool(showListsKey, value);
  }

  /// Reads the lists again, e.g. after a user song was edited or deleted.
  void reload() {
    final mine = {for (final song in mySongs.all()) song.id: song};
    playlistsNotifier.value = [
      for (final playlist in repository.all())
        PlaylistDetails(playlist, [
          // A song that no longer exists is left out rather than shown empty.
          for (final ref in repository.songsOf(playlist.id))
            if (_entry(ref, mine) case final entry?) entry,
        ]),
    ];
  }

  PlaylistEntry? _entry(SongRef ref, Map<int, MySong> mine) {
    if (ref.isMine) {
      final song = mine[ref.mySongId];
      return song == null ? null : PlaylistEntry.mine(song);
    }
    final song = songs.byNumber(ref.songNumber);
    return song == null ? null : PlaylistEntry.songbook(song);
  }

  PlaylistDetails? byId(int id) => playlistsNotifier.value.where((details) => details.playlist.id == id).firstOrNull;

  DateTime get _today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  PlaylistGroup groupOf(Playlist playlist) {
    final date = playlist.date;
    if (date == null) {
      return PlaylistGroup.undated;
    }
    return date.isBefore(_today) ? PlaylistGroup.past : PlaylistGroup.upcoming;
  }

  /// Lists in groups, each only when it has any: upcoming from the nearest date, undated from the last
  /// changed, past from the most recent.
  List<(PlaylistGroup, List<PlaylistDetails>)> groups() {
    int byDate(PlaylistDetails a, PlaylistDetails b) => a.playlist.date!.compareTo(b.playlist.date!);
    final all = playlistsNotifier.value;
    List<PlaylistDetails> inGroup(PlaylistGroup group) =>
        all.where((details) => groupOf(details.playlist) == group).toList();
    return [
      (PlaylistGroup.upcoming, inGroup(PlaylistGroup.upcoming)..sort(byDate)),
      (
        PlaylistGroup.undated,
        inGroup(PlaylistGroup.undated)..sort((a, b) => b.playlist.updatedAt.compareTo(a.playlist.updatedAt)),
      ),
      (PlaylistGroup.past, inGroup(PlaylistGroup.past)..sort((a, b) => byDate(b, a))),
    ].where((group) => group.$2.isNotEmpty).toList();
  }

  Playlist create(PlaylistDraft draft, {List<SongRef> songs = const []}) {
    final now = _now();
    final playlist = Playlist(name: draft.name.trim(), createdAt: now, updatedAt: now)
      ..date = draft.date
      ..color = draft.color
      ..icon = draft.icon;
    repository.save(playlist);
    if (songs.isNotEmpty) {
      repository.setSongs(playlist.id, _inAddingOrder(songs.toSet().toList()));
    }
    reload();
    return playlist;
  }

  void update(Playlist playlist, PlaylistDraft draft) {
    playlist
      ..name = draft.name.trim()
      ..date = draft.date
      ..color = draft.color
      ..icon = draft.icon
      ..updatedAt = _now();
    repository.save(playlist);
    reload();
  }

  void delete(Playlist playlist) {
    repository.delete(playlist.id);
    reload();
  }

  /// How many of [refs] are on [playlist] already.
  int alreadyOn(Playlist playlist, List<SongRef> refs) {
    final on = repository.songsOf(playlist.id).toSet();
    return refs.where(on.contains).length;
  }

  /// Adds [refs] at the end, songbook songs in order of numbers; songs already on the list are skipped.
  AddSongsResult addSongs(Playlist playlist, List<SongRef> refs) {
    final current = repository.songsOf(playlist.id);
    final toAdd = _inAddingOrder(refs.toSet().difference(current.toSet()).toList());
    if (toAdd.isNotEmpty) {
      _setSongs(playlist, [...current, ...toAdd]);
    }
    return (added: toAdd.length, skipped: refs.toSet().length - toAdd.length);
  }

  static List<SongRef> _inAddingOrder(List<SongRef> refs) =>
      refs..sort((a, b) => a.isMine == b.isMine ? a.songNumber.compareTo(b.songNumber) : (a.isMine ? 1 : -1));

  /// Removes the song at [index]; returns it, so the removal can be undone with [insert].
  SongRef removeAt(Playlist playlist, int index) {
    final current = repository.songsOf(playlist.id);
    final removed = current.removeAt(index);
    _setSongs(playlist, current);
    return removed;
  }

  void insert(Playlist playlist, int index, SongRef ref) {
    final current = repository.songsOf(playlist.id);
    if (current.contains(ref)) {
      return;
    }
    _setSongs(playlist, current..insert(index.clamp(0, current.length), ref));
  }

  /// Moves the song at [from] so that it ends up at [to] (both in the list before the move).
  void move(Playlist playlist, int from, int to) {
    final current = repository.songsOf(playlist.id);
    if (from == to || from < 0 || from >= current.length) {
      return;
    }
    current.insert(to.clamp(0, current.length - 1), current.removeAt(from));
    _setSongs(playlist, current);
  }

  Future<void> markReorderHintSeen() async {
    if (reorderHintSeenNotifier.value) {
      return;
    }
    reorderHintSeenNotifier.value = true;
    await (await SharedPreferences.getInstance()).setBool(reorderHintSeenKey, true);
  }

  void _setSongs(Playlist playlist, List<SongRef> refs) {
    repository.setSongs(playlist.id, refs);
    playlist.updatedAt = _now();
    repository.save(playlist);
    reload();
  }

  /// Song numbers in the order of the list, e.g. „8 · 114 · 4”; a user song by its title in quotes.
  static String numbersText(PlaylistDetails details) =>
      details.entries.map((entry) => entry.number?.toString() ?? '„${entry.title}”').join(' · ');

  /// The list as plain text for sharing: the name with the date, then numbered titles.
  static String shareText(PlaylistDetails details) {
    final date = details.playlist.date;
    return [
      date == null ? details.playlist.name : '${details.playlist.name} · ${formatDay(date, withYear: true)}',
      for (final (index, entry) in details.entries.indexed)
        '${index + 1}. ${entry.title}${entry.number == null ? '' : ' (${entry.number})'}',
    ].join('\n');
  }
}
