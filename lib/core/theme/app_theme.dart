import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] from Nearby's tokens.
///
/// Everything visual is derived from [AppColors], [AppTypography] and
/// [AppSpacing]. Component themes are configured here so stock Material
/// widgets already look like Nearby — screens rarely need to restyle a widget
/// inline, which is what keeps the app from drifting back toward a default
/// Flutter look.
abstract final class AppTheme {
  /// [overrideColors] swaps the whole palette, for side-by-side comparisons and
  /// design review. Production callers leave it null.
  static ThemeData light({
    bool highContrast = false,
    AppColors? overrideColors,
  }) => _build(
    overrideColors ??
        AppColors.resolve(
          brightness: Brightness.light,
          highContrast: highContrast,
        ),
  );

  static ThemeData dark({
    bool highContrast = false,
    AppColors? overrideColors,
  }) => _build(
    overrideColors ??
        AppColors.resolve(
          brightness: Brightness.dark,
          highContrast: highContrast,
        ),
  );

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentContainer,
      onSecondaryContainer: c.onAccentContainer,
      tertiary: c.primary,
      onTertiary: c.onPrimary,
      error: c.error,
      onError: c.brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF3A0906),
      surface: c.surface,
      onSurface: c.label,
      onSurfaceVariant: c.labelSecondary,
      outline: c.separator,
      outlineVariant: c.separator,
      // The M3 surface tint blends the primary colour into elevated surfaces.
      // Nearby expresses elevation with a hairline border instead, so the tint
      // is neutralised to keep cards a true neutral.
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.textTheme(c.label);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkSparkle.splashFactory,

      // -----------------------------------------------------------------------
      // Bars
      //
      // Design guideline — Layout > Visual hierarchy: "Differentiate controls
      // from content. Instead of a background, use a scroll edge effect to
      // provide a transition between content and the control area."
      // scrolledUnderElevation draws that transition only once content passes
      // beneath the bar.
      // -----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.label,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: c.separator,
        centerTitle: false,
        titleSpacing: AppSpacing.screenMargin,
        titleTextStyle: AppTypography.headline.copyWith(color: c.label),
        iconTheme: IconThemeData(color: c.label, size: AppSizing.iconLg),
        actionsIconTheme: IconThemeData(
          color: c.primary,
          size: AppSizing.iconLg,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bgBase,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption2.copyWith(
            color: selected ? c.primary : c.labelSecondary,
            fontWeight: selected
                ? AppTypography.semibold
                : AppTypography.medium,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizing.iconLg,
            color: selected ? c.onPrimaryContainer : c.labelSecondary,
          );
        }),
      ),

      // -----------------------------------------------------------------------
      // Cards
      //
      // On the dark appearance a card is a slightly lighter fill on the
      // near-black ground and carries NO border — surface value does the
      // separating, which is what keeps the screen looking like panels of
      // material rather than outlined boxes. Light keeps a hairline, because
      // white-on-off-white has no value separation to lean on.
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: c.brightness == Brightness.dark
              ? BorderSide.none
              : BorderSide(color: c.separator, width: AppSizing.separator),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: DividerThemeData(
        color: c.separator,
        thickness: AppSizing.separator,
        space: AppSizing.separator,
      ),

      // -----------------------------------------------------------------------
      // Buttons
      //
      // Design guideline — Accessibility > Mobility: mobile default control
      // size is 44x44pt. Every button below has a minimum height at or above
      // that floor.
      // -----------------------------------------------------------------------
      // The primary action is a full pill in the ground's opposite value —
      // white on the dark appearance. Nothing else on screen competes with it.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceRaised,
          disabledForegroundColor: c.labelTertiary,
          minimumSize: const Size(64, AppSizing.primaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          textStyle: AppTypography.callout,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.label,
          disabledForegroundColor: c.labelTertiary,
          minimumSize: const Size(64, AppSizing.secondaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: AppTypography.callout,
          side: BorderSide(color: c.separator, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),

      // A text button has no fill and no border, so colour is its only
      // affordance — it takes [primary] rather than [label]. Outlined buttons
      // keep the neutral label colour, because their border already says
      // "control" without spending the interactive hue on them.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          disabledForegroundColor: c.labelTertiary,
          minimumSize: const Size(
            AppSizing.minTouchTarget,
            AppSizing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: AppTypography.callout,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.label,
          minimumSize: const Size(
            AppSizing.minTouchTarget,
            AppSizing.minTouchTarget,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Inputs
      //
      // Design guideline — Entering data > Best practices: "Be clear about the
      // data you need... display a prompt in a text field."
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.brightness == Brightness.light ? c.bgGrouped : c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg - 2,
        ),
        hintStyle: AppTypography.body.copyWith(color: c.labelTertiary),
        labelStyle: AppTypography.subhead.copyWith(color: c.labelSecondary),
        floatingLabelStyle: AppTypography.footnoteEmphasis.copyWith(
          color: c.primary,
        ),
        helperStyle: AppTypography.footnote.copyWith(color: c.labelSecondary),
        errorStyle: AppTypography.footnote.copyWith(color: c.error),
        prefixIconColor: c.labelSecondary,
        suffixIconColor: c.labelSecondary,
        // A field is a filled panel like every other surface. The border only
        // materialises on focus — a quiet resting state, an unmistakable
        // active one.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: c.brightness == Brightness.dark
              ? BorderSide.none
              : BorderSide(color: c.separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.label, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.error, width: 2),
        ),
      ),

      // -----------------------------------------------------------------------
      // Chips, sheets, dialogs
      // -----------------------------------------------------------------------
      // Stock chips follow the inversion rule too, so anything built with a
      // plain Chip/FilterChip cannot drift away from the hand-rolled ones.
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.surfaceRaised,
        labelStyle: AppTypography.subheadEmphasis.copyWith(color: c.label),
        secondaryLabelStyle: AppTypography.subheadEmphasis.copyWith(
          color: c.onPrimary,
        ),
        side: c.brightness == Brightness.dark
            ? BorderSide.none
            : BorderSide(color: c.separator),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),

      // Design guideline — Modality > Best practices: "Always give people an
      // obvious way to dismiss a modal view... in mobile platforms, people
      // typically expect to find a button in the top toolbar or swipe down."
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surfaceRaised,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.separator,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.title3.copyWith(color: c.label),
        contentTextStyle: AppTypography.body.copyWith(color: c.labelSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.brightness == Brightness.light
            ? c.label
            : c.surfaceRaised,
        contentTextStyle: AppTypography.subhead.copyWith(
          color: c.brightness == Brightness.light ? c.bgBase : c.label,
        ),
        actionTextColor: c.brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : c.label,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.labelSecondary,
        textColor: c.label,
        titleTextStyle: AppTypography.body.copyWith(color: c.label),
        subtitleTextStyle: AppTypography.subhead.copyWith(
          color: c.labelSecondary,
        ),
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.separator,
        circularTrackColor: Colors.transparent,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.labelSecondary,
        labelStyle: AppTypography.subheadEmphasis,
        unselectedLabelStyle: AppTypography.subhead,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: c.separator,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.primary, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.separator,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surfaceRaised,
        dialBackgroundColor: c.bgGrouped,
        hourMinuteTextStyle: AppTypography.title1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.primary,
        headerForegroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}
