import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/booking.dart';
import 'booking_card.dart';
import 'booking_providers.dart';

/// The customer's appointments, split into what is coming and what is done.
///
/// Design guideline — Layout: the most important information goes first, so
/// Upcoming is the default segment. History matters, but not as much as the
/// appointment on Thursday.
class CustomerBookingsScreen extends ConsumerStatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  ConsumerState<CustomerBookingsScreen> createState() =>
      _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState
    extends ConsumerState<CustomerBookingsScreen> {
  static const _segments = ['Upcoming', 'Past'];

  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookingsAsync = ref.watch(customerBookingsProvider);
    final isUpcoming = _selectedSegment == 0;

    return Scaffold(
      // bgBase, not bgGrouped: in Monochrome & Gold the near-black ground is
      // the one plane and the borderless cards separate from it by surface
      // value alone (the two tokens are the same colour in dark anyway).
      backgroundColor: colors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The heading lives in the body at largeTitle rather than in an
            // AppBar: a tab root has no back affordance and nothing else for a
            // toolbar to hold, and 34pt is the scheme's screen-owning size.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                0,
              ),
              child: Text(
                'Bookings',
                style: context.type.largeTitle.copyWith(color: colors.label),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Two peer views of the same list, so the scheme's segmented pills
            // (white active pill in a dark track) rather than a Material TabBar
            // underline. Local state plus a conditional body keeps it simple —
            // there is nothing here worth a controller. The header stays put
            // while the list scrolls, so switching segments is always one tap.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: SegmentedPills(
                segments: _segments,
                selectedIndex: _selectedSegment,
                onChanged: (index) => setState(() => _selectedSegment = index),
              ),
            ),
            Expanded(
              child: bookingsAsync.when(
                loading: () => const _BookingsSkeleton(),
                error: (error, _) => ErrorView(
                  failure: toAppFailure(error),
                  onRetry: () => ref.invalidate(customerBookingsProvider),
                ),
                data: (bookings) {
                  final split = splitBookings(bookings);
                  return _BookingsList(
                    bookings: isUpcoming ? split.upcoming : split.past,
                    isUpcoming: isUpcoming,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.bookings, required this.isUpcoming});

  final List<Booking> bookings;
  final bool isUpcoming;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final confirmed = await AppFeedback.confirmDestructive(
      context,
      title: 'Cancel this appointment?',
      message:
          '${booking.serviceName} with ${booking.businessName} on '
          '${Fmt.friendlyDateTime(booking.startTime)} will be cancelled and the '
          'slot released.',
      confirmLabel: 'Cancel appointment',
      cancelLabel: 'Keep it',
    );

    if (!confirmed) return;

    final success = await ref
        .read(bookingActionsProvider.notifier)
        .cancel(bookingId: booking.id, by: CancelledBy.customer);

    if (!context.mounted) return;

    if (success) {
      AppFeedback.showSuccess(
        context,
        message: 'Appointment cancelled. The slot is free for someone else.',
      );
    } else {
      final failure = ref.read(bookingActionsProvider).failure;
      if (failure != null) AppFeedback.showFailure(context, failure: failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      return isUpcoming
          ? EmptyView(
              illustration: NearbyIllustration.noBookings,
              icon: Icons.event_available_outlined,
              title: 'No appointments booked',
              message:
                  'When you book a tailor, your appointment will appear here.',
              actionLabel: 'Find a tailor',
              onAction: () => context.go('/discover'),
            )
          : const EmptyView(
              illustration: NearbyIllustration.noBookings,
              icon: Icons.history_rounded,
              title: 'No past appointments',
              message:
                  'Completed and cancelled appointments will be listed here.',
            );
    }

    final actionState = ref.watch(bookingActionsProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final booking = bookings[index];

        return BookingCard(
          booking: booking,
          isBusy: actionState.isBusy(booking.id),
          actions: [
            // Reviewing is the one thing a finished appointment still wants
            // from the customer, so it gets the card's white pill; everything
            // else stays a quiet outlined pill.
            if (booking.canReview)
              FilledButton(
                onPressed: () => context.pushNamed(
                  AppRoutes.writeReview,
                  pathParameters: {'bookingId': booking.id},
                ),
                child: const Text('Leave a review'),
              ),
            if (isUpcoming && canCustomerCancel(booking))
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

class _BookingsSkeleton extends StatelessWidget {
  const _BookingsSkeleton();

  /// Mirrors BookingCard's identity avatar, including its rounded-square
  /// corner, so nothing shifts shape when the real card arrives.
  static const double _avatarSize = 40;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      // NearbyCard rather than a hand-rolled container, so the placeholder
      // inherits the borderless dark treatment from the same primitive as the
      // real card and cannot flash a hairline the card never shows.
      itemBuilder: (_, __) => NearbyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton.square(_avatarSize, radius: _avatarSize * 0.30),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Skeleton.text(width: 150, fontSize: 17)),
                const SizedBox(width: AppSpacing.sm),
                const Skeleton(width: 76, height: 22, radius: AppRadius.xs),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Skeleton.text(width: 210, fontSize: 15),
            const SizedBox(height: AppSpacing.sm),
            Skeleton.text(width: 140, fontSize: 15),
          ],
        ),
      ),
    );
  }
}
