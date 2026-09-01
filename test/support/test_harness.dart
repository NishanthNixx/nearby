import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby/core/config/app_config.dart';
import 'package:nearby/core/data/in_memory/in_memory_store.dart';
import 'package:nearby/core/di/providers.dart';
import 'package:nearby/features/auth/domain/app_user.dart';
import 'package:nearby/features/auth/domain/auth_repository.dart';
import 'package:nearby/features/bookings/domain/booking_repository.dart';
import 'package:nearby/features/businesses/domain/business.dart';
import 'package:nearby/features/businesses/domain/business_repository.dart';
import 'package:nearby/features/businesses/domain/service_offering.dart';
import 'package:nearby/features/discovery/domain/location_service.dart';
import 'package:nearby/features/reviews/domain/review_repository.dart';

/// A running app backed by the in-memory implementations.
///
/// These are the same classes the app falls back to when Firebase is not
/// configured — not mocks written for the tests. So a test exercising booking
/// concurrency here is exercising real code that ships, and the fact that the
/// same tests would pass against the Firebase implementation is what shows the
/// repository interfaces are genuinely backend-agnostic.
class TestHarness {
  TestHarness._(this.container, this.store);

  /// Builds a harness, optionally overriding the device location.
  factory TestHarness.create({LocationService? locationService}) {
    AppConfig.dataSource = DataSource.inMemory;

    final store = InMemoryStore();

    final container = ProviderContainer(
      overrides: [
        inMemoryStoreProvider.overrideWithValue(store),
        if (locationService != null)
          locationServiceProvider.overrideWithValue(locationService),
      ],
    );

    return TestHarness._(container, store);
  }

  final ProviderContainer container;
  final InMemoryStore store;

  AuthRepository get auth => container.read(authRepositoryProvider);
  BusinessRepository get businesses =>
      container.read(businessRepositoryProvider);
  BookingRepository get bookings => container.read(bookingRepositoryProvider);
  ReviewRepository get reviews => container.read(reviewRepositoryProvider);

  /// Seeded credentials, so tests read as scenarios rather than fixtures.
  static const String customerEmail = 'customer@example.com';
  static const String ownerEmail = 'lakshmi@example.com';
  static const String otherOwnerEmail = 'ashraf@example.com';
  static const String password = 'password123';

  Future<AppUser> signInCustomer() =>
      auth.signIn(email: customerEmail, password: password);

  Future<AppUser> signInOwner([String email = ownerEmail]) =>
      auth.signIn(email: email, password: password);

  /// The first seeded business, with its services.
  Future<(Business, List<ServiceOffering>)> firstBusiness() async {
    final business = store.businesses.values.first;
    final services = await businesses.getServices(business.id);
    return (business, services);
  }

  Business businessNamed(String name) =>
      store.businesses.values.firstWhere((b) => b.name == name);

  /// The next date this business trades, at or after [from].
  DateTime nextTradingDate(Business business, {DateTime? from}) {
    var date = from ?? DateTime.now().add(const Duration(days: 1));
    date = DateTime(date.year, date.month, date.day);

    for (var i = 0; i < 14; i++) {
      if (business.openingHours.tradesOn(date)) return date;
      date = date.add(const Duration(days: 1));
    }
    throw StateError('${business.name} has no trading day in the next 14 days');
  }

  /// A slot start that is on the business's cadence and comfortably ahead of
  /// the lead time.
  DateTime slotOn(Business business, DateTime date, {int index = 0}) {
    final hours = business.openingHours.forDate(date);
    return hours.opensAt
        .onDate(date)
        .add(
          Duration(minutes: business.openingHours.slotDurationMinutes * index),
        );
  }

  void dispose() {
    container.dispose();
    AppConfig.dataSource = DataSource.firebase;
  }
}
