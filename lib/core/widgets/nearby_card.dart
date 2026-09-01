import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Nearby's card primitive.
///
/// A neutral surface with a generous radius and no drop shadow — at this
/// density a shadow reads as heavy in light and vanishes entirely in dark.
///
/// How a card separates from its ground depends on the appearance. In dark it
/// is borderless: the surface is a lighter value than the near-black ground, so
/// value alone does the work and the screen reads as panels of material rather
/// than outlined boxes. In light there is no value gap to lean on, so a
/// hairline carries it instead.
///
/// Selection inverts the fill to the ground's opposite value, the same rule the
/// primary button and every selectable cell follow.
///
/// Design guideline — Layout > Best practices: "Group related items to help
/// people find the information they want... you might use negative space,
/// background shapes, colors, materials, or separator lines to show when
/// elements are related."
class NearbyCard extends StatelessWidget {
  const NearbyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.semanticsLabel,
    this.isSelected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// A single label for the whole card, so a screen reader announces one
  /// coherent item instead of reading six disconnected fragments. Children
  /// that supply it should exclude their own semantics.
  final String? semanticsLabel;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final isDark = colors.brightness == Brightness.dark;

    final decorated = AnimatedContainer(
      duration: AppMotion.fast,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // Selection inverts the surface: a selected card is the ground's
        // opposite value, the same rule as the primary button. Shape change
        // (the thicker border in light) plus the inversion keeps selection
        // legible without a hue.
        color: isSelected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isSelected
            ? Border.all(color: colors.primary, width: 2)
            : (isDark
                  // Dark cards carry no border — surface value separates them
                  // from the near-black ground.
                  ? null
                  : Border.all(
                      color: colors.separator,
                      width: AppSizing.separator,
                    )),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return semanticsLabel == null
          ? decorated
          : Semantics(label: semanticsLabel, child: decorated);
    }

    return Semantics(
      button: true,
      selected: isSelected ? true : null,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: decorated,
        ),
      ),
    );
  }
}

/// A grouped list of rows inside one card, with hairline separators between.
///
/// Used for services, opening hours and settings-style lists, where a card per
/// row would fragment the page.
class NearbyCardList extends StatelessWidget {
  const NearbyCardList({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          const Padding(
            // Inset so the rule stops short of the card's rounded corners,
            // which is what makes it read as a divider rather than a slice.
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Divider(height: AppSizing.separator),
          ),
        );
      }
    }

    return NearbyCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}
