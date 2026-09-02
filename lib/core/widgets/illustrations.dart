import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Line illustrations for empty, error and success states.
///
/// Drawn rather than shipped as assets: they recolour with the theme, stay
/// sharp at any size, and add nothing to the bundle. A stock icon dropped in a
/// grey circle is what makes an empty state look unfinished, and empty states
/// are where a customer forms their impression of whether the app works.
///
/// Design guideline — Layout > Best practices: essential information gets
/// space. These are deliberately calm — a neutral line drawing carrying a cool
/// and a warm accent, so an empty screen is never a single hue — so they
/// support the message rather than competing with it.
enum NearbyIllustration {
  /// No tailors within the radius. A search circle with the pin at its centre
  /// and nothing inside it.
  noTailorsNearby,

  /// Filters excluded everything. A magnifier over an empty list.
  noSearchResults,

  /// Nothing booked yet. A calendar with an open slot.
  noBookings,

  /// Location permission is off. A pin, struck through.
  locationOff,

  /// The day has no free times left.
  noAvailability,

  /// Nothing to review, or no reviews yet.
  noReviews,

  /// Something went wrong.
  problem,

  /// No services listed.
  noServices,
}

/// Renders a [NearbyIllustration] at [size].
class Illustration extends StatelessWidget {
  const Illustration({super.key, required this.kind, this.size = 132});

  final NearbyIllustration kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ExcludeSemantics(
      // Decorative: the title and message beside it carry the meaning, so the
      // drawing is kept out of the accessibility tree rather than announced as
      // a redundant label.
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _IllustrationPainter(
            kind: kind,
            line: colors.labelSecondary,
            faint: colors.separator,
            accent: colors.primary,
            warm: colors.accent,
            surface: colors.surface,
          ),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter({
    required this.kind,
    required this.line,
    required this.faint,
    required this.accent,
    required this.warm,
    required this.surface,
  });

  final NearbyIllustration kind;
  final Color line;
  final Color faint;
  final Color accent;
  final Color warm;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is expressed as a fraction of the canvas, so one drawing
    // serves every size it is used at.
    final u = size.width / 100;

    Paint stroke(Color color, double width, {bool round = true}) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * u
      ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    Paint fill(Color color) => Paint()..color = color;

    switch (kind) {
      case NearbyIllustration.noTailorsNearby:
        _drawSearchRadius(canvas, u, stroke, fill);
      case NearbyIllustration.noSearchResults:
        _drawMagnifier(canvas, u, stroke, fill);
      case NearbyIllustration.noBookings:
        _drawCalendar(canvas, u, stroke, fill);
      case NearbyIllustration.locationOff:
        _drawLocationOff(canvas, u, stroke, fill);
      case NearbyIllustration.noAvailability:
        _drawClock(canvas, u, stroke, fill);
      case NearbyIllustration.noReviews:
        _drawStar(canvas, u, stroke, fill);
      case NearbyIllustration.problem:
        _drawProblem(canvas, u, stroke, fill);
      case NearbyIllustration.noServices:
        _drawSpool(canvas, u, stroke, fill);
    }
  }

  // --- The pin, reused across several of the drawings ------------------------

  Path _pinPath(double cx, double cy, double r) {
    final path = Path();
    final tipY = cy + r * 2.5;

    path.moveTo(cx, tipY);
    path.cubicTo(
      cx - r * 0.95,
      cy + r * 0.85,
      cx - r,
      cy + r * 0.2,
      cx - r,
      cy,
    );
    path.arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.cubicTo(cx + r, cy + r * 0.2, cx + r * 0.95, cy + r * 0.85, cx, tipY);
    path.close();
    return path;
  }

  void _drawPin(
    Canvas canvas,
    double u,
    double cx,
    double cy,
    double r,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    canvas.drawPath(_pinPath(cx * u, cy * u, r * u), stroke(accent, 2.4));
    canvas.drawCircle(Offset(cx * u, cy * u), r * 0.34 * u, fill(accent));
  }

  // --- Individual drawings --------------------------------------------------

