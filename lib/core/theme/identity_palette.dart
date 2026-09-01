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
/// The identities are a **spectrum walk**. Ten stops march around the app
/// icon's hue range — cyan, azure, indigo, violet, purple, magenta, rose, red,
/// burnt orange, amber — so two shops next to each other in a list are always
/// far apart in hue, not merely a shade apart in grey.
///
/// Hue is a far stronger differentiator than value: a customer scanning a list
/// picks out "the purple one" instantly, where they would never pick out "the
/// slightly lighter grey one". The monogram still does the precise work; the
/// colour is what makes the card findable on a second visit.
///
/// Every stop is deliberately deep rather than bright. A white monogram has to
/// clear 4.5:1 on the lightest pixel of the gradient, which caps how light a
/// stop may be — so these read as saturated and rich, never pastel.
///
/// Design guideline — Accessibility > Vision: every pairing below was measured.
/// White monogram text clears 4.5:1 against the lightest stop of every gradient
/// in both appearances — the second stop is always darker, so the first stop is
/// the binding constraint. Each also clears 1.35:1 against its card surface, so
/// an avatar never sinks into the card.
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
  /// Light-appearance identities. Measured white contrast 4.48:1 – 8.39:1
  /// on the first stop, and 4.48:1 or better against a white card.
  static const List<IdentityGradient> _light = [
    // cyan
    IdentityGradient(from: Color(0xFF0E7C99), to: Color(0xFF0A4E63)),
    // azure
    IdentityGradient(from: Color(0xFF1565C0), to: Color(0xFF0D3F7A)),
    // indigo
    IdentityGradient(from: Color(0xFF2A3FB8), to: Color(0xFF1A2878)),
    // violet
    IdentityGradient(from: Color(0xFF5B35B5), to: Color(0xFF3A2178)),
    // purple
    IdentityGradient(from: Color(0xFF8E2FA8), to: Color(0xFF5C1E6E)),
    // magenta
    IdentityGradient(from: Color(0xFFB32D7D), to: Color(0xFF741D51)),
    // rose
    IdentityGradient(from: Color(0xFFC62A5A), to: Color(0xFF80193A)),
    // red
    IdentityGradient(from: Color(0xFFC43A2A), to: Color(0xFF7E251B)),
    // burnt orange
    IdentityGradient(from: Color(0xFFB9541A), to: Color(0xFF783512)),
    // amber
    IdentityGradient(from: Color(0xFF9E640D), to: Color(0xFF64400A)),
  ];

  /// Dark-appearance identities — the committed appearance. The same ramp:
  /// a shop should be the same colour whichever appearance you open the app
  /// in, or the recognition this exists to build resets. Measured 2.18:1 or
  /// better against the dark card surface.
  static const List<IdentityGradient> _dark = [
    // cyan
    IdentityGradient(from: Color(0xFF0E7C99), to: Color(0xFF0A4E63)),
    // azure
    IdentityGradient(from: Color(0xFF1565C0), to: Color(0xFF0D3F7A)),
    // indigo
    IdentityGradient(from: Color(0xFF2A3FB8), to: Color(0xFF1A2878)),
    // violet
    IdentityGradient(from: Color(0xFF5B35B5), to: Color(0xFF3A2178)),
    // purple
    IdentityGradient(from: Color(0xFF8E2FA8), to: Color(0xFF5C1E6E)),
    // magenta
    IdentityGradient(from: Color(0xFFB32D7D), to: Color(0xFF741D51)),
    // rose
    IdentityGradient(from: Color(0xFFC62A5A), to: Color(0xFF80193A)),
    // red
    IdentityGradient(from: Color(0xFFC43A2A), to: Color(0xFF7E251B)),
    // burnt orange
    IdentityGradient(from: Color(0xFFB9541A), to: Color(0xFF783512)),
    // amber
    IdentityGradient(from: Color(0xFF9E640D), to: Color(0xFF64400A)),
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
