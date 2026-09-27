import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

/// Song numbers from the songbook's notation: numbers and ranges `a-b` separated by commas, e.g.
/// `"1-3, 7, 10-11"`. A range includes both ends. Keeps the order of the notation, which is not always
/// ascending. Throws [FormatException] on anything else.
List<int> expandRanges(String notation) {
  final numbers = <int>[];
  for (final part in notation.split(',')) {
    final bounds = part.split('-').map((bound) => int.parse(bound.trim())).toList();
    if (bounds.length > 2 || bounds.last < bounds.first) {
      throw FormatException('Not a number or a range: "$part"');
    }
    for (var number = bounds.first; number <= bounds.last; number++) {
      numbers.add(number);
    }
  }
  return numbers;
}

/// A part of the songbook's table of contents, e.g. „II Droga zbawienia”.
class SongCategory {
  /// Roman numeral: I to IV.
  final String id;
  final String name;
  final List<SongSubcategory> subcategories;

  const SongCategory({required this.id, required this.name, required this.subcategories});
}

/// A section of a [SongCategory], e.g. „22 Ślub”.
class SongSubcategory {
  /// 1 to 24, unique across the categories.
  final int id;
  final String categoryId;
  final String name;

  /// Unique song numbers, ascending.
  final List<int> songs;

  const SongSubcategory({required this.id, required this.categoryId, required this.name, required this.songs});
}

/// The table of contents from `assets/data/kategorie.json`. Kept in memory rather than in ObjectBox:
/// the asset is read-only and small, so parsing it on start is cheaper than storing and syncing a copy.
///
/// A song may belong to several subcategories; user songs belong to none.
class SongCategories {
  static const String assetPath = 'assets/data/kategorie.json';

  static const SongCategories empty = SongCategories([]);

  /// In the order of the book.
  final List<SongCategory> categories;

  const SongCategories(this.categories);

  /// Throws [FormatException] when the file does not match the expected structure.
  factory SongCategories.fromJsonString(String json) {
    try {
      final root = jsonDecode(json) as Map<String, dynamic>;
      return SongCategories([
        for (final category in root['categories'] as List)
          SongCategory(
            id: category['id'] as String,
            name: category['name'] as String,
            subcategories: [
              for (final subcategory in category['subcategories'] as List)
                SongSubcategory(
                  id: subcategory['id'] as int,
                  categoryId: category['id'] as String,
                  name: subcategory['name'] as String,
                  songs: (expandRanges(subcategory['songs'] as String).toSet().toList()..sort()),
                ),
            ],
          ),
      ]);
    } on TypeError catch (error) {
      throw FormatException('Unexpected structure of $assetPath: $error');
    }
  }

  static Future<SongCategories> load(AssetBundle bundle) async =>
      SongCategories.fromJsonString(await bundle.loadString(assetPath));

  Iterable<SongSubcategory> get subcategories => categories.expand((category) => category.subcategories);

  SongSubcategory? subcategory(int id) => subcategories.where((subcategory) => subcategory.id == id).firstOrNull;

  SongCategory category(String id) => categories.firstWhere((category) => category.id == id);

  /// Songs in any of [subcategoryIds]: the union, not the intersection.
  Set<int> songsIn(Iterable<int> subcategoryIds) => {
        for (final id in subcategoryIds) ...?subcategory(id)?.songs,
      };
}
