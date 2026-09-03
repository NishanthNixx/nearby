@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/config/app_config.dart';
import 'package:nearby/core/data/in_memory/in_memory_repositories.dart';
import 'package:nearby/core/data/in_memory/in_memory_store.dart';
import 'package:nearby/core/di/providers.dart';
import 'package:nearby/core/theme/app_colors.dart';
import 'package:nearby/core/theme/app_theme.dart';
import 'package:nearby/core/utils/geo.dart';
import 'package:nearby/features/auth/presentation/sign_in_screen.dart';
import 'package:nearby/features/auth/presentation/sign_up_screen.dart';
import 'package:nearby/features/bookings/presentation/booking_flow_screen.dart';
import 'package:nearby/features/bookings/presentation/customer_bookings_screen.dart';
import 'package:nearby/features/businesses/presentation/business_profile_screen.dart';
import 'package:nearby/features/discovery/presentation/discovery_screen.dart';

/// Renders the main screens to PNGs so the design can actually be looked at.
///
/// Run with `flutter test --update-goldens test/golden` to regenerate.
///
/// These are review artefacts rather than regression gates: they are not
/// asserted against in CI, because a golden that fails on every deliberate
/// design change is a tax rather than a test. The behavioural guarantees live in
/// test/widget.
/// Applies the loaded system font to the theme's text styles.
///
/// The type ladder deliberately leaves `fontFamily` null so it resolves to the
/// platform font on a device. In a test that resolves to the placeholder font,
/// where every glyph is an identical rectangle — useless for reviewing type. The
/// family has to go on the theme, because that is what Material turns into the
/// ambient `DefaultTextStyle` that the ladder's styles inherit from.
ThemeData _withRealFont(ThemeData theme) {
  const family = 'NearbyGoldenFont';
  ButtonStyle withFamily(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: family),
        ),
      );

  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: family),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: family,
      ),
    ),
    // A ButtonStyle's textStyle is resolved directly rather than merged with the
    // ambient DefaultTextStyle, so button labels need the family applied
    // separately or they render as placeholder boxes.
    filledButtonTheme: FilledButtonThemeData(
      style: withFamily(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: withFamily(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: withFamily(theme.textButtonTheme.style),
    ),
  );
}

void main() {
  const seedCentre = GeoPoint(latitude: 12.9716, longitude: 77.5946);

  setUpAll(() async {
    // The test renderer ships a placeholder font where every glyph is an
    // identical rectangle, which makes a golden useless for judging type. Load
    // the real system font so the output reflects what a device shows.
    final loader = FontLoader('NearbyGoldenFont');
    var loaded = false;

    // .ttc collections cannot be loaded, so only plain .ttf/.otf are tried.
    for (final path in [
      '/System/Library/Fonts/SFNS.ttf',
      '/System/Library/Fonts/Geneva.ttf',
      '/Library/Fonts/Arial.ttf',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        loaded = true;
        break;
      }
    }

    if (loaded) await loader.load();

    // Material Icons ships with the SDK. Without it every icon renders as an
    // empty box and the golden cannot be used to check icon placement.
    // Walk up from the Dart binary to flutter/bin/cache, where the SDK keeps
    // its bundled fonts.
    var dir = File(Platform.resolvedExecutable).parent;
    File? iconFont;
    for (var i = 0; i < 6 && iconFont == null; i++) {
      final candidate = File(
        '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (candidate.existsSync()) {
        iconFont = candidate;
      } else {
        dir = dir.parent;
      }
    }

    if (iconFont != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(ByteData.sublistView(iconFont.readAsBytesSync())),
        );
      await icons.load();
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

  Widget host(
    Widget child, {
    required Brightness brightness,
    AppColors? palette,
  }) {
    return ProviderScope(
      overrides: [
        inMemoryStoreProvider.overrideWithValue(InMemoryStore()),
        locationServiceProvider.overrideWithValue(
          const FixedLocationService(position: seedCentre),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withRealFont(
          brightness == Brightness.dark
              ? AppTheme.dark(overrideColors: palette)
              : AppTheme.light(overrideColors: palette),
        ),
        home: child,
      ),
    );
  }

  Future<void> capture(
    WidgetTester tester,
    Widget screen,
    String name, {
    // Light is the app's committed appearance, so it is the default here too —
    // a dark-only render would be reviewing a mode nobody sees.
    Brightness brightness = Brightness.light,
    Size size = const Size(393, 852),
    AppColors? palette,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(screen, brightness: brightness, palette: palette),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('images/$name.png'),
    );
  }

  testWidgets('discovery — default (light)', (tester) async {
    await capture(tester, const DiscoveryScreen(), 'discovery_light');
  });

  testWidgets('discovery — dark counterpart', (tester) async {
    await capture(
      tester,
      const DiscoveryScreen(),
      'discovery_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('business profile', (tester) async {
    await capture(
      tester,
      const BusinessProfileScreen(businessId: 'biz_2'),
      'profile_light',
    );
  });

  testWidgets('booking flow — choose a service', (tester) async {
    await capture(
      tester,
      const BookingFlowScreen(businessId: 'biz_2'),
      'booking_service_light',
    );
  });

  testWidgets('booking flow — schedule (date + time)', (tester) async {
    // Driven to the time step, which is the densest screen in the flow and the
    // one most likely to break at scale.
    await tester.binding.setSurfaceSize(const Size(393, 852));
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        const BookingFlowScreen(
          businessId: 'biz_2',
          preselectedServiceId: 'svc_3',
        ),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();

    // Service is preselected, so the flow lands on the date step; advance to
    // the times.
    final continueButton = find.text('Continue');
    if (continueButton.evaluate().isNotEmpty) {
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('images/booking_schedule_light.png'),
    );
  });

  testWidgets('bookings — empty', (tester) async {
    await capture(
      tester,
      const CustomerBookingsScreen(),
      'bookings_empty_light',
    );
  });

  testWidgets('sign in', (tester) async {
    await capture(tester, const SignInScreen(), 'sign_in_light');
  });

  testWidgets('sign up', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(const SignUpScreen(), brightness: Brightness.light),
    );
    await tester.pumpAndSettle();

    // ONLY the decode goes inside runAsync. pumpWidget must stay outside it:
    // within runAsync the test binding stops intercepting asset loads, so
    // Image.asset falls through to PlatformAssetBundle and fails to find a
    // bundle that exists perfectly well from rootBundle.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/marketplace.jpg'),
        tester.element(find.byType(SignUpScreen)),
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SignUpScreen),
      matchesGoldenFile('images/sign_up_light.png'),
    );
  });
}
