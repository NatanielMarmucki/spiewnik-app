/// Polish plural form after a number: [one] for 1, [few] for 2-4, 22-24, 32-34... (but not 12-14),
/// [many] for the rest. Returns the number and the word, e.g. „3 listy”.
String plural(int count, String one, String few, String many) {
  final lastDigit = count % 10;
  final lastTwo = count % 100;
  final word = count == 1
      ? one
      : lastDigit >= 2 && lastDigit <= 4 && (lastTwo < 12 || lastTwo > 14)
          ? few
          : many;
  return '$count $word';
}

/// „1 pieśń”, „2 pieśni”, „5 pieśni”.
String songsCount(int count) => plural(count, 'pieśń', 'pieśni', 'pieśni');

/// „1 lista”, „2 listy”, „5 list”.
String listsCount(int count) => plural(count, 'lista', 'listy', 'list');
