import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_tab_view.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_playlist_repository.dart';
import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';
import 'support/screen_harness.dart';

void main() {
  late FakeWakelock wakelock;
  late SongViewModel songs;
  late MySongViewModel mySongs;
  late PlaylistViewModel playlists;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wakelock = FakeWakelock()..install();
    final songRepository = FakeSongRepository([
      for (final n in [4, 8, 12, 114]) Song(number: n, title: 'Pieśń $n', content: 'Treść pieśni $n', favorite: false),
    ]);
    final mySongRepository = FakeMySongRepository([
      MySong(title: 'Wieczorna', content: 'Zostań z nami', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    ]);
    songs = SongViewModel(songRepository);
    mySongs = MySongViewModel(mySongRepository);
    playlists = PlaylistViewModel(
      FakePlaylistRepository(),
      songs: songRepository,
      mySongs: mySongRepository,
      now: () => DateTime(2026, 9, 27),
    );
  });
  tearDown(() => wakelock.uninstall());

  PlaylistDraft draft(String name, {DateTime? date}) =>
      (name: name, date: date, color: PlaylistColor.rose, icon: PlaylistIcon.cross);

  Future<void> pumpMyTab(WidgetTester tester, {double textScale = 1.0, ThemeData? theme}) async {
    await pumpScreen(
      tester,
      (context) => Scaffold(body: MyTabView(mySongs: mySongs, playlists: playlists, songs: songs)),
      textScale: textScale,
      theme: theme,
    );
    await playlists.setShowLists(true);
    await tester.pumpAndSettle();
  }

  Future<Playlist> pumpList(WidgetTester tester, {double textScale = 1.0}) async {
    final list = playlists.create(
      draft('Nabożeństwo niedzielne', date: DateTime(2026, 10, 4)),
      songs: const [SongRef.songbook(8), SongRef.songbook(114), SongRef.mine(1)],
    );
    await pumpScreen(
      tester,
      (context) => PlaylistDetailView(playlistId: list.id, viewModel: playlists, songs: songs),
      textScale: textScale,
    );
    return list;
  }

  List<String> titles(Playlist list) => playlists.byId(list.id)!.entries.map((e) => e.title).toList();

  group('Moje › Listy', () {
    testWidgets('empty: explains lists and offers a new one', (tester) async {
      await pumpMyTab(tester);

      expect(find.text('Brak list'), findsOneWidget);
      expect(find.text('+ Nowa lista'), findsOneWidget);
      expect(find.textContaining('przytrzymaj pieśń w Śpiewniku'), findsOneWidget);
    });

    testWidgets('groups lists into upcoming, undated and past, with the count in the tab', (tester) async {
      playlists
        ..create(draft('Ślub Ani', date: DateTime(2026, 10, 4)), songs: const [SongRef.songbook(4)])
        ..create(draft('Próba chóru'))
        ..create(draft('Wielkanoc', date: DateTime(2026, 4, 5)));
      await pumpMyTab(tester);

      expect(find.text('NADCHODZĄCE'), findsOneWidget);
      expect(find.text('BEZ DATY'), findsOneWidget);
      expect(find.text('MINIONE'), findsOneWidget);
      expect(find.text('niedziela, 4 października'), findsOneWidget);
      expect(find.bySemanticsLabel('Listy, 3'), findsOneWidget);
    });

    testWidgets('switching back to „Pieśni” shows the user songs and is remembered', (tester) async {
      await pumpMyTab(tester);

      await tester.tap(find.text('Pieśni'));
      await tester.pumpAndSettle();

      expect(find.text('Wieczorna'), findsOneWidget);
      expect(playlists.showListsNotifier.value, isFalse);
    });

    testWidgets('the form creates a list only with a name, then opens it', (tester) async {
      await pumpMyTab(tester);
      await tester.tap(find.text('+ Nowa lista'));
      await tester.pumpAndSettle();

      final create = find.widgetWithText(TextButton, 'Utwórz');
      expect(tester.widget<TextButton>(create).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Ślub');
      await tester.tap(find.bySemanticsLabel('Kolor liliowy'));
      await tester.tap(find.bySemanticsLabel('Ikona: obrączki'));
      await tester.pump();
      await tester.tap(create);
      await tester.pumpAndSettle();

      final created = playlists.playlistsNotifier.value.single.playlist;
      expect((created.name, created.color, created.icon, created.date),
          ('Ślub', PlaylistColor.lilac, PlaylistIcon.rings, null));
      expect(find.byType(PlaylistDetailView), findsOneWidget);
      expect(find.text('Lista jest pusta'), findsOneWidget);
    });
  });

  group('a list', () {
    testWidgets('shows the date, the name, the songs in order and a hint about reordering', (tester) async {
      await pumpList(tester);

      expect(find.text('NIEDZIELA · 4 PAŹDZIERNIKA 2026'), findsOneWidget);
      expect(find.text('Nabożeństwo niedzielne'), findsOneWidget);
      expect(find.text('3 pieśni'), findsOneWidget);
      expect(find.text('przytrzymaj uchwyt, by przestawić'), findsOneWidget);
      expect(find.text('MOJA'), findsOneWidget);
    });

    testWidgets('screen reader actions move a song and hide the hint for good', (tester) async {
      final list = await pumpList(tester);
      final semantics = tester.ensureSemantics();

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp(r'^1 z 3, Pieśń 8')),
        const CustomSemanticsAction(label: 'Przesuń niżej'),
      );
      await tester.pumpAndSettle();

      expect(titles(list), ['Pieśń 114', 'Pieśń 8', 'Wieczorna']);
      expect(playlists.reorderHintSeenNotifier.value, isTrue);
      expect(find.text('przytrzymaj uchwyt, by przestawić'), findsNothing);
      semantics.dispose();
    });

    testWidgets('dragging the handle reorders', (tester) async {
      final list = await pumpList(tester);

      final handle = find.byIcon(Icons.drag_handle).first;
      await tester.timedDrag(handle, const Offset(0, 150), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(titles(list).first, isNot('Pieśń 8'));
      expect(titles(list).toSet(), {'Pieśń 8', 'Pieśń 114', 'Wieczorna'});
    });

    testWidgets('the row menu removes a song, and „Cofnij” puts it back in place', (tester) async {
      final list = await pumpList(tester);

      await tester.longPress(find.bySemanticsLabel(RegExp(r'^2 z 3, Pieśń 114')));
      await tester.pumpAndSettle();
      expect(find.text('Przesuń wyżej'), findsOneWidget);
      await tester.tap(find.text('Usuń z listy'));
      await tester.pumpAndSettle();
      expect(titles(list), ['Pieśń 8', 'Wieczorna']);

      await tester.tap(find.text('Cofnij'));
      await tester.pumpAndSettle();
      expect(titles(list), ['Pieśń 8', 'Pieśń 114', 'Wieczorna']);
    });

    testWidgets('„Śpiewaj po kolei” goes through the list in its order, user songs included', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Śpiewaj po kolei'));
      await tester.pumpAndSettle();

      expect(find.byType(SongDetailView), findsOneWidget);
      expect(find.text('8. Pieśń 8'), findsOneWidget);
      expect(find.text('NABOŻEŃSTWO NIEDZIELNE'), findsOneWidget);
      expect(find.bySemanticsLabel('Następna pieśń, 2 z 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Poprzednia pieśń'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Następna pieśń, 2 z 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Następna pieśń, 3 z 3'));
      await tester.pumpAndSettle();

      expect(find.text('Wieczorna'), findsOneWidget);
      expect(find.text('Zostań z nami', findRichText: true), findsWidgets);
      expect(find.bySemanticsLabel('Następna pieśń'), findsOneWidget);
      expect(find.byTooltip('Dodaj do ulubionych'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Wróć do listy Nabożeństwo niedzielne'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailView), findsOneWidget);
    });

    testWidgets('options: copy numbers, duplicate and delete', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await pumpList(tester);

      await tester.tap(find.byTooltip('Opcje listy'));
      await tester.pumpAndSettle();
      expect(find.text('8 · 114 · „Wieczorna”'), findsOneWidget);
      await tester.tap(find.text('Kopiuj numery'));
      await tester.pumpAndSettle();
      expect(clipboard, '8 · 114 · „Wieczorna”');
      expect(find.text('Skopiowano'), findsOneWidget);

      await tester.tap(find.byTooltip('Opcje listy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplikuj'));
      await tester.pumpAndSettle();
      expect(playlists.playlistsNotifier.value.map((d) => d.playlist.name), contains('Nabożeństwo niedzielne (kopia)'));

      await tester.tap(find.byTooltip('Opcje listy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń listę'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Usuń'));
      await tester.pumpAndSettle();
      expect(playlists.playlistsNotifier.value.map((d) => d.playlist.name), ['Nabożeństwo niedzielne (kopia)']);
    });
  });

  group('text scale ×2.0', () {
    for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
      testWidgets('lists, a list and the form fit, $name theme', (tester) async {
        playlists
          ..create(draft('Ślub Ani i Tomka w kościele na Woli', date: DateTime(2026, 10, 4)))
          ..create(draft('Próba chóru'));
        await pumpMyTab(tester, textScale: 2.0, theme: theme);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Próba chóru'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a list and its form fit', (tester) async {
      await pumpList(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Opcje listy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nazwa, data, kolor i ikona'));
      await tester.pumpAndSettle();
      expect(find.text('Edytuj listę'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('sharing', () {
    late FakeShare share;
    late FakePathProvider paths;

    setUp(() {
      share = FakeShare()..install();
      paths = FakePathProvider()..install();
    });
    tearDown(() {
      share.uninstall();
      paths.uninstall();
    });

    testWidgets('„Tytuły z numerami” shares plain text', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byTooltip('Udostępnij listę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tytuły z numerami'));
      await tester.pumpAndSettle();

      expect(
        share.shares.single['text'],
        'Nabożeństwo niedzielne — niedziela, 4 października 2026\n1. Pieśń 8 (8)\n2. Pieśń 114 (114)\n3. Wieczorna',
      );
    });

    testWidgets('„Pełne teksty · PDF” shares a PDF file named after the list', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byTooltip('Udostępnij listę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pełne teksty · PDF'));
      // Building the PDF and writing the file are real I/O: let it run between frames.
      for (var i = 0; i < 100 && share.shares.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.text('Nie udało się przygotować PDF'), findsNothing);

      final path = (share.shares.single['paths'] as List).single as String;
      expect(path, endsWith('Nabożeństwo niedzielne.pdf'));
      expect(File(path).readAsBytesSync().take(5), '%PDF-'.codeUnits);
    });
  });
}
