import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/view/add_to_playlist_sheet.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/widgets/go_to_song_dialog.dart';
import 'package:spiewnik/view/widgets/song_bottom_bar.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';

/// Songs of a list, when a song is opened from it: the pages follow the order of the list.
class SongListContext {
  final String name;
  final List<PlaylistEntry> entries;

  const SongListContext({required this.name, required this.entries});
}

/// A song screen: the song text is a page in a [PageView] over the whole songbook, so moving to the
/// previous or next song turns the page under the bars instead of replacing the screen.
///
/// With a [listContext] the pages are the songs of that list instead, user songs included, and
/// [initialIndex] is the position on it.
class SongDetailView extends StatefulWidget {
  final Song? song;
  final SongViewModel viewModel;

  /// For „Dodaj do listy” (Add to list) in the options; without it the option is not there.
  final PlaylistViewModel? playlistViewModel;

  /// Opens a list after a song was added to it, from the snackbar.
  final void Function(BuildContext context, int playlistId)? onOpenPlaylist;

  final SongListContext? listContext;
  final int initialIndex;

  const SongDetailView({
    super.key,
    required Song this.song,
    required this.viewModel,
    this.playlistViewModel,
    this.onOpenPlaylist,
  })  : listContext = null,
        initialIndex = 0;

  const SongDetailView.inList({
    super.key,
    required SongListContext this.listContext,
    required this.initialIndex,
    required this.viewModel,
    this.playlistViewModel,
    this.onOpenPlaylist,
  }) : song = null;

  @override
  SongDetailViewState createState() => SongDetailViewState();
}

/// What one page shows.
class _Page {
  /// Null for a user song.
  final Song? song;
  final PlaylistEntry? entry;

  const _Page(this.song, this.entry);

  String get title => song?.title ?? entry!.title;
  String get content => song?.content ?? entry!.content;

  /// „8. Chwalże ma duszo”, or only the title of a user song.
  String get heading => song == null ? title : '${song!.number}. ${song!.title}';
}

class SongDetailViewState extends State<SongDetailView> {
  late final PageController _pageController;

  /// Position of the shown song: in [SongViewModel.allSongsNotifier], which lists songs by number, or on the list.
  late int _index;

  /// Anchor for the share sheet on iPad, where it is a popover next to the button.
  final GlobalKey _optionsButtonKey = GlobalKey();

  List<Song> get _songs => widget.viewModel.allSongsNotifier.value;

  SongListContext? get _list => widget.listContext;

  int get _count => _list?.entries.length ?? _songs.length;

  /// The page at [index]. In a list the song is taken from the songbook anew, so a favorite toggled here
  /// shows at once.
  _Page _pageAt(List<Song> songs, int index) {
    final list = _list;
    if (list == null) {
      return _Page(songs[index], null);
    }
    final entry = list.entries[index];
    final number = entry.number;
    if (number == null) {
      return _Page(null, entry);
    }
    final at = _indexOfNumber(songs, number);
    return _Page(at >= 0 ? songs[at] : entry.song, entry);
  }

  _Page get _page => _pageAt(_songs, _index);

  @override
  void initState() {
    super.initState();
    ScreenWakeLock.acquire();
    _index = _list == null ? _indexOfNumber(_songs, widget.song!.number) : widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    ScreenWakeLock.release();
    super.dispose();
  }

  static int _indexOfNumber(List<Song> songs, int number) => songs.indexWhere((s) => s.number == number);

