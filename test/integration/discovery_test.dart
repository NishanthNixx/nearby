import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/errors/app_failure.dart';
import 'package:nearby/core/utils/geo.dart';
import 'package:nearby/features/businesses/domain/business_repository.dart';
import 'package:nearby/core/data/in_memory/in_memory_repositories.dart';
import 'package:nearby/features/discovery/presentation/discovery_controller.dart';

import '../support/test_harness.dart';

void main() {
  // The seed centre. Businesses are placed at known offsets from here.
  const seedCentre = GeoPoint(latitude: 12.9716, longitude: 77.5946);

  group('findNearby', () {
    late TestHarness harness;

    setUp(() => harness = TestHarness.create());
    tearDown(() => harness.dispose());

    test('returns tailors within the radius, nearest first', () async {
      final results = await harness.businesses.findNearby(
        const NearbyQuery(center: seedCentre, radiusKm: 10),
      );

      expect(results, isNotEmpty);

      // Sorted by distance.
      final distances = results.map((r) => r.distanceKm!).toList();
      final sorted = [...distances]..sort();
      expect(distances, sorted);

      // Nearest seeded shop is about 1.2km away.
      expect(results.first.distanceKm, lessThan(2));
      expect(results.first.business.name, 'Sri Lakshmi Tailors');
    });

    test('excludes anything beyond the radius', () async {
      final tight = await harness.businesses.findNearby(
        const NearbyQuery(center: seedCentre, radiusKm: 2),
      );
      final wide = await harness.businesses.findNearby(
        const NearbyQuery(center: seedCentre, radiusKm: 10),
      );

      expect(tight.length, lessThan(wide.length));
      expect(tight.every((r) => r.distanceKm! <= 2), isTrue);
    });

    test('returns an empty list when nothing is in range', () async {
      // Far out in the Indian Ocean.
      final results = await harness.businesses.findNearby(
        const NearbyQuery(
          center: GeoPoint(latitude: -20, longitude: 70),
          radiusKm: 5,
        ),
      );

      expect(results, isEmpty);
    });

    test('filters by name, case-insensitively and on partial words', () async {
      final results = await harness.businesses.findNearby(
        const NearbyQuery(
          center: seedCentre,
          radiusKm: 25,
          searchTerm: 'lakshmi',
        ),
      );

      expect(results.length, 1);
      expect(results.first.business.name, 'Sri Lakshmi Tailors');
    });

    test('matches on the tagline as well as the name', () async {
      final results = await harness.businesses.findNearby(
        const NearbyQuery(
          center: seedCentre,
          radiusKm: 25,
          searchTerm: 'sherwani',
        ),
      );

      expect(results.length, 1);
      expect(results.first.business.name, 'Ashraf Master Tailors');
    });

    test('returns nothing for a term that matches no one', () async {
      final results = await harness.businesses.findNearby(
        const NearbyQuery(
          center: seedCentre,
          radiusKm: 25,
          searchTerm: 'zzzzz-no-such-shop',
        ),
      );

      expect(results, isEmpty);
    });

    test('still lists results without a location fix', () async {
      // Declining the location prompt must degrade the experience, not break
      // it — an empty screen here would read as a broken app.
      final results = await harness.businesses.findNearby(
        const NearbyQuery(radiusKm: 5),
      );

      expect(results, isNotEmpty);
      expect(results.every((r) => r.distanceKm == null), isTrue);
    });

    test(
      'the open-now filter only returns businesses open at this moment',
      () async {
        final results = await harness.businesses.findNearby(
          const NearbyQuery(
            center: seedCentre,
            radiusKm: 25,
            openNowOnly: true,
          ),
        );

        final now = DateTime.now();
        expect(results.every((r) => r.business.isOpenAt(now)), isTrue);
      },
    );
  });

  group('DiscoveryController', () {
    test('resolves a location, then loads results', () async {
      final harness = TestHarness.create(
        locationService: const FixedLocationService(position: seedCentre),
      );
      addTearDown(harness.dispose);

      final controller = harness.container.read(
        discoveryControllerProvider.notifier,
      );
      await controller.initialise();

      final state = harness.container.read(discoveryControllerProvider);

      expect(state.center, seedCentre);
      expect(state.locationFailure, isNull);
      expect(state.isLoading, isFalse);
      expect(state.results, isNotNull);
      expect(state.results, isNotEmpty);
    });

    test('surfaces a denied location but still loads results', () async {
      final harness = TestHarness.create(
        locationService: FixedLocationService(
          failure: LocationFailure.denied(),
        ),
      );
      addTearDown(harness.dispose);

      final controller = harness.container.read(
        discoveryControllerProvider.notifier,
      );
      await controller.initialise();

      final state = harness.container.read(discoveryControllerProvider);

      expect(state.locationFailure, isA<LocationFailure>());
      expect(state.center, isNull);
      // The key assertion: no location does not mean no tailors.
      expect(state.results, isNotEmpty);
      expect(state.hasLocation, isFalse);
    });

    test('a permanently denied location offers a settings route out', () async {
      final harness = TestHarness.create(
        locationService: FixedLocationService(
          failure: LocationFailure.deniedForever(),
        ),
      );
      addTearDown(harness.dispose);

      await harness.container
          .read(discoveryControllerProvider.notifier)
          .initialise();

      final failure = harness.container
          .read(discoveryControllerProvider)
          .locationFailure;

      expect(failure, isNotNull);
      // Retrying the prompt cannot help once it is permanently denied, so the
      // recovery action has to be the settings deep link.
      expect(failure!.canOpenSettings, isTrue);
    });

    test('widening the radius brings in more tailors', () async {
      final harness = TestHarness.create(
        locationService: const FixedLocationService(position: seedCentre),
      );
      addTearDown(harness.dispose);

      final controller = harness.container.read(
        discoveryControllerProvider.notifier,
      );
      await controller.initialise();

      await controller.setRadius(2);
      final narrow = harness.container
          .read(discoveryControllerProvider)
          .results!
          .length;

      await controller.setRadius(25);
      final wide = harness.container
          .read(discoveryControllerProvider)
          .results!
          .length;

      expect(wide, greaterThan(narrow));
    });

    test('reports being filtered so the empty state can say why', () async {
      final harness = TestHarness.create(
        locationService: const FixedLocationService(position: seedCentre),
      );
      addTearDown(harness.dispose);

      final controller = harness.container.read(
        discoveryControllerProvider.notifier,
      );
      await controller.initialise();

      expect(
        harness.container.read(discoveryControllerProvider).isFiltered,
        isFalse,
      );

      controller.setSearchTerm('lakshmi');
      expect(
        harness.container.read(discoveryControllerProvider).isFiltered,
        isTrue,
      );
    });
  });
}
