import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// The application shell.
class NearbyApp extends ConsumerWidget {
  const NearbyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Keeps this device's push token attached to whoever is signed in. Watched
    // here so it lives as long as the app rather than as long as a screen.
    ref.watch(deviceRegistrationProvider);

    return MaterialApp.router(
      title: 'Nearby',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      // Nearby commits to a LIGHT appearance. The dark-first version lost the
      // argument on two counts.
      //
      // The practical one was always in the open: this app is opened on a
      // footpath in daylight, and a near-black screen is hardest to read
      // exactly there.
      //
      // The second only showed up under measurement. The brand's colour is a
      // four-hue spectrum, and on a near-black ground colour has to be placed
      // in dim atmospheric layers to avoid blowing out — where it composites
      // straight back to black (four measured "aurora" hues resolved to
      // #0B1118, #0A0C1B, #120B13, #171010). On paper the same hues sit in
      // opaque foreground fills and stay chromatic. The icon's own ground is
      // white; the app now agrees with it.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // The platform's Increase Contrast setting swaps in the stronger palette.
      //
      // Design guideline — Color > Best practices: "Make sure all your app's
      // colors work well in light, dark, and increased contrast contexts."
      highContrastTheme: AppTheme.light(highContrast: true),
      highContrastDarkTheme: AppTheme.dark(highContrast: true),

      themeMode: ThemeMode.light,
      builder: (context, child) => _TextScaleGuard(child: child),
    );
  }
}

/// Clamps the platform text scale to a range the layouts have been checked
/// against.
///
/// Design guideline — Typography > Supporting scalable text: "Make sure your
/// app's layout adapts to all font sizes." Nearby honours the user's choice; the
/// clamp only bounds the extremes, well above the standard sizes, so a
/// pathological scale factor cannot make a screen unusable.
class _TextScaleGuard extends StatelessWidget {
  const _TextScaleGuard({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: AppConfig.minTextScale,
          maxScaleFactor: AppConfig.maxTextScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
