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
/// Nearby's scheme is **Spectrum, dark-first**: a near-black ground, cards
/// separated by surface value rather than borders, and the two halves of the
/// app icon carrying two different jobs — a cool cyan for anything tappable,
/// a warm orange for anything merely informative.
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

  /// The primary action colour: the icon's cyan. On the near-black ground a
  /// saturated cyan pill carrying near-black text is the brightest, most
  /// chromatic object on the screen (9.89:1 against the ground), so the eye
  /// still lands on the booking action first — the job white used to do.
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

  /// The icon's warm orange. Ratings, open-now, and prices — information the
  /// eye should find fast. Never interactivity: warm is the one thing in this
  /// app that is never tappable, which is what keeps [primary] unambiguous.
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
  // Spectrum — dark-first.
  //
  // The palette is taken from the app icon, which splits into a cool half (the
  // cyan-to-indigo stem) and a warm half (the magenta-to-orange arch and dot).
  // That split is the whole system:
  //
  // 1. The ground stays near-black and cards sit on it as slightly lighter
  //    fills — separation comes from surface value, not from hairline borders.
  //    Colour is spent on meaning, never on structure.
  // 2. COOL MEANS TAPPABLE. The primary action is a saturated cyan pill with
  //    near-black text. Selected chips, focus rings and links are cool too.
  //    Nothing that cannot be tapped is ever cyan.
  // 3. WARM MEANS INFORMATIVE. Ratings, open-now and price emphasis are
  //    orange. Warm is never interactive. Because the two families sit at
  //    opposite ends of the spectrum, a glance is enough to tell an action
  //    from a fact — which is the same discipline the previous monochrome
  //    scheme enforced with value, now enforced with hue.
  //
  // The full spectrum appears only where identity is the point: the brand mark
  // and business avatars (see AppGradients and IdentityPalette). Elsewhere a
  // screen shows at most one cool and one warm accent, so the app reads as
  // vivid rather than busy.
  //
  // Dark is the app's committed appearance (see app.dart). The light variants
  // deepen both hues to hold contrast on white; the roles do not move.
  // ---------------------------------------------------------------------------

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF09090E),
    bgGrouped: Color(0xFF09090E),
    surface: Color(0xFF14141C),
    surfaceRaised: Color(0xFF1E1E28),
    label: Color(0xFFFFFFFF),
    labelSecondary: Color(0xFF9C9CB0),
    labelTertiary: Color(0xFF6C6C80),
    separator: Color(0xFF25252F),
    primary: Color(0xFF3FC5F0),
    onPrimary: Color(0xFF03202B),
    primaryContainer: Color(0xFF0B2E3C),
    onPrimaryContainer: Color(0xFFA9E4F7),
    accent: Color(0xFFFF9440),
    onAccent: Color(0xFF2A1204),
    accentContainer: Color(0xFF3A2110),
    onAccentContainer: Color(0xFFFFD0A6),
    open: Color(0xFFFF9440),
    closed: Color(0xFF8A8A9E),
    warning: Color(0xFFFFB443),
    error: Color(0xFFFF6B7A),
    skeleton: Color(0xFF1A1A22),
  );

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFFAFAFC),
    bgGrouped: Color(0xFFF1F1F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF0A0A12),
    labelSecondary: Color(0xFF55556A),
    labelTertiary: Color(0xFF84849A),
    separator: Color(0xFFE3E3EA),
    primary: Color(0xFF0B6E96),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE0F4FC),
    onPrimaryContainer: Color(0xFF06394D),
    accent: Color(0xFFA64B08),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFDECDC),
    onAccentContainer: Color(0xFF5A2905),
    open: Color(0xFFA64B08),
    closed: Color(0xFF6B6B80),
    warning: Color(0xFF8A5A0B),
    error: Color(0xFFC0243C),
    skeleton: Color(0xFFEAEAEF),
  );

  static const AppColors darkHighContrast = AppColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF000000),
    bgGrouped: Color(0xFF000000),
    surface: Color(0xFF0E0E14),
    surfaceRaised: Color(0xFF18181F),
    label: Color(0xFFFFFFFF),
    labelSecondary: Color(0xFFCCCCD8),
    labelTertiary: Color(0xFF9C9CB0),
    separator: Color(0xFF4A4A57),
    primary: Color(0xFF7FDBFF),
    onPrimary: Color(0xFF03202B),
    primaryContainer: Color(0xFF0B2E3C),
    onPrimaryContainer: Color(0xFFD3F1FD),
    accent: Color(0xFFFFB877),
    onAccent: Color(0xFF2A1204),
    accentContainer: Color(0xFF331C0C),
    onAccentContainer: Color(0xFFFFE2C8),
    open: Color(0xFFFFB877),
    closed: Color(0xFFB0B0C2),
    warning: Color(0xFFFFCC7A),
    error: Color(0xFFFF97A3),
    skeleton: Color(0xFF1A1A22),
  );

  static const AppColors lightHighContrast = AppColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFFFFFFF),
    bgGrouped: Color(0xFFEDEDF2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF000000),
    labelSecondary: Color(0xFF38384A),
    labelTertiary: Color(0xFF55556A),
    separator: Color(0xFFACACB8),
    primary: Color(0xFF08536F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDF1FA),
    onPrimaryContainer: Color(0xFF042C3B),
    accent: Color(0xFF7A3706),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFBE7D5),
    onAccentContainer: Color(0xFF441F04),
    open: Color(0xFF7A3706),
    closed: Color(0xFF55556A),
    warning: Color(0xFF6B4508),
    error: Color(0xFF8E1229),
    skeleton: Color(0xFFEAEAEF),
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