  /// A search radius with the customer at the centre and nothing in range.
  void _drawSearchRadius(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    final centre = Offset(50 * u, 54 * u);

    // Two concentric rings suggesting distance bands.
    canvas.drawCircle(centre, 40 * u, stroke(faint, 1.6));
    _dashedCircle(canvas, centre, 26 * u, stroke(faint, 1.4), u);

    // Ground line, so the composition sits rather than floats.
    canvas.drawLine(
      Offset(18 * u, 88 * u),
      Offset(82 * u, 88 * u),
      stroke(faint, 1.6),
    );

    _drawPin(canvas, u, 50, 46, 9, stroke, fill);

    // Two faint shops outside the radius: the reason the list is empty is that
    // they are too far, not that none exist.
    _tinyShop(canvas, u, 12, 40, stroke);
    _tinyShop(canvas, u, 76, 30, stroke);
  }

  void _tinyShop(
    Canvas canvas,
    double u,
    double x,
    double y,
    Paint Function(Color, double, {bool round}) stroke,
  ) {
    final rect = Rect.fromLTWH(x * u, y * u, 12 * u, 10 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(1.6 * u)),
      stroke(faint, 1.5),
    );
    canvas.drawLine(
      Offset(x * u, (y + 3.4) * u),
      Offset((x + 12) * u, (y + 3.4) * u),
      stroke(faint, 1.5),
    );
  }

  void _drawMagnifier(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    // Three list rows, the middle one emphasised as the thing being sought.
    for (var i = 0; i < 3; i++) {
      final y = (26 + i * 14) * u;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(18 * u, y, 46 * u, 7 * u),
          Radius.circular(3.5 * u),
        ),
        stroke(faint, 1.6),
      );
    }

    final lensCentre = Offset(62 * u, 60 * u);
    canvas.drawCircle(lensCentre, 19 * u, fill(surface));
    canvas.drawCircle(lensCentre, 19 * u, stroke(accent, 2.6));
    canvas.drawLine(
      Offset(75 * u, 74 * u),
      Offset(86 * u, 85 * u),
      stroke(accent, 3.0),
    );

    // An empty lens: nothing matched.
    canvas.drawLine(
      Offset(55 * u, 60 * u),
      Offset(69 * u, 60 * u),
      stroke(faint, 2.2),
    );
  }

  void _drawCalendar(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    final body = Rect.fromLTWH(18 * u, 26 * u, 64 * u, 58 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(6 * u)),
      stroke(line, 2.2),
    );

    // Header band and hangers.
    canvas.drawLine(
      Offset(18 * u, 42 * u),
      Offset(82 * u, 42 * u),
      stroke(line, 2.2),
    );
    canvas.drawLine(
      Offset(34 * u, 18 * u),
      Offset(34 * u, 30 * u),
      stroke(line, 2.6),
    );
    canvas.drawLine(
      Offset(66 * u, 18 * u),
      Offset(66 * u, 30 * u),
      stroke(line, 2.6),
    );

    // A grid of days with two slots marked open — the implication being that
    // there are times waiting to be taken.
    //
    // The two markers take DIFFERENT hues, and that is the point: an empty
    // state is nothing but type, one button and this drawing, so if the
    // illustration is single-hue the whole screen is. Marks are dots, never
    // labels, so both can be fully saturated.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final cx = (28 + col * 15) * u;
        final cy = (52 + row * 12) * u;
        final Paint paint;
        if (row == 1 && col == 2) {
          paint = fill(accent);
        } else if (row == 2 && col == 0) {
          paint = fill(warm);
        } else {
          paint = fill(faint);
        }
        canvas.drawCircle(Offset(cx, cy), 3.4 * u, paint);
      }
    }
  }

  void _drawLocationOff(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    final centre = Offset(50 * u, 50 * u);
    _dashedCircle(canvas, centre, 34 * u, stroke(faint, 1.5), u);

    canvas.drawPath(_pinPath(50 * u, 44 * u, 13 * u), stroke(line, 2.6));
    canvas.drawCircle(Offset(50 * u, 44 * u), 4.6 * u, fill(line));

    // Struck through — the state is "off", and the slash says so without
    // relying on colour.
    canvas.drawLine(
      Offset(24 * u, 24 * u),
      Offset(78 * u, 78 * u),
      stroke(warm, 3.4),
    );
  }

  void _drawClock(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    final centre = Offset(50 * u, 50 * u);
    canvas.drawCircle(centre, 30 * u, stroke(line, 2.4));

    // Ticks at the quarters.
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final isQuarter = i % 3 == 0;
      final outer = 30 * u;
      final inner = outer - (isQuarter ? 6 : 3.5) * u;
      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        stroke(faint, isQuarter ? 2.0 : 1.4),
      );
    }

    // Hands at roughly ten past eight — a shape that reads as "clock" fastest.
    canvas.drawLine(
      centre,
      centre + Offset(-11 * u, -8 * u),
      stroke(line, 2.8),
    );
    canvas.drawLine(
      centre,
      centre + Offset(9 * u, -16 * u),
      stroke(accent, 2.8),
    );
    canvas.drawCircle(centre, 2.6 * u, fill(accent));

    canvas.drawLine(
      Offset(20 * u, 88 * u),
      Offset(80 * u, 88 * u),
      stroke(faint, 1.6),
    );
  }

  void _drawStar(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    // A speech bubble holding a star: a review, not just a rating.
    final bubble = Rect.fromLTWH(16 * u, 24 * u, 68 * u, 46 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, Radius.circular(10 * u)),
      stroke(line, 2.2),
    );

    final tail = Path()
      ..moveTo(34 * u, 70 * u)
      ..lineTo(34 * u, 82 * u)
      ..lineTo(46 * u, 70 * u);
    canvas.drawPath(tail, stroke(line, 2.2));

    canvas.drawPath(
      _starPath(Offset(50 * u, 46 * u), 15 * u, 6.4 * u),
      Paint()
        ..color = warm
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * u
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawProblem(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    // A disconnected thread: two ends that no longer meet.
    final left = Path()
      ..moveTo(12 * u, 46 * u)
      ..cubicTo(26 * u, 30 * u, 34 * u, 58 * u, 42 * u, 48 * u);
    final right = Path()
      ..moveTo(58 * u, 48 * u)
      ..cubicTo(66 * u, 38 * u, 74 * u, 66 * u, 88 * u, 50 * u);

    canvas.drawPath(left, stroke(line, 2.6));
    canvas.drawPath(right, stroke(line, 2.6));

    canvas.drawCircle(Offset(42 * u, 48 * u), 3.2 * u, fill(warm));
    canvas.drawCircle(Offset(58 * u, 48 * u), 3.2 * u, fill(warm));

    // The gap, marked with a dotted span so it reads as a break rather than a
    // drawing error.
    for (var x = 45.0; x < 56; x += 4) {
      canvas.drawCircle(Offset(x * u, 48 * u), 0.9 * u, fill(faint));
    }

    canvas.drawLine(
      Offset(22 * u, 78 * u),
      Offset(78 * u, 78 * u),
      stroke(faint, 1.6),
    );
  }

  void _drawSpool(
    Canvas canvas,
    double u,
    Paint Function(Color, double, {bool round}) stroke,
    Paint Function(Color) fill,
  ) {
    // A thread spool with a needle: the tailoring motif, used where the subject
    // is the shop's own craft rather than the customer's journey.
    final body = Rect.fromLTWH(30 * u, 30 * u, 30 * u, 46 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(4 * u)),
      stroke(line, 2.2),
    );
    canvas.drawLine(
      Offset(26 * u, 34 * u),
      Offset(64 * u, 34 * u),
      stroke(line, 2.6),
    );
    canvas.drawLine(
      Offset(26 * u, 72 * u),
      Offset(64 * u, 72 * u),
      stroke(line, 2.6),
    );

    // Wound thread.
    for (var i = 0; i < 4; i++) {
      final y = (42 + i * 7) * u;
      canvas.drawLine(Offset(33 * u, y), Offset(57 * u, y), stroke(faint, 1.8));
    }

    // Needle, angled across the composition.
    canvas.drawLine(
      Offset(62 * u, 76 * u),
      Offset(84 * u, 38 * u),
      stroke(accent, 2.4),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(83 * u, 34 * u),
        width: 5 * u,
        height: 8 * u,
      ),
      stroke(accent, 1.8),
    );
  }

  // --- Primitives -----------------------------------------------------------

  Path _starPath(Offset centre, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = (i / 10) * 2 * math.pi - math.pi / 2;
      final point =
          centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  /// A dashed circle. Canvas has no dash support, so the arc is drawn in
  /// segments.
  void _dashedCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    Paint paint,
    double u,
  ) {
    const segments = 28;
    const sweep = 2 * math.pi / segments;
    for (var i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        i * sweep,
        sweep * 0.9,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.line != line ||
      oldDelegate.faint != faint ||
      oldDelegate.accent != accent ||
      oldDelegate.warm != warm ||
      oldDelegate.surface != surface;
}
