import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'objectbox.g.dart';
import 'json_manager.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/migration/legacy_settings_migration.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
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
import 'package:spiewnik/post_migration_welcome.dart';
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

Future<void> initializeApp(JsonManager jsonManager) async {
  bool shouldForceUpdate = false;
  String? currentAppVersion;

  try {
    logger.i("Starting app initialization and version check...");
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    currentAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

    final lastRunAppVersion = prefs.getString(_kLastRunAppVersionKey);

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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final objectBoxStore = await openStore();
  final jsonLoader = JsonManager(objectBoxStore, logger);

  await initializeApp(jsonLoader);
  // After the songs are loaded, so favorites from the old iOS app can be matched by number.
  final coreDataResult = await CoreDataMigration.runOnStartup(store: objectBoxStore, logger: logger);
  // Before runApp, so FontSizeModel loads the migrated font size.
  final migratedFontSize = await LegacySettingsMigration(logger: logger).run();
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
      child: MyApp(store: objectBoxStore, welcome: welcome),
    ),
  );

  // Outside `build`: the review prompt is a side effect of launching, not part of drawing the screen
  // (point 7 of ARCHITECTURE-PROPOSAL.md). No `await`, so the first frame is not delayed.
  unawaited(ReviewService(logger: logger).onLaunch());
}

class MyApp extends StatelessWidget {
  final Store store;

  /// The one-time welcome screen after the migration from the old iOS app, shown first; null skips it.
  final WelcomeVariant? welcome;

  const MyApp({
    super.key,
    required this.store,
    this.welcome,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Śpiewnik',
      theme: lightTheme,
      debugShowCheckedModeBanner: false,
      darkTheme: darkTheme,
      themeMode: context.watch<AppSettingsModel>().themeMode,
      builder: (context, child) => TabletTextScale(child: child!),
      home: WelcomeGate(welcome: welcome, buildHome: (context) => HomeScreen(store: store)),
    );
  }
}

@immutable
class HomeScreen extends StatefulWidget {
  final Store store;

  const HomeScreen({
    super.key,
    required this.store,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late SongViewModel viewModel;
  late MySongViewModel mySongViewModel;

  @override
  void initState() {
    super.initState();
    viewModel = SongViewModel(ObjectBoxSongRepository(widget.store));
    mySongViewModel = MySongViewModel(ObjectBoxMySongRepository(widget.store));
  }

  List<Widget> _buildScreens() {
    return [
      SongListView(viewModel: viewModel),
      FavoriteSongsView(viewModel: viewModel),
      MySongsView(viewModel: mySongViewModel),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Śpiewnik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj pieśń',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MySongFormView(viewModel: mySongViewModel)),
                );
              },
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
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
