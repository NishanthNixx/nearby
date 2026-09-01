/// Spacing, radius and sizing tokens for Nearby.
///
/// Built on a 4pt grid. Every gap, inset and radius in the app comes from here
/// so rhythm stays consistent across screens.
///
/// Design guideline — Layout > Best practices: "Group related items to help
/// people find the information they want... use negative space, background
/// shapes, colors, materials, or separator lines to show when elements are
/// related."
abstract final class AppSpacing {
  /// 2pt — hairline nudges only.
  static const double xxs = 2;

  /// 4pt — the grid unit. Icon-to-label in a dense chip.
  static const double xs = 4;

  /// 8pt — tight grouping inside a single component.
  static const double sm = 8;

  /// 12pt — padding around bezelled controls.
  ///
  /// Design guideline — Accessibility > Mobility: "it works well to add about
  /// 12 points of padding around elements that include a bezel."
  static const double md = 12;

  /// 16pt — the default. Screen margin, card padding, list row gap.
  static const double lg = 16;

  /// 20pt — separation between subsections.
  static const double xl = 20;

  /// 24pt — padding around unbezelled elements; gap between major blocks.
  ///
  /// Design guideline — Accessibility > Mobility: "For elements without a
  /// bezel, about 24 points of padding works well around the element's
  /// visible edges."
  static const double xxl = 24;

  /// 32pt — section break.
  static const double xxxl = 32;

  /// 40pt — above a screen's primary heading.
  static const double huge = 40;

  /// Standard horizontal screen margin.
  ///
  /// Design guideline — Layout > Mobile: "Buttons feel at home on mobile when
  /// they respect system-defined margins and are inset from the edges of the
  /// screen."
  static const double screenMargin = lg;
}

/// Corner radius tokens. Larger surfaces get larger radii so nested shapes
/// stay visually concentric.
///
/// The geometry is deliberately generous: big card radii and fully-round
/// buttons are half of what makes the dark surfaces read as considered rather
/// than utilitarian.
abstract final class AppRadius {
  /// 8pt — badges, tiny overlays on imagery.
  static const double xs = 8;

  /// 12pt — text fields, small tiles.
  static const double sm = 12;

  /// 16pt — medium tiles, date and slot cells.
  static const double md = 16;

  /// 24pt — cards.
  static const double lg = 24;

  /// 32pt — sheets, hero imagery, the raised CTA tray.
  static const double xl = 32;

  /// Fully rounded. Buttons and chips are pills, always.
  static const double pill = 999;
}

/// Sizing tokens with accessibility floors baked in.
abstract final class AppSizing {
  /// Minimum tappable edge.
  ///
  /// Design guideline — Accessibility > Mobility: mobile default control size
  /// is 44x44pt. Nothing interactive in Nearby goes below this.
  static const double minTouchTarget = 44;

  /// Height of the primary call-to-action button. Tall, because the white
  /// pill is the anchor of every screen it appears on.
  static const double primaryButtonHeight = 56;

  /// Height of a secondary/tertiary button.
  static const double secondaryButtonHeight = 48;

  /// Height of the search field on the discovery screen.
  static const double searchFieldHeight = 48;

  /// Hairline separator thickness. Kept at a real device pixel where possible.
  static const double separator = 1;

  /// Avatar / business thumbnail on a list card.
  static const double thumbnail = 64;

  /// Large avatar on a profile header.
  static const double avatarLarge = 88;

  /// Height of the media header on a business profile.
  static const double profileHeaderHeight = 220;

  /// Icon sizes.
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
}

/// Motion tokens.
///
/// Design guideline — Motion > Best practices: "Add motion purposefully,
/// supporting the experience without overshadowing it. Don't add motion for
/// the sake of adding motion." Durations here are deliberately short.
abstract final class AppMotion {
  /// 120ms — state change on a control the user just touched.
  static const Duration fast = Duration(milliseconds: 120);

  /// 220ms — the default. Cross-fades, expansion, route content.
  static const Duration normal = Duration(milliseconds: 220);

  /// 320ms — larger surfaces entering, e.g. a sheet.
  static const Duration slow = Duration(milliseconds: 320);
}
