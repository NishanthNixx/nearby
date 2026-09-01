import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A tappable one-to-five star rating.
///
/// Design guideline — Accessibility > Mobility: mobile controls should be at
/// least 44x44pt. Each star is a full-size tap target even though the glyph
/// itself is smaller, and the whole control also exposes an increment/decrement
/// action so it can be driven without precise tapping.
///
/// The current value is always spelled out in words beneath the stars, so the
/// rating is never conveyed by shape alone.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 0 means nothing chosen yet.
  final int value;
  final ValueChanged<int> onChanged;

  static const List<String> _descriptions = [
    'Tap a star to rate',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Semantics(
          slider: true,
          value: value == 0 ? 'No rating' : '$value of 5 stars',
          increasedValue: value < 5 ? '${value + 1} of 5 stars' : null,
          decreasedValue: value > 1 ? '${value - 1} of 5 stars' : null,
          onIncrease: value < 5 ? () => onChanged(value + 1) : null,
          onDecrease: value > 1 ? () => onChanged(value - 1) : null,
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              final filled = star <= value;

              return InkWell(
                onTap: () => onChanged(star),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: AppSizing.minTouchTarget + 4,
                  height: AppSizing.minTouchTarget + 4,
                  child: Center(
                    child: AnimatedScale(
                      // A brief, small pop on selection. Under 150ms and
                      // barely 6% of scale — enough to confirm the tap landed
                      // without becoming a performance.
                      scale: filled ? 1.06 : 1,
                      duration: AppMotion.fast,
                      curve: Curves.easeOut,
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 34,
                        color: filled ? colors.accent : colors.labelTertiary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _descriptions[value.clamp(0, 5)],
          style: context.type.subheadEmphasis.copyWith(
            color: value == 0 ? colors.labelSecondary : colors.label,
          ),
        ),
      ],
    );
  }
}

/// Read-only stars, for showing a review's rating in a list.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = AppSizing.iconSm,
  });

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final filled = index < rating;
          return Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? colors.accent : colors.separator,
            ),
          );
        }),
      ),
    );
  }
}
