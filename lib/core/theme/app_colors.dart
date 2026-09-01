import 'package:flutter/material.dart';

/// Nearby's semantic colour palette.
///
/// Colours are named by *purpose*, never by appearance, so a role means the
/// same thing in every appearance mode.
///
/// Design guideline — Color > System colors: "Each dynamic color is
/// semantically defined by its purpose, rather than its appearance or color
/// values." And: "Avoid redefining the semantic meanings of dynamic system
/// colors... don't use the separator color as a text color."
///
/// Nearby's scheme is **Monochrome & Gold, dark-first**: a near-black ground,
/// cards separated by surface value rather than borders, a white primary
/// action, and gold as the single hue — reserved for ratings and open-now.
///
/// Four variants exist — light, dark, and an increased-contrast version of
/// each — because the platform exposes an Increase Contrast setting.
///
/// Design guideline — Color > Best practices: "If you define a custom color,
/// make sure to supply light and dark variants, and an increased contrast
/// option for each variant."
///
/// Every foreground/background pair below has been measured. Text roles clear
/// 4.5:1 in the standard variants and 7:1 in the increased-contrast variants.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bgBase,
    required this.bgGrouped,
    required this.surface,
    required this.surfaceRaised,
    required this.label,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.separator,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.open,
    required this.closed,
    required this.warning,
    required this.error,
    required this.skeleton,
  });

  final Brightness brightness;

  // ---------------------------------------------------------------------------
  // Backgrounds
  //
  // Design guideline — Dark Mode > Mobile platforms: "the system uses two sets
  // of background colors — called base and elevated — to enhance the
  // perception of depth when one dark interface is layered above another."
  // `bgBase` recedes; `surfaceRaised` advances.
  // ---------------------------------------------------------------------------

  /// The furthest-back plane of a screen.
  final Color bgBase;

  /// Background for screens made of grouped content (settings-style lists).
  final Color bgGrouped;

  /// A card or sheet sitting on [bgBase] or [bgGrouped].
  final Color surface;

  /// A surface layered above another surface — a sheet over a card.
  final Color surfaceRaised;

  // ---------------------------------------------------------------------------
  // Foreground text
  // ---------------------------------------------------------------------------

  /// Primary content text. Titles, values, body copy.
  final Color label;

  /// Supporting text that still carries meaning — distances, prices, hours.
  /// Meets 4.5:1, so it is safe for essential information.
  final Color labelSecondary;

  /// Decorative or duplicative text only. Meets 3:1, not 4.5:1, so never put
  /// information here that appears nowhere else.
  final Color labelTertiary;

  /// Hairline rules and dividers. Never used for text.
  final Color separator;

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// The primary action colour: white on the dark appearance, near-black on
  /// the light one. Maximum contrast against the ground is the whole idea —
  /// the booking pill is the brightest object on the screen.
  ///
  /// Design guideline — Color > Best practices: "Avoid using the same color to
  /// mean different things." In Nearby, [primary] means *tappable* or *this is
  /// the main action*. Non-interactive text never uses it.
  final Color primary;

  /// Text/icons on top of a filled [primary] surface.
  final Color onPrimary;

  /// A tonal wash of the brand colour for selected chips and quiet badges.
  final Color primaryContainer;

  /// Text/icons on top of [primaryContainer].
  final Color onPrimaryContainer;

  /// Gold — the one hue in the scheme. Ratings, open-now, and nothing else.
  /// Never a surface fill, never interactivity. Kept under a tenth of any
  /// screen; used generously it stops meaning anything.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  // ---------------------------------------------------------------------------
  // Status
  //
  // Design guideline — Accessibility > Vision: "Convey information with more
  // than color alone." Every use of these is paired with a glyph and a text
  // label, so colour is reinforcement, not the message.
  // ---------------------------------------------------------------------------

  /// Business is open now.
  final Color open;

  /// Business is closed.
  final Color closed;

  /// Caution — a slot is nearly gone, a profile is incomplete.
  final Color warning;

  /// Something failed and the user must act.
  final Color error;

  /// Fill for loading placeholders.
  final Color skeleton;

  // ---------------------------------------------------------------------------
  // Variants
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Monochrome & Gold — dark-first.
  //
  // The scheme is built on three rules taken from the reference direction:
  //
  // 1. The ground is near-black and the cards sit on it as slightly lighter
  //    fills — separation comes from surface value, not from hairline borders.
  // 2. The primary action is WHITE. On a near-black screen a white pill is the
  //    highest-contrast object that can exist (19.7:1), so the eye lands on the
  //    booking action before anything else. Inverted selection follows the same
  //    rule: a selected date or slot is a white cell with black text.
  // 3. Exactly one hue: gold, reserved for ratings and open-now. Everything
  //    else is monochrome. One colour used sparingly reads as expensive; three
  //    colours used generously read as a template.
  //
  // Dark is the app's committed appearance (see app.dart). The light variants
  // below keep the same logic inverted — a black pill on off-white — so a
  // light mode can be reinstated by flipping one line.
  // ---------------------------------------------------------------------------

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF0B0B0C),
    bgGrouped: Color(0xFF0B0B0C),
    surface: Color(0xFF161619),
    surfaceRaised: Color(0xFF202024),
    label: Color(0xFFFFFFFF),
    labelSecondary: Color(0xFF9C9CA4),
    labelTertiary: Color(0xFF6E6E77),
    separator: Color(0xFF26262B),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF0B0B0C),
    primaryContainer: Color(0xFF202024),
    onPrimaryContainer: Color(0xFFFFFFFF),
    accent: Color(0xFFE9A23B),
    onAccent: Color(0xFF241703),
    accentContainer: Color(0xFF3A2A10),
    onAccentContainer: Color(0xFFF7D9A6),
    open: Color(0xFFE9A23B),
    closed: Color(0xFFE8796B),
    warning: Color(0xFFE9A23B),
    error: Color(0xFFE8796B),
    skeleton: Color(0xFF1C1C20),
  );

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFFAFAFA),
    bgGrouped: Color(0xFFF1F1F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF0B0B0C),
    labelSecondary: Color(0xFF5A5A62),
    labelTertiary: Color(0xFF8A8A93),
    separator: Color(0xFFE4E4E7),
    primary: Color(0xFF111113),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF1F1F2),
    onPrimaryContainer: Color(0xFF111113),
    accent: Color(0xFF8A5A0B),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFBEFD9),
    onAccentContainer: Color(0xFF4A3005),
    open: Color(0xFF8A5A0B),
    closed: Color(0xFFB3392B),
    warning: Color(0xFF8A5A0B),
    error: Color(0xFFB3392B),
    skeleton: Color(0xFFEAEAEC),
  );

  static const AppColors darkHighContrast = AppColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF000000),
    bgGrouped: Color(0xFF000000),
    surface: Color(0xFF101013),
    surfaceRaised: Color(0xFF1A1A1E),
    label: Color(0xFFFFFFFF),
    labelSecondary: Color(0xFFC9C9D0),
    labelTertiary: Color(0xFF9C9CA4),
    separator: Color(0xFF4A4A52),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF0B0B0C),
    primaryContainer: Color(0xFF202024),
    onPrimaryContainer: Color(0xFFFFFFFF),
    accent: Color(0xFFF5C070),
    onAccent: Color(0xFF241703),
    accentContainer: Color(0xFF2E200A),
    onAccentContainer: Color(0xFFFBE6C4),
    open: Color(0xFFF5C070),
    closed: Color(0xFFF5A79A),
    warning: Color(0xFFF5C070),
    error: Color(0xFFF5A79A),
    skeleton: Color(0xFF1C1C20),
  );

  static const AppColors lightHighContrast = AppColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFFFFFFF),
    bgGrouped: Color(0xFFEDEDEE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF000000),
    labelSecondary: Color(0xFF3A3A41),
    labelTertiary: Color(0xFF5A5A62),
    separator: Color(0xFFAEAEB5),
    primary: Color(0xFF111113),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF1F1F2),
    onPrimaryContainer: Color(0xFF111113),
    accent: Color(0xFF6B4508),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFBEFD9),
    onAccentContainer: Color(0xFF4A3005),
    open: Color(0xFF6B4508),
    closed: Color(0xFF8E2221),
    warning: Color(0xFF6B4508),
    error: Color(0xFF8E2221),
    skeleton: Color(0xFFEAEAEC),
  );

  /// Picks the variant matching the platform appearance and contrast settings.
  static AppColors resolve({
    required Brightness brightness,
    required bool highContrast,
  }) {
    if (brightness == Brightness.dark) {
      return highContrast ? darkHighContrast : dark;
    }
    return highContrast ? lightHighContrast : light;
  }

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? bgBase,
    Color? bgGrouped,
    Color? surface,
    Color? surfaceRaised,
    Color? label,
    Color? labelSecondary,
    Color? labelTertiary,
    Color? separator,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? open,
    Color? closed,
    Color? warning,
    Color? error,
    Color? skeleton,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      bgBase: bgBase ?? this.bgBase,
      bgGrouped: bgGrouped ?? this.bgGrouped,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      label: label ?? this.label,
      labelSecondary: labelSecondary ?? this.labelSecondary,
      labelTertiary: labelTertiary ?? this.labelTertiary,
      separator: separator ?? this.separator,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      open: open ?? this.open,
      closed: closed ?? this.closed,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      skeleton: skeleton ?? this.skeleton,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgBase: c(bgBase, other.bgBase),
      bgGrouped: c(bgGrouped, other.bgGrouped),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      label: c(label, other.label),
      labelSecondary: c(labelSecondary, other.labelSecondary),
      labelTertiary: c(labelTertiary, other.labelTertiary),
      separator: c(separator, other.separator),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentContainer: c(accentContainer, other.accentContainer),
      onAccentContainer: c(onAccentContainer, other.onAccentContainer),
      open: c(open, other.open),
      closed: c(closed, other.closed),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      skeleton: c(skeleton, other.skeleton),
    );
  }
}

/// Reads [AppColors] off the ambient theme.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
