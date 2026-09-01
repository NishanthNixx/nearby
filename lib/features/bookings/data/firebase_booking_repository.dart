import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/config/app_config.dart';
import '../../../core/data/firebase_error_mapper.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/data/user_mapper.dart';
import '../../businesses/data/business_mapper.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/domain/service_offering.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import 'booking_mapper.dart';

/// Firestore implementation of [BookingRepository].
///
/// The interesting part is [createBooking]. Everything else is CRUD with a
/// state-machine check.
class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository({
    required FirebaseFirestore firestore,
    required fb.FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirestorePaths.bookings);

  CollectionReference<Map<String, dynamic>> get _slotLocks =>
      _firestore.collection(FirestorePaths.slotLocks);

  CollectionReference<Map<String, dynamic>> get _businesses =>
      _firestore.collection(FirestorePaths.businesses);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  String get _requireUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw AuthFailure.notSignedIn();
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Booking>> watchCustomerBookings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return FirebaseErrorMapper.guardStream(
      _bookings
          .where(BookingMapper.fieldCustomerId, isEqualTo: uid)
          .orderBy(BookingMapper.fieldStartTime, descending: true)
          .limit(100)
          .snapshots()
          .map(_toBookings),
    );
  }

  @override
  Future<List<Booking>> getCustomerBookings() {
    return FirebaseErrorMapper.guard(() async {
      final snapshot = await _bookings
          .where(BookingMapper.fieldCustomerId, isEqualTo: _requireUid)
          .orderBy(BookingMapper.fieldStartTime, descending: true)
          .limit(100)
          .get();
      return _toBookings(snapshot);
    });
  }

  @override
  Stream<List<Booking>> watchBusinessBookings(String businessId) {
    return FirebaseErrorMapper.guardStream(
      _bookings
          .where(BookingMapper.fieldBusinessId, isEqualTo: businessId)
          .orderBy(BookingMapper.fieldStartTime, descending: true)
          .limit(200)
          .snapshots()
          .map(_toBookings),
    );
  }

  @override
  Future<List<Booking>> getBookingsForDay({
    required String businessId,
    required DateTime date,
  }) {
    return FirebaseErrorMapper.guard(() async {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // An appointment starting late on the previous day could still run into
      // this one, so the window starts a few hours early and the caller's
      // overlap check discards anything that does not actually reach today.
      final windowStart = dayStart.subtract(const Duration(hours: 12));

      final snapshot = await _bookings
          .where(BookingMapper.fieldBusinessId, isEqualTo: businessId)
          .where(
            BookingMapper.fieldStartTime,
            isGreaterThanOrEqualTo: FirestoreTime.fromDateTime(windowStart),
          )
          .where(
            BookingMapper.fieldStartTime,
            isLessThan: FirestoreTime.fromDateTime(dayEnd),
          )
          .get();

      return _toBookings(snapshot);
    });
  }

  @override
  Future<Booking?> getBooking(String bookingId) {
    return FirebaseErrorMapper.guard(() async {
      final doc = await _bookings.doc(bookingId).get();
      return doc.exists ? BookingMapper.fromDocument(doc) : null;
    });
  }

  // ---------------------------------------------------------------------------
  // Creating a booking
  // ---------------------------------------------------------------------------

  @override
  Future<Booking> createBooking(BookingRequest request) {
    return FirebaseErrorMapper.guard(() async {
      final uid = _requireUid;

      final businessRef = _businesses.doc(request.businessId);
      final serviceRef = businessRef
          .collection(FirestorePaths.services)
          .doc(request.serviceId);
      final bookingRef = _bookings.doc();

      // The customer's own profile, read outside the transaction because it
      // cannot affect whether the slot is free.
      final customerDoc = await _users.doc(uid).get();
      final customer = customerDoc.exists
          ? UserMapper.fromDocument(customerDoc)
          : null;

      return _firestore.runTransaction<Booking>((transaction) async {
        // --- Read everything the decision depends on ------------------------
        final businessDoc = await transaction.get(businessRef);
        if (!businessDoc.exists) {
          throw const NotFoundFailure(what: 'tailor');
        }
        final business = BusinessMapper.fromDocument(businessDoc);

        final serviceDoc = await transaction.get(serviceRef);
        if (!serviceDoc.exists) {
          throw const NotFoundFailure(what: 'service');
        }
        final service = BusinessMapper.serviceFromDocument(
          serviceDoc,
          request.businessId,
        );

        // Duration comes from the stored service, never from the client, so a
        // tampered request cannot book a two-hour slot at a 30-minute price.
        final startTime = request.startTime;
        final endTime = startTime.add(
          Duration(minutes: service.durationMinutes),
        );

        _validateBookable(
          business: business,
          service: service,
          startTime: startTime,
          endTime: endTime,
          now: DateTime.now(),
        );

        // --- Claim every cadence slot the appointment spans -----------------
        //
        // One lock per start time is not enough: with a 30-minute cadence and a
        // 60-minute service, a booking at 9:00 and one at 9:30 have different
        // start times but overlap. Locking each cadence slot the appointment
        // covers makes that collision impossible.
        final lockIds = slotLockIdsFor(
          businessId: request.businessId,
          startTime: startTime,
          endTime: endTime,
          cadenceMinutes: business.openingHours.slotDurationMinutes,
        );

        final lockRefs = lockIds.map(_slotLocks.doc).toList(growable: false);
        final lockDocs = await Future.wait(lockRefs.map(transaction.get));

        // Any lock already present means someone else got here first. The
        // transaction is the authority — the availability list the customer
        // was looking at is only ever a hint.
        if (lockDocs.any((doc) => doc.exists)) {
          throw const SlotUnavailableFailure();
        }

        // --- Write ----------------------------------------------------------
        final booking = Booking(
          id: bookingRef.id,
          customerId: uid,
          businessId: request.businessId,
          serviceId: request.serviceId,
          startTime: startTime,
          endTime: endTime,
          status: BookingStatus.pending,
          createdAt: DateTime.now(),
          serviceName: service.name,
          servicePrice: service.price,
          businessName: business.name,
          customerName: customer?.name,
          customerPhone: customer?.phone,
          note: request.note?.trim().isEmpty ?? true
              ? null
              : request.note!.trim(),
        );

        transaction.set(
          bookingRef,
          BookingMapper.toCreatePayload(booking: booking, slotLockIds: lockIds),
        );

        for (var i = 0; i < lockRefs.length; i++) {
          transaction.set(
            lockRefs[i],
            SlotLockMapper.toPayload(
              bookingId: bookingRef.id,
              businessId: request.businessId,
              customerId: uid,
              slotStart: _lockSlotStart(
                startTime: startTime,
                index: i,
                cadenceMinutes: business.openingHours.slotDurationMinutes,
              ),
            ),
          );
        }

        return booking;
      });
    });
  }

  /// The lock IDs covering `[startTime, endTime)` on the business's cadence.
  ///
  /// Public so the concurrency tests can assert on it directly.
  static List<String> slotLockIdsFor({
    required String businessId,
    required DateTime startTime,
    required DateTime endTime,
    required int cadenceMinutes,
  }) {
    final cadence = cadenceMinutes <= 0
        ? AppConfig.defaultSlotDurationMinutes
        : cadenceMinutes;
    final step = Duration(minutes: cadence);

    final ids = <String>[];
    for (var slot = startTime; slot.isBefore(endTime); slot = slot.add(step)) {
      ids.add(
        FirestorePaths.slotLockId(businessId: businessId, startTimeUtc: slot),
      );
    }

    // A service shorter than one cadence step still claims its own slot.
    if (ids.isEmpty) {
      ids.add(
        FirestorePaths.slotLockId(
          businessId: businessId,
          startTimeUtc: startTime,
        ),
      );
    }

    return ids;
  }

  static DateTime _lockSlotStart({
    required DateTime startTime,
    required int index,
    required int cadenceMinutes,
  }) {
    final cadence = cadenceMinutes <= 0
        ? AppConfig.defaultSlotDurationMinutes
        : cadenceMinutes;
    return startTime.add(Duration(minutes: cadence * index));
  }

  /// Rejects requests that should never have been submitted.
  ///
  /// Runs inside the transaction against freshly read records, so it also
  /// catches a business that closed or a service that was deactivated while
  /// the customer sat on the booking screen.
  static void _validateBookable({
    required Business business,
    required ServiceOffering service,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime now,
  }) {
    if (!business.isAcceptingBookings) {
      throw const BusinessUnavailableFailure();
    }
    if (!service.isActive) {
      throw const InvalidBookingFailure(
        message: 'This service is no longer offered. Choose another one.',
        recovery: 'Choose a service',
      );
    }
    if (startTime.isBefore(now.add(AppConfig.minimumBookingLeadTime))) {
      throw const InvalidBookingFailure(
        message:
            'That time is too soon. Pick a slot at least half an hour from now.',
        recovery: 'Choose another time',
      );
    }
    if (startTime.isAfter(
      now.add(const Duration(days: AppConfig.bookingHorizonDays)),
    )) {
      throw const InvalidBookingFailure(
        message: 'Appointments can only be booked a month ahead.',
        recovery: 'Choose another date',
      );
    }

    final hours = business.openingHours;
    if (!hours.tradesOn(startTime)) {
      throw const InvalidBookingFailure(
        message: 'The tailor is closed on that day.',
        recovery: 'Choose another date',
      );
    }

    final dayHours = hours.forDate(startTime);
    final opens = dayHours.opensAt.onDate(startTime);
    final closes = dayHours.closesAt.onDate(startTime);

    if (startTime.isBefore(opens) || endTime.isAfter(closes)) {
      throw const InvalidBookingFailure(
        message: 'That appointment would fall outside opening hours.',
        recovery: 'Choose another time',
      );
    }

    // The slot must sit on the business's cadence. Without this, a crafted
    // request could take a 9:07 appointment and fragment the day.
    final offsetMinutes = startTime.difference(opens).inMinutes;
    if (offsetMinutes % hours.slotDurationMinutes != 0) {
      throw const InvalidBookingFailure(
        message:
            'That start time is not one of the tailor\'s appointment slots.',
        recovery: 'Choose another time',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // State changes
  // ---------------------------------------------------------------------------

  @override
  Future<Booking> confirmBooking(String bookingId) =>
      _transition(bookingId, BookingStatus.confirmed);

  @override
  Future<Booking> completeBooking(String bookingId) =>
      _transition(bookingId, BookingStatus.completed);

  /// Cancels the booking and deletes its slot locks in one transaction, so the
  /// slot becomes bookable again the moment the cancellation lands.
  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    required CancelledBy by,
  }) {
    return FirebaseErrorMapper.guard(() async {
      final ref = _bookings.doc(bookingId);

      return _firestore.runTransaction<Booking>((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) throw const NotFoundFailure(what: 'booking');

        final booking = BookingMapper.fromDocument(doc);

        if (!booking.status.canTransitionTo(BookingStatus.cancelled)) {
          throw InvalidBookingFailure(
            message:
                'This appointment is already ${booking.status.shortLabel.toLowerCase()} and cannot be cancelled.',
          );
        }

        if (by == CancelledBy.customer &&
            !booking.canCustomerCancel(
              now: DateTime.now(),
              cutoff: AppConfig.cancellationCutoff,
            )) {
          throw const InvalidBookingFailure(
            message:
                'Appointments can only be cancelled more than two hours ahead. Call the tailor to let them know.',
          );
        }

        transaction.update(
          ref,
          BookingMapper.toStatusPayload(
            status: BookingStatus.cancelled,
            cancelledBy: by,
          ),
        );

        for (final lockId in BookingMapper.slotLockIdsFrom(doc)) {
          transaction.delete(_slotLocks.doc(lockId));
        }

        return booking.copyWith(
          status: BookingStatus.cancelled,
          cancelledBy: by,
          cancelledAt: DateTime.now(),
        );
      });
    });
  }

  Future<Booking> _transition(String bookingId, BookingStatus next) {
    return FirebaseErrorMapper.guard(() async {
      final ref = _bookings.doc(bookingId);

      return _firestore.runTransaction<Booking>((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) throw const NotFoundFailure(what: 'booking');

        final booking = BookingMapper.fromDocument(doc);

        if (!booking.status.canTransitionTo(next)) {
          throw InvalidBookingFailure(
            message:
                'This appointment cannot go from ${booking.status.shortLabel.toLowerCase()} to ${next.shortLabel.toLowerCase()}.',
          );
        }

        if (next == BookingStatus.completed &&
            !booking.canComplete(DateTime.now())) {
          throw const InvalidBookingFailure(
            message:
                'This appointment has not finished yet, so it cannot be marked completed.',
          );
        }

        transaction.update(ref, BookingMapper.toStatusPayload(status: next));

        return booking.copyWith(status: next);
      });
    });
  }

  List<Booking> _toBookings(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map(BookingMapper.fromDocument).toList(growable: false);
}
