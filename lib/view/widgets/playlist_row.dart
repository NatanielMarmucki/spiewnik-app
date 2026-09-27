import 'package:flutter/material.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/polish_date.dart';
import 'package:spiewnik/model/polish_plural.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/widgets/playlist_icon.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';

/// A song list in a list: the tile with its icon, the name (Newsreader 17), dots and the number of songs,
/// and below a [subtitle] in Grotesk 13. At least 64 dp with a subtitle, 56 dp without.
class PlaylistRow extends StatelessWidget {
  final Playlist playlist;
  final int songCount;
  final String? subtitle;

  /// A past list: name in secondary text, gray icon.
  final bool past;
  final VoidCallback onTap;

  const PlaylistRow({
    super.key,
    required this.playlist,
    required this.songCount,
    this.subtitle,
    this.past = false,
    required this.onTap,
  });

  /// The date in words, without the year when it is the current one: „niedziela, 4 października”.
  static String? dateText(Playlist playlist, DateTime now) {
    final date = playlist.date;
    return date == null ? null : formatDay(date, withYear: date.year != now.year);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: [playlist.name, if (subtitle != null) subtitle!, songsCount(songCount)].join(', '),
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 56.0 : 64.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                PlaylistTile(icon: playlist.icon, color: playlist.color, dimmed: past),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LeaderRow(
                        title: Text(
                          playlist.name,
                          style: textTheme.titleMedium?.copyWith(color: past ? appColors.textSecondary : null),
                        ),
                        trailing: '$songCount',
                        trailingStyle: textTheme.titleSmall,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2.0),
                        Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: appColors.textTertiary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
