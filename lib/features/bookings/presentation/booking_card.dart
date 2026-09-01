import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/indicators.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/remote_image.dart';
import '../domain/booking.dart';

/// One appointment, from either side.
///
/// The same card serves the customer and the tailor; only [showCustomer] and the
/// action buttons differ. Keeping one card means the two experiences cannot
/// drift apart visually.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.showCustomer = false,
    this.actions = const [],
    this.isBusy = false,
    this.onTap,
  });

  final Booking booking;

  /// Shows the customer's name and phone instead of the business's name — what
  /// the tailor needs to see.
  final bool showCustomer;

  final List<Widget> actions;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCancelled = booking.status == BookingStatus.cancelled;

    return NearbyCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdentityLine(
                  booking: booking,
                  showCustomer: showCustomer,
                  isCancelled: isCancelled,
                ),
                const SizedBox(height: AppSpacing.sm),

                // The when is the most-scanned line on this card, so it gets
                // the emphasis and the calendar glyph.
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: AppSizing.iconSm,
                      // Monochrome discipline: the glyph matches the white
                      // when-text rather than borrowing an accent — nothing on
                      // this card carries a hue except the status pill.
                      color: colors.label,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${Fmt.friendlyDate(booking.startTime)} · ${Fmt.timeRange(booking.startTime, booking.endTime)}',
                        style: context.type.subheadEmphasis.copyWith(
                          color: colors.label,
                          // Semibold, a step above the ladder's medium: this is
                          // the line the customer came to the card to read.
                          fontWeight: AppTypography.semibold,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Row(
                  children: [
                    Icon(
                      Icons.design_services_outlined,
                      size: AppSizing.iconSm,
                      color: colors.labelSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        booking.serviceName,
                        style: context.type.subhead.copyWith(
                          color: colors.labelSecondary,
                        ),
                      ),
                    ),
                    Text(
                      booking.servicePrice == 0
                          ? 'Free'
                          : Fmt.priceFrom(booking.servicePrice),
                      style: context.type.subhead.copyWith(
                        color: colors.labelSecondary,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),

                if (showCustomer && booking.customerPhone != null) ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: AppSizing.iconSm,
                        color: colors.labelSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Expanded so a long number ellipsizes at 2x text scale
                      // instead of overflowing the row.
                      Expanded(
                        child: Text(
                          booking.customerPhone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.subhead.copyWith(
                            color: colors.labelSecondary,
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (booking.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      // Not bgGrouped: on dark that equals the near-black
                      // ground, so the note would punch a hole in the card.
                      // surfaceRaised is the layer-above-a-surface value and
                      // separates in both themes without a border.
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      booking.note!,
                      style: context.type.footnote.copyWith(
                        color: colors.label,
                      ),
                    ),
                  ),
                ],

                if (isCancelled && booking.cancelledBy != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    booking.cancelledBy == CancelledBy.customer
                        ? 'Cancelled by the customer'
                        : 'Cancelled by the tailor',
                    style: context.type.caption.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (actions.isNotEmpty) ...[
            // Dark surfaces never carry hairlines — spacing alone divides the
            // actions from the details, mirroring NearbyCard's borderless dark
            // treatment. Light keeps the rule, where the white card needs it.
            if (colors.brightness != Brightness.dark)
              Divider(height: 1, color: colors.separator),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: isBusy
                  // The spinner replaces the buttons outright, so it announces
                  // itself the way LoadingView does — otherwise a screen reader
                  // finds the actions simply gone.
                  ? Semantics(
                      liveRegion: true,
                      label: 'Updating this appointment',
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  // Wrap, not Row: two pill buttons at 2x text scale exceed
                  // the card width, and pills must never truncate their label.
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: actions,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  /// One or two letters for a customer with no photo.
  static String _initialsOf(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The avatar, the name, and the booking's state.
///
/// Laid out by measurement rather than by a fixed arrangement: the status pill
/// is a whole word plus a glyph, and a pill must never truncate its label, so
/// at large text sizes it wants more room than the name has to give. When that
/// happens it takes a line of its own above the identity — the same
/// status-above-the-name order the discovery card uses for OPEN NOW — where it
/// has the card's full width to sit in.
class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.booking,
    required this.showCustomer,
    required this.isCancelled,
  });

  final Booking booking;
  final bool showCustomer;
  final bool isCancelled;

  /// Deliberately smaller than a profile avatar: the identity orients the
  /// reader, but the when-line is what the card exists to answer.
  static const double _avatarSize = 40;

  /// StatusPill's own chrome: its glyph, the gap after it, and its horizontal
  /// padding. All fixed sizes, so unlike the label they do not grow with the
  /// reader's text size.
  static const double _pillChrome =
      (AppSizing.iconSm - 2) + (AppSpacing.xs + 1) + AppSpacing.sm * 2;

  /// Whether the pill still fits beside the name.
  ///
  /// The rule: it may claim at most half the room beside the avatar. Measured
  /// from the label's own metrics rather than compared against a text-scale
  /// threshold, because how much room it wants depends on the status word and
  /// the card's width as much as on the scale.
  bool _statusFitsBeside(BuildContext context, double maxWidth) {
    final label = TextPainter(
      text: TextSpan(
        // The same style StatusPill sets on its label, so the measurement is
        // of the pill that will actually be built.
        text: booking.status.shortLabel,
        style: context.type.caption.copyWith(
          fontWeight: AppTypography.semibold,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    final beside = maxWidth - _avatarSize - AppSpacing.md - AppSpacing.sm;
    return label.width + _pillChrome <= beside / 2;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The shop's generated identity, so a booking is recognisable as the
        // same business the customer browsed. The tailor sees the customer's
        // initials in the same slot.
        if (!showCustomer)
          BusinessAvatar(
            businessId: booking.businessId,
            name: booking.businessName,
            size: _avatarSize,
          )
        else
          InitialsAvatar(
            initials: BookingCard._initialsOf(booking.customerName),
            size: _avatarSize,
          ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            showCustomer
                ? (booking.customerName ?? 'Nearby customer')
                : booking.businessName,
            // Two lines then ellipsis, as on the discovery card: a name left
            // unbounded makes a list of cards ragged once text is scaled up.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.headline.copyWith(
              color: isCancelled ? colors.labelSecondary : colors.label,
              // A cancelled appointment is struck through as well as being
              // labelled, so the state reads at a glance.
              decoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );

    final status = StatusPill.bookingStatus(
      status: booking.status,
      context: context,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_statusFitsBeside(context, constraints.maxWidth)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.sm),
              status,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Past the point where the label alone is wider than the card,
            // scaleDown shrinks the pill rather than letting it overflow: it
            // costs a little size but never a letter, and a pill must not
            // truncate its label. It does not engage at any ordinary text
            // size — the measurement above has already given the pill the
            // card's full width by then.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: status,
            ),
            const SizedBox(height: AppSpacing.sm),
            identity,
          ],
        );
      },
    );
  }
}
