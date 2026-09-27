import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/song_model.dart';

/// Song search over the text of the whole songbook.
///
/// The search text of each song (lower case, no diacritics, cleaned content) is computed once, on the
/// first search, and kept in memory: recomputing it for 2000 songs on every query took about 120 ms in
/// release. Songs are keyed by number and the entry is rebuilt when the title or content differs, so
/// the cache survives the reloads a favorite causes (new Song objects, same text).
///
/// Pure Dart on purpose, so tools/search_benchmark.dart measures this code compiled ahead of time.
class SongSearch {
  final Map<int, _SearchText> _texts = {};

  /// Songs matching [query]: the number contains the query, or **every** word of the query is found in
  /// the title or the content (see [findWord]), in any order, ignoring letter case, Polish diacritics
  /// and punctuation.
  ///
  /// Results of a query in words are ranked (see [_score]); equal ones keep the order of [songs], which
  /// lists songs by number. A query of digits keeps that order too: it looks for a number.
  List<Song> filter(List<Song> songs, String query) {
    final words = queryWords(query);
    final matches = [
      for (final song in songs)
        if (song.number.toString().contains(query) || (words.isNotEmpty && _hasAll(_textOf(song), words))) song,
    ];
    if (words.isEmpty || _digits.hasMatch(query)) {
      return matches;
    }
    final scores = {for (final song in matches) song: _score(_textOf(song), words)};
    final order = {for (final (index, song) in matches.indexed) song: index};
    return matches
      ..sort((a, b) {
        final byScore = scores[b]!.compareTo(scores[a]!);
        return byScore != 0 ? byScore : order[a]!.compareTo(order[b]!);
      });
  }

  static final RegExp _digits = RegExp(r'^\s*\d+\s*$');

  /// How well a matching song matches [words], from the strongest signal down:
  /// - a word in the title (1000 for the exact form, 600 for a form found by its stem), before one in
  ///   the content (100 exact, 60 by stem, plus up to 10 for an early verse: the first verse is how a song
  ///   is remembered);
  /// - all words next to each other in the order of the query, in the title (500) or the content (50).
  static int _score(_SearchText text, List<String> words) {
    var score = 0;
    for (final word in words) {
      if (_find(text.title, word, exact: true) >= 0) {
        score += 1000;
      } else if (findWord(text.title, word) >= 0) {
        score += 600;
      } else {
        final exactAt = _find(text.content, word, exact: true);
        final at = exactAt >= 0 ? exactAt : findWord(text.content, word);
        score += (exactAt >= 0 ? 100 : 60) + 10 - text.verseAt(at).clamp(0, 10);
      }
    }
    if (words.length > 1) {
      if (_inOrder(text.title, words)) {
        score += 500;
      } else if (_inOrder(text.content, words)) {
        score += 50;
      }
    }
    return score;
  }

  /// Whether [words] follow each other in [text], separated only by spaces or punctuation.
  static bool _inOrder(String text, List<String> words) {
    for (var at = findWord(text, words.first); at >= 0; at = _find(text, words.first, from: at + 1)) {
      var position = at;
      var inOrder = true;
      for (final next in words.skip(1)) {
        position = _wordEnd(text, position);
        final nextStart = _nextWordStart(text, position);
        if (nextStart == position || !_matchesAt(text, nextStart, next)) {
          inOrder = false;
          break;
        }
        position = nextStart;
      }
      if (inOrder) {
        return true;
      }
    }
    return false;
  }

  static int _wordEnd(String text, int from) {
    var end = from;
    while (end < text.length && _isLetter(text.codeUnitAt(end))) {
      end++;
    }
    return end;
  }

  static int _nextWordStart(String text, int from) {
    var start = from;
    while (start < text.length && !_isLetter(text.codeUnitAt(start))) {
      start++;
    }
    return start;
  }

  bool _hasAll(_SearchText text, List<String> words) =>
      words.every((word) => findWord(text.title, word) >= 0 || findWord(text.content, word) >= 0);

  /// Parts of [song]'s title matching the words of [query], with the original letters, for highlighting.
  List<String> titleMatches(Song song, String query) {
    final title = _textOf(song).title;
    return [
      for (final word in queryWords(query))
        if (findWord(title, word) case final start when start >= 0)
          // Lowercasing and removing diacritics keep every letter in place, so positions match the original.
          song.title.substring(start, _highlightEnd(title, start, word)),
    ];
  }

  /// End of the highlight for [word] found at [start]: as long as the typed word, but not past the end
  /// of the word in the title, so "chwałę" highlights "Chwały" whole and "chwal" only "Chwal" of "Chwalże".
  static int _highlightEnd(String title, int start, String word) {
    var end = start;
    while (end < title.length && end - start < word.length && _isLetter(title.codeUnitAt(end))) {
      end++;
    }
    return end;
  }

  /// Where [word] of a query is found in normalized [text], or -1. The rule depends on its length:
  /// - 1-2 letters: a whole word, so "o" or "na" do not match inside every other word;
  /// - 3-4 letters: the start of a word ("pan" finds "Panu", not "wspaniały");
  /// - 5 letters or more: the start of a word, after cutting a Polish ending off the query word
  ///   ([stem]), so "chwała" finds "chwały" and "matko" finds "matka".
  static int findWord(String text, String word) => _find(text, word);

