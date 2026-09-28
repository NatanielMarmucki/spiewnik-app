import 'package:flutter/material.dart';
import 'package:spiewnik/post_migration_welcome.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// One-time welcome screen after the migration from the old iOS app (issue #37).
///
/// Whether it appears is decided in `PostMigrationWelcome`; this is only the screen. Full screen,
/// before the song list, with a single way out: no "Wesprzyj" or "Zgłoś błąd" from the old app.
/// Nothing has a fixed height and the content scrolls, so it holds at system text scale 2.0.
class WelcomeView extends StatelessWidget {
  final WelcomeVariant variant;
  final VoidCallback onContinue;

  const WelcomeView({super.key, this.variant = WelcomeVariant.songs, required this.onContinue});

  static const String title = 'Śpiewnik w nowej odsłonie';
  static const String songsLead =
      'Twoje ulubione i własne pieśni są na miejscu — przeniosły się razem z aplikacją.';

  /// When only the font size came over: the user had no favorites or songs to promise.
  static const String settingsOnlyLead = 'Twoje ustawienia przeniosły się razem z aplikacją.';
  static const String changesTitle = 'Co się zmieniło:';
  static const List<String> changes = [
    'Nowy wygląd, czytelniejszy przy słabym świetle',
    'Tekst pieśni z wyraźnym podziałem na zwrotki i refren',
    'Wyszukiwanie działa też bez polskich znaków',
    'Ustawienia rozmiaru tekstu i interlinii w jednym miejscu',
    'Filtr kategorii i listy pieśni pod nabożeństwo, ślub czy próbę chóru',
  ];
  static const String continueLabel = 'Zaczynajmy';
  static const String continueSemanticsLabel = 'Zaczynajmy, przejdź do listy pieśni';

  /// Welcome heading, Newsreader 300 at 30 / 1.15 (docs/DESIGN-SYSTEM.md, section 5).
  static const double titleSize = 30.0;

  /// Same limit as the song column at the default size S = 19 (34 × S), so lines stay readable on iPad.
  static const double maxContentWidth = 646.0;

  static const double minButtonHeight = 48.0;

  static final RegExp _oneLetterWord = RegExp(r'(?<=^|\s)([aiouwzAIOUWZ]) ');

  /// Polish typesetting: a one-letter word ("i", "w", "z") never ends a line, a no-break space
  /// keeps it with the next word. Only the line breaking changes, not the text.
  static String leadFor(WelcomeVariant variant) => switch (variant) {
    WelcomeVariant.songs => songsLead,
    WelcomeVariant.settingsOnly => settingsOnlyLead,
  };

  static String typeset(String text) => text.replaceAllMapped(_oneLetterWord, (match) => '${match[1]}\u00A0');

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final body = textTheme.bodyMedium?.copyWith(color: colors.onSurface);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              // The column below grows with the text; when it no longer fits, the whole screen scrolls.
              hasScrollBody: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            typeset(title),
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              fontSize: titleSize,
                              height: 1.15,
                              fontWeight: FontWeight.w300,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(typeset(leadFor(variant)), style: body),
                        const SizedBox(height: 32.0),
                        Text(changesTitle, style: textTheme.labelLarge?.copyWith(color: colors.onSurface)),
                        const SizedBox(height: 12.0),
                        for (final change in changes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Semantics(
                              label: change,
                              container: true,
                              excludeSemantics: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('•', style: body?.copyWith(color: appColors.accent)),
                                  const SizedBox(width: 12.0),
                                  Expanded(child: Text(typeset(change), style: body)),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(height: 24.0),
                        Semantics(
                          button: true,
                          label: continueSemanticsLabel,
                          onTap: onContinue,
                          container: true,
                          excludeSemantics: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: minButtonHeight),
                            child: ElevatedButton(
                              onPressed: onContinue,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              ),
                              child: const Text(continueLabel, textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [WelcomeView] in the given [welcome] variant first, then the screen from [buildHome] for good.
/// With [welcome] null the welcome screen is skipped.
///
/// The welcome screen replaces the home screen instead of being pushed over it, so there is no
/// back gesture or back button leading anywhere: "Zaczynajmy" is the only way out.
class WelcomeGate extends StatefulWidget {
  final WelcomeVariant? welcome;
  final WidgetBuilder buildHome;

  const WelcomeGate({super.key, required this.welcome, required this.buildHome});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  late bool _welcomeVisible = widget.welcome != null;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _welcomeVisible
          ? WelcomeView(
              key: const ValueKey('welcome'),
              variant: widget.welcome!,
              onContinue: () => setState(() => _welcomeVisible = false),
            )
          : KeyedSubtree(key: const ValueKey('home'), child: Builder(builder: widget.buildHome)),
    );
  }
}
