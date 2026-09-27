import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/go_to_number_icon.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';
import 'support/screen_harness.dart';

/// Step 5b: every tap target is at least 40 x 48 dp (docs/DESIGN-SYSTEM.md, section 6).
///
/// Disabled states are measured too: the arrow at either end of the songbook stays in place, so
/// it has to keep its size so the bar does not jump.
void main() {
  late FakeWakelock wakelock;
  late FakeShare share;

  late SemanticsHandle semantics;

  setUp(() {
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  /// A tap target can be larger than what is drawn: Material adds a reaction area around the icon
  /// (`MaterialTapTargetSize.padded`), which only shows up in the semantics tree. What counts is
  /// what the finger actually hits, that is, the larger of the two rectangles.
  void expectTarget(WidgetTester tester, Finder finder, String what) {
    semantics = tester.ensureSemantics();
    final widgetSize = tester.getSize(finder);
    final semanticsSize = tester.getSemantics(finder).rect.size;
    final width = math.max(widgetSize.width, semanticsSize.width);
    final height = math.max(widgetSize.height, semanticsSize.height);
    semantics.dispose();

    expect(width, greaterThanOrEqualTo(40.0), reason: '$what: szerokość celu');
    expect(height, greaterThanOrEqualTo(48.0), reason: '$what: wysokość celu');
  }

  Finder tapRegionOf(Finder inner) => find.ancestor(of: inner, matching: find.byType(InkWell)).first;

  SongViewModel songs() => SongViewModel(
        FakeSongRepository([
          Song(number: 1, title: 'Alleluja, chwalcie Pana', content: 'treść 1', favorite: false),
          Song(number: 2, title: 'Barankowi chwałę', content: 'treść 2', favorite: true),
        ]),
      );

  MySongViewModel mySongs() {
    final repository = FakeMySongRepository();
    final now = DateTime(2026, 9, 18, 12);
    repository.save(MySong(title: 'Wieczorna modlitwa', content: 'treść', createdAt: now, updatedAt: now));
    return MySongViewModel(repository);
  }

  testWidgets('list row and search field', (tester) async {
    final viewModel = songs();
    await pumpScreen(tester, (context) => Scaffold(body: SongListView(viewModel: viewModel)));

    expectTarget(tester, find.byType(SongListTile).first, 'wiersz listy');

    await tester.enterText(find.byType(TextField), 'Alleluja');
    await tester.pumpAndSettle();
    expectTarget(tester, find.byTooltip('Wyczyść wyszukiwanie'), 'czyszczenie wyszukiwania');
  });

  testWidgets('bottom navigation tabs, including inactive ones', (tester) async {
    await pumpScreen(
      tester,
      (context) => Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: AppNavigationBar(selectedIndex: 0, onSelected: (_) {}),
      ),
    );

    for (final destination in AppNavigationBar.destinations) {
      expectTarget(tester, tapRegionOf(find.text(destination.label)), 'zakładka ${destination.label}');
    }
  });

  group('song detail', () {
    testWidgets('top bar icons', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      expectTarget(tester, find.byTooltip('Dodaj do ulubionych'), 'serce');
      expectTarget(tester, find.byTooltip('Opcje pieśni'), 'trzy kropki');
    });

    testWidgets('arrows and go-to-number, with a disabled arrow', (tester) async {
      final viewModel = songs();
      // First song: the left arrow is disabled but stays in place.
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      expectTarget(tester, tapRegionOf(find.byIcon(Icons.chevron_left)), 'strzałka wstecz (nieaktywna)');
      expectTarget(tester, tapRegionOf(find.byIcon(Icons.chevron_right)), 'strzałka w przód');
      expectTarget(tester, tapRegionOf(find.byType(GoToNumberIcon)), 'przejście do numeru');
    });

    testWidgets('options sheet items', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      for (final label in ['Udostępnij pieśń', 'Rozmiar tekstu', 'Kopiuj tekst']) {
        expectTarget(tester, tapRegionOf(find.text(label)), 'arkusz: $label');
      }
    });

    testWidgets('go-to-number modal actions, including the disabled button', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );
      await tester.tap(find.byType(GoToNumberIcon), warnIfMissed: false);
      await tester.pumpAndSettle();

      // With no number entered, „Przejdź” is disabled, yet it keeps its size.
      expectTarget(tester, find.widgetWithText(TextButton, 'Przejdź'), 'Przejdź (zablokowany)');
      expectTarget(tester, find.widgetWithText(TextButton, 'Anuluj'), 'Anuluj');
    });
  });

  testWidgets('user song actions', (tester) async {
    final viewModel = mySongs();
    await pumpScreen(
      tester,
      (context) => MySongDetailView(song: viewModel.getMySongs().first, viewModel: viewModel),
    );

    expectTarget(tester, find.byTooltip('Opcje pieśni'), 'trzy kropki');

    await tester.tap(find.byTooltip('Opcje pieśni'));
    await tester.pumpAndSettle();
    for (final label in ['Udostępnij pieśń', 'Edytuj pieśń', 'Usuń pieśń']) {
      expectTarget(tester, tapRegionOf(find.text(label)), 'arkusz własnej pieśni: $label');
    }
  });

  testWidgets('settings rows, switch and theme picker', (tester) async {
    await pumpScreen(tester, (context) => const SettingsView());

    expectTarget(tester, tapRegionOf(find.text('Nie gaś ekranu przy pieśni')), 'przełącznik blokady');
    expectTarget(tester, tapRegionOf(find.text('Kontakt')), 'ustawienia: Kontakt');
    // Theme segments: each is a separate target, even though they sit in one segmented control.
    for (final label in ['System', 'Jasny', 'Ciemny']) {
      expectTarget(tester, tapRegionOf(find.text(label)), 'motyw: $label');
    }
    expectTarget(
      tester,
      find.widgetWithText(OutlinedButton, 'Przywróć domyślny rozmiar i interlinię'),
      'reset ustawień czytania',
    );
  });
}
