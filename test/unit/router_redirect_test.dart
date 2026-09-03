import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/routing/app_router.dart';
import 'package:nearby/features/auth/domain/app_user.dart';

/// The router's redirect rules, asserted directly.
///
/// These were inline in the GoRouter config and untested, which is how an
/// owner could finish shop setup and be left standing on the setup screen: the
/// gate that pushed them in had no matching rule to let them out.
void main() {
  AppUser user({required UserRole role, String? businessId}) => AppUser(
    id: 'u1',
    email: 'a@b.com',
    role: role,
    createdAt: DateTime(2026),
    businessId: businessId,
  );

  final customer = user(role: UserRole.customer);
  final ownerNeedingSetup = user(role: UserRole.businessOwner);
  final ownerWithShop = user(role: UserRole.businessOwner, businessId: 'biz_1');

  String? go(AppUser? u, String location, {bool isRestoring = false}) =>
      redirectFor(isRestoring: isRestoring, user: u, location: location);

  group('owner setup gate', () {
    test('an owner without a shop is pushed into setup', () {
      expect(go(ownerNeedingSetup, '/owner/bookings'), '/owner/setup');
    });

    test('an owner without a shop stays on setup', () {
      expect(go(ownerNeedingSetup, '/owner/setup'), isNull);
    });

    test('an owner WITH a shop is let out of setup', () {
      // The regression. Setup is a valid owner route, so the role fence alone
      // left them there — on a screen with no back and a spent button.
      expect(go(ownerWithShop, '/owner/setup'), '/owner/bookings');
    });

    test('an owner with a shop is left alone elsewhere in the owner app', () {
      expect(go(ownerWithShop, '/owner/bookings'), isNull);
      expect(go(ownerWithShop, '/owner/services'), isNull);
    });
  });

  group('role fencing', () {
    test('a customer cannot open owner routes', () {
      expect(go(customer, '/owner/bookings'), '/discover');
    });

    test('an owner cannot open customer routes', () {
      expect(go(ownerWithShop, '/discover'), '/owner/bookings');
    });

    test('a customer is left alone in the customer app', () {
      expect(go(customer, '/discover'), isNull);
    });
  });

  group('session', () {
    test('restoring holds on the splash screen', () {
      expect(go(null, '/discover', isRestoring: true), '/');
      expect(go(null, '/', isRestoring: true), isNull);
    });

    test('signed out lands on sign-in, except on the auth screens', () {
      expect(go(null, '/discover'), '/sign-in');
      expect(go(null, '/sign-in'), isNull);
      expect(go(null, '/sign-up'), isNull);
    });

    test('signing in leaves the auth screens for the role home', () {
      expect(go(customer, '/sign-in'), '/discover');
      expect(go(ownerNeedingSetup, '/sign-in'), '/owner/setup');
      expect(go(ownerWithShop, '/sign-in'), '/owner/bookings');
    });
  });
}
