import 'package:flutter/widgets.dart';

/// Larger text on tablets: the system text scale times [tabletFactor], for the whole app.
///
/// A tablet often stands on a music stand, further from the eyes than a phone in the hand. Everything
/// that follows the text scale grows with it: interface text, the song text (S × text scale, the
/// slider still shows S) and the list rows, whose height is a minimum, not fixed. Icons and spacing
/// stay in dp. docs/DESIGN-SYSTEM.md, section 2.
class TabletTextScale extends StatelessWidget {
  final Widget child;

  const TabletTextScale({super.key, required this.child});

  static const double tabletFactor = 1.35;

  /// Shortest side, in dp, from which a device counts as a tablet; phones in landscape stay below it.
  static const double tabletShortestSide = 600;

  /// Highest combined text scale: the layouts are tested up to ×2.0 (test/a11y_text_scale_test.dart).
  static const double maxScale = 2.0;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    if (data.size.shortestSide < tabletShortestSide) {
      return child;
    }
    // ponytail: the system scale is read at 14 sp and applied linearly, so Android 14's nonlinear
    // scaling becomes linear on tablets; wrap the system TextScaler instead if that ever matters.
    final systemScale = data.textScaler.scale(14) / 14;
    final textScaler = TextScaler.linear(systemScale * tabletFactor).clamp(maxScaleFactor: maxScale);
    return MediaQuery(data: data.copyWith(textScaler: textScaler), child: child);
  }
}
