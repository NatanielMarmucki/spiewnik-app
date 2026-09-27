import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/polish_plural.dart';

void main() {
  test('songs', () {
    expect([0, 1, 2, 4, 5, 12, 22, 25].map(songsCount),
        ['0 pieśni', '1 pieśń', '2 pieśni', '4 pieśni', '5 pieśni', '12 pieśni', '22 pieśni', '25 pieśni']);
  });

  test('lists', () {
    expect([0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 102, 112].map(listsCount), [
      '0 list', '1 lista', '2 listy', '4 listy', '5 list', '11 list', '12 list', '14 list', '21 list', //
      '22 listy', '102 listy', '112 list',
    ]);
  });
}
