import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/widgets/settings_section.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

import 'support/platform_fakes.dart';

void main() {
  late FakeUrlLauncher urlLauncher;
  late FakeWakelock wakelock;
  late AppSettingsModel appSettings;
  late FontSizeModel fontSizeModel;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Śpiewnik',
      packageName: 'com.nm.spiewnik',
      version: '12.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    urlLauncher = FakeUrlLauncher()..install();
    wakelock = FakeWakelock()..install();
  });

  tearDown(() {
    urlLauncher.uninstall();
    wakelock.uninstall();
    ScreenWakeLock.resetEnabledForTesting();
  });

  Future<void> pumpSettings(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    fontSizeModel = FontSizeModel();
    appSettings = AppSettingsModel();
    await fontSizeModel.loaded;
    await appSettings.loaded;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: fontSizeModel),
          ChangeNotifierProvider.value(value: appSettings),
          Provider(create: (_) => SettingsViewModel()),
        ],
        child: MaterialApp(theme: lightTheme, home: const SettingsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The settings are taller than the test screen, so the target has to be scrolled to before tapping.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the settings sections', (tester) async {
    await pumpSettings(tester);

    expect(find.text('CZYTANIE'), findsOneWidget);
    expect(find.text('WYGLĄD'), findsOneWidget);
    expect(find.text('Rozmiar tekstu'), findsOneWidget);
    expect(find.text('Interlinia'), findsOneWidget);
  });

  testWidgets('line height sits right below text size, and the sample below both', (tester) async {
    await pumpSettings(tester);

    final size = tester.getCenter(find.text('Rozmiar tekstu')).dy;
    final lineHeight = tester.getCenter(find.text('Interlinia')).dy;
    final sample = tester.getCenter(find.byType(SongContent)).dy;

    expect(lineHeight, greaterThan(size));
    expect(sample, greaterThan(lineHeight), reason: 'próbka pokazuje oba ustawienia naraz');
    expect(
      find.byType(SettingsSlider),
      findsNWidgets(2),
      reason: 'między suwakami nie ma nic innego',
    );
  });

  testWidgets('reset is a centered button right below the sliders, above the sample', (tester) async {
    await pumpSettings(tester);

    final button = find.widgetWithText(OutlinedButton, 'Przywróć domyślny rozmiar i interlinię');
    final reset = tester.getCenter(button);
    final lineHeight = tester.getCenter(find.byType(SettingsSlider).last).dy;
    final sample = tester.getCenter(find.byType(SongContent)).dy;

    expect(reset.dy, greaterThan(lineHeight));
    expect(reset.dy, lessThan(sample), reason: 'reset zostaje przy suwakach, których dotyczy');
    expect(reset.dx, moreOrLessEquals(tester.getCenter(find.byType(SettingsSlider).last).dx, epsilon: 1.0));
  });

  group('keep screen on', () {
    testWidgets('is on by default, and turning it off releases the wakelock immediately', (tester) async {
      await pumpSettings(tester);
      // A song open in the background: settings can be reached from the song screen.
      ScreenWakeLock.acquire();
      addTearDown(ScreenWakeLock.release);
      await tester.pump();
      expect(wakelock.enabled, isTrue);

      await tapVisible(tester, find.byType(Switch));

      expect(appSettings.keepScreenOn, isFalse);
      expect(wakelock.enabled, isFalse, reason: 'blokada schodzi, choć pieśń jest otwarta');
    });

    testWidgets('when off, opening a song does not enable the wakelock', (tester) async {
      SharedPreferences.setMockInitialValues({AppSettingsModel.keepScreenOnKey: false});
      await pumpSettings(tester);

      ScreenWakeLock.acquire();
      addTearDown(ScreenWakeLock.release);
      await tester.pump();

      expect(wakelock.enabled, isFalse);
    });

    testWidgets('is saved in preferences', (tester) async {
      await pumpSettings(tester);

      await tapVisible(tester, find.byType(Switch));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppSettingsModel.keepScreenOnKey), isFalse);
    });
  });

  group('theme', () {
    testWidgets('follows the system by default and offers three choices in one segmented control', (tester) async {
      await pumpSettings(tester);

      expect(appSettings.themeMode, ThemeMode.system);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Jasny'), findsOneWidget);
      expect(find.text('Ciemny'), findsOneWidget);
    });

    testWidgets('choosing dark is saved and selects its segment', (tester) async {
      await pumpSettings(tester);

      await tapVisible(tester, find.text('Ciemny'));

      expect(appSettings.themeMode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppSettingsModel.themeModeKey), 'dark');
      final button = tester.widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
      expect(button.selected, {ThemeMode.dark});
    });

    testWidgets('the saved theme is restored on reload', (tester) async {
      SharedPreferences.setMockInitialValues({AppSettingsModel.themeModeKey: 'light'});

      await pumpSettings(tester);

      expect(appSettings.themeMode, ThemeMode.light);
    });
  });

  testWidgets('reset does not change the theme or keep-screen-on', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppSettingsModel.themeModeKey: 'dark',
      AppSettingsModel.keepScreenOnKey: false,
    });
    await pumpSettings(tester);
    fontSizeModel.setFontSize(FontSizeModel.maxFontSize);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Przywróć domyślny rozmiar i interlinię'));

    expect(fontSizeModel.fontSize, FontSizeModel.defaultFontSize);
    expect(appSettings.themeMode, ThemeMode.dark);
    expect(appSettings.keepScreenOn, isFalse);
  });

  testWidgets('song sample grows with text size and nothing is clipped', (tester) async {
    await pumpSettings(tester, size: const Size(400, 900));
    final sample = find.byType(SongContent);
    final smallest = tester.getSize(sample).height;

    fontSizeModel.setFontSize(FontSizeModel.maxFontSize);
    await tester.pumpAndSettle();

    final largest = tester.getSize(sample).height;
    expect(largest, greaterThan(smallest), reason: 'brak stałej wysokości: próbka rośnie');
    expect(tester.takeException(), isNull, reason: 'nic nie przepełnia się przy największej czcionce');
  });
}
