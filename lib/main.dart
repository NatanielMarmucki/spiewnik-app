import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'objectbox.g.dart';
import 'json_manager.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/migration/legacy_settings_migration.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/add_to_playlist_sheet.dart';
import 'package:spiewnik/view/my_tab_view.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/view/playlists_view.dart';
import 'package:spiewnik/view/widgets/outlined_pill_button.dart';
import 'package:spiewnik/data/repositories/playlist_repository.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/tablet_text_scale.dart';
import 'package:spiewnik/view/welcome_view.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_categories.dart';
import 'package:spiewnik/post_migration_welcome.dart';
import 'package:spiewnik/view/whats_new_sheet.dart';
import 'package:spiewnik/whats_new.dart';
import 'package:spiewnik/review_service.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

const String _kLastRunAppVersionKey = 'last_run_app_version';

/// Loads the songs and returns the version that ran before this start (null on a clean install or when it
/// could not be read) and the current one, for [WhatsNew].
Future<({String? previous, String? current})> initializeApp(JsonManager jsonManager) async {
  bool shouldForceUpdate = false;
  String? currentAppVersion;
  String? previousAppVersion;

  try {
    logger.i("Starting app initialization and version check...");
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    currentAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

    final lastRunAppVersion = prefs.getString(_kLastRunAppVersionKey);
    previousAppVersion = lastRunAppVersion;

    logger.i("Current app version: $currentAppVersion");
    logger.i("Stored app version: $lastRunAppVersion");

    if (lastRunAppVersion == null || lastRunAppVersion != currentAppVersion) {
      logger.i('Version mismatch or first launch. Forcing data update.');
      shouldForceUpdate = true;
    } else {
      logger.i('App versions match. No data update needed.');
    }
  } catch (e, stacktrace) {
    logger.e('Error during version check!', error: e, stackTrace: stacktrace);
    shouldForceUpdate = false;
  }

  await jsonManager.loadDataFromJsonIfNeeded(forceUpdate: shouldForceUpdate);

  if (shouldForceUpdate && currentAppVersion != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastRunAppVersionKey, currentAppVersion);
      logger.i('Successfully saved current app version: $currentAppVersion');
    } catch (e) {
      logger.e('Failed to save the new app version string!', error: e);
    }
  }
  return (previous: previousAppVersion, current: currentAppVersion);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final objectBoxStore = await openStore();
  final jsonLoader = JsonManager(objectBoxStore, logger);

  final versions = await initializeApp(jsonLoader);
  // After the songs are loaded, so favorites from the old iOS app can be matched by number.
  final coreDataResult = await CoreDataMigration.runOnStartup(store: objectBoxStore, logger: logger);
  // Before runApp, so FontSizeModel loads the migrated font size.
  final migratedFontSize = await LegacySettingsMigration(logger: logger).run();
  final categories = await _loadCategories();
  final showWhatsNew = await WhatsNew(logger: logger).decide(
    previousVersion: versions.previous,
    currentVersion: versions.current,
  );
  // From what the migrations returned in this session, not from their flags: see PostMigrationWelcome.
  final welcome = await PostMigrationWelcome(logger: logger).decide(
    coreDataResult: coreDataResult,
    migratedFontSize: migratedFontSize,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<Store>.value(value: objectBoxStore),
        ChangeNotifierProvider(create: (_) => FontSizeModel()),
        ChangeNotifierProvider(create: (_) => AppSettingsModel()),
        Provider(create: (_) => SettingsViewModel()),
      ],
      child: MyApp(store: objectBoxStore, categories: categories, welcome: welcome, showWhatsNew: showWhatsNew),
    ),
  );

  // Outside `build`: the review prompt is a side effect of launching, not part of drawing the screen
  // (point 7 of ARCHITECTURE-PROPOSAL.md). No `await`, so the first frame is not delayed.
  unawaited(ReviewService(logger: logger).onLaunch());
}

/// Without the table of contents the app still works, only without the category filter.
Future<SongCategories> _loadCategories() async {
  try {
    return await SongCategories.load(rootBundle);
  } catch (e, s) {
    logger.e('Could not read ${SongCategories.assetPath}. The category filter is off.', error: e, stackTrace: s);
    return SongCategories.empty;
  }
}

class MyApp extends StatelessWidget {
  final Store store;
  final SongCategories categories;

  /// Opens the „Co nowego” sheet over the home screen once, see [WhatsNew].
  final bool showWhatsNew;

  /// The one-time welcome screen after the migration from the old iOS app, shown first; null skips it.
  final WelcomeVariant? welcome;

