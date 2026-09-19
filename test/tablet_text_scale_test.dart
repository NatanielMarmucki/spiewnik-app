import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/view/tablet_text_scale.dart';

void main() {
  /// The text scale the app sees on a screen of [size] dp with the system text scale [system].
  Future<double> textScaleOn(WidgetTester tester, Size size, {double system = 1.0}) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = size * 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = system;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    late double scale;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TabletTextScale(child: child!),
        home: Builder(builder: (context) {
          scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          return const SizedBox();
        }),
      ),
    );
    return scale;
  }

  const phone = Size(402, 874);
  const tablet = Size(1032, 1376); // iPad Pro 13"
  const smallTablet = Size(744, 1133); // iPad mini

  test('the factor is 1.35', () => expect(TabletTextScale.tabletFactor, 1.35));

  testWidgets('a phone keeps the system text scale', (tester) async {
    expect(await textScaleOn(tester, phone), 1.0);
    expect(await textScaleOn(tester, phone, system: 1.5), 1.5);
  });

  testWidgets('a phone in landscape is not a tablet', (tester) async {
    expect(await textScaleOn(tester, phone.flipped), 1.0);
  });

  testWidgets('a tablet scales text by the factor, in both orientations', (tester) async {
    expect(await textScaleOn(tester, tablet), closeTo(1.35, 1e-9));
    expect(await textScaleOn(tester, tablet.flipped), closeTo(1.35, 1e-9));
    expect(await textScaleOn(tester, smallTablet), closeTo(1.35, 1e-9));
  });

  testWidgets('on a tablet the system text scale still counts, up to ×2.0 in total', (tester) async {
    expect(await textScaleOn(tester, tablet, system: 1.2), closeTo(1.62, 1e-9));
    expect(await textScaleOn(tester, tablet, system: 2.0), 2.0);
  });
}
