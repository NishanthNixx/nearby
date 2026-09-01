import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/config/app_config.dart';
import 'package:nearby/core/data/in_memory/in_memory_repositories.dart';
import 'package:nearby/core/data/in_memory/in_memory_store.dart';
import 'package:nearby/core/di/providers.dart';
import 'package:nearby/core/theme/app_theme.dart';
import 'package:nearby/core/utils/geo.dart';
import 'package:nearby/features/auth/presentation/sign_in_screen.dart';
import 'package:nearby/features/bookings/presentation/booking_flow_screen.dart';
import 'package:nearby/features/bookings/presentation/customer_bookings_screen.dart';
import 'package:nearby/features/businesses/presentation/business_profile_screen.dart';
import 'package:nearby/features/discovery/presentation/discovery_screen.dart';

/// Renders every main screen on the narrowest phone Nearby supports, at the
/// largest text size it allows, and fails if anything overflows.
///
/// This exists because overflow bugs kept reaching review: the other widget
/// tests run at 393pt, which is wide enough to hide a row that breaks at 320pt.
/// Three separate defects were found by hand at 320pt × 2x that a 393pt test
/// passed cleanly.
///
/// Design guideline — Typography > Supporting scalable text: "Make sure your
/// app's layout adapts to all font sizes. Verify that your design scales, and
/// that text and glyphs are legible at all font sizes."
///
/// A RenderFlex overflow raises a FlutterError, which the test binding records
/// as a failure — so reaching the end of each case IS the assertion. There is
/// nothing to expect() beyond that.
void main() {
  const seedCentre = GeoPoint(latitude: 12.9716, longitude: 77.5946);

  // iPhone SE (1st gen) — the narrowest screen still worth supporting.
  const narrow = Size(320, 568);

  setUpAll(() async {
    // A real font, because the test placeholder renders every glyph as a full
    // em and would report overflows that no device can produce.
    final loader = FontLoader('NearbyTestFont');
    for (final path in [
      '/System/Library/Fonts/SFNS.ttf',
      '/System/Library/Fonts/Geneva.ttf',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        await loader.load();
        break;
      }
    }
  });

  setUp(() {
    AppConfig.dataSource = DataSource.inMemory;
    inMemoryLatency = Duration.zero;
  });

  tearDown(() {
    AppConfig.dataSource = DataSource.firebase;
    inMemoryLatency = const Duration(milliseconds: 260);
  });

  Widget host(Widget child, double scale) {
    final base = AppTheme.dark();

    return ProviderScope(
      overrides: [
        inMemoryStoreProvider.overrideWithValue(InMemoryStore()),
        locationServiceProvider.overrideWithValue(
          const FixedLocationService(position: seedCentre),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'NearbyTestFont'),
        ),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );
  }

  /// Only the ceiling. 1x is already covered by the other widget tests, and
  /// running the full matrix with scrolling exhausted the test runner's memory.
  const scales = [AppConfig.maxTextScale];

  final screens = <String, Widget Function()>{
    'discovery': () => const DiscoveryScreen(),
    'business profile': () =>
        const BusinessProfileScreen(businessId: 'biz_2'),
    'booking flow — service': () =>
        const BookingFlowScreen(businessId: 'biz_2'),
    'booking flow — schedule': () => const BookingFlowScreen(
      businessId: 'biz_2',
      preselectedServiceId: 'svc_3',
    ),
    'bookings': () => const CustomerBookingsScreen(),
    'sign in': () => const SignInScreen(),
  };

  for (final entry in screens.entries) {
    for (final scale in scales) {
      testWidgets(
        '${entry.key} does not overflow at 320pt x ${scale}x',
        (tester) async {
          await tester.binding.setSurfaceSize(narrow);
          tester.view.physicalSize = narrow * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(host(entry.value(), scale));
          await tester.pumpAndSettle();

          // Scroll the full length of the primary scrollable, so rows below the
          // fold are built and laid out too — a lazy list hides its own
          // overflows until the offending row is constructed.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            for (var i = 0; i < 3; i++) {
              await tester.drag(scrollable.first, const Offset(0, -600));
              await tester.pumpAndSettle();
            }
          }
        },
      );
    }
  }
}
