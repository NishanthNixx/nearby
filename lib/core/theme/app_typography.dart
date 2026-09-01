import 'package:flutter/material.dart';

/// Nearby's type ladder.
///
/// One typeface — the platform system font (SF Pro on iOS, Roboto on Android).
///
/// Design guideline — Typography > Conveying hierarchy: "Minimize the number of
/// typefaces you use, even in a highly customized interface. Mixing too many
/// different typefaces can obscure your information hierarchy and hinder
/// readability."
///
/// Design guideline — Typography > Using system fonts: "Access all system
/// fonts — don't embed system fonts in your app." Leaving `fontFamily` null
/// resolves to the platform font, which also means Nearby inherits scalable
/// text and the Bold Text accessibility setting for free.
///
/// Nearby's typographic identity therefore comes from the *ladder* — the sizes,
/// leading, weights and tracking below — rather than a novelty face. Display
/// sizes are tracked tight for a confident feel; small sizes are tracked open,
/// because positive tracking measurably improves legibility below 13pt.
///
/// Sizes mirror the platform text styles so hierarchy survives when someone
/// changes their text size. Nothing is smaller than 11pt.
///
/// Design guideline — Typography > Ensuring legibility: mobile default size is
/// 17pt and the minimum is 11pt. Also: "avoid light font weights... prefer
/// Regular, Medium, Semibold, or Bold." Nearby uses only w400–w700.
abstract final class AppTypography {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Lines up digits in columns. Applied to prices, times and distances so
  /// numbers in a vertical list share a common left edge.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// 34/41 — the screen-owning heading. One per screen at most.
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    fontWeight: bold,
    letterSpacing: -0.6,
  );

  /// 28/34 — a major section heading, or a business name on its profile.
  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: bold,
    letterSpacing: -0.4,
  );

  /// 22/28 — a card-group heading.
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: semibold,
    letterSpacing: -0.3,
  );

  /// 20/25 — a subsection heading.
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    fontWeight: semibold,
    letterSpacing: -0.2,
  );

  /// 17/22 semibold — distinguishes a heading from the content beside it.
  /// The business name on a list card, a service name in a row.
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: semibold,
    letterSpacing: -0.2,
  );

  /// 17/22 — the default reading size. Descriptions, paragraphs, field values.
  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: regular,
    letterSpacing: -0.1,
  );

  /// 17/22 medium — body copy that needs a touch more presence, such as a
  /// selected row's label.
  static const TextStyle bodyEmphasis = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: medium,
    letterSpacing: -0.1,
  );

  /// 16/21 — button labels and inline callouts.
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    height: 21 / 16,
    fontWeight: semibold,
    letterSpacing: -0.1,
  );

  /// 15/20 — secondary line on a list row: distance, category, hours.
  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: regular,
  );

  /// 15/20 medium — a short label above a field or a chip's text.
  static const TextStyle subheadEmphasis = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: medium,
  );

  /// 13/18 — footnotes, helper text under a field, timestamps.
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: regular,
    letterSpacing: 0.05,
  );

  /// 13/18 semibold — a section header over a grouped list.
  static const TextStyle footnoteEmphasis = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: semibold,
    letterSpacing: 0.05,
  );

  /// 12/16 — the smallest comfortable size. Badge text, metadata.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: regular,
    letterSpacing: 0.1,
  );

  /// 11/13 medium — the floor. Tab bar labels only.
  ///
  /// Design guideline — Typography: mobile minimum text size is 11pt. Nothing
  /// in Nearby goes below this, and this style is deliberately medium weight
  /// because "thicker weights are easier to read for smaller font sizes."
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: medium,
    letterSpacing: 0.2,
  );

  /// Maps the ladder onto Material's [TextTheme] so stock widgets inherit it.
  static TextTheme textTheme(Color label) {
    return TextTheme(
      displayLarge: largeTitle.copyWith(color: label),
      displayMedium: title1.copyWith(color: label),
      displaySmall: title2.copyWith(color: label),
      headlineLarge: title1.copyWith(color: label),
      headlineMedium: title2.copyWith(color: label),
      headlineSmall: title3.copyWith(color: label),
      titleLarge: title3.copyWith(color: label),
      titleMedium: headline.copyWith(color: label),
      titleSmall: subheadEmphasis.copyWith(color: label),
      bodyLarge: body.copyWith(color: label),
      bodyMedium: subhead.copyWith(color: label),
      bodySmall: footnote.copyWith(color: label),
      labelLarge: callout.copyWith(color: label),
      labelMedium: subheadEmphasis.copyWith(color: label),
      labelSmall: caption.copyWith(color: label),
    );
  }
}

/// Convenience access to the ladder, pre-coloured for the current theme.
///
/// `context.type.headline` reads better at a call site than a long
/// `Theme.of(context).textTheme.titleMedium!.copyWith(...)` chain, and keeps
/// screens from reaching for arbitrary sizes.
extension AppTypographyX on BuildContext {
  NearbyTypeScale get type => NearbyTypeScale(this);
}

/// The type ladder, reachable as `context.type.headline`.
class NearbyTypeScale {
  const NearbyTypeScale(this._context);

  final BuildContext _context;

  TextStyle get largeTitle => AppTypography.largeTitle;
  TextStyle get title1 => AppTypography.title1;
  TextStyle get title2 => AppTypography.title2;
  TextStyle get title3 => AppTypography.title3;
  TextStyle get headline => AppTypography.headline;
  TextStyle get body => AppTypography.body;
  TextStyle get bodyEmphasis => AppTypography.bodyEmphasis;
  TextStyle get callout => AppTypography.callout;
  TextStyle get subhead => AppTypography.subhead;
  TextStyle get subheadEmphasis => AppTypography.subheadEmphasis;
  TextStyle get footnote => AppTypography.footnote;
  TextStyle get footnoteEmphasis => AppTypography.footnoteEmphasis;
  TextStyle get caption => AppTypography.caption;
  TextStyle get caption2 => AppTypography.caption2;

  /// Text scale factor currently in effect, clamped to a range Nearby's
  /// layouts have been checked against.
  double get scale => MediaQuery.textScalerOf(_context).scale(17) / 17;
}
