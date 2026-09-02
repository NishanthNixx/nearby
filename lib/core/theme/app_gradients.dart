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

  /// Ink for text sitting on [action]. White, at APCA Lc 91.7.
  static const Color onAction = Color(0xFFFFFFFF);

  /// Cognac — the light end of the leather ramp.
  static const Color cognac = Color(0xFF7A4420);

  /// Chocolate — its dark end.
  static const Color chocolate = Color(0xFF4A2C17);

  /// The hero action's fill: polished leather.
  ///
  /// Brown is a better CTA fill than any hue in the icon, for a structural
  /// reason. A text-bearing fill has to be dark, and brown is NATIVELY dark —
  /// so it reaches Lc 91.7 under white ink without being pushed anywhere it
  /// does not want to go. The icon's own hues cannot: cyan and orange are too
  /// light to carry a label at all, and the warm ramp had to be darkened until
  /// its chroma collapsed from 174 to 121 before white ink would clear.
  ///
  /// It also belongs to the product. Beige and brown are the materials of a
  /// tailor's shop — leather, thread, kraft paper — where an electric blue was
  /// only ever a tech convention borrowed from elsewhere.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [cognac, chocolate],
  );

  /// The expressive half — hero panels and empty-state art.
  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [magenta, orange],
  );
}
