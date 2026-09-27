import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/data_migration_notice.dart';
import 'package:spiewnik/view/link_failure_dialog.dart';
import 'package:spiewnik/view/widgets/outlined_pill_button.dart';
import 'package:spiewnik/view/widgets/settings_section.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Settings after the redesign (docs/DESIGN-SYSTEM.md, sections 4-6).
///
/// Sections instead of cards: „Czytanie”, „Wygląd”, „Aplikacja” and the versions at the end. The song
/// sample sits **directly below the size slider** and grows with the text — it has no fixed height,
/// so nothing gets cut off at the largest font size (rule 1 from section 7).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  /// Two lines of a song: enough to see the line height, and few enough not to hide the sliders.
  static const String sampleText = 'Alleluja, chwalcie Pana,\nNućcie Jemu chwałę, cześć!';

  @override
  Widget build(BuildContext context) {
    final settingsViewModel = Provider.of<SettingsViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          const _ReadingSection(),
          const _AppearanceSection(),
          SettingsSection(
            title: 'Aplikacja',
            children: [
              SettingsRow(
                icon: Icons.sms,
                label: 'Kontakt',
                onTap: () => _openPage(context, settingsViewModel, 'https://spiewnik.odoo.com/contactus'),
              ),
              SettingsRow(
                icon: Icons.person,
                label: 'O mnie',
                onTap: () => _openPage(context, settingsViewModel, 'https://spiewnik.odoo.com/about-us'),
              ),
              SettingsRow(
                icon: Icons.favorite_border,
                label: 'Wesprzyj',
                onTap: () => _openPage(context, settingsViewModel, 'https://suppi.pl/spiewnik'),
              ),
              SettingsRow(
                icon: Icons.error_outline,
                label: 'Zgłoś błąd',
                onTap: () => _reportBug(context, settingsViewModel),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: DataMigrationNotice(settingsViewModel: settingsViewModel),
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}

/// Opens a web page, and when that fails, says so instead of staying silent.
Future<void> _openPage(BuildContext context, SettingsViewModel viewModel, String url) async {
  final opened = await viewModel.launchURL(url);
  if (!opened && context.mounted) {
    await showPageFailureDialog(context, url);
  }
}

Future<void> _reportBug(BuildContext context, SettingsViewModel viewModel) async {
  final version = await viewModel.getAppVersion();
  final sent = await viewModel.sendEmail(version);
  if (!sent && context.mounted) {
    await showEmailFailureDialog(context, SettingsViewModel.contactEmail);
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection();

  @override
  Widget build(BuildContext context) {
    final fontSizeModel = context.watch<FontSizeModel>();
    final appSettings = context.watch<AppSettingsModel>();

    return SettingsSection(
      title: 'Czytanie',
      children: [
        SettingsSlider(
          label: 'Rozmiar tekstu',
          value: fontSizeModel.fontSize,
          valueLabel: '${fontSizeModel.fontSize.round()}',
          min: FontSizeModel.minFontSize,
          max: FontSizeModel.maxFontSize,
          divisions: (FontSizeModel.maxFontSize - FontSizeModel.minFontSize).round(),
          onChanged: fontSizeModel.setFontSize,
        ),
        SettingsSlider(
          label: 'Interlinia',
          value: fontSizeModel.lineHeight,
          valueLabel: fontSizeModel.lineHeight.toStringAsFixed(2),
          min: FontSizeModel.minLineHeight,
          max: FontSizeModel.maxLineHeight,
          divisions: ((FontSizeModel.maxLineHeight - FontSizeModel.minLineHeight) / 0.05).round(),
          onChanged: fontSizeModel.setLineHeight,
        ),
        // Right below the sliders it resets; centered, as a button, not a link at the edge.
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 4.0, 22.0, 12.0),
          child: Center(
            child: OutlinedPillButton(
              // The reset applies only to size and line height: theme and keep-screen-on stay.
              label: 'Przywróć domyślny rozmiar i interlinię',
              onPressed: fontSizeModel.resetToDefaults,
            ),
          ),
        ),
        // Sample below both sliders: shows size and line height at once.
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 4.0, 22.0, 16.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // No height limit: the sample grows with the font.
              child: SongContent(
                content: SettingsView.sampleText,
                padding: EdgeInsets.zero,
                scrollable: false,
              ),
            ),
          ),
        ),
        SettingsSwitch(
          label: 'Nie gaś ekranu przy pieśni',
          description: 'Ekran zostaje włączony, dopóki masz otwartą pieśń.',
          value: appSettings.keepScreenOn,
          onChanged: appSettings.setKeepScreenOn,
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  static const List<({ThemeMode mode, String label})> _options = [
    (mode: ThemeMode.system, label: 'System'),
    (mode: ThemeMode.light, label: 'Jasny'),
    (mode: ThemeMode.dark, label: 'Ciemny'),
  ];

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsModel>();
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return SettingsSection(
      title: 'Wygląd',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 4.0, 22.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Motyw', style: textTheme.bodyMedium),
              const SizedBox(height: 8.0),
              // A three-way switch instead of a list: the choice is visible without reading three rows.
              // Full width, so the labels have room even with an enlarged font.
              SegmentedButton<ThemeMode>(
                segments: [
                  for (final option in _options)
                    ButtonSegment(value: option.mode, label: Text(option.label)),
                ],
                selected: {appSettings.themeMode},
                onSelectionChanged: (selection) => appSettings.setThemeMode(selection.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  foregroundColor: appColors.textSecondary,
                  selectedForegroundColor: appColors.onAccent,
                  selectedBackgroundColor: appColors.accent,
                  side: BorderSide(color: appColors.line),
                  textStyle: textTheme.labelLarge,
                  // The touch target grows with the font: the height is a minimum, not fixed.
                  minimumSize: const Size(0.0, 48.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
