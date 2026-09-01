import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/theme/app_colors.dart';
import 'package:nearby/core/theme/identity_palette.dart';

/// The generated-identity palette carries a contrast guarantee, so that
/// guarantee is asserted here rather than left as a claim in a comment. If
/// someone adds a gradient that is too light for a white monogram, this fails.
void main() {
  /// WCAG relative luminance.
  double luminance(Color color) {
    double channel(double component) => component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Distance between the strongest and weakest channel, 0–255. Zero is pure
  /// grey; a saturated hue runs well over 100.
  int chroma(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return [r, g, b].reduce((a, x) => a > x ? a : x) -
        [r, g, b].reduce((a, x) => a < x ? a : x);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  group('identity gradients', () {
    for (final brightness in Brightness.values) {
      test(
        'a white monogram is legible on every ${brightness.name} gradient',
        () {
          // Probing by seed is how the app actually reaches these, and it also
          // confirms every entry in the list is reachable.
          final seen = <IdentityGradient>{};

          for (var i = 0; i < 400; i++) {
            final identity = IdentityPalette.forSeed('seed-$i', brightness);
            seen.add(identity);

            for (final stop in [identity.from, identity.to]) {
              expect(
                contrast(identity.foreground, stop),
                greaterThanOrEqualTo(4.5),
                reason:
                    'monogram on ${brightness.name} gradient stop '
                    '#${stop.toARGB32().toRadixString(16)} is below 4.5:1',
              );
            }
          }

          // Ten curated hues; if selection collapsed onto a few the list would
          // stop doing its job.
          expect(seen.length, 10);
        },
      );

      test(
        'every ${brightness.name} gradient separates from its card surface',
        () {
          final surface = brightness == Brightness.dark
              ? AppColors.dark.surface
              : AppColors.light.surface;

          for (var i = 0; i < 200; i++) {
            final identity = IdentityPalette.forSeed('seed-$i', brightness);
            expect(
              contrast(identity.from, surface),
              greaterThanOrEqualTo(1.35),
              reason: 'an avatar that blends into the card is invisible',
            );
          }
        },
      );

      test('the second stop is darker, in ${brightness.name}', () {
        // The invariant the contrast guarantee rests on: the first stop is the
        // lightest pixel, so checking it is sufficient.
        for (var i = 0; i < 200; i++) {
          final identity = IdentityPalette.forSeed('seed-$i', brightness);
          expect(luminance(identity.to), lessThan(luminance(identity.from)));
        }
      });
    }

    test('the same business always gets the same colour', () {
      // The whole point is recognition, so this has to be stable — including
      // across app versions, which is why the hash is FNV-1a rather than
      // String.hashCode.
      for (final seed in ['biz_1', 'business-abcdef', 'x']) {
        final first = IdentityPalette.forSeed(seed, Brightness.light);
        for (var i = 0; i < 5; i++) {
          expect(IdentityPalette.forSeed(seed, Brightness.light), first);
        }
      }
    });

    test('different businesses get visibly different identities', () {
      final seeds = [for (var i = 0; i < 10; i++) 'biz_$i'];
      final gradients = seeds
          .map((s) => IdentityPalette.forSeed(s, Brightness.light))
          .toSet();

      // Collisions are expected with ten entries and ten seeds, but they should
      // not all land on one.
      expect(gradients.length, greaterThan(3));
    });

    for (final brightness in Brightness.values) {
      test('every ${brightness.name} identity is neutral, not coloured', () {
        // The app permits exactly one hue — gold, for ratings and open-now. Ten
        // coloured avatars would be the loudest thing on a black-and-white
        // screen. Identities differentiate by value; this is the guard that
        // stops a hue creeping back in.
        for (var i = 0; i < 200; i++) {
          final identity = IdentityPalette.forSeed('seed-$i', brightness);
          for (final stop in [identity.from, identity.to]) {
            expect(
              chroma(stop),
              lessThanOrEqualTo(12),
              reason:
                  'identity stop #${stop.toARGB32().toRadixString(16)} has '
                  'chroma ${chroma(stop)} — that reads as a colour, not a grey',
            );
          }
        }
      });

      test('${brightness.name} identities span a usable value range', () {
        // Value is the only thing distinguishing them now, so the ladder has to
        // actually spread rather than clustering on one tone.
        final luminances =
            [for (var i = 0; i < 10; i++) 'seed-$i']
                .map((s) => IdentityPalette.forSeed(s, brightness))
                .map((g) => luminance(g.from))
                .toSet()
                .toList()
              ..sort();

        expect(luminances.length, greaterThan(3));
        expect(
          luminances.last - luminances.first,
          greaterThan(0.02),
          reason: 'identities that share a value are indistinguishable',
        );
      });
    }
  });

  group('monograms', () {
    test('skips generic business words', () {
      // "Sri" and "Tailors" carry no identity; "Lakshmi" does.
      expect(IdentityPalette.monogramFor('Sri Lakshmi Tailors'), 'LA');
      expect(IdentityPalette.monogramFor('Ashraf Master Tailors'), 'AS');
      expect(IdentityPalette.monogramFor('Bismillah Tailors'), 'BI');
    });

    test('uses two distinctive words when there are two', () {
      expect(IdentityPalette.monogramFor('Vasantha Ladies Tailoring'), 'VL');
      expect(IdentityPalette.monogramFor('Anand Alterations'), 'AA');
      expect(IdentityPalette.monogramFor('New Style Stitching Centre'), 'SS');
    });

    test('falls back to the raw name when every word is generic', () {
      // Better a real initial than a question mark.
      expect(IdentityPalette.monogramFor('The Tailor Shop'), 'TT');
      expect(IdentityPalette.monogramFor('Tailors'), 'TA');
    });

    test('handles punctuation and extra whitespace', () {
      expect(IdentityPalette.monogramFor('  Raj  &  Sons  '), 'RS');
      expect(IdentityPalette.monogramFor('Kumar-Bhai Tailors'), 'KB');
      expect(IdentityPalette.monogramFor('A.B. Stitching'), 'AB');
    });

    test('never returns empty, whatever the input', () {
      for (final name in ['', '   ', '&&&', '-', '.']) {
        final monogram = IdentityPalette.monogramFor(name);
        expect(
          monogram,
          isNotEmpty,
          reason: 'a blank avatar reads as a broken card',
        );
      }
    });

    test('is always upper case and at most two characters', () {
      for (final name in [
        'sri lakshmi tailors',
        'a',
        'Very Long Business Name With Many Words',
        'Zenith',
      ]) {
        final monogram = IdentityPalette.monogramFor(name);
        expect(monogram.length, lessThanOrEqualTo(2));
        expect(monogram, monogram.toUpperCase());
      }
    });
  });
}
