import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Below search results cut at [shown] (#52): how many songs matched and how to narrow them down.
class SearchLimitNote extends StatelessWidget {
  final int shown;
  final int total;

  const SearchLimitNote({super.key, required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32.0, 20.0, 32.0, 32.0),
      child: Text(
        'Pokazano $shown najlepiej pasujących z $total. Dopisz kolejne słowo, żeby zawęzić wyniki.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.textTertiary),
      ),
    );
  }
}
