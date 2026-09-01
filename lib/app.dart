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

      // Nearby commits to a dark appearance as a brand decision — the whole
      // visual language (near-black ground, white booking pill, gold ratings)
      // is built for it, the way high-end hospitality apps commit.
      //
      // Design guideline — Dark Mode > Best practices: "In rare cases, consider
      // using only a dark appearance in the interface." The trade-off is real:
      // a dark screen is harder to read in direct sunlight, and this app is
      // used on the street. The light palette below keeps the same logic
      // inverted, so reverting to system-following is a one-line change of
      // [themeMode] if that trade-off proves wrong in use.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // The platform's Increase Contrast setting swaps in the stronger palette.
      //
      // Design guideline — Color > Best practices: "Make sure all your app's
      // colors work well in light, dark, and increased contrast contexts."
      highContrastTheme: AppTheme.light(highContrast: true),
      highContrastDarkTheme: AppTheme.dark(highContrast: true),

      themeMode: ThemeMode.dark,
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
