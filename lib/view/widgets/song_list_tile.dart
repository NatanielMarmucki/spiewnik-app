import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/widgets/app_checkbox.dart';

/// List row from docs/DESIGN-SYSTEM.md, section 5. One variant for three lists:
/// songs, favorites and user songs.
///
/// Title at the left edge, number at the right, and the empty space between them is filled by a
/// dotted leader line — as in a table of contents. **The title is shown in full**: a long one wraps
/// onto further lines, and the dots run from the end of the last line to the number. A favorite's
/// heart sits at the end of the title so it does not get lost. A user song gets the uppercase `MOJA`
/// instead of a number.
///
/// The height is a **minimum** of 48 dp, so the row grows with the system font scaling
/// and with the number of title lines (rules 1 and 6 in section 7 of the document).
class SongListTile extends StatefulWidget {
  /// Song title.
  final String title;

  /// Song number shown at the right edge. Null for user songs.
  final int? number;

  /// Text shown instead of the number, e.g. `MOJA` for a user song.
  final String? badge;

  /// Draws a heart next to the title.
  final bool isFavorite;

  /// The currently open song: number in the accent color.
  final bool isSelected;

  /// Parts of the title to highlight, e.g. the words of a search.
  final List<String> highlights;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// In the selection mode: a checkbox at the left, [isChecked] rows on the surface with the number in the accent.
  final bool selectable;
  final bool isChecked;

  const SongListTile({
    super.key,
    required this.title,
    this.number,
    this.badge,
    this.isFavorite = false,
    this.isSelected = false,
    this.highlights = const [],
    this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.isChecked = false,
  });

  /// Minimum row height.
  static const double minHeight = 48.0;

  /// Duration of the background darkening on touch (section 6 of the document).
  static const Duration pressDuration = Duration(milliseconds: 80);

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final numberStyle = theme.textTheme.titleSmall?.copyWith(
      color: widget.isSelected || widget.isChecked ? appColors.accent : appColors.textSecondary,
    );
    final background = _pressed || widget.isChecked ? appColors.pressedSurface : theme.colorScheme.surface;
    final line = _IndexLine(
      title: widget.title,
      highlights: widget.highlights,
      isFavorite: widget.isFavorite,
      trailingText: widget.badge ?? (widget.number == null ? null : '${widget.number}'),
      trailingStyle: widget.badge != null ? theme.textTheme.labelMedium : numberStyle,
    );

    return Semantics(
      button: widget.onTap != null,
      selected: widget.isSelected,
      checked: widget.selectable ? widget.isChecked : null,
      // One node per row: number, title and „ulubiona” (favorite) read together, instead of separate icons.
      container: true,
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      label: [
        if (widget.number != null) '${widget.number}',
        widget.title,
        if (widget.badge != null) widget.badge!,
        if (widget.isFavorite) 'ulubiona',
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // the whole row is the touch target
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: SongListTile.pressDuration,
          decoration: BoxDecoration(color: background),
          constraints: const BoxConstraints(minHeight: SongListTile.minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: widget.selectable
              ? Row(
                  children: [
                    AppCheckbox(value: widget.isChecked),
                    const SizedBox(width: 14.0),
                    Expanded(child: line),
                  ],
                )
              : line,
        ),
      ),
    );
  }
}

/// Table-of-contents line: title, dots and number.
///
/// We measure the title ourselves with a [TextPainter] and split it into lines, because the dots
/// have to start where the **last** line of the title ends. A plain `Row` cannot do that: wrapped
/// text takes the full width, so nothing would be left for the dots.
class _IndexLine extends StatelessWidget {
  final String title;
  final List<String> highlights;
  final bool isFavorite;
  final String? trailingText;
  final TextStyle? trailingStyle;

  const _IndexLine({
    required this.title,
    required this.highlights,
    required this.isFavorite,
    required this.trailingText,
    required this.trailingStyle,
  });

  /// Gap on both sides of the dots.
  static const double _gap = 12.0;

  /// The shortest leader line we leave: below this the dots no longer clearly guide the eye.
  static const double _minDots = 12.0;

  static const double _favoriteIcon = 11.0;
  static const double _favoriteGap = 8.0;

