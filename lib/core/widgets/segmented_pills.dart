import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A segmented control rendered as pills in a track — the reference's
/// Booking / Portfolio / Reviews pattern.
///
/// Selection follows the scheme's inversion rule: the active segment is a
/// white pill with black text, the ground's opposite value, exactly like the
/// primary button and a selected date cell. Shape (the filled pill) carries the
/// state as well as value, so selection never rests on colour alone.
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: colors.brightness == Brightness.dark
            ? null
            : Border.all(color: colors.separator),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: _Segment(
                label: segments[i],
                isSelected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          constraints: const BoxConstraints(
            // The track's own padding brings the visual pill under 44pt, but
            // the tappable row stays at the floor.
            minHeight: AppSizing.minTouchTarget - AppSpacing.xs * 2,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.subheadEmphasis.copyWith(
              color: isSelected ? colors.onPrimary : colors.labelSecondary,
              fontWeight: isSelected
                  ? AppTypography.semibold
                  : AppTypography.medium,
            ),
          ),
        ),
      ),
    );
  }
}
