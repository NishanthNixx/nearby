import '../../../core/config/app_config.dart';

/// A time of day, minute precision, with no date attached.
///
/// Opening hours are the same every Monday, so storing them against a date
/// would be wrong. Minutes-from-midnight keeps comparison and serialisation
/// trivial.
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  const TimeOfDayValue({required this.hour, required this.minute});

  /// From minutes since midnight.
  factory TimeOfDayValue.fromMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60);
    return TimeOfDayValue(hour: clamped ~/ 60, minute: clamped % 60);
  }

  final int hour;
  final int minute;

  int get minutesFromMidnight => hour * 60 + minute;

  /// Anchors this time of day onto a calendar date, in local time.
  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  @override
  int compareTo(TimeOfDayValue other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  bool operator <(TimeOfDayValue other) => compareTo(other) < 0;
  bool operator >(TimeOfDayValue other) => compareTo(other) > 0;
  bool operator <=(TimeOfDayValue other) => compareTo(other) <= 0;
  bool operator >=(TimeOfDayValue other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// One weekday's trading hours.
class DayHours {
  const DayHours({
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
  });

  /// A day the business does not trade.
  const DayHours.closed()
    : isOpen = false,
      opensAt = const TimeOfDayValue(hour: 9, minute: 0),
      closesAt = const TimeOfDayValue(hour: 20, minute: 0);

  /// The default used when a business first sets up: 9am to 8pm.
  const DayHours.standard()
    : isOpen = true,
      opensAt = const TimeOfDayValue(hour: 9, minute: 0),
      closesAt = const TimeOfDayValue(hour: 20, minute: 0);

  final bool isOpen;
  final TimeOfDayValue opensAt;
  final TimeOfDayValue closesAt;

  /// Hours are only usable if the business trades and closing is after opening.
  /// Overnight trading is out of scope for the MVP.
  bool get isValid => !isOpen || closesAt > opensAt;

  int get openMinutes =>
      isOpen ? closesAt.minutesFromMidnight - opensAt.minutesFromMidnight : 0;

  DayHours copyWith({
    bool? isOpen,
    TimeOfDayValue? opensAt,
    TimeOfDayValue? closesAt,
  }) => DayHours(
    isOpen: isOpen ?? this.isOpen,
    opensAt: opensAt ?? this.opensAt,
    closesAt: closesAt ?? this.closesAt,
  );

  @override
  bool operator ==(Object other) =>
      other is DayHours &&
      other.isOpen == isOpen &&
      other.opensAt == opensAt &&
      other.closesAt == closesAt;

  @override
  int get hashCode => Object.hash(isOpen, opensAt, closesAt);
}

/// A full trading week, plus the appointment length and any blocked dates.
///
/// This is everything needed to generate bookable slots. Slot generation
/// itself is a pure function elsewhere, so it can be tested without a backend.
class OpeningHours {
  const OpeningHours({
    required this.byWeekday,
    required this.slotDurationMinutes,
    this.blockedDates = const {},
  });

  /// Monday to Saturday open, Sunday closed — the common pattern for a local
  /// tailor, and a sensible starting point that an owner can adjust.
  factory OpeningHours.standard() => const OpeningHours(
    byWeekday: {
      DateTime.monday: DayHours.standard(),
      DateTime.tuesday: DayHours.standard(),
      DateTime.wednesday: DayHours.standard(),
      DateTime.thursday: DayHours.standard(),
      DateTime.friday: DayHours.standard(),
      DateTime.saturday: DayHours.standard(),
      DateTime.sunday: DayHours.closed(),
    },
    slotDurationMinutes: AppConfig.defaultSlotDurationMinutes,
  );

  /// Keyed by [DateTime.monday] … [DateTime.sunday] (1–7).
  final Map<int, DayHours> byWeekday;

  /// Appointment granularity. Slots are generated on this cadence.
  final int slotDurationMinutes;

  /// Individual dates the business is shut — a holiday, a family event.
  /// Stored as midnight-local dates.
  final Set<DateTime> blockedDates;

  DayHours forWeekday(int weekday) =>
      byWeekday[weekday] ?? const DayHours.closed();

  DayHours forDate(DateTime date) => forWeekday(date.weekday);

  bool isDateBlocked(DateTime date) =>
      blockedDates.contains(DateTime(date.year, date.month, date.day));

  /// Whether the business could take an appointment on this date at all.
  bool tradesOn(DateTime date) => forDate(date).isOpen && !isDateBlocked(date);

  /// Whether the business is open at [moment], by the clock.
  ///
  /// Drives the "Open now" / "Closed" indicator. Note the indicator is always
  /// rendered with a glyph and a text label as well, never colour alone.
  bool isOpenAt(DateTime moment) {
    if (!tradesOn(moment)) return false;
    final hours = forDate(moment);
    final now = TimeOfDayValue(hour: moment.hour, minute: moment.minute);
    return now >= hours.opensAt && now < hours.closesAt;
  }

  bool get isValid =>
      slotDurationMinutes >= AppConfig.minSlotDurationMinutes &&
      slotDurationMinutes <= AppConfig.maxSlotDurationMinutes &&
      byWeekday.values.every((d) => d.isValid) &&
      byWeekday.values.any((d) => d.isOpen);

  /// Weekdays grouped into consecutive runs that share the same hours, so the
  /// UI can print "Mon–Sat 9:00 AM – 8:00 PM" rather than six identical rows.
  List<HoursGroup> get grouped {
    final groups = <HoursGroup>[];
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final hours = forWeekday(weekday);
      final last = groups.isEmpty ? null : groups.last;

      if (last != null &&
          last.hours == hours &&
          last.endWeekday == weekday - 1) {
        groups[groups.length - 1] = HoursGroup(
          startWeekday: last.startWeekday,
          endWeekday: weekday,
          hours: hours,
        );
      } else {
        groups.add(
          HoursGroup(startWeekday: weekday, endWeekday: weekday, hours: hours),
        );
      }
    }
    return groups;
  }

  OpeningHours copyWith({
    Map<int, DayHours>? byWeekday,
    int? slotDurationMinutes,
    Set<DateTime>? blockedDates,
  }) => OpeningHours(
    byWeekday: byWeekday ?? this.byWeekday,
    slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
    blockedDates: blockedDates ?? this.blockedDates,
  );
}

/// A run of consecutive weekdays sharing the same hours.
class HoursGroup {
  const HoursGroup({
    required this.startWeekday,
    required this.endWeekday,
    required this.hours,
  });

  final int startWeekday;
  final int endWeekday;
  final DayHours hours;

  bool get isSingleDay => startWeekday == endWeekday;
}
