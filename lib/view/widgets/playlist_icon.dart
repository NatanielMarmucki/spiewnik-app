import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:spiewnik/model/playlist_model.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Polish names of the list colors and icons, for the screen reader.
const Map<PlaylistColor, String> playlistColorNames = {
  PlaylistColor.saffron: 'szafranowy',
  PlaylistColor.rose: 'różany',
  PlaylistColor.sage: 'szałwiowy',
  PlaylistColor.sky: 'błękitny',
  PlaylistColor.lilac: 'liliowy',
  PlaylistColor.clay: 'ceglany',
};

const Map<PlaylistIcon, String> playlistIconNames = {
  PlaylistIcon.cross: 'krzyż',
  PlaylistIcon.note: 'nuta',
  PlaylistIcon.rings: 'obrączki',
  PlaylistIcon.book: 'księga',
  PlaylistIcon.star: 'gwiazda',
  PlaylistIcon.candle: 'świeca',
};

/// A list icon: an outline drawing on an 18 dp grid with a 1.5 dp stroke. Drawn rather than taken from
/// Material Icons, which have no cross, rings or candle in this style.
class PlaylistIconGlyph extends StatelessWidget {
  final PlaylistIcon icon;
  final Color color;
  final double size;

  const PlaylistIconGlyph({super.key, required this.icon, required this.color, this.size = 18.0});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _GlyphPainter(icon, color)),
    );
  }
}

/// The 38 dp tile of a list: the icon in the list's color on the surface, 10 dp radius. [dimmed] for a past
/// list: the icon in tertiary text. [dashed] draws a dashed outline instead of the surface, for „Nowa lista”.
class PlaylistTile extends StatelessWidget {
  final PlaylistIcon icon;
  final PlaylistColor color;
  final bool dimmed;
  final bool dashed;

  const PlaylistTile({
    super.key,
    required this.icon,
    required this.color,
    this.dimmed = false,
    this.dashed = false,
  });

  static const double size = 38.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final glyphColor = dimmed ? appColors.textTertiary : appColors.playlistColor(color);
    final glyph = Center(child: PlaylistIconGlyph(icon: icon, color: glyphColor));
    if (dashed) {
      return CustomPaint(
        size: const Size.square(size),
        painter: _DashedBorderPainter(appColors.accent),
        child: SizedBox.square(dimension: size, child: Center(child: Icon(Icons.add, size: 18.0, color: appColors.accent))),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: glyph,
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final PlaylistIcon icon;
  final Color color;

  const _GlyphPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18.0);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case PlaylistIcon.cross:
        canvas.drawLine(const Offset(9, 2), const Offset(9, 16), paint);
        canvas.drawLine(const Offset(4.5, 6.5), const Offset(13.5, 6.5), paint);
      case PlaylistIcon.note:
        canvas.drawOval(Rect.fromCenter(center: const Offset(6.5, 13.5), width: 5, height: 4), paint);
        canvas.drawLine(const Offset(9, 13.5), const Offset(9, 2.5), paint);
        canvas.drawPath(
          Path()
            ..moveTo(9, 2.5)
            ..quadraticBezierTo(13.5, 4, 13, 8.5),
          paint,
        );
      case PlaylistIcon.rings:
        canvas.drawCircle(const Offset(6.5, 10.5), 4.5, paint);
        canvas.drawCircle(const Offset(11.5, 10.5), 4.5, paint);
      case PlaylistIcon.book:
        canvas.drawPath(
          Path()
            ..moveTo(9, 5)
            ..cubicTo(7, 3.5, 4.5, 3.3, 2, 4)
            ..lineTo(2, 14)
            ..cubicTo(4.5, 13.3, 7, 13.5, 9, 15)
            ..cubicTo(11, 13.5, 13.5, 13.3, 16, 14)
            ..lineTo(16, 4)
            ..cubicTo(13.5, 3.3, 11, 3.5, 9, 5)
            ..lineTo(9, 15),
          paint,
        );
      case PlaylistIcon.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? 7.5 : 3.2;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final point = Offset(9 + radius * math.cos(angle), 9.8 + radius * math.sin(angle));
          i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path..close(), paint);
      case PlaylistIcon.candle:
        canvas.drawRRect(
          RRect.fromLTRBR(6.25, 8, 11.75, 16.5, const Radius.circular(1)),
          paint,
        );
        canvas.drawLine(const Offset(9, 8), const Offset(9, 6.5), paint);
        canvas.drawPath(
          Path()
            ..moveTo(9, 1.5)
            ..cubicTo(11, 3.5, 11, 5.3, 9, 5.5)
            ..cubicTo(7, 5.3, 7, 3.5, 9, 1.5),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.icon != icon || old.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final border = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), const Radius.circular(10)));
    for (final ui.PathMetric metric in border.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 6.0) {
        canvas.drawPath(metric.extractPath(start, start + 3.0), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
