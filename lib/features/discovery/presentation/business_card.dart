import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/domain/service_offering.dart';

/// One tailor in the nearby list: the photography-led card.
///
/// Every result gets the same treatment — imagery on top, identity and
/// metadata below, a quiet booking affordance at the foot. One uniform card
/// rather than a "featured" variant plus a compact one: the symmetry is what
/// makes the list read as a considered collection instead of an index. The
/// nearest result is still called out, but with a badge on its imagery, not a
/// different layout.
///
/// The card answers, in reading order, the questions a customer asks before
/// tapping: how good are they, are they open and until when, who is it, how
/// far, and roughly what will it cost.
///
/// Design guideline — Layout > Best practices: "Make essential information
/// easy to find by giving it sufficient space."
class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.services = const [],
    this.showClosestBadge = false,
  });

  final NearbyBusiness entry;
  final VoidCallback onTap;

  /// Used for the "from ₹350" price anchor. Empty is fine — the metadata line
  /// simply omits the price.
  final List<ServiceOffering> services;

  /// Marks the nearest result. Only meaningful when the list is actually
  /// ordered by distance — the caller decides, because without a location fix
  /// "closest to you" would be a lie.
  final bool showClosestBadge;

  /// Roughly 16:9 against a full-width card on a mobile screen. Fixed rather
  /// than text-derived because it is imagery, not scalable content.
  static const double _imageHeight = 180;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final business = entry.business;
    final now = DateTime.now();
    final isOpen = business.isOpenAt(now);
    final todayHours = business.openingHours.forDate(now);
    final cheapest = _cheapest(services);

    return NearbyCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      // One label for the whole card, so a screen reader reads a single
      // sentence instead of a dozen disconnected fragments. The whole card is
      // one tap target; "Book Now" below is an affordance, not a button.
      semanticsLabel: _semanticsLabel(
        business: business,
        isOpen: isOpen,
        openHoursPhrase: isOpen
            ? Fmt.timeRange(
                todayHours.opensAt.onDate(now),
                todayHours.closesAt.onDate(now),
              )
            : null,
        distanceKm: entry.distanceKm,
        cheapest: cheapest,
        showClosestBadge: showClosestBadge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Imagery -------------------------------------------------------
          // Clipped to the card's own radius: NearbyCard rounds its decoration
          // but does not clip children, and a square-cornered photo inside a
          // 24pt-radius card would break the shape.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: SizedBox(
              height: _imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The photo when there is one; the shop's generated identity
                  // gradient when there is not — so a photo-less listing still
                  // leads with imagery rather than an empty grey band.
                  BusinessBanner(
                    businessId: business.id,
                    name: business.name,
                    photoUrl: business.photoUrl,
                  ),
                  // Both overlays share one row rather than being positioned
                  // independently, so at large text sizes they shrink side by
                  // side instead of colliding.
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _RatingChip(business: business)),
                        if (showClosestBadge) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Flexible(child: _ClosestBadge()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Identity and metadata ----------------------------------------
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OpenStateLine(
                  isOpen: isOpen,
                  hoursText: isOpen
                      ? Fmt.timeRange(
                          todayHours.opensAt.onDate(now),
                          todayHours.closesAt.onDate(now),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  business.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.headline.copyWith(color: colors.label),
                ),
                if (entry.distanceKm != null || cheapest != null) ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  _MetadataLine(
                    distanceKm: entry.distanceKm,
                    cheapest: cheapest,
                  ),
                ],

                // The booking affordance, separated by space alone — no
                // hairline. Gold discipline: it is white, because "tappable"
                // is the primary colour's meaning, not the accent's.
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    'Book Now',
                    style: context.type.callout.copyWith(
                      color: colors.label,
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The cheapest active service — the most useful anchor for someone deciding
  /// whether a shop is in their range.
  static ServiceOffering? _cheapest(List<ServiceOffering> services) {
    final active = services.where((s) => s.isActive).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return active.isEmpty ? null : active.first;
  }

  /// The card's children exclude their own semantics, so everything a sighted
  /// user can see is reassembled here, in reading order and natural case.
  static String _semanticsLabel({
    required Business business,
    required bool isOpen,
    required String? openHoursPhrase,
    required double? distanceKm,
    required ServiceOffering? cheapest,
    required bool showClosestBadge,
  }) {
    final parts = <String>[
      if (showClosestBadge) 'Closest to you',
      business.name,
      if (business.ratingCount > 0)
        'rated ${Fmt.rating(business.ratingAverage)} out of 5 from ${Fmt.reviewCount(business.ratingCount)}'
      else
        'new, no reviews yet',
      if (isOpen && openHoursPhrase != null)
        'open now, $openHoursPhrase'
      else if (isOpen)
        'open now'
      else
        'closed',
      if (distanceKm != null) Fmt.distanceAway(distanceKm),
      if (cheapest != null) 'from ${Fmt.price(cheapest.price)}',
      'book now',
    ];
    return parts.join(', ');
  }
}

/// "OPEN NOW · 9:00 AM – 8:00 PM", or "CLOSED".
///
/// One of the two sanctioned uses of the gold on a card (the other is the
/// rating star). Hours ride along in the secondary colour so the state word
/// stays the loudest part — and only appear when open, because the hours of a
/// closed shop answer a question nobody asked from a list.
class _OpenStateLine extends StatelessWidget {
  const _OpenStateLine({required this.isOpen, required this.hoursText});

  final bool isOpen;

  /// Pre-formatted "9:00 AM – 8:00 PM"; null when closed.
  final String? hoursText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // A single rich text rather than a Row, so at large text sizes the line
    // wraps mid-sentence instead of overflowing.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: isOpen ? 'OPEN NOW' : 'CLOSED',
            style: context.type.caption.copyWith(
              color: isOpen ? colors.open : colors.closed,
              fontWeight: AppTypography.semibold,
              // Wide tracking because the label is set in capitals.
              letterSpacing: 1.1,
            ),
          ),
          if (isOpen && hoursText != null)
            TextSpan(
              text: ' · $hoursText',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pin, distance, and the price anchor in one quiet footnote line.
class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.distanceKm, required this.cheapest});

  final double? distanceKm;
  final ServiceOffering? cheapest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final parts = <String>[
      if (distanceKm != null) Fmt.distance(distanceKm!),
      if (cheapest != null)
        cheapest!.price == 0 ? 'Free' : 'from ${Fmt.price(cheapest!.price)}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The pin only appears alongside a distance — a location glyph next to
        // a bare price would imply the price is somewhere.
        if (distanceKm != null) ...[
          Padding(
            // Optically aligns the glyph with the footnote's cap height.
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.place_rounded,
              size: AppSizing.iconSm,
              color: colors.labelSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Text(
            parts.join(' · '),
            style: context.type.footnote.copyWith(
              color: colors.labelSecondary,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// The rating, on an opaque chip over the imagery.
///
/// Opaque because anything can be behind a chip sitting on a photograph — a
/// tinted wash relies on knowing what is underneath. Gold star plus a numeral:
/// the rating never depends on counting stars.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasRating = business.ratingCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: hasRating
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: AppSizing.iconSm,
                  color: colors.accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  Fmt.rating(business.ratingAverage),
                  style: context.type.caption.copyWith(
                    color: colors.label,
                    fontWeight: AppTypography.semibold,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    '(${business.ratingCount})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: colors.labelSecondary,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              // Honest, and kinder to a new listing than "0.0".
              'NEW',
              // Natural case for the reader even though the display is caps.
              semanticsLabel: 'New',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
                fontWeight: AppTypography.semibold,
                letterSpacing: 1.1,
              ),
            ),
    );
  }
}

/// The badge the first, distance-ordered result earns.
///
/// Inverted — white fill, black text on the dark appearance — because "this
/// one" is what it is saying. It takes that inversion from [AppColors.label]
/// rather than from [AppColors.primary]: primary now means *tappable*, and this
/// badge is a statement of fact, not a control. It sits on the imagery, so it
/// stays a chip rather than bare text.
class _ClosestBadge extends StatelessWidget {
  const _ClosestBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: colors.label,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        'CLOSEST TO YOU',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: 'Closest to you',
        style: context.type.caption.copyWith(
          color: colors.bgBase,
          fontWeight: AppTypography.semibold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