  /// In an extremely narrow row the title still gets this much space; below it there is nothing to split.
  static const double _minTitleWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textScaler = MediaQuery.textScalerOf(context);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final titleStyle = defaultStyle.merge(Theme.of(context).textTheme.titleMedium);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidth = _measure(
          TextSpan(text: trailingText ?? '', style: defaultStyle.merge(trailingStyle)),
          direction,
          textScaler,
        );
        final favoriteWidth = isFavorite ? textScaler.scale(_favoriteIcon) + _favoriteGap : 0.0;
        // The space left for the title text after the number, heart, gaps and dots.
        final available = math.max(
          _minTitleWidth,
          constraints.maxWidth - trailingWidth - favoriteWidth - 2 * _gap - _minDots,
        );
        final lines = _splitIntoLines(titleStyle, direction, textScaler, available);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines.take(lines.length - 1)) _text(context, line, titleStyle),
            Row(
              children: [
                // A hard constraint instead of Flexible: Flexible would split the free space in half
                // with the dots' Expanded and cut the title with an ellipsis, even though it was measured
                // for this width.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: available),
                  child: _text(context, lines.last, titleStyle),
                ),
                if (isFavorite) ...[
                  const SizedBox(width: _favoriteGap),
                  Icon(Icons.favorite, size: _favoriteIcon, color: appColors.favorite),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gap),
                    child: const LeaderDots(),
                  ),
                ),
                if (trailingText != null) Text(trailingText!, style: trailingStyle),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _text(BuildContext context, TextRange range, TextStyle style) {
    return Text.rich(
      TextSpan(children: _spans(context, range, style)),
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  double _measure(TextSpan span, TextDirection direction, TextScaler scaler) {
    final painter = TextPainter(text: span, textDirection: direction, textScaler: scaler)..layout();
    return painter.width;
  }

  /// Ranges of the successive title lines at the given width. Always at least one.
  List<TextRange> _splitIntoLines(
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
    double maxWidth,
  ) {
    if (maxWidth <= 0 || title.isEmpty) {
      return [TextRange(start: 0, end: title.length)];
    }
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);

    final ranges = <TextRange>[];
    var offset = 0;
    while (offset < title.length) {
      final line = painter.getLineBoundary(TextPosition(offset: offset));
      // Guard against an infinite loop in case the boundary does not move forward.
      final end = line.end > offset ? line.end : title.length;
      ranges.add(TextRange(start: offset, end: end));
      offset = end;
    }
    return ranges.isEmpty ? [TextRange(start: 0, end: title.length)] : ranges;
  }

  /// Part of the title with the search matches highlighted, where they fall in this line.
  List<TextSpan> _spans(BuildContext context, TextRange line, TextStyle style) {
    final text = title.substring(line.start, line.end).trimRight();
    // Matches are found over the whole title and clipped to this line; overlapping ones merge.
    final lowerTitle = title.toLowerCase();
    final marked = List<bool>.filled(text.length, false);
    for (final fragment in highlights) {
      final start = fragment.isEmpty ? -1 : lowerTitle.indexOf(fragment.toLowerCase());
      if (start < 0) {
        continue;
      }
      final from = (start - line.start).clamp(0, text.length);
      final to = (start + fragment.length - line.start).clamp(0, text.length);
      marked.fillRange(from, to, true);
    }
    final highlighted = style.copyWith(color: context.appColors.accent);
    final spans = <TextSpan>[];
    var runStart = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || marked[i] != marked[runStart]) {
        final part = text.substring(runStart, i);
        spans.add(marked[runStart] ? TextSpan(text: part, style: highlighted) : TextSpan(text: part));
        runStart = i;
      }
    }
    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

/// Dotted leader line between a title and a number, as in a table of contents. Fills the width it gets.
class LeaderDots extends StatelessWidget {
  const LeaderDots({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LeaderDotsPainter(color: context.appColors.indexDots),
      size: const Size(double.infinity, 2.0),
    );
  }
}

/// [title], a dotted leader line and [trailing], for rows whose title fits on one or two lines (a category,
/// a song list). The trailing text is measured, and the title gets what is left after it and the shortest
/// dots; song rows measure their lines instead, see [SongListTile].
class LeaderRow extends StatelessWidget {
  final Widget title;
  final String trailing;
  final TextStyle? trailingStyle;

  const LeaderRow({super.key, required this.title, required this.trailing, this.trailingStyle});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(trailingStyle);
    final trailingWidth = (TextPainter(
      text: TextSpan(text: trailing, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout())
        .width;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(0.0, constraints.maxWidth - trailingWidth - 2 * _IndexLine._gap - _IndexLine._minDots),
            ),
            child: title,
          ),
          const Expanded(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: _IndexLine._gap), child: LeaderDots())),
          Text(trailing, style: trailingStyle),
        ],
      ),
    );
  }
}

class _LeaderDotsPainter extends CustomPainter {
  final Color color;

  const _LeaderDotsPainter({required this.color});

  static const double _radius = 1.0;
  static const double _spacing = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerY = size.height / 2;
    for (var x = size.width - _radius; x >= 0; x -= _spacing) {
      canvas.drawCircle(Offset(x, centerY), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LeaderDotsPainter oldDelegate) => oldDelegate.color != color;
}
