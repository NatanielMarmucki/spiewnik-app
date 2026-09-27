import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/main.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/playlist_detail_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/my_tab_view.dart';

import 'support/test_store.dart';

void main() {
  late TestStore testStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testStore = TestStore.open();
  });
  tearDown(() => testStore.close());

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FontSizeModel(),
        child: MaterialApp(theme: lightTheme, home: HomeScreen(store: testStore.store)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens user songs from the third tab', (tester) async {
    await pumpHomeScreen(tester);

    await tester.tap(find.text('Moje'));
    await tester.pumpAndSettle();

    final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(indexedStack.index, 2);
    expect(indexedStack.children[2], isA<MyTabView>());
    expect(find.byType(MySongsView), findsOneWidget);
    expect(find.text('Brak własnych pieśni'), findsOneWidget);
  });

  testWidgets('shows the add button only on the user songs tab and opens the form', (tester) async {
    await pumpHomeScreen(tester);
    expect(find.byTooltip('Dodaj pieśń'), findsNothing);

    await tester.tap(find.text('Ulubione'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dodaj pieśń'), findsNothing);

    await tester.tap(find.text('Moje'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj pieśń'));
    await tester.pumpAndSettle();

    expect(find.byType(MySongFormView), findsOneWidget);
    expect(find.text('Dodaj pieśń'), findsOneWidget);
  });

  group('selection mode', () {
    setUp(() {
      testStore.store.box<Song>().putMany([
        for (final n in [4, 8, 12, 114]) Song(number: n, title: 'Pieśń $n', content: 'treść $n', favorite: n == 8),
      ]);
    });

    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('a long press selects, taps toggle, and the selection survives a search', (tester) async {
      await pumpHomeScreen(tester);

      await tester.longPress(find.text('Pieśń 12'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Zaznaczono 1'), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsNothing);
      expect(find.text('Dodaj do listy'), findsOneWidget);
      expect(find.text('Szukaj — zaznaczenie zostaje'), findsOneWidget);

      await tester.tap(find.text('Pieśń 4'));
      await tester.pumpAndSettle();
      await search(tester, '114');
      await tester.tap(find.text('Pieśń 114'));
      await tester.pumpAndSettle();
      await search(tester, '');

      expect(find.bySemanticsLabel('Zaznaczono 3'), findsOneWidget);
      expect(find.byType(SongDetailView), findsNothing);
    });

    testWidgets('the system back leaves the selection mode', (tester) async {
      await pumpHomeScreen(tester);
      await tester.longPress(find.text('Pieśń 12'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppNavigationBar), findsOneWidget);
      expect(find.text('Szukaj'), findsOneWidget);
    });

    testWidgets('adds the selection to a new list, in order of numbers, and offers to open it', (tester) async {
      await pumpHomeScreen(tester);
      await tester.longPress(find.text('Pieśń 114'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pieśń 4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dodaj do listy'));
      await tester.pumpAndSettle();
      expect(find.text('Dodaj 2 pieśni do listy'), findsOneWidget);
      expect(find.text('4 · 114'), findsOneWidget);
      await tester.tap(find.text('Nowa lista z zaznaczonych'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Niedziela');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Utwórz'));
      await tester.pumpAndSettle();

      expect(find.byType(AppNavigationBar), findsOneWidget);
      expect(find.text('Dodano 2 pieśni do „Niedziela”'), findsOneWidget);
      final items = testStore.store.box<PlaylistItem>().getAll()..sort((a, b) => a.position.compareTo(b.position));
      expect(items.map((item) => item.songNumber), [4, 114]);

      await tester.tap(find.text('Otwórz'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailView), findsOneWidget);
    });

    testWidgets('adding to an existing list skips songs already on it and says so', (tester) async {
      await pumpHomeScreen(tester);
      await tester.longPress(find.text('Pieśń 8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj do listy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nowa lista z tą pieśnią'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Ślub');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Utwórz'));
      await tester.pumpAndSettle();

      // Again: 8 is on the list already, 12 is not.
      await tester.longPress(find.text('Pieśń 8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pieśń 12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj do listy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 z 2 już jest'), findsOneWidget);
      await tester.tap(find.text('Ślub'));
      await tester.pumpAndSettle();

      expect(find.text('Dodano 1 pieśń do „Ślub” · 1 już była'), findsOneWidget);
      expect(testStore.store.box<PlaylistItem>().getAll().map((item) => item.songNumber), unorderedEquals([8, 12]));
    });
  });
}
