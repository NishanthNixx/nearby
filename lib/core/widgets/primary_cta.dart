import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The pinned action bar at the bottom of a screen with one clear next step.
///
/// Design guideline — Layout > Mobile: "Avoid full-width buttons. Buttons feel
/// at home on mobile when they respect system-defined margins and are inset
/// from the edges of the screen."
///
/// So the button is inset by the standard screen margin rather than running
/// edge to edge, and the bar sits above the device's safe area.
///
/// Design guideline — Layout > Visual hierarchy: "Differentiate controls from
/// content." The bar carries a hairline top rule and the surface colour, so it
/// reads as a control layer over the scrolling content beneath it.
class PrimaryCtaBar extends StatelessWidget {
  const PrimaryCtaBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.supportingText,
    this.trailingText,
    this.isBusy = false,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.icon,
  });

  final String label;

  /// Null disables the button. Combined with [supportingText] this is how a
  /// screen explains *why* the action is not yet available.
  final VoidCallback? onPressed;

  /// A line above the button — the selected slot, or what is still missing.
  final String? supportingText;

  /// A value shown opposite the supporting text, typically the price.
  final String? trailingText;

  /// Swaps the label for a spinner and blocks repeat taps.
  final bool isBusy;

  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      // A raised tray rather than a full-width bar: rounded top corners and a
      // lighter surface lift it off the ground, the way the reference floats
      // its booking summary. No border — surface value does the separating.
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: colors.brightness == Brightness.dark
            ? null
            : Border(
                top: BorderSide(
                  color: colors.separator,
                  width: AppSizing.separator,
                ),
              ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (supportingText != null || trailingText != null) ...[
                Row(
                  children: [
                    if (supportingText != null)
                      Expanded(
                        child: Text(
                          supportingText!,
                          style: context.type.footnote.copyWith(
                            color: colors.labelSecondary,
                          ),
                        ),
                      ),
                    if (trailingText != null)
                      Text(
                        trailingText!,
                        style: context.type.headline.copyWith(
                          color: colors.label,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  if (secondaryLabel != null && onSecondaryPressed != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy ? null : onSecondaryPressed,
                        child: Text(secondaryLabel!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    // The primary action always takes the larger share, so
                    // which one is primary is never ambiguous.
                    flex: secondaryLabel == null ? 1 : 2,
                    child: SizedBox(
                      height: AppSizing.primaryButtonHeight,
                      child: ActionPill(
                        enabled: !isBusy && onPressed != null,
                        child: FilledButton(
                        style: actionButtonStyle,
                        onPressed: isBusy ? null : onPressed,
                        child: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppGradients.onAction,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, size: AppSizing.iconMd),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width-within-margins button for use inline in a form.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;

  /// Sits after the label. A forward arrow on a sign-in or sign-up button says
  /// "this continues" where a leading icon would try to say what the action is,
  /// which the label already does.
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // A minimum, not a fixed height: the label is scalable text, and boxing
      // scalable text at a fixed height is the mistake this codebase keeps
      // catching elsewhere.
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: AppSizing.primaryButtonHeight,
      ),
      child: ActionPill(
        enabled: !isBusy && onPressed != null,
        child: FilledButton(
        style: actionButtonStyle,
        onPressed: isBusy ? null : onPressed,
        child: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppGradients.onAction,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizing.iconMd),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Flexible, because the label is scalable text sharing a
                  // fixed-width pill with up to two icons. At 320pt and 2.0x
                  // scale an unflexed label plus a trailing arrow overflowed by
                  // 11px — the label gives way, the affordance stays.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(trailingIcon, size: AppSizing.iconMd),
                  ],
                ],
              ),
        ),
      ),
    );
  }
}

/// The hero action's fill: the icon's warm half, painted opaque on the pill.
///
/// Opaque is the point. Colour placed in dim background fields measures out as
/// near-black on this ground — four "aurora" hues resolved to #0B1118, #0A0C1B,
/// #120B13 and #171010 when checked. The spectrum only reads if it sits in a
/// large, saturated, foreground surface, so it goes on the button the eye is
/// already looking for.
///
/// Disabled drops the gradient entirely rather than fading it: a washed-out
/// gradient still reads as decoration, where a flat raised surface reads as
/// unavailable.
class ActionPill extends StatelessWidget {
  const ActionPill({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppGradients.action : null,
        color: enabled ? null : context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

/// Makes the button itself transparent so [_SpectrumPill]'s gradient shows
/// through, and pins the label to the ink measured against that gradient.
/// Pairs with [ActionPill]: makes the button transparent so the pill's
/// gradient shows through, and pins the label to the measured ink.
final ButtonStyle actionButtonStyle = FilledButton.styleFrom(
  backgroundColor: Colors.transparent,
  disabledBackgroundColor: Colors.transparent,
  foregroundColor: AppGradients.onAction,
  shadowColor: Colors.transparent,
  elevation: 0,
);
