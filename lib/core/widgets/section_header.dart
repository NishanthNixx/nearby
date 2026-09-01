import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A heading above a group of content, with an optional trailing action.
///
/// Design guideline — Layout > Visual hierarchy: "Place items to convey their
/// relative importance. People often start by viewing items in reading order...
/// it generally works well to place the most important items near the top and
/// leading side."
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(
      left: AppSpacing.screenMargin,
      right: AppSpacing.screenMargin,
      top: AppSpacing.xxl + AppSpacing.xs,
      bottom: AppSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Sections are labelled the way the reference does it: a tiny
                  // uppercase caption with wide tracking, quiet enough that the
                  // content under it stays the loudest thing in the group.
                  title.toUpperCase(),
                  // The reader hears the natural-case title, not letterspaced
                  // capitals it might spell out letter by letter.
                  semanticsLabel: title,
                  style: context.type.caption.copyWith(
                    color: colors.labelSecondary,
                    fontWeight: AppTypography.semibold,
                    letterSpacing: 1.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: context.type.footnote.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: context.type.subheadEmphasis.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small uppercase-free label above a field group in a form.
class FieldGroupLabel extends StatelessWidget {
  const FieldGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        semanticsLabel: text,
        style: context.type.caption.copyWith(
          color: context.colors.labelSecondary,
          fontWeight: AppTypography.semibold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
