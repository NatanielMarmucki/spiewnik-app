@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/go_to_number_icon.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/welcome_view.dart';
import 'package:spiewnik/view/whats_new_sheet.dart';
import 'package:spiewnik/view/widgets/song_scroll_bar.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import '../support/fakes/fake_my_song_repository.dart';
import '../support/fakes/fake_song_repository.dart';
import '../support/golden_harness.dart';
import '../support/platform_fakes.dart';

/// Screenshots of every screen in both themes, rendered without a device.
///
/// The images are made on Linux, because font rasterization differs between platforms.
/// On other systems the tests are skipped so that a local `flutter test` stays fast
/// and green; you check them with `tools/golden.sh` (a Linux container).
void main() {
  // The images in the repository come from Linux and match pixel for pixel only there.
  // On macOS and Windows the tests are skipped; you check them with tools/golden.sh.
  final bool skipOnOtherPlatforms = !Platform.isLinux;

  late FakeWakelock wakelock;
  late FakeShare share;

  setUpAll(loadAppFonts);

  setUp(() {
    // The detail screens call platform channels; without fakes the test fails with MissingPluginException.
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  SongViewModel songs({bool empty = false}) =>
      SongViewModel(FakeSongRepository(empty ? [] : sampleSongs()));

  MySongViewModel mySongs({bool empty = false}) {
    final repository = FakeMySongRepository();
    if (!empty) {
      repository.save(sampleMySong());
    }
    return MySongViewModel(repository);
  }

  testWidgets('song list', (tester) async {
    await goldenScreen(tester, '01-lista-piesni', (context) {
      return Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs()));
    });
  }, skip: skipOnOtherPlatforms);

  testWidgets('song list: fast scrolling', (tester) async {
    // The thumb appears only for a list longer than two screens, so this one has more songs.
    final viewModel = SongViewModel(FakeSongRepository(manySongs()));
    await goldenScreen(
      tester,
      '20-lista-szybkie-przewijanie',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Śpiewnik')),
        body: SongListView(viewModel: viewModel),
      ),
      afterPump: (tester) async {
        final bar = tester.getRect(find.byType(SongScrollBar));
        final start = Offset(
          bar.right - SongScrollBar.hitWidth / 2,
          bar.top + SongScrollBar.thumbHeight / 2,
        );
        final gesture = await tester.startGesture(start);
        await gesture.moveTo(Offset(start.dx, bar.top + bar.height * 0.45));
        await tester.pumpAndSettle();
        addTearDown(() async => gesture.up());
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song list: search results', (tester) async {
    await goldenScreen(
      tester,
      '02-wyszukiwanie-wyniki',
      (context) => Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs())),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextField), 'chwal');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song list: no search results', (tester) async {
    await goldenScreen(
      tester,
      '03-wyszukiwanie-brak-wynikow',
      (context) => Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs())),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextField), 'qqqq');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('favorites', (tester) async {
    await goldenScreen(
      tester,
      '04-ulubione',
      (context) => Scaffold(appBar: AppBar(title: const Text('Ulubione')), body: FavoriteSongsView(viewModel: songs())),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('favorites: empty list', (tester) async {
    await goldenScreen(
      tester,
      '04b-ulubione-puste',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Ulubione')),
        body: FavoriteSongsView(viewModel: songs(empty: true)),
      ),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('user songs', (tester) async {
    await goldenScreen(
      tester,
      '05-moje-piesni',
      (context) => Scaffold(appBar: AppBar(title: const Text('Moje pieśni')), body: MySongsView(viewModel: mySongs())),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('user songs: empty list', (tester) async {
    await goldenScreen(
      tester,
      '05b-moje-piesni-puste',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Moje pieśni')),
        body: MySongsView(viewModel: mySongs(empty: true)),
      ),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('user song delete dialog', (tester) async {
    await goldenScreen(
      tester,
      '06-usuwanie-dialog',
      (context) => Scaffold(appBar: AppBar(title: const Text('Moje pieśni')), body: MySongsView(viewModel: mySongs())),
      afterPump: (tester) async {
        await tester.drag(find.text('Wieczorna modlitwa'), const Offset(-600, 0));
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('form: empty fields', (tester) async {
    await goldenScreen(tester, '07-formularz-pusty', (context) => MySongFormView(viewModel: mySongs(empty: true)));
  }, skip: skipOnOtherPlatforms);

  testWidgets('form: validation errors', (tester) async {
    await goldenScreen(
      tester,
      '08-formularz-walidacja',
      (context) => MySongFormView(viewModel: mySongs(empty: true)),
      afterPump: (tester) async {
        await tester.tap(find.byTooltip('Zapisz'));
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('form: discard changes dialog', (tester) async {
    await goldenScreen(
      tester,
      '09-formularz-odrzuc-zmiany',
      (context) => MySongFormView(viewModel: mySongs(empty: true)),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextFormField).first, 'Nowa');
        await tester.pumpAndSettle();
        // The form is the home screen here, so there is no back button:
        // we trigger leaving the way the system gesture does.
        await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('user song preview', (tester) async {
    final viewModel = mySongs();
    await goldenScreen(
      tester,
      '10-podglad-mojej-piesni',
      (context) => MySongDetailView(song: viewModel.getMySongs().single, viewModel: viewModel),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song details', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '12-szczegoly-piesni',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song details: go to number dialog', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '13-dialog-przejdz-do-piesni',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      afterPump: (tester) async {
        // warnIfMissed: the icon sits in an InkWell in the bar; the hit warning is misleading,
        // the dialog opens correctly.
        await tester.tap(find.ancestor(of: find.byType(GoToNumberIcon), matching: find.byType(InkWell)).first);
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song details: go to number dialog with a number entered', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '13b-dialog-przejdz-wpisany-numer',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      afterPump: (tester) async {
        await tester.tap(find.ancestor(of: find.byType(GoToNumberIcon), matching: find.byType(InkWell)).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '4');
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song details: options sheet', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '14-arkusz-opcji',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      afterPump: (tester) async {
        // warnIfMissed: the icon sits in a bar button; the hit warning is misleading,
        // the sheet opens correctly.
        await tester.tap(find.byIcon(Icons.more_vert), warnIfMissed: false);
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('settings', (tester) async {
    await goldenScreen(tester, '16-ustawienia', (context) => const SettingsView());
  }, skip: skipOnOtherPlatforms);

  testWidgets('settings: largest text', (tester) async {
    await goldenScreen(
      tester,
      '16b-ustawienia-max',
      (context) => const SettingsView(),
      preferences: const {'fontSize': 30.0, 'lineHeight': 1.8},
    );
  }, skip: skipOnOtherPlatforms);

  // System text scaling ×2.0 (section 6 of the document) on the key screens.
  testWidgets('song list: text scale x2', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '17-lista-piesni-x2',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Śpiewnik')),
        body: SongListView(viewModel: viewModel),
      ),
      textScale: 2.0,
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('song details: text scale x2', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '18-szczegoly-piesni-x2',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      textScale: 2.0,
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('settings: text scale x2', (tester) async {
    await goldenScreen(
      tester,
      '19-ustawienia-x2',
      (context) => const SettingsView(),
      textScale: 2.0,
    );
  }, skip: skipOnOtherPlatforms);

  // Welcome screen after migrating from the old iOS app (issue #37).
  testWidgets('welcome screen', (tester) async {
    await goldenScreen(tester, '21-powitanie', (context) => WelcomeView(onContinue: () {}));
  }, skip: skipOnOtherPlatforms);

  testWidgets('welcome screen: text scale x2', (tester) async {
    await goldenScreen(tester, '22-powitanie-x2', (context) => WelcomeView(onContinue: () {}), textScale: 2.0);
  }, skip: skipOnOtherPlatforms);

  testWidgets('welcome screen: text scale x2, scrolled to the button', (tester) async {
    await goldenScreen(
      tester,
      '22b-powitanie-x2-przycisk',
      (context) => WelcomeView(onContinue: () {}),
      textScale: 2.0,
      afterPump: (tester) => tester.ensureVisible(find.text(WelcomeView.continueLabel)),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('what is new after an update', (tester) async {
    await goldenScreen(
      tester,
      '23-co-nowego',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Śpiewnik')),
        body: Center(child: TextButton(onPressed: () => showWhatsNewSheet(context), child: const Text('otwórz'))),
      ),
      afterPump: (tester) => tester.tap(find.text('otwórz')),
    );
  }, skip: skipOnOtherPlatforms);
}
