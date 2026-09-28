import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/whats_new_sheet.dart';
import 'package:spiewnik/whats_new.dart';

import 'support/screen_harness.dart';

void main() {
  final whatsNew = WhatsNew(logger: Logger(level: Level.off));

  group('when it shows', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('once, after an update from 12.0 to 12.1', () async {
      expect(await whatsNew.decide(previousVersion: '12.0.0+7', currentVersion: '12.1.0+1'), isTrue);
      expect(await whatsNew.decide(previousVersion: '12.0.0+7', currentVersion: '12.1.0+1'), isFalse);
      expect((await SharedPreferences.getInstance()).getString(WhatsNew.shownKey), '12.1');
    });

    test('also after an update from an old Android version', () async {
      expect(await whatsNew.decide(previousVersion: '11.3.2+45', currentVersion: '12.1.0+1'), isTrue);
    });

    test('not on a clean install or an update from the old iOS app (no previous version)', () async {
      expect(await whatsNew.decide(previousVersion: null, currentVersion: '12.1.0+1'), isFalse);
    });

    test('not within 12.1 (a build or patch update) and not before 12.1', () async {
      expect(await whatsNew.decide(previousVersion: '12.1.0+1', currentVersion: '12.1.1+2'), isFalse);
      expect(await whatsNew.decide(previousVersion: '12.0.0+6', currentVersion: '12.0.0+7'), isFalse);
    });

    test('a version it cannot read means no sheet, not a crash', () async {
      expect(await whatsNew.decide(previousVersion: 'dev', currentVersion: '12.1.0+1'), isFalse);
    });
  });

  group('the sheet', () {
    Future<void> openSheet(WidgetTester tester, {double textScale = 1.0, ThemeData? theme, Size? size}) async {
      await pumpScreen(
        tester,
        (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => showWhatsNewSheet(context), child: const Text('otwórz')),
          ),
        ),
        textScale: textScale,
        theme: theme,
        size: size ?? const Size(411, 915),
      );
      await tester.tap(find.text('otwórz'));
      await tester.pumpAndSettle();
    }

    testWidgets('says what changed and where to find it, and closes with „Rozumiem”', (tester) async {
      await openSheet(tester);

      expect(find.textContaining('Co nowego'), findsOneWidget);
      for (final item in WhatsNewSheet.items.take(3)) {
        expect(find.text(item.title), findsOneWidget);
      }
      expect(WhatsNewSheet.items.every((item) => !item.text.contains('—')), isTrue, reason: 'no em dashes');

      await tester.tap(find.text(WhatsNewSheet.closeLabel));
      await tester.pumpAndSettle();
      expect(find.textContaining('Co nowego'), findsNothing);
    });

    for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
      testWidgets('fits at text scale ×2.0 on a 320 dp screen and „Rozumiem” is reachable, $name theme',
          (tester) async {
        await openSheet(tester, textScale: 2.0, theme: theme, size: const Size(320, 640));

        expect(tester.takeException(), isNull);
        expect(find.text(WhatsNewSheet.closeLabel).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(find.text(WhatsNewSheet.items.last.title), 200.0,
            scrollable: find.byType(Scrollable).last);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
