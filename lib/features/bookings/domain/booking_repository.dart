import 'booking.dart';

/// Appointments, from both sides of the transaction.
abstract interface class BookingRepository {
  // --- Customer --------------------------------------------------------------

  /// The signed-in customer's bookings, newest appointment first.
  Stream<List<Booking>> watchCustomerBookings();

  Future<List<Booking>> getCustomerBookings();

  // --- Business --------------------------------------------------------------

  /// Bookings for a business the signed-in user owns.
  Stream<List<Booking>> watchBusinessBookings(String businessId);

  /// Bookings for a business on a single day, used to work out which slots on
  /// that day are already taken.
  Future<List<Booking>> getBookingsForDay({
    required String businessId,
    required DateTime date,
  });

  Future<Booking?> getBooking(String bookingId);

  // --- Writes ----------------------------------------------------------------

  /// Creates a booking, claiming the slot atomically.
  ///
  /// The implementation must make this the authoritative check: if two
  /// customers submit the same slot at the same moment, exactly one succeeds
  /// and the other gets [SlotUnavailableFailure]. A client-side availability
  /// check is a courtesy, never the guard.
  Future<Booking> createBooking(BookingRequest request);

  /// Business accepts a pending booking.
  Future<Booking> confirmBooking(String bookingId);

  /// Cancels and releases the slot so someone else can take it.
  Future<Booking> cancelBooking({
    required String bookingId,
    required CancelledBy by,
  });

  /// Business marks an appointment as done, which is what unlocks reviewing.
  Future<Booking> completeBooking(String bookingId);
}
