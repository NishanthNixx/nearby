import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/config/app_config.dart';
import 'package:nearby/core/data/in_memory/in_memory_repositories.dart';
import 'package:nearby/core/data/in_memory/in_memory_store.dart';
import 'package:nearby/core/di/providers.dart';
import 'package:nearby/core/errors/app_failure.dart';
import 'package:nearby/core/theme/app_spacing.dart';
import 'package:nearby/core/theme/identity_palette.dart';
import 'package:nearby/core/theme/app_theme.dart';
import 'package:nearby/core/utils/geo.dart';
import 'package:nearby/core/widgets/skeleton.dart';
import 'package:nearby/features/discovery/domain/location_service.dart';
import 'package:nearby/core/widgets/brand.dart';
import 'package:nearby/features/discovery/presentation/business_card.dart';
import 'package:nearby/features/discovery/presentation/discovery_screen.dart';

/// Verifies the discovery screen reaches each of its four states.
///
/// Design guideline — Loading: a screen that sits blank while data loads reads
/// as broken. These tests assert that a skeleton, results, an empty state and a
/// location notice each actually appear.
/// The "N tailors within X km" line, which is always on screen.
///
/// Anchored at the leading digits: the words "within N km" also appear on the
/// radius filter chips, so an unanchored substring match hits two widgets.
/// Section titles render uppercase, hence the case-insensitive flag.
Finder _countFinder() =>
    find.textContaining(RegExp(r'^\d+ tailors? within', caseSensitive: false));

String _countLabel(WidgetTester tester) =>
    tester.widget<Text>(_countFinder().first).data!;

int _resultCount(WidgetTester tester) =>
    int.parse(RegExp(r'^(\d+)').firstMatch(_countLabel(tester))!.group(1)!);

