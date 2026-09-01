import 'package:flutter/material.dart';

import '../../features/bookings/domain/booking.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// A small pill combining a glyph, a colour and a text label.
///
/// Design guideline — Accessibility > Vision: "Convey information with more
/// than color alone. Some people have trouble differentiating between certain
/// colors and shades... Offer visual indicators, like distinct shapes or
/// icons, in addition to color."
///
/// Every status in Nearby uses all three channels, so the meaning survives
/// colour blindness, a greyscale screenshot and a screen reader alike.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.background,
    this.semanticsLabel,
  });

  /// "Open now" / "Closed" for a business's trading state.
  ///
  /// Note the label is a full phrase, not a bare colour swatch: someone who
  /// cannot distinguish the green from the red still reads the words.
  ///
  /// Set [onImagery] when the pill sits over a photograph or a dark identity
  /// banner. The default tinted wash relies on the surface behind it being
  /// light; over dark artwork it collapses to low-contrast colour-on-colour.
  factory StatusPill.openState({
    Key? key,
    required bool isOpen,
    required BuildContext context,
    bool onImagery = false,
  }) {
    final colors = context.colors;
    return StatusPill(
      key: key,
      // Uppercase, in the reference's manner — this and the rating are the two
      // places the gold appears.
      label: isOpen ? 'OPEN NOW' : 'CLOSED',
      semanticsLabel: isOpen ? 'Open now' : 'Closed',
      icon: isOpen ? Icons.schedule_rounded : Icons.schedule_outlined,
      color: isOpen ? colors.open : colors.closed,
      // Bare text on a card; an opaque chip only over imagery, where anything
      // could be behind it.
      background: onImagery ? colors.surface : Colors.transparent,
    );
  }

  /// A booking's status.
  factory StatusPill.bookingStatus({
    Key? key,
    required BookingStatus status,
    required BuildContext context,
  }) {
    final colors = context.colors;
    // Monochrome discipline: gold marks the one state that is waiting on
    // someone, white marks good standing, and only cancelled gets the failure
    // colour. Icons and labels differ throughout, so no state leans on colour
    // alone.
    final (color, icon) = switch (status) {
      BookingStatus.pending => (colors.warning, Icons.hourglass_top_rounded),
      BookingStatus.confirmed => (
        colors.label,
        Icons.check_circle_outline_rounded,
      ),
      BookingStatus.cancelled => (colors.closed, Icons.cancel_outlined),
      BookingStatus.completed => (
        colors.labelSecondary,
        Icons.task_alt_rounded,
      ),
    };

    return StatusPill(
      key: key,
      label: status.shortLabel,
      icon: icon,
      color: color,
      // An opaque raised surface, not a tinted wash of the status colour. The
      // wash was the pre-restyle idiom; here the glyph and the label carry the
      // state and the chip is just a container.
      background: colors.surfaceRaised,
    );
  }

  final String label;
  final IconData icon;
  final Color color;
  final Color? background;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground = background ?? color.withValues(alpha: 0.12);

    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: resolvedBackground == Colors.transparent
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs + 1,
              ),
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizing.iconSm - 2, color: color),
            const SizedBox(width: AppSpacing.xs + 1),
            // Flexible so the pill shrinks to whatever it is given instead of
            // overflowing from the inside. Callers should not have to measure
            // the label to lay this out.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: context.type.caption.copyWith(
                  color: color,
                  fontWeight: AppTypography.semibold,
                  // Wide tracking when the label is set in capitals; neutral
                  // otherwise.
                  letterSpacing: label == label.toUpperCase() ? 1.1 : 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Star, rating value and optional review count.
///
/// The star is the accent colour — Nearby's one non-interactive use of it — and
/// the numeral is always shown, so the rating never depends on counting stars.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.average,
    required this.count,
    this.showCount = true,
    this.compact = false,
  });

  final double average;
  final int count;
  final bool showCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (count == 0) {
      return Semantics(
        label: 'No reviews yet',
        excludeSemantics: true,
        child: Text(
          'New',
          style: context.type.caption.copyWith(
            color: colors.labelSecondary,
            fontWeight: AppTypography.semibold,
          ),
        ),
      );
    }

    final style =
        (compact ? context.type.caption : context.type.subheadEmphasis)
            .copyWith(color: colors.label, fontFeatures: AppTypography.tabular);

    return Semantics(
      label: '${Fmt.rating(average)} out of 5, ${Fmt.reviewCount(count)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: compact ? AppSizing.iconSm : AppSizing.iconMd,
            color: colors.accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(Fmt.rating(average), style: style),
          if (showCount) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '($count)',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pin glyph plus a distance.
///
/// The pin is what makes distance readable at a glance in a dense card, and it
/// is the app's recurring location motif — the same glyph marks the header
/// location, the address row and this label.
class DistanceLabel extends StatelessWidget {
  const DistanceLabel({
    super.key,
    required this.distanceKm,
    this.emphasise = false,
  });

  /// Null when the customer has no location fix. The label hides itself rather
  /// than showing a placeholder, because a wrong distance is worse than none.
  final double? distanceKm;

  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final km = distanceKm;
    if (km == null) return const SizedBox.shrink();

    final colors = context.colors;
    final color = emphasise ? colors.primary : colors.labelSecondary;

    return Semantics(
      label: Fmt.distanceAway(km),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, size: AppSizing.iconSm, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            Fmt.distance(km),
            style: context.type.subhead.copyWith(
              color: color,
              fontWeight: emphasise ? AppTypography.semibold : null,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// The customer's current location, shown above the nearby list.
///
/// Design guideline — Maps > Custom information: custom controls over a map
/// need enough contrast to stand apart. The same reasoning applies here — the
/// location row is the app's anchor, so it gets the brand colour and a filled
/// glyph rather than being another line of grey text.
class LocationHeader extends StatelessWidget {
  const LocationHeader({
    super.key,
    required this.label,
    this.onTap,
    this.isResolving = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final row = Row(
      children: [
        Icon(
          Icons.place_rounded,
          size: AppSizing.iconMd,
          color: colors.primary,
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.subheadEmphasis.copyWith(color: colors.label),
          ),
        ),
        if (isResolving) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: colors.labelSecondary,
            ),
          ),
        ] else if (onTap != null) ...[
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: AppSizing.iconMd,
            color: colors.labelSecondary,
          ),
        ],
      ],
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: 'Location: $label. Change',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          // Keeps the row at the minimum comfortable tap height even though
          // its content is only about 20pt tall.
          constraints: const BoxConstraints(
            minHeight: AppSizing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A price, right-aligned with tabular figures so a column of prices lines up.
class PriceLabel extends StatelessWidget {
  const PriceLabel({
    super.key,
    required this.amount,
    this.from = true,
    this.emphasise = true,
  });

  final int amount;

  /// Renders as "₹350+", signalling a starting price.
  final bool from;

  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (amount == 0) {
      return Text(
        'Free',
        // Not gold. Gold is reserved for ratings, open-now and the pending
        // badge; a price of zero is still a price, so it takes the same
        // treatment as any other.
        style: context.type.subheadEmphasis.copyWith(color: colors.label),
      );
    }

    final text = from ? Fmt.priceFrom(amount) : Fmt.price(amount);

    return Semantics(
      label: from ? 'from ${Fmt.price(amount)}' : Fmt.price(amount),
      excludeSemantics: true,
      child: Text(
        text,
        style: (emphasise ? context.type.headline : context.type.subhead)
            .copyWith(color: colors.label, fontFeatures: AppTypography.tabular),
      ),
    );
  }
}