  /// [findWord] from position [from]; with [exact], [word] itself as a whole word, not its stem.
  static int _find(String text, String word, {int from = 0, bool exact = false}) {
    final needle = exact ? word : _needle(word);
    for (var at = text.indexOf(needle, from); at >= 0; at = text.indexOf(needle, at + 1)) {
      if (_matchesAt(text, at, word, exact: exact)) {
        return at;
      }
    }
    return -1;
  }

  static bool _matchesAt(String text, int at, String word, {bool exact = false}) {
    final needle = exact ? word : _needle(word);
    if (!text.startsWith(needle, at) || (at > 0 && _isLetter(text.codeUnitAt(at - 1)))) {
      return false;
    }
    final end = at + needle.length;
    final endsWord = end == text.length || !_isLetter(text.codeUnitAt(end));
    return endsWord || !(exact || word.length <= 2);
  }

  static String _needle(String word) => word.length >= 5 ? stem(word) : word;

  /// [word] without its Polish inflectional ending, if at least 4 letters remain: "chwala" becomes
  /// "chwal", "jezusowi" "jezus". A light stemmer, not a dictionary: an ending is cut only when the word
  /// has one from the list, and alternating vowels ("baranek", "baranka") stay out of reach.
  static String stem(String word) {
    for (final ending in _endings) {
      if (word.length - ending.length >= 4 && word.endsWith(ending)) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return word;
  }

  /// Polish endings, without diacritics (ą, ę became a, e), longest first so "-ami" wins over "-i".
  static const List<String> _endings = [
    'ami', 'ach', 'ego', 'emu', 'ymi', 'imi', 'owi', //
    'ow', 'om', 'ie', 'ia', 'iu', 'ej', //
    'a', 'e', 'i', 'o', 'u', 'y',
  ];

  /// A letter of the normalized text: a-z, or anything from Latin-1 letters up (foreign accented
  /// letters). Spaces, digits, "/" of the repeat markers and other punctuation separate words.
  static bool _isLetter(int unit) =>
      (unit >= 0x61 && unit <= 0x7A) || (unit >= 0xC0 && unit != 0xD7 && unit != 0xF7 && unit < 0x2000);

  /// Words of [query]: lower case, no diacritics, split on whitespace and on the punctuation that is
  /// removed from the song text too.
  static List<String> queryWords(String query) => [
        for (final word in removePolishDiacritics(query.toLowerCase()).split(_wordSeparators))
          if (word.isNotEmpty) word,
      ];

  static final RegExp _wordSeparators = RegExp(r"[\s,.;:'\[\]()!?\-”—„]+");

  _SearchText _textOf(Song song) {
    final cached = _texts[song.number];
    if (cached != null && cached.sourceTitle == song.title && cached.sourceContent == song.content) {
      return cached;
    }
    return _texts[song.number] = _SearchText(song.title, song.content);
  }

  /// Collapses runs of whitespace into a single space.
  ///
  /// Removing the ignored characters leaves gaps inside the text: „Baranku Boży, x zmiłuj się"
  /// became „Baranku Boży  zmiłuj się" with a double space, so the query „boży zmiłuj" did not
  /// match, but „boży  zmiłuj" did. Both sides are now normalized the same way, so both work.
  static String normalizeWhitespace(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _SearchText {
  final String sourceTitle;
  final String sourceContent;
  final String title;
  final String content;

  /// Where each verse (a block after a blank line) starts in [content].
  final List<int> verseStarts;

  factory _SearchText(String sourceTitle, String sourceContent) {
    final (content, verseStarts) = _clean(removePolishDiacritics(sourceContent.toLowerCase()));
    return _SearchText._(sourceTitle, sourceContent, removePolishDiacritics(sourceTitle.toLowerCase()), content,
        verseStarts);
  }

  _SearchText._(this.sourceTitle, this.sourceContent, this.title, this.content, this.verseStarts);

  /// Index of the verse that contains [position] of [content]: 0 for the first one.
  int verseAt(int position) {
    var verse = 0;
    while (verse + 1 < verseStarts.length && verseStarts[verse + 1] <= position) {
      verse++;
    }
    return verse;
  }

  /// Splits the content into words on everything that is not a letter (see [SongSearch._isLetter]): verse
  /// numbers, punctuation, the slashes of repeat markers. A separator becomes a space, so „Wiesz-li” is two
  /// words, not „wieszli” (#49). The x of a repeat marker (`/x3`, `3x`) is a separator too; any other x is a
  /// letter. Collapses whitespace in the same pass and notes where verses start: after a blank line.
  static (String, List<int>) _clean(String text) {
    final units = <int>[];
    final verseStarts = [0];
    var pendingSpace = false;
    var newlines = 0;
    final codeUnits = text.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      final unit = codeUnits[i];
      if (!SongSearch._isLetter(unit) || _isRepeatX(codeUnits, i)) {
        pendingSpace = units.isNotEmpty;
        if (unit == 0x0A) {
          newlines++;
        }
        continue;
      }
      if (pendingSpace) {
        units.add(0x20);
        pendingSpace = false;
        if (newlines >= 2) {
          verseStarts.add(units.length);
        }
      }
      newlines = 0;
      units.add(unit);
    }
    return (String.fromCharCodes(units), verseStarts);
  }

  /// Whether the x at [i] belongs to a repeat marker: right after a slash or a digit, or right before a digit.
  static bool _isRepeatX(List<int> units, int i) {
    if (units[i] != 0x78) {
      return false;
    }
    bool isDigit(int at) => at >= 0 && at < units.length && units[at] >= 0x30 && units[at] <= 0x39;
    return (i > 0 && units[i - 1] == 0x2F) || isDigit(i - 1) || isDigit(i + 1);
  }
}
