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

  /// Ink for text sitting on [action]. White, at APCA Lc 88.8.
  static const Color onAction = Color(0xFFFFFFFF);

  /// The hero action's fill — the icon's INDIGO end, not its warm end.
  ///
  /// This is a measured constraint, and it overturns the obvious choice. The
  /// warm ramp cannot carry a label in either polarity:
  ///
  ///   magenta->orange + near-black ink   APCA Lc 40.1   (floor is 45)
  ///   magenta->orange + pure black       APCA Lc 40.8   (the ceiling)
  ///   magenta->orange + white ink        APCA Lc 47.5
  ///
  /// WCAG 2.x scores that same pill at 5.19:1 and calls it a pass, because
  /// WCAG 2.x systematically overestimates contrast for saturated colour at
  /// middling luminance — which is exactly what magenta and orange are.
  /// Darkening the ramp until white ink clears Lc 75 collapses chroma from 174
  /// to 121, i.e. plum and olive.
  ///
  /// Indigo is natively dark AND saturated, so it carries white ink at FULL
  /// chroma: Lc 88.8, chroma 174. Of the icon's four hues only its dark end can
  /// be a text-bearing fill; cyan and orange are too light, and belong in
  /// containers and decoration instead.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [indigo, Color(0xFF4A2CB8)],
  );

  /// The expressive half — hero panels and empty-state art.
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [magenta, orange],
  );
}
