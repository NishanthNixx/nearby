import 'dart:math' as math;

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
  final Color? color;

  /// The proximity arc. Dropped at very small sizes where it turns to mush.
  final bool showArc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NearbyMarkPainter(
          // No explicit colour means the mark is speaking for the brand, so it
          // is painted in the icon's own spectrum rather than a flat fill.
          color: color,
          showArc: showArc && size >= 20,
        ),
      ),
    );
  }
}

class _NearbyMarkPainter extends CustomPainter {
  const _NearbyMarkPainter({required this.color, required this.showArc});

  /// Null paints the mark with [AppGradients.brand] — the icon's sweep from
  /// cyan through to orange. A value paints it flat instead, for the places
  /// that need the mark in a single ink: a disabled state, or a glyph small
  /// enough that a four-stop gradient would turn to mud.
  final Color? color;
  final bool showArc;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The pin occupies the upper-left ~72%, leaving room for the arc to sweep
    // out to the lower right without the two shapes colliding.
    final pinWidth = w * 0.60;
    final pinHeight = h * 0.78;
    final left = w * 0.04;
    final top = h * 0.05;

    final centreX = left + pinWidth / 2;
    final headRadius = pinWidth / 2;
    final headCentreY = top + headRadius;

    // Teardrop: a circle for the head, with two curves drawn down to the point.
    final pin = Path();
    final tipY = top + pinHeight;

    pin.moveTo(centreX, tipY);
    pin.cubicTo(
      centreX - headRadius * 0.92,
      headCentreY + headRadius * 0.72,
      centreX - headRadius,
      headCentreY + headRadius * 0.18,
      centreX - headRadius,
      headCentreY,
    );
    pin.arcToPoint(
      Offset(centreX + headRadius, headCentreY),
      radius: Radius.circular(headRadius),
      clockwise: true,
    );
    pin.cubicTo(
      centreX + headRadius,
      headCentreY + headRadius * 0.18,
      centreX + headRadius * 0.92,
      headCentreY + headRadius * 0.72,
      centreX,
      tipY,
    );
    pin.close();

    // The void: knocked out of the pin rather than painted over it, so the mark
    // works on any background.
    final void_ = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(centreX, headCentreY),
          radius: headRadius * 0.36,
        ),
      );

    // One shader spans the whole mark, so the pin and the arc are two windows
    // onto a single sweep rather than two separately-coloured shapes.
    final bounds = Offset.zero & size;
    Paint ink(double opacity) {
      final flat = color;
      if (flat != null) {
        return Paint()..color = flat.withValues(alpha: flat.a * opacity);
      }
      return Paint()
        ..shader = LinearGradient(
          begin: AppGradients.brand.begin,
          end: AppGradients.brand.end,
          stops: AppGradients.brand.stops,
          colors: [
            for (final stop in AppGradients.brand.colors)
              stop.withValues(alpha: opacity),
          ],
        ).createShader(bounds);
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, pin, void_),
      ink(1),
    );

    if (!showArc) return;

    // Proximity arc, sweeping around the pin's lower right.
    final strokeWidth = math.max(1.4, w * 0.075);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(centreX, headCentreY + headRadius * 0.35),
        radius: w * 0.44,
      ),
      -math.pi * 0.34,
      math.pi * 0.62,
      false,
      ink(0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NearbyMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showArc != showArc;
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
