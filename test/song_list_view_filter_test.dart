import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_categories.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/category_filter_sheet.dart';
import 'package:spiewnik/view/widgets/section_header.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'dart:io';

import 'support/fakes/fake_song_repository.dart';
import 'support/screen_harness.dart';

const categories = SongCategories([
  SongCategory(id: 'I', name: 'Bóg Trójjedyny', subcategories: [
    SongSubcategory(id: 1, categoryId: 'I', name: 'Chwała i dziękczynienie', songs: [1, 2, 5]),
    SongSubcategory(id: 4, categoryId: 'I', name: 'Duch Święty', songs: [3, 5]),
  ]),
  SongCategory(id: 'IV', name: 'Społeczność świętych', subcategories: [
    SongSubcategory(id: 22, categoryId: 'IV', name: 'Ślub', songs: [4]),
  ]),
]);

void main() {
  late SongViewModel viewModel;

  Future<void> pumpList(WidgetTester tester) async {
    viewModel = SongViewModel(
      FakeSongRepository([
        for (var n = 1; n <= 6; n++)
          Song(number: n, title: n == 5 ? 'Źródło' : 'Pieśń $n', content: 'treść', favorite: false),
      ]),
      categories: categories,
    );
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: Scaffold(body: SongListView(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
  }

  List<int?> numbers(WidgetTester tester) =>
      tester.widgetList<SongListTile>(find.byType(SongListTile)).map((tile) => tile.number).toList();

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Filtruj według kategorii'));
    await tester.pumpAndSettle();
  }

  testWidgets('the filter button is 48 dp and has a Polish label', (tester) async {
    await pumpList(tester);

    final button = find.bySemanticsLabel('Filtruj według kategorii');
    expect(tester.getSize(button), const Size(48.0, 48.0));
  });

  testWidgets('selecting subcategories counts the union live and shows sections after „Pokaż”', (tester) async {
    await pumpList(tester);
    await openSheet(tester);
    expect(find.text('Pokaż 6 pieśni'), findsOneWidget);

    await tester.tap(find.text('Bóg Trójjedyny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duch Święty'));
    await tester.pump();
    expect(find.text('Pokaż 2 pieśni'), findsOneWidget);
    await tester.tap(find.text('Chwała i dziękczynienie'));
    await tester.pump();
    expect(find.text('Pokaż 4 pieśni'), findsOneWidget);
    expect(find.text('WYBRANE · 2'), findsOneWidget);

    await tester.tap(find.text('Pokaż 4 pieśni'));
    await tester.pumpAndSettle();

    expect(viewModel.subcategoryFilter, {1, 4});
    expect(find.text('I · CHWAŁA I DZIĘKCZYNIENIE'), findsOneWidget);
    expect(find.text('I · DUCH ŚWIĘTY'), findsOneWidget);
    // 5 is in both subcategories, so it shows in both sections.
    expect(numbers(tester), [1, 2, 5, 3, 5]);
    expect(find.text('Szukaj w 4 pieśniach'), findsOneWidget);
  });

  testWidgets('„Cała kategoria” checks every subcategory of the category', (tester) async {
    await pumpList(tester);
    await openSheet(tester);
    await tester.tap(find.text('Bóg Trójjedyny'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cała kategoria'));
    await tester.pump();

    expect(find.text('Pokaż 4 pieśni'), findsOneWidget);
  });

  testWidgets('closing the sheet with ✕ drops the draft', (tester) async {
    await pumpList(tester);
    await openSheet(tester);
    await tester.tap(find.text('Społeczność świętych'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ślub'));
    await tester.pump();

    await tester.tap(find.byTooltip('Zamknij'));
    await tester.pumpAndSettle();

    expect(viewModel.subcategoryFilter, isEmpty);
    expect(numbers(tester), [1, 2, 3, 4, 5, 6]);
  });

  testWidgets('✕ on a chip removes the subcategory from the filter', (tester) async {
    await pumpList(tester);
    viewModel.subcategoryFilter = {4, 22};
    await tester.pumpAndSettle();
    expect(find.byType(SectionHeader), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Usuń filtr: Ślub'));
    await tester.pumpAndSettle();

    expect(viewModel.subcategoryFilter, {4});
    expect(find.byType(SectionHeader), findsOneWidget);
    expect(numbers(tester), [3, 5]);
  });

  testWidgets('filter and search together: an empty result offers both ways out', (tester) async {
    await pumpList(tester);
    viewModel.subcategoryFilter = {22};
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zrodlo');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Brak wyników'), findsOneWidget);

    await tester.tap(find.text('Usuń filtry'));
    await tester.pumpAndSettle();

    expect(viewModel.subcategoryFilter, isEmpty);
    expect(numbers(tester), [5]);
  });

  for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
    testWidgets('the sheet and the sections fit at text scale ×2.0 on a 320 dp screen, $name theme', (tester) async {
      final real = SongCategories.fromJsonString(File(SongCategories.assetPath).readAsStringSync());
      final model = SongViewModel(
        FakeSongRepository([
          for (var n = 1; n <= 60; n++) Song(number: n, title: 'Pieśń numer $n', content: 'treść', favorite: false),
        ]),
        categories: real,
      )..subcategoryFilter = {3, 21};
      await pumpScreen(
        tester,
        (context) => Scaffold(body: SongListView(viewModel: model)),
        theme: theme,
        textScale: 2.0,
        size: const Size(320, 640),
      );
      expect(find.textContaining('I · ŚMIERĆ'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Filtruj według kategorii'));
      await tester.pumpAndSettle();
      // I and IV start expanded, because they have selected subcategories; expand the other two.
      final sheetList = find.descendant(of: find.byType(CategoryFilterSheet), matching: find.byType(Scrollable));
      for (final name in ['Droga zbawienia', 'Życie chrześcijanina']) {
        await tester.scrollUntilVisible(find.text(name), 200.0, scrollable: sheetList.first);
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('Pory dnia i roku'), 200.0, scrollable: sheetList.first);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Pokaż'), findsOneWidget);
    });
  }
}
