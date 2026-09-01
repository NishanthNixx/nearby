import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../businesses/presentation/business_providers.dart';
import '../domain/booking.dart';

/// The signed-in customer's bookings.
final customerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchCustomerBookings();
});

/// Bookings for the owner's own business.
final ownerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final business = ref.watch(myBusinessProvider).value;
  if (business == null) return Stream.value(const []);
  return ref
      .watch(bookingRepositoryProvider)
      .watchBusinessBookings(business.id);
});

/// A single booking by id, sourced from whichever list the caller already has
/// open, so opening a detail view needs no extra read.
final bookingByIdProvider = Provider.family<Booking?, String>((ref, id) {
  final customerBookings = ref.watch(customerBookingsProvider).value;
  final found = customerBookings?.where((b) => b.id == id).firstOrNull;
  if (found != null) return found;

  final ownerBookings = ref.watch(ownerBookingsProvider).value;
  return ownerBookings?.where((b) => b.id == id).firstOrNull;
});

/// Splits a list into what is still ahead and what is behind.
///
/// Sorting differs by section on purpose: upcoming reads soonest-first because
/// the next appointment is what matters, while history reads newest-first.
({List<Booking> upcoming, List<Booking> past}) splitBookings(
  List<Booking> bookings, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();

  final upcoming = bookings.where((b) => b.isUpcoming(reference)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  final past = bookings.where((b) => b.isPast(reference)).toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));

  return (upcoming: upcoming, past: past);
}

/// Runs booking state changes and surfaces the outcome.
///
/// Shared by both roles: a cancellation is the same operation whoever asks for
/// it, and the repository decides what each is allowed to do.
class BookingActionsController extends Notifier<BookingActionState> {
  @override
  BookingActionState build() => const BookingActionState();

  Future<bool> cancel({required String bookingId, required CancelledBy by}) =>
      _run(
        bookingId,
        () => ref
            .read(bookingRepositoryProvider)
            .cancelBooking(bookingId: bookingId, by: by),
      );

  Future<bool> confirm(String bookingId) => _run(
    bookingId,
    () => ref.read(bookingRepositoryProvider).confirmBooking(bookingId),
  );

  Future<bool> complete(String bookingId) => _run(
    bookingId,
    () => ref.read(bookingRepositoryProvider).completeBooking(bookingId),
  );

  Future<bool> _run(String bookingId, Future<void> Function() action) async {
    state = BookingActionState(busyBookingId: bookingId);
    try {
      await action();
      state = const BookingActionState();
      return true;
    } catch (error) {
      state = BookingActionState(failure: toAppFailure(error));
      return false;
    }
  }
}

class BookingActionState {
  const BookingActionState({this.busyBookingId, this.failure});

  /// Which booking has an action in flight, so only that card shows a spinner
  /// rather than the whole list going busy.
  final String? busyBookingId;

  final AppFailure? failure;

  bool isBusy(String bookingId) => busyBookingId == bookingId;
}

final bookingActionsProvider =
    NotifierProvider<BookingActionsController, BookingActionState>(
      BookingActionsController.new,
    );

/// Whether the customer may still cancel, per the single rule in the domain.
bool canCustomerCancel(Booking booking) => booking.canCustomerCancel(
  now: DateTime.now(),
  cutoff: AppConfig.cancellationCutoff,
);
