import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
                      child: FilledButton(
                        onPressed: isBusy ? null : onPressed,
                        child: isBusy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: colors.onPrimary,
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;

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
      child: FilledButton(
        onPressed: isBusy ? null : onPressed,
        child: isBusy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: context.colors.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizing.iconMd),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
