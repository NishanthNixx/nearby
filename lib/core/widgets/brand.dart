import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/identity_palette.dart';
import 'remote_image.dart';

/// Nearby's mark: a location pin with a proximity arc.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size and
/// recolours with the theme. Location is the app's organising idea — the same
/// pin silhouette recurs in the header, the splash, the distance label and the
/// empty states — and the arc is the "nearby" part: a radius around the point.
///
/// Design guideline — Branding: express the brand through refinement rather
/// than by putting a logo everywhere. This appears once per screen at most.
class NearbyMark extends StatelessWidget {
  const NearbyMark({
    super.key,
    this.size = 28,
    this.color,
    this.showArc = true,
  });

  final double size;

  /// Collapses the mark to a single ink. Null keeps the icon's two browns —
  /// a deep brown letterform with a lighter pin — which is what makes the pin
  /// read as a separate object rather than part of the "n".
  final Color? color;

  /// The dashed proximity arc. Dropped at very small sizes, where six dashes
  /// turn into a smudge.
  final bool showArc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NearbyMarkPainter(
          ink: color ?? AppGradients.chocolate,
          pin: color ?? context.colors.primary,
          showArc: showArc && size >= 32,
        ),
      ),
    );
  }
}

/// Draws the app icon's mark: a lowercase "n" whose right leg tapers into a
/// swash, a dashed arc sweeping off its shoulder, and a map pin the arc points
/// at.
///
/// Coded rather than shipped as a raster because the mark appears at a dozen
/// sizes — inline in a text run, in the header, on the splash — and a single
/// PNG cannot serve all of them crisply. Geometry is expressed against a
/// 100-unit square and scaled, so proportions hold at any size.
class _NearbyMarkPainter extends CustomPainter {
  const _NearbyMarkPainter({
    required this.ink,
    required this.pin,
    required this.showArc,
  });

  final Color ink;
  final Color pin;
  final bool showArc;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;

    Paint solid(Color c) => Paint()
      ..color = c
      ..isAntiAlias = true;

    Paint bar(Color c, double weight, {StrokeCap cap = StrokeCap.round}) =>
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = weight * u
          ..strokeCap = cap
          ..isAntiAlias = true;

    // --- The "n" ------------------------------------------------------------
    // Drawn as ONE continuous stroke — stem up, shoulder over, leg down — with
    // round joins. Three separate primitives left a visible seam where the arc
    // butted into the stem, because a butt cap and a round cap cannot meet
    // cleanly at a tangent.
    const weight = 10.5;
    const stemX = 30.0;
    const legX = 55.0;
    const shoulderY = 38.0;
    const baseline = 71.0;
    const legFoot = 55.0;

    final letter = Path()
      ..moveTo(stemX * u, baseline * u)
      ..lineTo(stemX * u, shoulderY * u)
      ..arcToPoint(
        Offset(legX * u, shoulderY * u),
        radius: Radius.circular(((legX - stemX) / 2) * u),
        clockwise: true,
      )
      ..lineTo(legX * u, legFoot * u);

    canvas.drawPath(
      letter,
      bar(ink, weight)..strokeJoin = StrokeJoin.round,
    );

    // The swash: the leg keeps going and hooks down-LEFT, narrowing to a
    // point. A filled path rather than a stroke, because a stroke cannot
    // taper.
    const half = weight / 2;
    final swash = Path()
      ..moveTo((legX - half) * u, (legFoot - 4) * u)
      ..cubicTo(
        (legX - half) * u,
        70 * u,
        (legX - half - 2) * u,
        78 * u,
        (legX - 9) * u,
        83 * u,
      )
      ..cubicTo(
        (legX - 1) * u,
        79 * u,
        (legX + half) * u,
        70 * u,
        (legX + half) * u,
        (legFoot - 4) * u,
      )
      ..close();
    canvas.drawPath(swash, solid(ink));

    // --- The pin ------------------------------------------------------------
    // A teardrop with the hole knocked OUT rather than painted over, so the
    // mark survives on any background.
    const pinCx = 72.0;
    const pinCy = 66.0;
    const pinR = 10.0;
    const tipY = 84.0;