  const MyApp({
    super.key,
    required this.store,
    this.categories = SongCategories.empty,
    this.welcome,
    this.showWhatsNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Śpiewnik',
      // Polish system widgets, e.g. the date picker of a song list.
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: lightTheme,
      debugShowCheckedModeBanner: false,
      darkTheme: darkTheme,
      themeMode: context.watch<AppSettingsModel>().themeMode,
      builder: (context, child) => TabletTextScale(child: child!),
      home: WelcomeGate(welcome: welcome, buildHome: (context) => HomeScreen(store: store, categories: categories, showWhatsNew: showWhatsNew)),
    );
  }
}

@immutable
class HomeScreen extends StatefulWidget {
  final Store store;
  final SongCategories categories;

  /// Opens the „Co nowego” sheet after the first frame.
  final bool showWhatsNew;

  const HomeScreen({
    super.key,
    required this.store,
    this.categories = SongCategories.empty,
    this.showWhatsNew = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late SongViewModel viewModel;
  late MySongViewModel mySongViewModel;
  late PlaylistViewModel playlistViewModel;

  @override
  void initState() {
    super.initState();
    viewModel = SongViewModel(ObjectBoxSongRepository(widget.store), categories: widget.categories);
    mySongViewModel = MySongViewModel(ObjectBoxMySongRepository(widget.store));
    playlistViewModel = PlaylistViewModel(
      ObjectBoxPlaylistRepository(widget.store),
      songs: ObjectBoxSongRepository(widget.store),
      mySongs: ObjectBoxMySongRepository(widget.store),
    );
    // Lists show user songs: a renamed or deleted one has to show so there too.
    mySongViewModel.mySongsNotifier.addListener(playlistViewModel.reload);
    if (widget.showWhatsNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showWhatsNewSheet(context);
        }
      });
    }
  }

  @override
  void dispose() {
    mySongViewModel.mySongsNotifier.removeListener(playlistViewModel.reload);
    super.dispose();
  }

  List<Widget> _buildScreens() {
    return [
      SongListView(viewModel: viewModel, playlistViewModel: playlistViewModel),
      FavoriteSongsView(viewModel: viewModel, playlistViewModel: playlistViewModel),
      MyTabView(mySongs: mySongViewModel, playlists: playlistViewModel, songs: viewModel),
    ];
  }

  Future<void> _addSelectionToPlaylist() async {
    final added = await showAddToPlaylistSheet(
      context,
      viewModel: playlistViewModel,
      songs: [for (final song in viewModel.selectedSongs) PlaylistEntry.songbook(song)],
      onOpen: (id) => openPlaylist(context, id: id, playlists: playlistViewModel, songs: viewModel),
    );
    if (added) {
      viewModel.endSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>?>(
      valueListenable: viewModel.selectionNotifier,
      builder: (context, selection, _) => PopScope(
        // The system back leaves the selection mode first.
        canPop: selection == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            viewModel.endSelection();
          }
        },
        child: Scaffold(
          appBar: selection == null ? _appBar() : _selectionAppBar(selection.length),
          body: IndexedStack(
            index: _selectedIndex,
            children: _buildScreens(),
          ),
          bottomNavigationBar: selection == null
              ? AppNavigationBar(
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                )
              : _SelectionBar(
                  count: selection.length,
                  onClear: viewModel.clearSelection,
                  onAdd: _addSelectionToPlaylist,
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: const Text(
        'Śpiewnik',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        if (_selectedIndex == 2)
          ValueListenableBuilder<bool>(
            valueListenable: playlistViewModel.showListsNotifier,
            builder: (context, showLists, _) => showLists
                ? IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Nowa lista',
                    onPressed: () => createPlaylist(context, playlistViewModel, viewModel),
                  )
                : IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Dodaj pieśń',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MySongFormView(viewModel: mySongViewModel)),
                      );
                    },
                  ),
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Ustawienia',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsView()),
            );
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar(int count) {
    final appColors = context.appColors;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Zakończ zaznaczanie',
        onPressed: viewModel.endSelection,
      ),
      title: Semantics(
        liveRegion: true,
        label: 'Zaznaczono $count',
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            text: 'Zaznaczono ',
            children: [TextSpan(text: '$count', style: TextStyle(color: appColors.accent))],
          ),
        ),
      ),
    );
  }
}

/// Replaces the bottom navigation in the selection mode: „Wyczyść” (Clear) and „+ Dodaj do listy”.
class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  const _SelectionBar({required this.count, required this.onClear, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Row(
            children: [
              OutlinedPillButton(label: 'Wyczyść', onPressed: count == 0 ? null : onClear),
              const SizedBox(width: 12.0),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48.0),
                  child: ElevatedButton.icon(
                    onPressed: count == 0 ? null : onAdd,
                    icon: const Icon(Icons.add, size: 18.0),
                    label: const Text('Dodaj do listy'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
