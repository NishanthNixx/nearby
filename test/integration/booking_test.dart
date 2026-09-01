import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/errors/app_failure.dart';
import 'package:nearby/features/bookings/domain/booking.dart';
import 'package:nearby/features/auth/domain/app_user.dart';
import 'package:nearby/features/auth/domain/auth_repository.dart';
import 'package:nearby/features/reviews/domain/review_repository.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() => harness = TestHarness.create());
  tearDown(() => harness.dispose());

  group('creating a booking', () {
    test('creates a pending booking with the stored service details', () async {
      await harness.signInCustomer();
      final (business, services) = await harness.firstBusiness();
      final service = services.first;
      final date = harness.nextTradingDate(business);

      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: service.id,
          startTime: harness.slotOn(business, date),
        ),
      );

      expect(booking.status, BookingStatus.pending);
      // Price and duration come from the stored service, not the request.
      expect(booking.servicePrice, service.price);
      expect(booking.serviceName, service.name);
      expect(
        booking.endTime.difference(booking.startTime).inMinutes,
        service.durationMinutes,
      );
      // Denormalised so the tailor's list needs one read.
      expect(booking.businessName, business.name);
      expect(booking.customerName, isNotNull);
    });

    test('attributes the booking to the signed-in customer', () async {
      final customer = await harness.signInCustomer();
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );

      expect(booking.customerId, customer.id);
    });

    test('refuses a slot inside the minimum lead time', () async {
      await harness.signInCustomer();
      final (business, services) = await harness.firstBusiness();

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: services.first.id,
            startTime: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });

    test('refuses a day the tailor is closed', () async {
      await harness.signInCustomer();
      // Vasantha is closed on Mondays.
      final business = harness.businessNamed('Vasantha Ladies Tailoring');
      final services = await harness.businesses.getServices(business.id);

      var monday = DateTime.now().add(const Duration(days: 1));
      while (monday.weekday != DateTime.monday) {
        monday = monday.add(const Duration(days: 1));
      }

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: services.first.id,
            startTime: DateTime(monday.year, monday.month, monday.day, 11),
          ),
        ),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });

    test('refuses a business that has paused bookings', () async {
      final owner = await harness.signInOwner();
      await harness.businesses.setAcceptingBookings(owner.businessId!, false);
      await harness.auth.signOut();

      await harness.signInCustomer();
      final business = harness.store.businesses[owner.businessId!]!;
      final services = await harness.businesses.getServices(business.id);
      final date = harness.nextTradingDate(business);

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: services.first.id,
            startTime: harness.slotOn(business, date),
          ),
        ),
        throwsA(isA<BusinessUnavailableFailure>()),
      );
    });

    test('refuses a service that is no longer offered', () async {
      final owner = await harness.signInOwner();
      final services = await harness.businesses.getServices(owner.businessId!);
      final retired = services.first;
      await harness.businesses.deactivateService(
        businessId: owner.businessId!,
        serviceId: retired.id,
      );
      await harness.auth.signOut();

      await harness.signInCustomer();
      final business = harness.store.businesses[owner.businessId!]!;
      final date = harness.nextTradingDate(business);

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: retired.id,
            startTime: harness.slotOn(business, date),
          ),
        ),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });
  });

  group('duplicate booking prevention', () {
    test('two customers cannot take the same slot', () async {
      final (business, services) = await harness.firstBusiness();
      final service = services.first;
      final date = harness.nextTradingDate(business);
      final slot = harness.slotOn(business, date);

      // First customer books.
      await harness.signInCustomer();
      final first = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: service.id,
          startTime: slot,
        ),
      );
      expect(first.status, BookingStatus.pending);
      await harness.auth.signOut();

      // A second customer tries the identical slot.
      await harness.auth.signUp(
        const SignUpRequest(
          email: 'second@example.com',
          password: 'a-good-password',
          role: UserRole.customer,
          displayName: 'Second Customer',
        ),
      );

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: service.id,
            startTime: slot,
          ),
        ),
        throwsA(isA<SlotUnavailableFailure>()),
      );

      // Exactly one booking exists for that time.
      final all = harness.store.bookings.values.where(
        (b) => b.startTime == slot && b.businessId == business.id,
      );
      expect(all.length, 1);
    });

    test(
      'concurrent attempts on the same slot resolve to exactly one winner',
      () async {
        final (business, services) = await harness.firstBusiness();
        final date = harness.nextTradingDate(business);
        final slot = harness.slotOn(business, date);

        await harness.signInCustomer();
        final request = BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: slot,
        );

        // Fired without awaiting between them, so both are in flight at once.
        final outcomes = await Future.wait(
          List.generate(
            5,
            (_) => harness.bookings
                .createBooking(request)
                .then<Object?>((booking) => booking)
                .catchError((Object error) => error),
          ),
        );

        final successes = outcomes.whereType<Booking>().length;
        final rejections = outcomes.whereType<SlotUnavailableFailure>().length;

        expect(successes, 1, reason: 'exactly one attempt may claim the slot');
        expect(rejections, 4);
      },
    );

    test('an overlapping longer appointment cannot start mid-way through a '
        'booked one', () async {
      // Ashraf uses a 60-minute cadence with 60-minute services, so a second
      // booking at the same start is the overlap case; the finer-grained check
      // is on a 30-minute-cadence shop with a 45-minute service.
      final business = harness.businessNamed('Vasantha Ladies Tailoring');
      final services = await harness.businesses.getServices(business.id);
      // Blouse stitching is 45 minutes on a 30-minute cadence.
      final long = services.firstWhere((s) => s.durationMinutes == 45);

      final date = harness.nextTradingDate(business);
      final firstSlot = harness.slotOn(business, date);
      // One cadence step later — overlaps the 45-minute appointment above.
      final overlapping = harness.slotOn(business, date, index: 1);

      await harness.signInCustomer();
      await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: long.id,
          startTime: firstSlot,
        ),
      );

      await expectLater(
        harness.bookings.createBooking(
          BookingRequest(
            businessId: business.id,
            serviceId: long.id,
            startTime: overlapping,
          ),
        ),
        throwsA(isA<SlotUnavailableFailure>()),
        reason:
            'a 45-minute appointment on a 30-minute cadence claims two '
            'slots, so the next step is not free',
      );
    });
  });

  group('cancellation', () {
    test('a customer cancels and the slot becomes bookable again', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);
      final slot = harness.slotOn(business, date);

      await harness.signInCustomer();
      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: slot,
        ),
      );

      final cancelled = await harness.bookings.cancelBooking(
        bookingId: booking.id,
        by: CancelledBy.customer,
      );

      expect(cancelled.status, BookingStatus.cancelled);
      expect(cancelled.cancelledBy, CancelledBy.customer);

      // The releasing of the lock is the point: someone else can now book it.
      final rebooked = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: slot,
        ),
      );
      expect(rebooked.status, BookingStatus.pending);
      expect(rebooked.id, isNot(booking.id));
    });

    test('cannot cancel an already-cancelled booking', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      await harness.signInCustomer();
      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );

      await harness.bookings.cancelBooking(
        bookingId: booking.id,
        by: CancelledBy.customer,
      );

      await expectLater(
        harness.bookings.cancelBooking(
          bookingId: booking.id,
          by: CancelledBy.customer,
        ),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });

    test(
      'a customer cannot cancel inside the cutoff, but the business can',
      () async {
        // A booking whose start is inside the two-hour customer cutoff has to be
        // written directly: createBooking would reject it on lead time.
        final (business, services) = await harness.firstBusiness();
        final customer = await harness.signInCustomer();

        final soon = DateTime.now().add(const Duration(minutes: 45));
        final booking = Booking(
          id: 'imminent',
          customerId: customer.id,
          businessId: business.id,
          serviceId: services.first.id,
          startTime: soon,
          endTime: soon.add(const Duration(minutes: 30)),
          status: BookingStatus.confirmed,
          createdAt: DateTime.now(),
          serviceName: services.first.name,
          servicePrice: services.first.price,
          businessName: business.name,
        );
        harness.store.bookings[booking.id] = booking;

        await expectLater(
          harness.bookings.cancelBooking(
            bookingId: booking.id,
            by: CancelledBy.customer,
          ),
          throwsA(isA<InvalidBookingFailure>()),
        );

        // The tailor can still cancel — they may have an emergency, and the
        // customer is better off being told.
        final cancelled = await harness.bookings.cancelBooking(
          bookingId: booking.id,
          by: CancelledBy.business,
        );
        expect(cancelled.status, BookingStatus.cancelled);
        expect(cancelled.cancelledBy, CancelledBy.business);
      },
    );
  });

  group('state transitions', () {
    test('pending to confirmed to completed', () async {
      final (business, services) = await harness.firstBusiness();
      final customer = await harness.signInCustomer();

      // Placed in the past so it is eligible for completion.
      final past = DateTime.now().subtract(const Duration(hours: 2));
      final booking = Booking(
        id: 'finished',
        customerId: customer.id,
        businessId: business.id,
        serviceId: services.first.id,
        startTime: past,
        endTime: past.add(const Duration(minutes: 30)),
        status: BookingStatus.pending,
        createdAt: past.subtract(const Duration(days: 1)),
        serviceName: services.first.name,
        servicePrice: services.first.price,
        businessName: business.name,
      );
      harness.store.bookings[booking.id] = booking;

      final confirmed = await harness.bookings.confirmBooking(booking.id);
      expect(confirmed.status, BookingStatus.confirmed);

      final completed = await harness.bookings.completeBooking(booking.id);
      expect(completed.status, BookingStatus.completed);
    });

    test('cannot complete an appointment that has not finished', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      await harness.signInCustomer();
      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );

      await expectLater(
        harness.bookings.completeBooking(booking.id),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });

    test('cannot confirm a cancelled booking', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      await harness.signInCustomer();
      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );
      await harness.bookings.cancelBooking(
        bookingId: booking.id,
        by: CancelledBy.customer,
      );

      await expectLater(
        harness.bookings.confirmBooking(booking.id),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });
  });

  group('reviews after a completed appointment', () {
    /// A completed booking for the signed-in customer.
    Future<Booking> completedBooking() async {
      final (business, services) = await harness.firstBusiness();
      final customer = harness.auth.currentUser!;

      final past = DateTime.now().subtract(const Duration(hours: 3));
      final booking = Booking(
        id: 'reviewable',
        customerId: customer.id,
        businessId: business.id,
        serviceId: services.first.id,
        startTime: past,
        endTime: past.add(const Duration(minutes: 30)),
        status: BookingStatus.completed,
        createdAt: past.subtract(const Duration(days: 1)),
        serviceName: services.first.name,
        servicePrice: services.first.price,
        businessName: business.name,
      );
      harness.store.bookings[booking.id] = booking;
      return booking;
    }

    test('a review raises the review count and shifts the average', () async {
      await harness.signInCustomer();
      final booking = await completedBooking();
      final before = harness.store.businesses[booking.businessId]!;

      await harness.reviews.submitReview(
        ReviewDraft(
          bookingId: booking.id,
          businessId: booking.businessId,
          rating: 5,
          comment: 'Perfect fit, ready early.',
        ),
      );

      final after = harness.store.businesses[booking.businessId]!;
      expect(after.ratingCount, before.ratingCount + 1);
      expect(after.ratingAverage, isNot(before.ratingAverage));
    });

    test('a second review for the same booking is refused', () async {
      await harness.signInCustomer();
      final booking = await completedBooking();

      final draft = ReviewDraft(
        bookingId: booking.id,
        businessId: booking.businessId,
        rating: 4,
      );

      await harness.reviews.submitReview(draft);

      await expectLater(
        harness.reviews.submitReview(draft),
        throwsA(isA<InvalidBookingFailure>()),
      );

      final reviews = await harness.reviews.getBusinessReviews(
        booking.businessId,
      );
      expect(reviews.where((r) => r.bookingId == booking.id).length, 1);
    });

    test('cannot review an appointment that is not completed', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      await harness.signInCustomer();
      final booking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );

      await expectLater(
        harness.reviews.submitReview(
          ReviewDraft(
            bookingId: booking.id,
            businessId: business.id,
            rating: 5,
          ),
        ),
        throwsA(isA<InvalidBookingFailure>()),
      );
    });

    test('rejects a rating outside one to five', () async {
      await harness.signInCustomer();
      final booking = await completedBooking();

      for (final rating in [0, 6, -1]) {
        await expectLater(
          harness.reviews.submitReview(
            ReviewDraft(
              bookingId: booking.id,
              businessId: booking.businessId,
              rating: rating,
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      }
    });
  });
}
