import 'dart:convert';

import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

/// A song in a `.spiewnik` file: a songbook song by number, or a user song with its full text.
typedef PlaylistFileSong = ({int? number, String? title, String? content});

/// The contents of a `.spiewnik` file.
class PlaylistFile {
  static const int version = 1;
  static const String extension = 'spiewnik';

  final PlaylistDraft draft;
  final List<PlaylistFileSong> songs;

  const PlaylistFile(this.draft, this.songs);

  /// `{"version": 1, "name", "date": "2026-10-04" | null, "colorKey", "iconKey", "songs": [{"number": 8},
  /// {"title", "content"}]}`: user songs go in full, because the receiver does not have them.
  static String encode(PlaylistDetails details) {
    final playlist = details.playlist;
    final date = playlist.date;
    return const JsonEncoder.withIndent('  ').convert({
      'version': version,
      'name': playlist.name,
      'date': date == null
          ? null
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'colorKey': playlist.colorKey,
      'iconKey': playlist.iconKey,
      'songs': [
        for (final entry in details.entries)
          entry.number != null ? {'number': entry.number} : {'title': entry.title, 'content': entry.content},
      ],
    });
  }

  /// Throws [FormatException] on a file that is not a song list of a known version. An unknown color or icon
  /// falls back to the default instead, so a newer app's file still opens.
  factory PlaylistFile.decode(String json) {
    try {
      final root = jsonDecode(json) as Map<String, dynamic>;
      if (root['version'] != version) {
        throw FormatException('Unsupported version: ${root['version']}');
      }
      final name = (root['name'] as String).trim();
      if (name.isEmpty) {
        throw const FormatException('Empty name');
      }
      final date = root['date'] as String?;
      return PlaylistFile(
        (
          name: name.length > Playlist.maxNameLength ? name.substring(0, Playlist.maxNameLength) : name,
          date: date == null ? null : DateTime.parse(date),
          color: PlaylistColor.values.asNameMap()[root['colorKey']] ?? PlaylistColor.saffron,
          icon: PlaylistIcon.values.asNameMap()[root['iconKey']] ?? PlaylistIcon.note,
        ),
        [
          for (final song in root['songs'] as List)
            (
              number: song['number'] as int?,
              title: song['title'] as String?,
              content: song['content'] as String?,
            ),
        ],
      );
    } on TypeError catch (error) {
      throw FormatException('Not a song list: $error');
    }
  }
}
