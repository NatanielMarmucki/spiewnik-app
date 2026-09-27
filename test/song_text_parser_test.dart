import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_text.dart';

/// The parser on real songs from the asset, not on made-up strings.
void main() {
  const parser = SongTextParser();
  late Map<int, Song> songs;

  setUpAll(() {
    final data = SongsData.fromJsonString(File('assets/songs_data.json').readAsStringSync());
    songs = {for (final song in data.songs) song.number: song};
  });

  List<SongBlock> parseSong(int number) => parser.parse(songs[number]!.content);

  group('song 1 „Alleluja, chwalcie Pana” — verses, chorus and a repeat', () {
    test('splits into blocks without empty lines', () {
      final blocks = parseSong(1);

      expect(blocks, isNotEmpty);
      expect(blocks.every((block) => block.text.trim().isNotEmpty), isTrue);
      expect(blocks.first, isA<VerseBlock>());
    });

    test('the first verse is marked as first, the later ones are not', () {
      final verses = parseSong(1).whereType<VerseBlock>().toList();

      expect(verses.first.number, 1);
      expect(verses.first.isFirst, isTrue);
      expect(verses.skip(1).map((verse) => verse.isFirst), everyElement(isFalse));
      expect(verses.map((verse) => verse.number), [1, 2, 3]);
    });

    test('removes the verse number from the running text', () {
      final first = parseSong(1).whereType<VerseBlock>().first;

      expect(first.text, startsWith('Alleluja, chwalcie Pana'));
      expect(first.text, isNot(startsWith('1.')));
    });

    test('removes the chorus label from the running text', () {
      final refrain = parseSong(1).whereType<RefrainBlock>().single;

      expect(refrain.text, startsWith('Wysławiajcie imię Pańskie'));
      expect(refrain.text, isNot(contains('Refren:')));
    });

    test('repeat marks stay as separate pieces, not in the text', () {
      final refrain = parseSong(1).whereType<RefrainBlock>().single;
      final marks = refrain.inlines.whereType<RepeatMark>().toList();

      expect(marks.map((mark) => mark.text), ['[:', ':]']);
      expect(refrain.text, isNot(contains('[:')));
      expect(refrain.text, contains('Niech są pełne Jego chwały,'));
    });
  });

  group('song 2 „Barankowi chwałę” — no chorus', () {
    test('has only verses', () {
      final blocks = parseSong(2);

      expect(blocks.whereType<RefrainBlock>(), isEmpty);
      expect(blocks.whereType<VerseBlock>().length, blocks.length);
    });
  });

  group('song 6 „Barankowi cześć” — a repeat spanning the whole verse', () {
    test('the verse starts and ends with repeat marks', () {
      final first = parseSong(6).whereType<VerseBlock>().first;

      expect(first.inlines.first, isA<RepeatMark>());
      expect((first.inlines.first as RepeatMark).isOpening, isTrue);
      expect(first.inlines.whereType<RepeatMark>().length, greaterThanOrEqualTo(2));
    });

    test('the text between the marks stays whole, even when it is long', () {
      final first = parseSong(6).whereType<VerseBlock>().first;

      expect(first.text, contains('Barankowi cześć, chwała Mu!'));
      expect(first.text.length, greaterThan(60));
    });
  });

  group('whole songbook', () {
    test('no block is empty or starts with a marker', () {
      for (final song in songs.values) {
        final blocks = parser.parse(song.content);
        expect(blocks, isNotEmpty, reason: 'pieśń ${song.number}');
        for (final block in blocks) {
          expect(block.text.trim(), isNotEmpty, reason: 'pieśń ${song.number}');
          expect(block.text.trimLeft(), isNot(startsWith('Refren:')), reason: 'pieśń ${song.number}');
          expect(
            RegExp(r'^\d+\.\s').hasMatch(block.text.trimLeft()),
            isFalse,
            reason: 'pieśń ${song.number}',
          );
        }
      }
    });

    test('repeat marks always balance within a block', () {
      for (final song in songs.values) {
        for (final block in parser.parse(song.content)) {
          var open = 0;
          for (final mark in block.inlines.whereType<RepeatMark>()) {
            open += mark.isOpening ? 1 : -1;
            expect(open, greaterThanOrEqualTo(0), reason: 'pieśń ${song.number}: zamknięcie bez otwarcia');
          }
          expect(open, 0, reason: 'pieśń ${song.number}: otwarcie bez zamknięcia');
        }
      }
    });

    test('the text joined back together matches the original without markers', () {
      final song = songs[15]!;
      final joined = parser
          .parse(song.content)
          .map((block) => block.inlines.map((part) => part is SongText ? part.text : (part as RepeatMark).text).join())
          .join('\n\n');
      final original = song.content
          .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^Refren:\s+', multiLine: true), '')
          .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
          .trim();

      expect(joined, original);
    });
  });

  group('typos in the data', () {
    test('an unpaired mark stays plain text, not a marker', () {
      // The typo song 169 had until #30: the opening mark lost its colon.
      final blocks = parser.parse('2. Twe serce czemuż zwleka? [Czym prędzej pośpiesz Doń!:]');

      expect(blocks.single.inlines.whereType<RepeatMark>(), isEmpty);
      expect(blocks.single.text, contains(':]'));
    });

    test('song 169, fixed in #30, has a repeat again', () {
      final withRepeat = parseSong(169).firstWhere((block) => block.text.contains('Czym prędzej'));

      expect(withRepeat.inlines.whereType<RepeatMark>().map((mark) => mark.text), ['[:', ':]']);
    });

    test('a pair in the same block still works', () {
      final blocks = parser.parse('1. Zwykły [:powtarzany:] tekst i samotny :] znak');
      final marks = blocks.single.inlines.whereType<RepeatMark>().toList();

      expect(marks.map((mark) => mark.text), ['[:', ':]']);
      expect(blocks.single.text, 'Zwykły powtarzany tekst i samotny :] znak');
    });
  });

  group('data quality', () {
    /// Blocks in which the repeat marks do not balance: typos in the lyrics, which the parser would show
    /// as plain text, that is, silently. All 14 were fixed in tools/song_merge/corrections.json (#30);
    /// the number must stay at 0.
    const knownUnpairedBlocks = 0;

    test('the number of blocks with unpaired marks does not grow', () {
      final offenders = <String>[];

      for (final song in songs.values) {
        for (final block in RegExp(r'\n\s*\n+').allMatches(song.content).isEmpty
            ? [song.content]
            : song.content.split(RegExp(r'\n\s*\n+'))) {
          final opens = RegExp(r'\[:').allMatches(block).length;
          final closes = RegExp(r':\]').allMatches(block).length;
          if (opens != closes) {
            offenders.add('${song.number} ${song.title}');
          }
        }
      }

      expect(
        offenders.length,
        lessThanOrEqualTo(knownUnpairedBlocks),
        reason: 'Nowe niesparowane znaki powtórzenia w danych: ${offenders.join(', ')}',
      );
    });
  });

  group('details', () {
    test('a single line break within a block is kept', () {
      final blocks = parser.parse('1. Pierwszy wers\ndrugi wers\n\n2. Kolejna zwrotka');

      expect(blocks, hasLength(2));
      expect(blocks.first.text, 'Pierwszy wers\ndrugi wers');
    });

    test('a block without a marker becomes a plain paragraph', () {
      final blocks = parser.parse('Sam tekst bez numeru');

      expect(blocks.single, isA<PlainBlock>());
      expect(blocks.single.text, 'Sam tekst bez numeru');
    });

    test('empty content gives an empty block list', () {
      expect(parser.parse(''), isEmpty);
      expect(parser.parse('\n\n  \n'), isEmpty);
    });
  });
}
