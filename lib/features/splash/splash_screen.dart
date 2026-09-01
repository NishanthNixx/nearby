import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/brand.dart';

/// Shown only while the session is being restored.
///
/// Design guideline — Launching: get people to your content quickly and avoid a
/// launch experience that lingers. The router redirects away the moment auth
/// resolves, so on a warm start this is barely a frame. It exists so the first
/// thing on screen is Nearby's identity rather than a white flash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NearbyWordmark(fontSize: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Local tailors, booked in a tap',
              style: context.type.subhead.copyWith(
                color: colors.labelSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            // A determinate spinner would be a lie — how long auth takes is not
            // knowable — so this is indeterminate and deliberately small.
            // Drawn in labelSecondary, not primary: on this screen the
            // wordmark is the only bright object, and the spinner is
            // supporting furniture rather than an action (Monochrome & Gold —
            // nothing here earns a hue or the action white).
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colors.labelSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
