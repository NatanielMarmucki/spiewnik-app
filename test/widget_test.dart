import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/main.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/objectbox.g.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

import 'support/test_store.dart';

void main() {
  late TestStore testStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The app opens its store with openStore(), which asks path_provider for the documents directory.
    // That platform channel has no implementation in tests and, inside testWidgets, the call never
    // completes, so the store is opened in a temporary directory instead.
    testStore = TestStore.open();
  });

  tearDown(() => testStore.close());

  testWidgets('starts the app on the songbook with all tabs', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Store>.value(value: testStore.store),
          ChangeNotifierProvider(create: (_) => FontSizeModel()),
          ChangeNotifierProvider(create: (_) => AppSettingsModel()),
          Provider(create: (_) => SettingsViewModel()),
        ],
        child: MyApp(store: testStore.store),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Śpiewnik');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Śpiewnik')), findsOneWidget);
    expect(find.text('Ulubione'), findsOneWidget);
    expect(find.text('Moje'), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
  });
}
