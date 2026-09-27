import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:spiewnik/export/playlist_pdf.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

PdfFonts testFonts() {
  pw.Font font(String name) => pw.Font.ttf(File('assets/fonts/$name.ttf').readAsBytesSync().buffer.asByteData());
  return PdfFonts(
    serif: font('Newsreader-Regular'),
    serifLight: font('Newsreader-Light'),
    ui: font('SchibstedGrotesk-Regular'),
    uiMedium: font('SchibstedGrotesk-Medium'),
  );
}

PlaylistDetails sampleList() {
  final playlist = Playlist(name: 'Nabożeństwo niedzielne', createdAt: DateTime(2026), updatedAt: DateTime(2026))
    ..date = DateTime(2026, 10, 4);
  return PlaylistDetails(playlist, [
    PlaylistEntry.songbook(Song(
      number: 8,
      title: 'Chwalże ma duszo',
      content: '1. Chwalże, ma duszo, Pana, Króla chwały! [:Zbawiciela:]\n\n'
          'Refren: Chwała, chwała, chwała Jemu! Źródło łask, żywota żółć, gęśl i jaźń.\n\n'
          '2. Który cię stworzył, który cię zachował.',
      favorite: false,
    )),
    PlaylistEntry.mine(
        MySong(id: 3, title: 'Wieczorna', content: 'Zostań z nami, Panie.', createdAt: DateTime(2026), updatedAt: DateTime(2026))),
  ]);
}

void main() {
  test('builds a PDF with the fonts embedded', () async {
    final bytes = await buildPlaylistPdf(sampleList(), testFonts());

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('FontFile2'), reason: 'fonts are embedded');
    // Title page and one page per song.
    expect(RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(bytes)).length, 3);

    final out = Platform.environment['PLAYLIST_PDF_OUT'];
    if (out != null) {
      File(out).writeAsBytesSync(bytes);
    }
  });
}
