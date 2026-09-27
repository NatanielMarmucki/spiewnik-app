import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:spiewnik/model/polish_date.dart';
import 'package:spiewnik/model/song_text.dart';
import 'package:spiewnik/viewmodel/playlist_viewmodel.dart';

/// The app's typefaces for the PDF, embedded in the file (latin + latin-ext subsets from assets/fonts/).
class PdfFonts {
  final pw.Font serif;
  final pw.Font serifLight;
  final pw.Font ui;
  final pw.Font uiMedium;

  const PdfFonts({required this.serif, required this.serifLight, required this.ui, required this.uiMedium});

  static Future<PdfFonts> load(AssetBundle bundle) async {
    Future<pw.Font> font(String name) async => pw.Font.ttf(await bundle.load('assets/fonts/$name.ttf'));
    return PdfFonts(
      serif: await font('Newsreader-Regular'),
      serifLight: await font('Newsreader-Light'),
      ui: await font('SchibstedGrotesk-Regular'),
      uiMedium: await font('SchibstedGrotesk-Medium'),
    );
  }
}

// Print colors: ink on white, the light theme's saffron for labels.
const PdfColor _ink = PdfColor.fromInt(0xFF1B1A17);
const PdfColor _secondary = PdfColor.fromInt(0xFF5C5852);
const PdfColor _accent = PdfColor.fromInt(0xFF7A5518);
const PdfColor _line = PdfColor.fromInt(0xFFE2DCD1);

/// The full texts of a list, in its order, as an A4 PDF: a title page with the name, the date and the contents,
/// then every song from a new page under a clear heading — the way a songbook is used at a music stand.
Future<Uint8List> buildPlaylistPdf(PlaylistDetails details, PdfFonts fonts) {
  final playlist = details.playlist;
  final date = playlist.date;
  final document = pw.Document(title: playlist.name, creator: 'Śpiewnik');
  final label = pw.TextStyle(font: fonts.uiMedium, fontSize: 8.5, letterSpacing: 1.7, color: _accent);
  final body = pw.TextStyle(font: fonts.serif, fontSize: 12.5, lineSpacing: 3.5, color: _ink);
  const parser = SongTextParser();
  final count = details.entries.length;

  pw.Widget footer(pw.Context context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          '${playlist.name} · ${context.pageNumber}/${context.pagesCount}',
          style: pw.TextStyle(font: fonts.ui, fontSize: 8, color: _secondary),
        ),
      );

  pw.Widget block(SongBlock block) {
    final text = pw.RichText(
      text: pw.TextSpan(
        style: body,
        children: [
          for (final inline in block.inlines)
            switch (inline) {
              SongText(:final text) => pw.TextSpan(text: text),
              RepeatMark() => pw.TextSpan(text: (inline).text, style: pw.TextStyle(color: _accent)),
            },
        ],
      ),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: switch (block) {
        VerseBlock(:final number) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 22, child: pw.Text('$number.', style: body.copyWith(color: _secondary))),
              pw.Expanded(child: text),
            ],
          ),
        RefrainBlock() => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 22),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [pw.Text('REFREN', style: label), pw.SizedBox(height: 3), text],
            ),
          ),
        PlainBlock() => text,
      },
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 40),
      footer: footer,
      build: (context) => [
        pw.SizedBox(height: 120),
        pw.Text('LISTA PIEŚNI', style: label),
        pw.SizedBox(height: 10),
        pw.Text(playlist.name, style: pw.TextStyle(font: fonts.serifLight, fontSize: 32, color: _ink)),
        if (date != null) ...[
          pw.SizedBox(height: 8),
          pw.Text(formatDay(date, withYear: true), style: pw.TextStyle(font: fonts.ui, fontSize: 12, color: _secondary)),
        ],
        pw.SizedBox(height: 32),
        pw.Container(height: 0.5, color: _line),
        pw.SizedBox(height: 12),
        for (final (index, entry) in details.entries.indexed)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 26, child: pw.Text('${index + 1}.', style: body.copyWith(color: _accent))),
                pw.Expanded(child: pw.Text(entry.title, style: body)),
                pw.Text(entry.number?.toString() ?? 'moja', style: body.copyWith(color: _secondary)),
              ],
            ),
          ),
        for (final (index, entry) in details.entries.indexed) ...[
          pw.NewPage(),
          pw.Text('${index + 1}/$count', style: label),
          pw.SizedBox(height: 6),
          pw.Text(
            entry.number == null ? entry.title : '${entry.number}. ${entry.title}',
            style: pw.TextStyle(font: fonts.serif, fontSize: 20, color: _ink),
          ),
          pw.SizedBox(height: 16),
          for (final songBlock in parser.parse(entry.content)) block(songBlock),
        ],
      ],
    ),
  );
  return document.save();
}