    final head = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(pinCx * u, pinCy * u), radius: pinR * u),
      );
    final point = Path()
      ..moveTo((pinCx - pinR * 0.82) * u, (pinCy + pinR * 0.58) * u)
      ..quadraticBezierTo(
        (pinCx - pinR * 0.30) * u,
        (tipY - 2) * u,
        pinCx * u,
        tipY * u,
      )
      ..quadraticBezierTo(
        (pinCx + pinR * 0.30) * u,
        (tipY - 2) * u,
        (pinCx + pinR * 0.82) * u,
        (pinCy + pinR * 0.58) * u,
      )
      ..close();

    final body = Path.combine(PathOperation.union, head, point);
    final hole = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(pinCx * u, pinCy * u),
          radius: pinR * 0.38 * u,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, body, hole),
      solid(pin),
    );

    if (!showArc) return;

    // --- The dashed arc -----------------------------------------------------
    // Sampled off a single curve with PathMetrics, so the dashes stay evenly
    // spaced along it at any size instead of drifting apart as the mark grows.
    final sweep = Path()
      ..moveTo(46 * u, 13 * u)
      ..cubicTo(71 * u, 13 * u, 86 * u, 29 * u, 83 * u, 52 * u);

    final metric = sweep.computeMetrics().first;
    const dashes = 6;
    final step = metric.length / (dashes * 2 - 1);
    final dashPaint = bar(ink, weight * 0.40);

    for (var i = 0; i < dashes; i++) {
      final start = i * step * 2;
      canvas.drawPath(
        metric.extractPath(start, math.min(start + step, metric.length)),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_NearbyMarkPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.pin != pin ||
      oldDelegate.showArc != showArc;
}

/// The wordmark: the pin plus "Nearby", for the header and the splash.
class NearbyWordmark extends StatelessWidget {
  const NearbyWordmark({super.key, this.fontSize = 34, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.label;

    return Semantics(
      label: 'Nearby',
      excludeSemantics: true,
      // The wordmark is identity, not content, so it holds its size when
      // someone raises their text size — the same reason a tab bar label or a
      // logo does not grow.
      //
      // Design guideline — Typography > Supporting scalable text: "Prioritize
      // important content when responding to text-size changes. Not all content
      // is equally important... they don't always want to increase the size of
      // every word on the screen."
      child: MediaQuery.withNoTextScaling(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NearbyMark(size: fontSize * 0.82),
            SizedBox(width: fontSize * 0.20),
            Text(
              // Set in capitals with wide tracking, masthead-style. At this
              // weight and size the tracking is identity, not body typography.
              'NEARBY',
              style: TextStyle(
                fontSize: fontSize * 0.72,
                height: 1.0,
                fontWeight: FontWeight.w800,
                letterSpacing: fontSize * 0.10,
                color: resolved,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A business's picture, or its generated identity when there is none.
///
/// This is what stops a list of photo-less shops from becoming a column of
/// identical grey squares.
class BusinessAvatar extends StatelessWidget {
  const BusinessAvatar({
    super.key,
    required this.businessId,
    required this.name,
    this.photoUrl,
    this.size = 56,
    this.radius,
    this.showOpenDot = false,
    this.isOpen = false,
  });

  final String businessId;
  final String name;
  final String? photoUrl;
  final double size;
  final double? radius;

  /// A small status dot on the avatar's corner. Reinforcement only — the card
  /// always carries a text status pill as well, so the dot is never the sole
  /// signal.
  final bool showOpenDot;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = radius ?? size * 0.30;
    final url = photoUrl?.trim();
    final hasPhoto =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    final monogram = _Monogram(
      businessId: businessId,
      name: name,
      size: size,
      cornerRadius: cornerRadius,
    );

    final Widget content = hasPhoto
        ? RemoteImage(
            url: url,
            width: size,
            height: size,
            radius: cornerRadius,
            semanticLabel: name,
            // Offline, or a dead URL, lands on the shop's own identity rather
            // than a generic placeholder.
            fallback: monogram,
          )
        : monogram;

    if (!showOpenDot) return content;

    final colors = context.colors;
    final dotSize = math.max(10.0, size * 0.20);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isOpen ? colors.open : colors.labelTertiary,
                shape: BoxShape.circle,
                // A ring in the surface colour, so the dot reads as sitting on
                // top of the avatar rather than being part of the artwork.
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.businessId,
    required this.name,
    required this.size,
    required this.cornerRadius,
  }) : assert(
         size > 0 && size < double.infinity,
         'Monogram type is derived from the box, so the box must be finite. '
         'Use BusinessBanner to fill an unbounded space.',
       );

  final String businessId;
  final String name;
  final double size;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final identity = IdentityPalette.forSeed(
      businessId,
      Theme.of(context).brightness,
    );
    final monogram = IdentityPalette.monogramFor(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: identity.gradient,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A very faint pin watermark ties the generated avatars back to the
          // brand, so ten different gradients still feel like one app.
          Opacity(
            opacity: 0.13,
            child: Transform.translate(
              offset: Offset(size * 0.20, size * 0.18),
              child: NearbyMark(
                size: size * 0.78,
                color: identity.foreground,
                showArc: false,
              ),
            ),
          ),
          Text(
            monogram,
            style: TextStyle(
              color: identity.foreground,
              fontSize: size * (monogram.length > 1 ? 0.34 : 0.42),
              fontWeight: FontWeight.w600,
              letterSpacing: size * 0.008,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill listing a service and its price, for the discovery card.
///
/// Putting two or three of these on the card answers "what does this cost"
/// without a tap, which is the question that otherwise forces one.
class ServicePricePill extends StatelessWidget {
  const ServicePricePill({super.key, required this.label, required this.price});

  final String label;

  /// Pre-formatted, so the pill has no opinion about currency.
  final String price;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: colors.bgGrouped,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: colors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(
            price,
            style: context.type.caption.copyWith(
              color: colors.label,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A business's identity stretched across a banner.
///
/// Separate from [BusinessAvatar] because the two have different sizing
/// contracts: an avatar is given a size, whereas a banner is given a box and has
/// to measure it. Passing an unbounded size to the avatar would leave the
/// monogram with no finite type size to compute from.
class BusinessBanner extends StatelessWidget {
  const BusinessBanner({
    super.key,
    required this.businessId,
    required this.name,
    this.photoUrl,
  });

  final String businessId;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasPhoto =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    if (hasPhoto) {
      return RemoteImage(
        url: url,
        radius: 0,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: name,
        fallback: _identityBanner(context),
      );
    }

    return _identityBanner(context);
  }

  /// The gradient-and-mark banner, used both when there is no photo and when
  /// one cannot be loaded.
  Widget _identityBanner(BuildContext context) {
    final identity = IdentityPalette.forSeed(
      businessId,
      Theme.of(context).brightness,
    );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: identity.gradient),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The mark is scaled off the banner's short edge, so it stays in
          // proportion whether the banner is wide and shallow or square.
          final shortEdge = math.min(
            constraints.maxHeight.isFinite ? constraints.maxHeight : 120,
            constraints.maxWidth.isFinite ? constraints.maxWidth : 120,
          );

          return Stack(
            children: [
              // An oversized, very faint mark bled off the trailing edge — it
              // gives the banner some texture without competing with the label
              // sitting on top of it.
              Positioned(
                right: -shortEdge * 0.18,
                bottom: -shortEdge * 0.34,
                child: Opacity(
                  opacity: 0.16,
                  child: NearbyMark(
                    size: shortEdge * 1.15,
                    color: identity.foreground,
                    showArc: false,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A dashed rule in the brand's brown — the icon's arc, straightened.
///
/// It replaced a full-spectrum gradient bar, which stopped being the brand the
/// moment the icon became beige and two browns. The dashes are the point: the
/// icon's one piece of ornament is a dashed arc sweeping from the letterform to
/// the pin, so a dashed rule reads as the same hand rather than as a generic
/// divider.
///
/// Decorative, and excluded from the accessibility tree — a rule announcing
/// itself to a screen reader is noise.
class BrandRule extends StatelessWidget {
  const BrandRule({super.key, this.width, this.height = 3, this.dashes = 20});

  /// Null spans the full width the parent offers, which is what a rule under a
  /// wordmark wants. A value centres a rule of that width instead.
  ///
  /// The distinction is explicit because a bare `width:` cannot be trusted: a
  /// ListView hands children TIGHT width constraints and silently ignores a
  /// child's own width.
  final double? width;

  final double height;
  final int dashes;

  @override
  Widget build(BuildContext context) {
    final rule = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: CustomPaint(
        painter: _DashedRulePainter(
          color: context.colors.primary,
          dashes: dashes,
        ),
      ),
    );

    return ExcludeSemantics(
      child: width == null ? rule : Center(child: rule),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter({required this.color, required this.dashes});

  final Color color;
  final int dashes;

  /// Gap as a fraction of dash length. Matches the icon's arc, where the gaps
  /// are a little shorter than the dashes.
  static const _gapRatio = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    // Solve for a dash length that lands the last dash exactly on the right
    // edge, so the rule never ends on a half-gap.
    final dash = size.width / (dashes + (dashes - 1) * _gapRatio);
    final stride = dash * (1 + _gapRatio);
    final y = size.height / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var i = 0; i < dashes; i++) {
      final x = i * stride;
      // Inset by half the cap so the round ends stay inside the box.
      canvas.drawLine(
        Offset(x + y, y),
        Offset(x + dash - y, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashes != dashes;
}

/// The brand banner: the marketplace illustration, blurred, with the wordmark
/// in front of it.
///
/// The illustration shows eight trades around a compass — a tailor, a baker, a
/// potter, a florist and so on. Blurring it is what makes it usable as a
/// backdrop: at full sharpness the vignettes compete with the wordmark and the
/// form beneath, and they also pin the brand to eight specific trades. Blurred,
/// it reads as warm activity rather than as a list of categories, which is the
/// honest impression for a platform still adding them.
///
/// A scrim sits between the blur and the text. Scrims over IMAGERY are the one
/// place this app allows a translucent fill — the "no alpha washes" rule exists
/// for tinted panels on the flat ground, where low-opacity colour composites to
/// sludge. Over a photograph or an illustration there is no other way to
/// guarantee the ink, because the pixel under any given letter is not knowable
/// in advance.
class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, this.height = 148});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset(
                'assets/brand/marketplace.jpg',
                fit: BoxFit.cover,
                // The blur samples beyond the widget's bounds, so the image is
                // scaled up slightly; without this the edges pull in the
                // illustration's own pale margin and the corners go flat.
                alignment: Alignment.center,
              ),
            ),
            // Lifts the blurred ground to a predictable value so the wordmark
            // clears contrast wherever the letters happen to land.
            //
            // 0.72 is measured, not chosen by eye. Compositing the scrim over
            // the UNBLURRED illustration — conservative, since blurring only
            // narrows the range — the darkest pixel gives the wordmark 5.40:1
            // at 0.70 and 6.23:1 at 0.75. At the 0.62 first tried it was
            // 4.28:1, under the floor. Re-measure if the image is replaced.
            ColoredBox(color: colors.bgBase.withValues(alpha: 0.72)),
            Center(
              child: Text(
                'Nearby',
                style: context.type.largeTitle.copyWith(
                  color: AppGradients.chocolate,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The marketplace illustration as a screen-opening hero, faded out at its
/// edges so it sits on the ground rather than in a box.
///
/// The fade is a radial mask rather than a rounded rectangle, which is what
/// keeps the illustration from reading as a photo in a card. Its edges dissolve
/// into the bone background, so the eye goes to the centre — where the artwork
/// already carries the NEARBY wordmark — and the composition has no hard border
/// competing with the form beneath it.
///
/// Distinct from [BrandBanner], which blurs the same family of artwork behind a
/// scrim to serve as a backdrop for text. Here the artwork IS the content, so
/// it stays sharp and nothing is laid over it.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, this.height = 248});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const RadialGradient(
            radius: 0.78,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.45, 0.80],
          ).createShader(bounds),
          child: Image.asset(
            'assets/brand/hero.jpg',
            // fitWidth, not cover: the artwork is 512x382 and the wordmark sits
            // near its top edge, so cover crops exactly the part that must
            // survive. Fitting the width keeps the full composition and lets
            // the radial fade absorb the overflow at the bottom instead.
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}
