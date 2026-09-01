import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/errors/app_failure.dart';
import 'package:nearby/features/auth/domain/app_user.dart';
import 'package:nearby/features/auth/domain/auth_repository.dart';
import 'package:nearby/features/bookings/domain/booking.dart';
import 'package:nearby/features/businesses/domain/business_repository.dart';
import 'package:nearby/features/businesses/domain/opening_hours.dart';
import 'package:nearby/features/reviews/domain/review_repository.dart';

import '../support/test_harness.dart';

/// Authorisation, checked at the repository boundary.
///
/// The authoritative enforcement is in the Firestore security rules — a client
/// check alone is never a guarantee — and those are covered separately by the
/// emulator suite in `test/security`. These tests cover the same rules at the
/// layer the app itself relies on, so a regression here is caught without
/// needing an emulator running.
void main() {
  late TestHarness harness;

  setUp(() => harness = TestHarness.create());
  tearDown(() => harness.dispose());

  group('a tailor cannot touch another tailor’s shop', () {
    test('cannot edit the listing', () async {
      final other = harness.businessNamed('Ashraf Master Tailors');

      // Signed in as Lakshmi, acting on Ashraf's shop.
      await harness.signInOwner(TestHarness.ownerEmail);

      await expectLater(
        harness.businesses.updateBusiness(
          other.id,
          BusinessDraft(
            name: 'Hijacked Tailors',
            address: other.address,
            location: other.location,
          ),
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );

      expect(harness.store.businesses[other.id]!.name, other.name);
    });

    test('cannot change the opening hours', () async {
      final other = harness.businessNamed('Ashraf Master Tailors');
      await harness.signInOwner(TestHarness.ownerEmail);

      await expectLater(
        harness.businesses.updateOpeningHours(
          other.id,
          OpeningHours.standard().copyWith(slotDurationMinutes: 15),
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });

    test('cannot pause their bookings', () async {
      final other = harness.businessNamed('Ashraf Master Tailors');
      await harness.signInOwner(TestHarness.ownerEmail);

      await expectLater(
        harness.businesses.setAcceptingBookings(other.id, false),
        throwsA(isA<PermissionDeniedFailure>()),
      );

      expect(harness.store.businesses[other.id]!.isAcceptingBookings, isTrue);
    });

    test('cannot add a service to it', () async {
      final other = harness.businessNamed('Ashraf Master Tailors');
      await harness.signInOwner(TestHarness.ownerEmail);

      await expectLater(
        harness.businesses.addService(
          businessId: other.id,
          name: 'Injected service',
          price: 1,
          durationMinutes: 15,
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });

    test('cannot retire one of its services', () async {
      final other = harness.businessNamed('Ashraf Master Tailors');
      final services = await harness.businesses.getServices(other.id);
      await harness.signInOwner(TestHarness.ownerEmail);

      await expectLater(
        harness.businesses.deactivateService(
          businessId: other.id,
          serviceId: services.first.id,
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );

      expect(harness.store.services[services.first.id]!.isActive, isTrue);
    });

    test('can edit its own listing', () async {
      // The counterpart: the checks above must not be blocking legitimate work.
      final owner = await harness.signInOwner(TestHarness.ownerEmail);
      final mine = harness.store.businesses[owner.businessId!]!;

      final updated = await harness.businesses.updateBusiness(
        mine.id,
        BusinessDraft(
          name: 'Sri Lakshmi Tailors & Sons',
          address: mine.address,
          location: mine.location,
        ),
      );

      expect(updated.name, 'Sri Lakshmi Tailors & Sons');
    });
  });

  group('a customer cannot act as a tailor', () {
    test('cannot edit a shop listing', () async {
      final business = harness.store.businesses.values.first;
      await harness.signInCustomer();

      await expectLater(
        harness.businesses.updateBusiness(
          business.id,
          BusinessDraft(
            name: 'Not my shop',
            address: business.address,
            location: business.location,
          ),
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });

    test('cannot add services to a shop', () async {
      final business = harness.store.businesses.values.first;
      await harness.signInCustomer();

      await expectLater(
        harness.businesses.addService(
          businessId: business.id,
          name: 'Free everything',
          price: 0,
          durationMinutes: 15,
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });
  });

  group('booking ownership', () {
    test('a customer only sees their own bookings', () async {
      final (business, services) = await harness.firstBusiness();
      final date = harness.nextTradingDate(business);

      // First customer books.
      final first = await harness.signInCustomer();
      final theirBooking = await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date),
        ),
      );
      await harness.auth.signOut();

      // A second customer books a different slot.
      await harness.auth.signUp(
        const SignUpRequest(
          email: 'other.customer@example.com',
          password: 'a-good-password',
          role: UserRole.customer,
          displayName: 'Other Customer',
        ),
      );
      await harness.bookings.createBooking(
        BookingRequest(
          businessId: business.id,
          serviceId: services.first.id,
          startTime: harness.slotOn(business, date, index: 4),
        ),
      );

      final visible = await harness.bookings.getCustomerBookings();

      expect(visible.length, 1);
      expect(visible.single.id, isNot(theirBooking.id));
      expect(visible.single.customerId, isNot(first.id));
    });

    test('a customer cannot review someone else’s appointment', () async {
      final (business, services) = await harness.firstBusiness();

      // A completed booking belonging to a different customer.
      final past = DateTime.now().subtract(const Duration(hours: 3));
      const strangerId = 'some-other-customer';
      harness.store.bookings['not-mine'] = Booking(
        id: 'not-mine',
        customerId: strangerId,
        businessId: business.id,
        serviceId: services.first.id,
        startTime: past,
        endTime: past.add(const Duration(minutes: 30)),
        status: BookingStatus.completed,
        createdAt: past,
        serviceName: services.first.name,
        servicePrice: services.first.price,
        businessName: business.name,
      );

      await harness.signInCustomer();

      await expectLater(
        harness.reviews.submitReview(
          const ReviewDraft(
            bookingId: 'not-mine',
            businessId: '',
            rating: 1,
          ).copyForBusiness(business.id),
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });
  });

  group('profile ownership', () {
    test('updating a profile always targets the signed-in user', () async {
      final customer = await harness.signInCustomer();
      await harness.auth.updateProfile(displayName: 'Renamed');

      // The other seeded accounts are untouched: there is no path in the
      // interface that lets a caller name whose profile to write.
      expect(harness.store.users[customer.id]!.displayName, 'Renamed');
      expect(
        harness.store.users.values
            .where((u) => u.id != customer.id)
            .every((u) => u.displayName != 'Renamed'),
        isTrue,
      );
    });

    test('updating a profile without signing in fails', () async {
      await expectLater(
        harness.auth.updateProfile(displayName: 'Nobody'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });
}

/// Small helper so the review-ownership test reads cleanly.
extension on ReviewDraft {
  ReviewDraft copyForBusiness(String businessId) => ReviewDraft(
    bookingId: bookingId,
    businessId: businessId,
    rating: rating,
    comment: comment,
  );
}