  @override
  Widget build(BuildContext context) {
    // Toggling a favorite reloads the list with new Song objects; order and length stay the same.
    return ValueListenableBuilder<List<Song>>(
      valueListenable: widget.viewModel.allSongsNotifier,
      builder: (context, songs, _) {
        final page = _pageAt(songs, _index);
        final song = page.song;
        final list = _list;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (list != null)
                  Semantics(
                    button: true,
                    label: 'Wróć do listy ${list.name}',
                    // Its own node: the app bar merges its title into one header otherwise.
                    container: true,
                    excludeSemantics: true,
                    onTap: () => Navigator.pop(context),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          list.name.toUpperCase(),
                          style: SectionHeader.style(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                Text(
                  page.heading,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                  maxLines: list == null ? null : 1,
                  overflow: list == null ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (song != null)
                IconButton(
                  tooltip: song.favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                  onPressed: () => widget.viewModel.toggleFavoriteStatus(song),
                  icon: Icon(
                    song.favorite ? Icons.favorite : Icons.favorite_border,
                    size: 24.0,
                    color: song.favorite ? context.appColors.favorite : null,
                  ),
                ),
              IconButton(
                key: _optionsButtonKey,
                tooltip: 'Opcje pieśni',
                onPressed: _showOptions,
                icon: const Icon(Icons.more_vert, size: 24.0),
              ),
            ],
          ),
          // Only the text moves; the bars stay (docs/DESIGN-SYSTEM.md, section 5, "Moving between songs").
          // The builder keeps only the shown page alive (two while dragging), not 2000.
          body: PageView.builder(
            controller: _pageController,
            physics: const _PageTurnPhysics(),
            itemCount: _count,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final page = _pageAt(songs, index);
              return _PageEdge(
                controller: _pageController,
                index: index,
                child: SongContent(
                  key: ValueKey(index),
                  content: page.content,
                ),
              );
            },
          ),
          bottomNavigationBar: list == null
              ? SongBottomBar(
                  previousNumber: _index > 0 ? songs[_index - 1].number : null,
                  nextNumber: _index < songs.length - 1 ? songs[_index + 1].number : null,
                  onPrevious: () => _turnTo(_index - 1),
                  onNext: () => _turnTo(_index + 1),
                  onGoToNumber: _showSearchDialog,
                )
              // Positions on the list, 1-based: „← 2/7” and „4/7 →”.
              : SongBottomBar(
                  previousNumber: _index > 0 ? _index : null,
                  nextNumber: _index < _count - 1 ? _index + 2 : null,
                  total: _count,
                  onPrevious: () => _turnTo(_index - 1),
                  onNext: () => _turnTo(_index + 1),
                  onGoToNumber: _showSearchDialog,
                ),
        );
      },
    );
  }

  /// Options sheet from the three dots. Items close the sheet **before** their action,
  /// so the system share sheet does not open on top of ours.
  Future<void> _showOptions() async {
    final fontSizeModel = context.read<FontSizeModel>();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      builder: (sheetContext) => SongOptionsSheet(
        options: [
          SongOption(
            icon: Icons.ios_share,
            label: 'Udostępnij pieśń',
            onTap: () {
              Navigator.pop(sheetContext);
              _share();
            },
          ),
          SongOption(
            icon: Icons.text_fields,
            label: 'Rozmiar tekstu',
            value: '${fontSizeModel.fontSize.round()}',
            onTap: () {
              Navigator.pop(sheetContext);
              _openSettings();
            },
          ),
          if (widget.playlistViewModel != null)
            SongOption(
              icon: Icons.playlist_add,
              label: 'Dodaj do listy',
              onTap: () {
                Navigator.pop(sheetContext);
                _addToPlaylist();
              },
            ),
          SongOption(
            icon: Icons.content_copy,
            label: 'Kopiuj tekst',
            onTap: () {
              Navigator.pop(sheetContext);
              _copyText();
            },
          ),
        ],
      ),
    );
  }

  void _addToPlaylist() {
    final page = _page;
    showAddToPlaylistSheet(
      context,
      viewModel: widget.playlistViewModel!,
      songs: [page.song != null ? PlaylistEntry.songbook(page.song!) : page.entry!],
      onOpen: (id) => widget.onOpenPlaylist?.call(context, id),
    );
  }

  Future<void> _share() async {
    final page = _page;
    final box = _optionsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: '${page.heading}\n\n${page.content}',
        subject: page.heading,
        // Required on iPad, where the system sheet is a popover anchored to the button.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _page.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Treść skopiowana do schowka')),
    );
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsView()));
  }

  Future<void> _showSearchDialog() async {
    final target = await showGoToSongDialog(context, widget.viewModel);
    if (!mounted || target == null) {
      return;
    }
    if (_list != null) {
      // Going to a number leaves the list: the songbook opens at that song, in place of this screen.
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, __) => SongDetailView(
            song: target,
            viewModel: widget.viewModel,
            playlistViewModel: widget.playlistViewModel,
            onOpenPlaylist: widget.onOpenPlaylist,
          ),
        ),
      );
      return;
    }
    // Opening the book at a page, not turning through the pages in between: no animation.
    _pageController.jumpToPage(_indexOfNumber(_songs, target.number));
  }

  /// Turns to the neighboring page like the swipe does; without animation when the system asks for less motion.
  void _turnTo(int index) {
    if (index < 0 || index >= _count) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(index, duration: Durations.short4, curve: Easing.emphasizedDecelerate);
    }
  }
}

/// The edge of a page while it turns: a hairline in the line color on the seam between two songs, like the
/// edge of a sheet of paper (a hairline instead of a shadow, docs/DESIGN-SYSTEM.md). At rest it is not drawn,
/// because the seam is off screen and the page's own edge would show at the screen edge.
class _PageEdge extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const _PageEdge({required this.controller, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final line = context.appColors.line;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients ? controller.page : null;
        // The seam on this page's left edge is on screen while the view is between the previous page and this one.
        final turning = page != null && page > index - 1 && page < index;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: turning ? Border(left: BorderSide(color: line, width: 0)) : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// Page physics with a stiffer spring than the default, critically damped: after a swipe the page settles
/// in about 0.45 s instead of 0.9 s, without overshooting (docs/DESIGN-SYSTEM.md, section 5).
class _PageTurnPhysics extends PageScrollPhysics {
  const _PageTurnPhysics({super.parent});

  @override
  _PageTurnPhysics applyTo(ScrollPhysics? ancestor) => _PageTurnPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: 0.5, stiffness: 300, ratio: 1.0);
}
