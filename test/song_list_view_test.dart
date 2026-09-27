import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/song_scroll_bar.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

void main() {
  late FakeSongRepository repository;

  setUp(() {
    repository = FakeSongRepository([
      Song(number: 1, title: 'Alleluja, chwalcie Pana', content: 'treść 1', favorite: false),
      Song(number: 2, title: 'Barankowi chwałę', content: 'treść 2', favorite: true),
      Song(number: 3, title: 'Źródło', content: 'treść 3', favorite: false),
    ]);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(body: SongListView(viewModel: SongViewModel(repository))),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  List<SongListTile> tiles(WidgetTester tester) =>
      tester.widgetList<SongListTile>(find.byType(SongListTile)).toList();

  testWidgets('the search field is visible right away, with the hint from the design system', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Szukaj'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('shows songs in number order', (tester) async {
    await pumpList(tester);

    expect(tiles(tester).map((tile) => tile.number), [1, 2, 3]);
  });

  testWidgets('filters by title and highlights the match', (tester) async {
    await pumpList(tester);

    await search(tester, 'zrodlo');

    expect(tiles(tester).map((tile) => tile.title), ['Źródło']);
    expect(tiles(tester).single.highlights, ['Źródło']);
  });

  testWidgets('filters by number', (tester) async {
    await pumpList(tester);

    await search(tester, '2');

    expect(tiles(tester).map((tile) => tile.number), [2]);
  });

  testWidgets('the clear icon appears only once there is text, and clears the search', (tester) async {
    await pumpList(tester);
    expect(find.byIcon(Icons.close), findsNothing);

    await search(tester, 'zrodlo');
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tiles(tester).map((tile) => tile.number), [1, 2, 3]);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('the filter waits for a pause in typing', (tester) async {
    await pumpList(tester);

    await tester.enterText(find.byType(TextField), 'zrodlo');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tiles(tester), hasLength(3), reason: 'przed upływem debounce lista bez zmian');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tiles(tester), hasLength(1));
  });

  testWidgets('the favorite flag reaches the list row', (tester) async {
    await pumpList(tester);

    expect(tiles(tester).firstWhere((tile) => tile.number == 2).isFavorite, isTrue);
    expect(tiles(tester).firstWhere((tile) => tile.number == 1).isFavorite, isFalse);
  });

  testWidgets('the fast-scroll thumb is disabled once a search is entered', (tester) async {
    await pumpList(tester);

    expect(
      tester.widget<SongScrollBar>(find.byType(SongScrollBar)).enabled,
      isTrue,
      reason: 'pełna lista: jest po czym jeździć',
    );

    await tester.enterText(find.byType(TextField), 'Alleluja');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SongScrollBar>(find.byType(SongScrollBar)).enabled,
      isFalse,
      reason: 'przy wynikach wyszukiwania uchwyt nic nie wnosi',
    );
  });

  testWidgets('a search matching more than 100 songs shows the best 100 and says how many matched', (tester) async {
    repository = FakeSongRepository([
      for (var n = 1; n <= 150; n++) Song(number: n, title: 'Chwała Panu $n', content: 'treść', favorite: false),
    ]);
    await pumpList(tester);

    await search(tester, 'chwała');
    await tester.scrollUntilVisible(find.textContaining('Pokazano 100'), 500.0, scrollable: find.byType(Scrollable).last);

    expect(find.text('Pokazano 100 najlepiej pasujących z 150. Dopisz kolejne słowo, żeby zawęzić wyniki.'), findsOneWidget);
  });
}
