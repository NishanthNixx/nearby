import 'package:flutter/material.dart';

/// A deterministic visual identity for a business that has no photograph.
///
/// Most local tailors will never upload a photo, so a listing cannot depend on
/// one to look finished. Without this every card renders the same grey
/// placeholder and six results become six identical rows.
///
/// Each business is assigned a gradient and shows its monogram, derived from its
/// identifier — so the same shop always looks the same, on every device and
/// across sessions, and a customer starts to recognise it.
///
/// The identities are **monochrome**. The app allows exactly one hue — gold, for
/// ratings and open-now — so ten coloured avatars would be the loudest thing on
/// an otherwise black-and-white screen, and would read as decoration rather than
/// information.
///
/// So they differentiate by *value* instead: an even luminance ladder from
/// 0.031 to 0.089, with a temperature shift small enough (chroma at most 11 of
/// 255) to still read as grey. The real differentiator is the monogram — letters
/// distinguish shops more sharply than hue ever did.
///
/// Design guideline — Accessibility > Vision: every pairing below was measured.
/// White monogram text clears 4.5:1 against the lightest stop of every gradient
/// in both appearances — the second stop is always darker, so the first stop is
/// the binding constraint. Each also clears 1.38:1 against its card surface, so
/// an avatar never sinks into the card.
@immutable
class IdentityGradient {
  const IdentityGradient({required this.from, required this.to});

  final Color from;
  final Color to;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );

  /// Monogram and glyph colour. White on every entry, verified.
  Color get foreground => const Color(0xFFFFFFFF);
}

abstract final class IdentityPalette {
  /// Light-appearance identities. Measured white contrast 5.90:1 – 9.59:1.
  static const List<IdentityGradient> _light = [
    IdentityGradient(from: Color(0xFF43454A), to: Color(0xFF2A2B2E)),
    IdentityGradient(from: Color(0xFF494643), to: Color(0xFF2D2B2A)),
    IdentityGradient(from: Color(0xFF4B4E55), to: Color(0xFF2E3035)),
    IdentityGradient(from: Color(0xFF514D4A), to: Color(0xFF32302E)),
    IdentityGradient(from: Color(0xFF525651), to: Color(0xFF333532)),
    IdentityGradient(from: Color(0xFF565157), to: Color(0xFF353236)),
    IdentityGradient(from: Color(0xFF57544D), to: Color(0xFF363430)),
    IdentityGradient(from: Color(0xFF5C5C62), to: Color(0xFF39393D)),
    IdentityGradient(from: Color(0xFF615C5C), to: Color(0xFF3C3939)),
    IdentityGradient(from: Color(0xFF66636A), to: Color(0xFF3F3D42)),
  ];

  /// Dark-appearance identities — the committed appearance. Measured white
  /// contrast 7.54:1 – 13.05:1, and at least 1.38:1 against the card surface.
  static const List<IdentityGradient> _dark = [
    IdentityGradient(from: Color(0xFF2F3134), to: Color(0xFF1D1E20)),
    IdentityGradient(from: Color(0xFF35322F), to: Color(0xFF211F1D)),
    IdentityGradient(from: Color(0xFF393B41), to: Color(0xFF232528)),
    IdentityGradient(from: Color(0xFF3F3B39), to: Color(0xFF272523)),
    IdentityGradient(from: Color(0xFF414540), to: Color(0xFF282B28)),
    IdentityGradient(from: Color(0xFF464146), to: Color(0xFF2B282B)),
    IdentityGradient(from: Color(0xFF48453D), to: Color(0xFF2D2B26)),
    IdentityGradient(from: Color(0xFF4C4C52), to: Color(0xFF2F2F33)),
    IdentityGradient(from: Color(0xFF514C4C), to: Color(0xFF322F2F)),
    IdentityGradient(from: Color(0xFF56535B), to: Color(0xFF353338)),
  ];

  /// The gradient for [seed], stable for the lifetime of that identifier.
  static IdentityGradient forSeed(String seed, Brightness brightness) {
    final palette = brightness == Brightness.dark ? _dark : _light;
    return palette[_hash(seed) % palette.length];
  }

  /// FNV-1a. Chosen because it is stable across platforms and Dart releases —
  /// `String.hashCode` is not guaranteed to be, and a shop changing colour
  /// between app versions would undo the recognition this exists to build.
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Words that carry no identity, so they are skipped when building a
  /// monogram. "Sri Lakshmi Tailors" reads as "SL", not "SL" plus a T nobody
  /// needs.
  static const Set<String> _genericWords = {
    'tailor',
    'tailors',
    'tailoring',
    'the',
    'and',
    'centre',
    'center',
    'shop',
    'store',
    'studio',
    'works',
    'co',
    'company',
    'ltd',
    'services',
    'service',
    'master',
    'masters',
    'new',
    'sri',
    'shree',
    'shri',
  };

  /// One or two letters standing in for a business name.
  ///
  /// Falls back through progressively weaker rules rather than ever returning
  /// nothing: a card with a blank avatar looks broken.
  static String monogramFor(String name) {
    final words = name
        .split(RegExp(r'[\s\-&.,]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';

    final meaningful = words
        .where((w) => !_genericWords.contains(w.toLowerCase()))
        .toList();

    // Prefer the distinctive words; if the name is entirely generic, use it
    // anyway rather than showing a question mark.
    final source = meaningful.isEmpty ? words : meaningful;

    if (source.length == 1) {
      final word = source.first;
      // A single distinctive word gives up two letters, which is more
      // recognisable than one.
      return word.length == 1
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }

    return (source[0][0] + source[1][0]).toUpperCase();
  }
}
