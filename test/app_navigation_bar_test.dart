import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';

void main() {
  Future<int?> pumpBar(WidgetTester tester, {int selected = 0, TextScaler scaler = TextScaler.noScaling}) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: Scaffold(
            bottomNavigationBar: AppNavigationBar(
              selectedIndex: selected,
              onSelected: (index) => tapped = index,
            ),
          ),
        ),
      ),
    );
    return tapped;
  }

  TextStyle labelStyle(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!;

  testWidgets('has three tabs with icons and labels', (tester) async {
    await pumpBar(tester);

    for (final destination in AppNavigationBar.destinations) {
      expect(find.text(destination.label), findsOneWidget);
      expect(find.byIcon(destination.icon), findsOneWidget);
    }
  });

  testWidgets('icon is 17 dp', (tester) async {
    await pumpBar(tester);

    expect(tester.widget<Icon>(find.byIcon(Icons.menu_book)).size, 17.0);
  });

  testWidgets('active tab: accent, weight 600 and a 2 dp indicator line', (tester) async {
    await pumpBar(tester, selected: 1);

    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color, AppColors.light.accent);
    expect(labelStyle(tester, 'Ulubione').fontWeight, FontWeight.w600);
    expect(labelStyle(tester, 'Ulubione').color, lightTheme.colorScheme.onSurface);

    final indicators = tester.widgetList<Container>(find.byType(Container)).where(
      (container) => (container.constraints?.maxHeight ?? 0) == AppNavigationBar.indicatorHeight,
    );
    expect(indicators, isNotEmpty);
  });

  testWidgets('inactive tab uses the tertiary text color', (tester) async {
    await pumpBar(tester, selected: 1);

    expect(tester.widget<Icon>(find.byIcon(Icons.menu_book)).color, AppColors.light.textTertiary);
    expect(labelStyle(tester, 'Śpiewnik').color, AppColors.light.textTertiary);
  });

  testWidgets('tap reports the selected tab', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          bottomNavigationBar: AppNavigationBar(selectedIndex: 0, onSelected: (index) => tapped = index),
        ),
      ),
    );

    await tester.tap(find.text('Moje'));
    expect(tapped, 2);
  });

  testWidgets('height is a minimum: it grows with font scaling', (tester) async {
    await pumpBar(tester);
    final normal = tester.getSize(find.byType(AppNavigationBar)).height;

    await pumpBar(tester, scaler: const TextScaler.linear(2.0));
    final scaled = tester.getSize(find.byType(AppNavigationBar)).height;

    expect(normal, greaterThanOrEqualTo(AppNavigationBar.minHeight));
    expect(scaled, greaterThan(normal));
  });

  testWidgets('each tab has a screen reader label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, selected: 0);

    expect(find.bySemanticsLabel('Ulubione'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tap target is at least 40 x 48 dp', (tester) async {
    await pumpBar(tester);

    final tile = tester.getRect(find.ancestor(of: find.text('Śpiewnik'), matching: find.byType(InkWell)).first);
    expect(tile.width, greaterThanOrEqualTo(40.0));
    expect(tile.height, greaterThanOrEqualTo(48.0));
  });
}