void main() {
  const seedCentre = GeoPoint(latitude: 12.9716, longitude: 77.5946);

  setUp(() {
    AppConfig.dataSource = DataSource.inMemory;
    // Deterministic by default: no artificial latency means no timer can be
    // left pending when a test ends. The one test that needs to observe the
    // loading state restores it locally.
    inMemoryLatency = Duration.zero;
  });

  tearDown(() {
    AppConfig.dataSource = DataSource.firebase;
    inMemoryLatency = const Duration(milliseconds: 260);
  });

  Widget wrap({
    required LocationService locationService,
    InMemoryStore? store,
  }) {
    final resolvedStore = store ?? InMemoryStore();

    return ProviderScope(
      overrides: [
        inMemoryStoreProvider.overrideWithValue(resolvedStore),
        locationServiceProvider.overrideWithValue(locationService),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const DiscoveryScreen(),
      ),
    );
  }

  testWidgets('shows the large title and search field on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pump();

    // Present before any data arrives — the screen is never blank.
    expect(find.text('NEARBY'), findsOneWidget);
    expect(find.text('Search tailors or services'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('shows skeleton cards while results load', (tester) async {
    // This test is specifically about the loading state, so it needs the
    // backend to actually take a moment.
    inMemoryLatency = const Duration(milliseconds: 260);

    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pump();

    // Skeletons shaped like the real cards, not a bare spinner.
    expect(find.byType(BusinessCardSkeleton), findsWidgets);
    expect(find.text('Sri Lakshmi Tailors'), findsNothing);

    // Then the real content replaces them.
    await tester.pumpAndSettle();
    expect(find.byType(BusinessCardSkeleton), findsNothing);
    expect(find.text('Sri Lakshmi Tailors'), findsOneWidget);
  });

  testWidgets('renders nearby tailors once loaded', (tester) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusinessCardSkeleton), findsNothing);
    expect(find.text('Sri Lakshmi Tailors'), findsOneWidget);

    // The distance and open state both appear, so the card answers "how far"
    // and "are they open" without a tap.
    expect(find.textContaining('km'), findsWidgets);
  });

  testWidgets('shows a count of what was found', (tester) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    // Anchored at the leading count: "within 5 km" also appears on the filter
    // chip, so an unanchored match is ambiguous.
    expect(_countFinder(), findsOneWidget);
    expect(_resultCount(tester), greaterThan(0));
  });

  testWidgets(
    'shows an empty state, not a blank screen, when nothing is near',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          locationService: const FixedLocationService(
            // Middle of the Indian Ocean.
            position: GeoPoint(latitude: -20, longitude: 70),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tailors nearby yet'), findsOneWidget);
      // And it offers the one thing that might help.
      expect(find.text('Search a wider area'), findsOneWidget);
    },
  );

  testWidgets('explains a denied location while still listing tailors', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        locationService: FixedLocationService(
          failure: LocationFailure.denied(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The notice explains the situation...
    expect(find.text('Location is off'), findsOneWidget);
    expect(find.text('Allow location'), findsOneWidget);
    // ...but results are still there, because a declined prompt must not
    // produce an empty app. Asserted on the cards rather than a particular
    // shop: the cards carry full-width imagery now, so which ones are built
    // depends on the viewport.
    expect(find.byType(BusinessCard), findsWidgets);
  });

  testWidgets('a permanently denied location offers the settings route', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        locationService: FixedLocationService(
          failure: LocationFailure.deniedForever(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location access blocked'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('searching narrows the list', (tester) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    // Asserted on the result count rather than on a particular card: the list
    // is lazy, so a shop further down may legitimately not be built yet.
    expect(_resultCount(tester), greaterThan(1));

    await tester.enterText(find.byType(TextField).first, 'lakshmi');
    await tester.pumpAndSettle();

    expect(find.text('Sri Lakshmi Tailors'), findsOneWidget);
    expect(_resultCount(tester), 1);
  });

  testWidgets('a search matching nobody explains that filters are the cause', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'zzzz-nothing');
    await tester.pumpAndSettle();

    // Distinct from the "none nearby" state — the wording has to tell the
    // customer it is their filter, not the neighbourhood.
    expect(find.text('No tailors match'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets(
    'widening the radius via the filter chip brings in more results',
    (tester) async {
      await tester.pumpWidget(
        wrap(locationService: const FixedLocationService(position: seedCentre)),
      );
      await tester.pumpAndSettle();

      // Asserted on the count line, which is always on screen. The list is
      // lazy, so a card further down may legitimately not be built.
      await tester.tap(find.text('Within 2 km'));
      await tester.pumpAndSettle();
      final narrow = _resultCount(tester);
      expect(_countLabel(tester), contains('2 KM'));

      await tester.tap(find.text('Within 10 km'));
      await tester.pumpAndSettle();
      final wide = _resultCount(tester);
      expect(_countLabel(tester), contains('10 KM'));

      expect(wide, greaterThan(narrow));
    },
  );

  testWidgets('the nearest tailor is badged, and only that one', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    // Every result is the same card now; the hierarchy is one badge, and it
    // only means something if it is not repeated.
    expect(find.text('CLOSEST TO YOU'), findsOneWidget);
    expect(find.byType(BusinessCard), findsWidgets);
  });

  testWidgets('no closest badge without a location fix', (tester) async {
    // "Closest to you" would be a claim the app cannot support when the list is
    // not ordered by distance.
    await tester.pumpWidget(
      wrap(
        locationService: FixedLocationService(
          failure: LocationFailure.denied(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLOSEST TO YOU'), findsNothing);
    // But results are still listed.
    expect(find.byType(BusinessCard), findsWidgets);
  });

  testWidgets('every card carries its shop identity', (tester) async {
    // The reason the identity system exists: without it, six photo-less shops
    // render as six identical grey placeholders. The card shows this through
    // BusinessBanner, which falls back to the generated gradient and monogram
    // when there is no reachable photo — which is the case here, offline.
    //
    // The monogram derivation itself is covered exhaustively in
    // test/unit/identity_palette_test.dart.
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    final banners = tester
        .widgetList<BusinessBanner>(find.byType(BusinessBanner))
        .toList();

    expect(banners, isNotEmpty);
    for (final banner in banners) {
      expect(banner.businessId, isNotEmpty);
      final monogram = IdentityPalette.monogramFor(banner.name);
      expect(monogram, isNotEmpty);
      expect(monogram, isNot('?'));
    }
  });

  testWidgets('every tappable control clears the minimum touch target', (
    tester,
  ) async {
    // Design guideline — Accessibility > Mobility: mobile controls should be at
    // least 44x44pt. Asserted rather than assumed, because a chip or icon
    // button is easy to shrink below it by accident.
    await tester.pumpWidget(
      wrap(locationService: const FixedLocationService(position: seedCentre)),
    );
    await tester.pumpAndSettle();

    final tappables = find.byType(InkWell);
    expect(tappables, findsWidgets);

    for (final element in tappables.evaluate()) {
      final size = element.size;
      if (size == null || size.isEmpty) continue;
      expect(
        size.height,
        greaterThanOrEqualTo(AppSizing.minTouchTarget),
        reason:
            'an InkWell only ${size.height}pt tall is below the 44pt '
            'minimum control size',
      );
    }
  });

  testWidgets('renders in dark mode without losing its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inMemoryStoreProvider.overrideWithValue(InMemoryStore()),
          locationServiceProvider.overrideWithValue(
            const FixedLocationService(position: seedCentre),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const DiscoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEARBY'), findsOneWidget);
    expect(find.text('Sri Lakshmi Tailors'), findsOneWidget);
  });

  testWidgets('survives the largest supported text size', (tester) async {
    // Design guideline — Typography > Supporting scalable text: "Make sure your
    // app's layout adapts to all font sizes." A layout overflow throws in
    // tests, so reaching the end of this test is the assertion.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inMemoryStoreProvider.overrideWithValue(InMemoryStore()),
          locationServiceProvider.overrideWithValue(
            const FixedLocationService(position: seedCentre),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: DiscoveryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sri Lakshmi Tailors'), findsOneWidget);
  });
}
