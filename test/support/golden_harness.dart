import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Tools for golden screenshots: real typefaces, phone size, both themes.
///
/// Screenshots are made offscreen, without a device, so they are repeatable and suitable for CI.
/// Updating the images: `flutter test --update-goldens test/golden`.

/// Screenshot screen size: a 411 x 915 dp phone (like a Pixel) at density 3.
const Size _screenSize = Size(411, 915);

/// Loads the typefaces from assets and the Material icon font; otherwise the test draws rectangles
/// instead of letters and icons.
Future<void> loadAppFonts() async {
  // `flutter test` always sets FLUTTER_ROOT, even when the shell does not.
  final iconsFont = File(
    '${Platform.environment['FLUTTER_ROOT']!}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconsFont.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(iconsFont.readAsBytesSync().buffer)));
    await loader.load();
  }

  final fonts = {
    'Newsreader': [
      'assets/fonts/Newsreader-ExtraLight.ttf',
      'assets/fonts/Newsreader-Light.ttf',
      'assets/fonts/Newsreader-Regular.ttf',
    ],
    'SchibstedGrotesk': [
      'assets/fonts/SchibstedGrotesk-Regular.ttf',
      'assets/fonts/SchibstedGrotesk-Medium.ttf',
      'assets/fonts/SchibstedGrotesk-SemiBold.ttf',
    ],
    'IBMPlexMono': ['assets/fonts/IBMPlexMono-Regular.ttf'],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(Future.value(ByteData.view(File(path).readAsBytesSync().buffer)));
    }
    await loader.load();
  }
}

/// Builds the screen in both themes and saves the screenshots to test/golden/goldens/.
///
/// [name] goes into the file name: `<name>-light.png` and `<name>-dark.png`.
Future<void> goldenScreen(
  WidgetTester tester,
  String name,
  Widget Function(BuildContext context) build, {
  Future<void> Function(WidgetTester tester)? afterPump,
  Map<String, Object> preferences = const {'fontSize': 19.0, 'lineHeight': 1.62},
  /// System text scaling, separate from the song text size.
  double textScale = 1.0,
}) async {
  for (final theme in [('light', lightTheme), ('dark', darkTheme)]) {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(preferences));
    final fontSizeModel = FontSizeModel();
    await fontSizeModel.loaded;
    final appSettings = AppSettingsModel();
    await appSettings.loaded;

    tester.view.physicalSize = Size(_screenSize.width * 3, _screenSize.height * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FontSizeModel>.value(value: fontSizeModel),
          ChangeNotifierProvider<AppSettingsModel>.value(value: appSettings),
          Provider<SettingsViewModel>(create: (_) => SettingsViewModel()),
        ],
        child: MaterialApp(
          // A key per theme: without it the second pass hits the same element tree,
          // the Navigator keeps its route stack and a dialog opened in the first theme stays on screen.
          key: ValueKey(theme.$1),
          theme: theme.$2,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Builder(builder: build),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await tester.pumpAndSettle();
    }

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name-${theme.$1}.png'));
  }
}

/// Songbook songs for screenshots: numbers, titles and two favorites (songs 3 and 5).
List<Song> sampleSongs() {
  const titles = [
    'Alleluja, chwalcie Pana',
    'Barankowi chwałę',
    'Bądź Panu cześć',
    'Boże wielki',
    'Chcę o Jezusie',
    'Barankowi cześć',
    'Chciejmy Zbawcę',
    'Chwalże ma duszo',
    'Chwałę daj Panu',
    'Czego chcesz od nas Panie',
  ];
  return [
    for (var i = 0; i < titles.length; i++)
      Song(
        number: i + 1,
        title: titles[i],
        content: i == 0
            ? '1. Alleluja, chwalcie Pana, Nućcie Jemu chwałę, cześć! Chwalcie, wszyscy aniołowie, '
                  'Głosząc Jego łaski wieść! Chwal Go, słońce i księżycu, Chwal Go, mnóstwo jasnych gwiazd, '
                  'Chwalcie, góry, chwalcie, drzewa, Chwalcie, ptaki, z swoich gniazd!\n\n'
                  'Refren: Wysławiajcie imię Pańskie, Uwielbiajcie Jego moc! [:Niech są pełne Jego chwały,:] '
                  'Niech są pełne Jego chwały Niebo, ziemia w dzień i w noc!'
            : 'treść ${i + 1}',
        favorite: i == 2 || i == 4,
      ),
  ];
}

/// A longer list for the fast scrolling screenshot: the thumb appears only when there is something
/// to scroll. Titles repeat cyclically, numbers increase as in the songbook.
List<Song> manySongs({int count = 200}) {
  final titles = sampleSongs().map((song) => song.title).toList();
  return [
    for (var i = 0; i < count; i++)
      Song(
        number: i + 1,
        title: titles[i % titles.length],
        content: 'treść ${i + 1}',
        favorite: i % 37 == 0,
      ),
  ];
}

/// A user song for screenshots.
MySong sampleMySong() {
  final now = DateTime(2026, 9, 18, 12);
  return MySong(
    title: 'Wieczorna modlitwa',
    content: '1. Zmierzch zapada, Panie, zostań z nami.\n\nRefren: Ciebie wielbimy.',
    createdAt: now,
    updatedAt: now,
  );
}
