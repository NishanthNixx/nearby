import 'package:flutter/material.dart';

/// The brand's gradients.
///
/// There is deliberately only one. The app icon is beige and two browns, so a
/// spectrum of brand gradients would have nothing to point at — the earlier
/// cyan-to-orange sweep was retired with the icon it came from.
///
/// Design guideline — Color > Best practices: "Avoid using the same color to
/// mean different things." [action] always means *this is the thing to press*,
/// and never encodes state.
abstract final class AppGradients {
  /// Ink for text sitting on [action]. White, at APCA Lc 91.7.
  static const Color onAction = Color(0xFFFFFFFF);

  /// Cognac — the light end of the leather ramp.
  static const Color cognac = Color(0xFF7A4420);

  /// Chocolate — its dark end.
  static const Color chocolate = Color(0xFF4A2C17);

  /// The hero action's fill: polished leather.
  ///
  /// This is the icon's own brown, and it is also the only kind of hue that
  /// can do this job. A text-bearing fill has to be dark, and brown is
  /// NATIVELY dark, so it reaches Lc 91.7 under white ink without being pushed
  /// anywhere it does not want to go.
  ///
  /// Worth recording, because it cost two attempts to learn: the previous
  /// icon's bright hues could not manage it. Cyan and orange are too light to
  /// carry a label in either polarity, and the magenta-to-orange ramp had to be
  /// darkened until its chroma collapsed from 174 to 121 — plum and olive —
  /// before white ink would clear. Any future accent asked to carry text has
  /// to be dark first and chromatic second, in that order.
  static const LinearGradient action = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cognac, chocolate],
  );
}
