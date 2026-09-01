import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../domain/opening_hours.dart';

/// Opening hours, collapsed into runs of identical days.
///
/// "Mon–Sat  9:00 AM – 8:00 PM" rather than six near-identical rows: the point
/// of the section is the shape of the week, and repetition obscures it.
class OpeningHoursList extends StatelessWidget {
  const OpeningHoursList({
    super.key,
    required this.hours,
    this.highlightToday = true,
  });

  final OpeningHours hours;

  /// Marks the row containing today, so a customer can find the answer to
  /// "are they open now" without reading the whole table.
  final bool highlightToday;

  static const List<String> _weekdayNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final groups = hours.grouped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
            child: _HoursRow(
              label: _labelFor(group),
              hours: group.hours,
              isToday:
                  highlightToday &&
                  today.weekday >= group.startWeekday &&
                  today.weekday <= group.endWeekday,
            ),
          ),
        if (hours.blockedDates.isNotEmpty) ...[
          // Space, not a rule: the closures are a footnote under the table
          // rather than another row of it, and this scheme separates blocks by
          // negative space wherever a hairline is not doing real work.
          const SizedBox(height: AppSpacing.lg),
          _ClosedDates(dates: hours.blockedDates),
        ],
      ],
    );
  }

  static String _labelFor(HoursGroup group) {
    if (group.isSingleDay) return _weekdayNames[group.startWeekday];
    return '${_weekdayNames[group.startWeekday]}–${_weekdayNames[group.endWeekday]}';
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.label,
    required this.hours,
    required this.isToday,
  });

  final String label;
  final DayHours hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = context.type.scale;
    final today = DateTime.now();

    final valueText = hours.isOpen
        ? Fmt.timeRange(
            hours.opensAt.onDate(today),
            hours.closesAt.onDate(today),
          )
        : 'Closed';

    // Today is white semibold against grey siblings — value contrast, the same
    // move as the selection inversion, rather than a hue. Semibold, not the
    // ladder's medium: at 15pt medium is too subtle a step to carry "this row
    // is today" on its own.
    final dayStyle = context.type.subhead.copyWith(
      color: isToday ? colors.label : colors.labelSecondary,
      fontWeight: isToday ? AppTypography.semibold : null,
    );
    final valueStyle = context.type.subhead.copyWith(
      color: isToday || hours.isOpen ? colors.label : colors.labelSecondary,
      fontWeight: isToday ? AppTypography.semibold : null,
      fontFeatures: AppTypography.tabular,
    );

    return Semantics(
      label: '$label: $valueText${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            // The day column scales with the user's text size so "Mon–Sat"
            // never collides with the times at accessibility scales — a fixed
            // width is a fixed overflow.
            width: MediaQuery.textScalerOf(context).scale(84),
            child: Row(
              children: [
                Flexible(child: Text(label, style: dayStyle)),
                if (isToday) ...[
                  // Gap and dot both track the text size: at an unscaled 5pt
                  // beside 30pt type the marker reads as punctuation glued to
                  // the label rather than as a mark of its own.
                  SizedBox(width: AppSpacing.xs * scale),
                  // A dot plus the bolder weight — today is marked twice, so
                  // it does not rely on a single visual cue. White (label),
                  // not primary: primary means tappable, and the dot is a
                  // marker, not a control.
                  Container(
                    width: 5 * scale,
                    height: 5 * scale,
                    decoration: BoxDecoration(
                      color: colors.label,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: Text(valueText, style: valueStyle)),
        ],
      ),
    );
  }
}

class _ClosedDates extends StatelessWidget {
  const _ClosedDates({required this.dates});

  final Set<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    // Past closures are noise; only what is still ahead matters.
    final upcoming =
        dates
            .where((d) => !d.isBefore(DateTime(now.year, now.month, now.day)))
            .toList()
          ..sort();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.event_busy_rounded,
          size: AppSizing.iconSm,
          color: colors.labelSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Closed on ${upcoming.take(4).map(Fmt.dayMonth).join(', ')}'
            '${upcoming.length > 4 ? ' and ${upcoming.length - 4} more' : ''}',
            style: context.type.footnote.copyWith(color: colors.labelSecondary),
          ),
        ),
      ],
    );
  }
}
