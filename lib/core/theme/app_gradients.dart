import 'package:flutter/material.dart';

/// The app icon's spectrum, as reusable gradients.
///
/// The icon sweeps cyan → indigo through the stem, then magenta → orange
/// across the arch and dot. [brand] reproduces that whole sweep; [cool] and
/// [warm] are its two halves, matching the two jobs colour does in this app
/// (see [AppColors]: cool is tappable, warm is informative).
///
/// These are for *identity* surfaces only — the brand mark, business avatars,
/// the sign-in hero. Ordinary controls take flat colours from [AppColors], so
/// a screen never carries more than one gradient. A gradient on every card is
/// how a spectrum palette turns into noise.
///
/// Design guideline — Color > Best practices: "Avoid using the same color to
/// mean different things." A gradient here always means *this is Nearby*, and
/// never encodes state.
abstract final class AppGradients {
  /// Icon cyan. The anchor of the cool half.
  static const Color cyan = Color(0xFF3FC5F0);

  /// Icon indigo — the deep end of the stem.
  static const Color indigo = Color(0xFF2A45D8);

  /// Icon magenta, where the arch turns warm.
  static const Color magenta = Color(0xFFE5479B);

  /// Icon orange. The anchor of the warm half, and the colour of the dot.
  static const Color orange = Color(0xFFFF9440);

  /// The full icon sweep. Used at exactly one size on any screen — the mark.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, indigo, magenta, orange],
    stops: [0.0, 0.34, 0.68, 1.0],
  );

  /// The interactive half: the gradient form of [AppColors.primary].
  static const LinearGradient cool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, indigo],
  );

  /// Ink for text sitting on [action]. Measured 5.19:1 against every point of
  /// that gradient — the worst case, not the endpoints.
  static const Color onAction = Color(0xFF1F0714);

  /// The hero action's fill.
  ///
  /// This is the warm half, NOT the full sweep, and that is a measured
  /// constraint rather than a preference: [brand] spans 3.55:1 in luminance
  /// from cyan to indigo, so no single ink clears 4.5:1 across all of it — the
  /// best possible ink still bottoms out at 2.79:1. The warm half spans only
  /// 1.68:1, which is narrow enough to carry a label safely.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [magenta, orange],
  );

  /// The expressive half — hero panels and empty-state art.
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [magenta, orange],
  );
}
