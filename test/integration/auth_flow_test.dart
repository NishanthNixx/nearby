import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/errors/app_failure.dart';
import 'package:nearby/features/auth/domain/app_user.dart';
import 'package:nearby/features/auth/domain/auth_repository.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() => harness = TestHarness.create());
  tearDown(() => harness.dispose());

  group('registration', () {
    test('creates a customer account and signs them in', () async {
      final user = await harness.auth.signUp(
        const SignUpRequest(
          email: 'New.Customer@Example.com',
          password: 'a-good-password',
          role: UserRole.customer,
          displayName: 'Ravi Kumar',
        ),
      );

      expect(user.role, UserRole.customer);
      expect(user.displayName, 'Ravi Kumar');
      // Normalised, so the same person cannot register twice with different
      // capitalisation.
      expect(user.email, 'new.customer@example.com');
      expect(harness.auth.currentUser?.id, user.id);
    });

    test('a new business owner has no listing yet', () async {
      final user = await harness.auth.signUp(
        const SignUpRequest(
          email: 'new.tailor@example.com',
          password: 'a-good-password',
          role: UserRole.businessOwner,
          displayName: 'Ashok Tailors',
        ),
      );

      expect(user.role, UserRole.businessOwner);
      expect(user.businessId, isNull);
      // This is what routes them into setup rather than the dashboard.
      expect(user.needsBusinessSetup, isTrue);
    });

    test('rejects a short password with a field-level message', () async {
      await expectLater(
        harness.auth.signUp(
          const SignUpRequest(
            email: 'someone@example.com',
            password: 'short',
            role: UserRole.customer,
            displayName: 'Someone',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors,
            'fieldErrors',
            containsPair('password', contains('8 characters')),
          ),
        ),
      );
    });

    test('rejects a malformed email', () async {
      await expectLater(
        harness.auth.signUp(
          const SignUpRequest(
            email: 'not-an-email',
            password: 'a-good-password',
            role: UserRole.customer,
            displayName: 'Someone',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.fieldErrors.keys,
            'fields',
            contains('email'),
          ),
        ),
      );
    });

    test('refuses an email that already has an account', () async {
      await expectLater(
        harness.auth.signUp(
          const SignUpRequest(
            email: TestHarness.customerEmail,
            password: 'a-good-password',
            role: UserRole.customer,
            displayName: 'Impostor',
          ),
        ),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('login', () {
    test('signs in with correct credentials', () async {
      final user = await harness.signInCustomer();
      expect(user.email, TestHarness.customerEmail);
      expect(user.role, UserRole.customer);
    });

    test(
      'rejects a wrong password without saying which field was wrong',
      () async {
        await expectLater(
          harness.auth.signIn(
            email: TestHarness.customerEmail,
            password: 'wrong-password',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.message,
              'message',
              // Deliberately does not reveal whether the account exists.
              contains('does not match an account'),
            ),
          ),
        );
        expect(harness.auth.currentUser, isNull);
      },
    );

    test('rejects an unknown account', () async {
      await expectLater(
        harness.auth.signIn(
          email: 'nobody@example.com',
          password: TestHarness.password,
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test(
      'a business owner signs in already attached to their listing',
      () async {
        final user = await harness.signInOwner();
        expect(user.role, UserRole.businessOwner);
        expect(user.businessId, isNotNull);
        expect(user.needsBusinessSetup, isFalse);
      },
    );
  });

  group('logout', () {
    test('clears the current user', () async {
      await harness.signInCustomer();
      expect(harness.auth.currentUser, isNotNull);

      await harness.auth.signOut();
      expect(harness.auth.currentUser, isNull);
    });
  });

  group('auth state stream', () {
    test(
      'emits the signed-out state, then the user, then null again',
      () async {
        final seen = <AppUser?>[];
        final subscription = harness.auth.watchAuthState().listen(seen.add);

        // Let the initial emission land.
        await Future<void>.delayed(Duration.zero);
        expect(seen, [null]);

        await harness.signInCustomer();
        await Future<void>.delayed(Duration.zero);
        expect(seen.last?.email, TestHarness.customerEmail);

        await harness.auth.signOut();
        await Future<void>.delayed(Duration.zero);
        expect(seen.last, isNull);

        await subscription.cancel();
      },
    );

    test('reflects a profile edit without a re-subscribe', () async {
      await harness.signInCustomer();

      final seen = <String?>[];
      final subscription = harness.auth.watchAuthState().listen(
        (u) => seen.add(u?.displayName),
      );

      await Future<void>.delayed(Duration.zero);
      await harness.auth.updateProfile(displayName: 'Renamed Customer');
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, 'Renamed Customer');
      await subscription.cancel();
    });
  });

  group('password reset', () {
    test(
      'succeeds for an unknown address, so accounts cannot be enumerated',
      () async {
        // No throw is the assertion: a "no such user" error here would let anyone
        // discover which emails have accounts.
        await expectLater(
          harness.auth.sendPasswordReset('nobody@example.com'),
          completes,
        );
      },
    );
  });
}
