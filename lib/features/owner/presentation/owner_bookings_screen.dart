import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/presentation/booking_card.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../../businesses/presentation/business_providers.dart';

/// The tailor's appointment book.
///
/// Three views matching how a shop actually thinks about the day: what needs a
/// decision now, what is coming, and what is done.
///
/// "Needs action" is first and default because a pending request left
/// unanswered is the one failure mode that loses the shop a customer.
class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  static const _segments = ['Needs action', 'Upcoming', 'Done'];

  int _selectedSegment = 0;

  /// Height of the two-line title bar, measured from the type ladder rather
  /// than fixed: a hard 68pt bar clips the shop-state line as soon as text
  /// scales up, and scalable text never belongs in a fixed-height box.
  static double _barHeight(BuildContext context, {required bool twoLine}) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style) =>
        scaler.scale(style.fontSize!) * style.height!;

    return math.max(
      kToolbarHeight,
      line(AppTypography.title2) +
          (twoLine ? line(AppTypography.caption) : 0) +
          AppSpacing.xxl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final business = ref.watch(myBusinessProvider).value;
    final bookingsAsync = ref.watch(ownerBookingsProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        toolbarHeight: _barHeight(context, twoLine: business != null),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointments',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.title2.copyWith(color: colors.label),
            ),
            if (business != null)
              Text(
                business.isAcceptingBookings
                    ? business.name
                    : '${business.name} · bookings paused',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Paused is called out by value, not hue: the gold is reserved
                // for ratings, open-now and the pending badge, so the louder
                // white does the work here and the words carry the meaning.
                style: context.type.caption.copyWith(
                  color: business.isAcceptingBookings
                      ? colors.labelSecondary
                      : colors.label,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Three peer views of one appointment book, so the scheme's
          // segmented pills (white active pill in a dark track) rather than a
          // Material TabBar underline. Local state plus a conditional body —
          // there is nothing here worth a controller.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: SegmentedPills(
              segments: _segments,
              selectedIndex: _selectedSegment,
              onChanged: (index) => setState(() => _selectedSegment = index),
            ),
          ),
          Expanded(
            child: bookingsAsync.when(
              loading: () =>
                  const LoadingView(label: 'Loading your appointments'),
              error: (error, _) => ErrorView(
                failure: toAppFailure(error),
                onRetry: () => ref.invalidate(ownerBookingsProvider),
              ),
              data: (bookings) {
                final now = DateTime.now();

                // Anything the tailor must respond to: a new request, or a
                // finished appointment waiting to be marked done.
                final needsAction =
                    bookings
                        .where(
                          (b) =>
                              b.status == BookingStatus.pending ||
                              (b.status == BookingStatus.confirmed &&
                                  !b.endTime.isAfter(now)),
                        )
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));

                final upcoming =
                    bookings
                        .where(
                          (b) => b.status.holdsSlot && b.endTime.isAfter(now),
                        )
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));

                final done = bookings.where((b) => b.status.isTerminal).toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));

                return switch (_selectedSegment) {
                  0 => _OwnerBookingList(
                    bookings: needsAction,
                    emptyIcon: Icons.inbox_rounded,
                    emptyIllustration: NearbyIllustration.noBookings,
                    emptyTitle: 'Nothing needs you',
                    emptyMessage:
                        'New booking requests and finished appointments waiting '
                        'to be marked done will show up here.',
                    showTodayHeader: true,
                  ),
                  1 => _OwnerBookingList(
                    bookings: upcoming,
                    emptyIcon: Icons.event_available_outlined,
                    emptyIllustration: NearbyIllustration.noBookings,
                    emptyTitle: 'No appointments booked',
                    emptyMessage:
                        'Once customers book you, their appointments appear '
                        'here.',
                    showTodayHeader: true,
                  ),
                  _ => _OwnerBookingList(
                    bookings: done,
                    emptyIcon: Icons.history_rounded,
                    emptyIllustration: NearbyIllustration.noBookings,
                    emptyTitle: 'Nothing finished yet',
                    emptyMessage:
                        'Completed and cancelled appointments are kept here.',
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerBookingList extends ConsumerWidget {
  const _OwnerBookingList({
    required this.bookings,
    required this.emptyIcon,
    required this.emptyIllustration,
    required this.emptyTitle,
    required this.emptyMessage,
    this.showTodayHeader = false,
  });

  final List<Booking> bookings;
  final IconData emptyIcon;
  final NearbyIllustration emptyIllustration;
  final String emptyTitle;
  final String emptyMessage;

  /// Adds a "Today" summary above the list, so the tailor can see the shape of
  /// the day without counting rows.
  final bool showTodayHeader;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .confirm(booking.id);
    if (!context.mounted) return;

    if (success) {
      AppFeedback.showSuccess(
        context,
        message:
            'Confirmed. ${booking.customerName ?? 'The customer'} has been notified.',
      );
    } else {
      _reportFailure(context, ref);
    }
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .complete(booking.id);
    if (!context.mounted) return;

    if (success) {
      AppFeedback.showSuccess(
        context,
        message: 'Marked as completed. The customer can now leave a review.',
      );
    } else {
      _reportFailure(context, ref);
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final confirmed = await AppFeedback.confirmDestructive(
      context,
      title: 'Cancel this appointment?',
      message:
          '${booking.customerName ?? 'The customer'} will be told their '
          '${Fmt.friendlyDateTime(booking.startTime)} appointment is cancelled. '
          'The slot becomes available again.',
      confirmLabel: 'Cancel appointment',
      cancelLabel: 'Keep it',
    );

    if (!confirmed) return;

    final success = await ref
        .read(bookingActionsProvider.notifier)
        .cancel(bookingId: booking.id, by: CancelledBy.business);

    if (!context.mounted) return;

    if (success) {
      AppFeedback.showSuccess(context, message: 'Appointment cancelled.');
    } else {
      _reportFailure(context, ref);
    }
  }

  static void _reportFailure(BuildContext context, WidgetRef ref) {
    final failure = ref.read(bookingActionsProvider).failure;
    if (failure != null) AppFeedback.showFailure(context, failure: failure);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      return EmptyView(
        illustration: emptyIllustration,
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final actionState = ref.watch(bookingActionsProvider);
    final now = DateTime.now();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: bookings.length + (showTodayHeader ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (showTodayHeader && index == 0) {
          return _TodaySummary(bookings: bookings, now: now);
        }

        final booking = bookings[index - (showTodayHeader ? 1 : 0)];
        final needsConfirming = booking.status == BookingStatus.pending;

        return BookingCard(
          booking: booking,
          showCustomer: true,
          isBusy: actionState.isBusy(booking.id),
          // Exactly one white pill per card, so which action the card is
          // asking for is never ambiguous; every other action is a quiet
          // outlined pill. A request that has also run past its end time can
          // offer both, and answering the request comes first.
          actions: [
            if (needsConfirming)
              FilledButton(
                onPressed: () => _confirm(context, ref, booking),
                child: const Text('Confirm'),
              ),
            if (booking.canComplete(now))
              if (needsConfirming)
                OutlinedButton(
                  onPressed: () => _complete(context, ref, booking),
                  child: const Text('Mark done'),
                )
              else
                FilledButton(
                  onPressed: () => _complete(context, ref, booking),
                  child: const Text('Mark done'),
                ),
            if (booking.canBusinessCancel(now))
              OutlinedButton(
                onPressed: () => _cancel(context, ref, booking),
                child: const Text('Cancel'),
              ),
          ],
        );
      },
    );
  }
}

/// A one-line read on today.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.bookings, required this.now});

  final List<Booking> bookings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todaysBookings = bookings
        .where(
          (b) => !b.startTime.isBefore(today) && b.startTime.isBefore(tomorrow),
        )
        .toList();

    final pending = bookings
        .where((b) => b.status == BookingStatus.pending)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: NearbyCard(
        child: Row(
          children: [
            Container(
              // A minimum, not a fixed square: the tile keeps its shape at the
              // default text size but grows with the number at large scales
              // instead of clipping it.
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                // A raised monochrome tile — the count is separated from its
                // card by surface value alone, keeping the gold discipline:
                // no wash, no hue, just a white number.
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                todaysBookings.length.toString(),
                style: context.type.title3.copyWith(
                  color: colors.label,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todaysBookings.length == 1
                        ? '1 appointment today'
                        : '${todaysBookings.length} appointments today',
                    style: context.type.headline.copyWith(color: colors.label),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    pending == 0
                        ? 'Nothing waiting on you'
                        : pending == 1
                        ? '1 request needs confirming'
                        : '$pending requests need confirming',
                    style: context.type.footnote.copyWith(
                      color: pending == 0
                          ? colors.labelSecondary
                          : colors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
