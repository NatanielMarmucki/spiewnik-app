import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_categories.dart';

void main() {
  group('expandRanges', () {
    test('expands numbers and inclusive ranges, keeping the order of the notation', () {
      expect(expandRanges('822-824, 624-625, 7'), [822, 823, 824, 624, 625, 7]);
    });

    test('accepts a single number and a one-song range', () {
      expect(expandRanges('5'), [5]);
      expect(expandRanges('5-5'), [5]);
    });

    test('rejects what is not a number or a range', () {
      expect(() => expandRanges('1-a'), throwsFormatException);
      expect(() => expandRanges('10-2'), throwsFormatException);
      expect(() => expandRanges('1-2-3'), throwsFormatException);
      expect(() => expandRanges(''), throwsFormatException);
    });
  });

  group('the asset', () {
    final json = File(SongCategories.assetPath).readAsStringSync();
    final categories = SongCategories.fromJsonString(json);

    test('has 4 categories and 24 subcategories', () {
      expect(categories.categories.map((c) => c.id), ['I', 'II', 'III', 'IV']);
      expect(categories.subcategories.map((s) => s.id), [for (var id = 1; id <= 24; id++) id]);
    });

    test('the parser reproduces "count" of every subcategory', () {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      for (final category in raw['categories'] as List) {
        for (final subcategory in category['subcategories'] as List) {
          expect(
            categories.subcategory(subcategory['id'] as int)!.songs.length,
            subcategory['count'],
            reason: subcategory['name'] as String,
          );
        }
      }
    });

    test('exactly 34 songs of 1-2000 have no category', () {
      final categorized = categories.songsIn(categories.subcategories.map((s) => s.id));
      final uncategorized = [for (var n = 1; n <= 2000; n++) if (!categorized.contains(n)) n];
      expect(uncategorized, [
        876, 880, 892, 921, 924, 940, 1004, 1017, 1018, 1089, 1129, 1153, 1174, 1236, 1263, 1309, 1348, //
        1353, 1362, 1452, 1476, 1480, 1503, 1537, 1539, 1589, 1657, 1681, 1706, 1742, 1746, 1754, 1762, 1895,
      ]);
    });

    test('a song can be in several subcategories; the union counts it once', () {
      expect(categories.subcategory(1)!.songs, contains(926));
      expect(categories.subcategory(4)!.songs, contains(926));
      expect(categories.songsIn([1, 4]).length, 116 + 37 - 1);
    });
  });
}
