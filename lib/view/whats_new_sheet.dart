import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/view/welcome_view.dart';
import 'package:spiewnik/view/widgets/outlined_pill_button.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';
import 'package:spiewnik/whats_new.dart';

/// A change in the release: what it is and where to find it.
typedef WhatsNewItem = ({IconData icon, String title, String text});

/// „Co nowego” (What's new) after an update to [WhatsNew.release]; shown once, see [WhatsNew].
Future<void> showWhatsNewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const WhatsNewSheet(),
  );
}

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  static const String title = 'Co nowego w wersji ${WhatsNew.release}';
  static const String lead = 'Kilka nowości, które ułatwią przygotowanie śpiewu.';
  static const String closeLabel = 'Rozumiem';

  /// Change it together with [WhatsNew.release].
  static const List<WhatsNewItem> items = [
    (
      icon: Icons.tune,
      title: 'Filtr kategorii',
      text: 'Przycisk z suwakami obok wyszukiwarki otwiera spis treści śpiewnika. Zaznacz na przykład „Ślub” '
          'albo „Pogrzeb”, a lista pokaże tylko te pieśni.',
    ),
    (
      icon: Icons.format_list_numbered,
      title: 'Listy pieśni',
      text: 'W zakładce Moje › Listy zbierzesz pieśni pod nabożeństwo, ślub czy próbę chóru, w kolejności '
          'śpiewania. Nową listę tworzysz plusem u góry.',
    ),
    (
      icon: Icons.add,
      title: 'Dodawanie pieśni do listy',
      text: 'Na liście przycisk „Dodaj pieśni” pozwala wyszukać i zaznaczyć pieśni. Możesz też przytrzymać '
          'pieśń w Śpiewniku albo w Ulubionych, zaznaczyć kilka i dodać je naraz.',
    ),
    (
      icon: Icons.play_arrow,
      title: 'Śpiewanie po kolei',
      text: 'Przycisk „Śpiewaj” otwiera pierwszą pieśń z listy, a strzałki na dole prowadzą w kolejności listy. '
          'Kolejność zmienisz, przeciągając uchwyt przy pieśni.',
    ),
    (
      icon: Icons.ios_share,
      title: 'Udostępnianie listy',
      text: 'Pod trzema kropkami na liście: numery pieśni do schowka, tytuły jako wiadomość albo pełne teksty '
          'w PDF do wydruku.',
    ),
    (
      icon: Icons.search,
      title: 'Lepsze wyszukiwanie',
      text: 'Słowa mogą być w dowolnej kolejności i w różnych formach: „chwała” znajdzie też „chwały”. '
          'Najlepiej pasujące pieśni są na górze.',
    ),
    (
      icon: Icons.check,
      title: 'Poprawione teksty',
      text: 'Poprawiliśmy znaki powtórzeń w kilkunastu pieśniach.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    WelcomeView.typeset(title),
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 26.0,
                      height: 1.15,
                      fontWeight: FontWeight.w300,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(WelcomeView.typeset(lead), style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary)),
                const SizedBox(height: 16.0),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: MergeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: ExcludeSemantics(child: Icon(item.icon, size: 18.0, color: appColors.accent)),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: textTheme.labelLarge?.copyWith(color: colors.onSurface)),
                                const SizedBox(height: 4.0),
                                Text(
                                  WelcomeView.typeset(item.text),
                                  style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedPillButton(label: closeLabel, onPressed: () => Navigator.pop(context)),
            ),
          ),
        ],
      ),
    );
  }
}
