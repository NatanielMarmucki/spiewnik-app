const List<String> _weekdays = ['poniedziałek', 'wtorek', 'środa', 'czwartek', 'piątek', 'sobota', 'niedziela'];

const List<String> _months = [
  'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca', //
  'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia',
];

/// A day in words, e.g. „niedziela, 4 października” or, [withYear], „niedziela, 4 października 2026”.
String formatDay(DateTime day, {bool withYear = false}) =>
    '${_weekdays[day.weekday - 1]}, ${_dayAndMonth(day)}${withYear ? ' ${day.year}' : ''}';

/// The heading form, e.g. „Niedziela · 4 października 2026”.
String formatDayHeading(DateTime day) {
  final weekday = _weekdays[day.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)} · ${_dayAndMonth(day)} ${day.year}';
}

String _dayAndMonth(DateTime day) => '${day.day} ${_months[day.month - 1]}';
