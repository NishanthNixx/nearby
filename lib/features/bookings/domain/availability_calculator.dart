import '../../businesses/domain/opening_hours.dart';
import 'booking.dart';

/// Turns opening hours plus existing appointments into bookable time slots.
///
/// A pure function, with no dependency on any backend. That is deliberate:
/// slot generation is the fiddliest logic in the product, and keeping it here
/// means it can be tested exhaustively with plain values.
///
/// The client uses this to *show* availability. It is never the authority — a
/// slot is only truly claimed by the atomic write in the booking repository,
/// because two customers can be looking at the same freshly generated list.
abstract final class AvailabilityCalculator {
  /// Slots for a single day.
  ///
  /// Slots start on the business's [OpeningHours.slotDurationMinutes] cadence
  /// but each runs for [serviceDurationMinutes]. So a 30-minute cadence with a
  /// 60-minute service offers 9:00, 9:30, 10:00 … and each candidate is
  /// checked for overlap against everything already booked. A slot is only
  /// offered if the whole appointment finishes before closing time.
  static List<TimeSlot> slotsForDay({
    required DateTime date,
    required OpeningHours openingHours,
    required int serviceDurationMinutes,
    required List<Booking> existingBookings,
    required DateTime now,
    Duration minimumLeadTime = Duration.zero,
  }) {
    if (!openingHours.tradesOn(date)) return const [];
    if (serviceDurationMinutes <= 0) return const [];

    final hours = openingHours.forDate(date);
    final dayOpens = hours.opensAt.onDate(date);
    final dayCloses = hours.closesAt.onDate(date);
    final serviceDuration = Duration(minutes: serviceDurationMinutes);
    final step = Duration(minutes: openingHours.slotDurationMinutes);

    if (step.inMinutes <= 0) return const [];

    // Only appointments that still hold their slot block a time. A cancelled
    // booking frees its slot for someone else.
    final blocking = existingBookings
        .where((b) => b.status.holdsSlot)
        .toList(growable: false);

    final earliestStart = now.add(minimumLeadTime);
    final slots = <TimeSlot>[];

    for (
      var start = dayOpens;
      !start.add(serviceDuration).isAfter(dayCloses);
      start = start.add(step)
    ) {
      final end = start.add(serviceDuration);

      final isPast = start.isBefore(earliestStart);
      final clashes = blocking.any(
        (b) => _overlaps(start, end, b.startTime, b.endTime),
      );

      slots.add(
        TimeSlot(start: start, end: end, isAvailable: !isPast && !clashes),
      );
    }

    return slots;
  }

  /// Whether any slot on [date] can still be taken.
  ///
  /// Used to mark days on the date strip, so a customer does not tap into a
  /// day only to find it full.
  static bool hasAvailability({
    required DateTime date,
    required OpeningHours openingHours,
    required int serviceDurationMinutes,
    required List<Booking> existingBookings,
    required DateTime now,
    Duration minimumLeadTime = Duration.zero,
  }) {
    final slots = slotsForDay(
      date: date,
      openingHours: openingHours,
      serviceDurationMinutes: serviceDurationMinutes,
      existingBookings: existingBookings,
      now: now,
      minimumLeadTime: minimumLeadTime,
    );
    return slots.any((s) => s.isAvailable);
  }

  /// The next [count] dates from [from] inclusive, for the date strip.
  ///
  /// Days the business never trades are skipped entirely — offering a Sunday
  /// that can only ever be empty wastes a tap.
  static List<DateTime> selectableDates({
    required DateTime from,
    required OpeningHours openingHours,
    required int horizonDays,
    int count = 14,
  }) {
    final dates = <DateTime>[];
    final start = DateTime(from.year, from.month, from.day);

    for (
      var offset = 0;
      offset < horizonDays && dates.length < count;
      offset++
    ) {
      final date = start.add(Duration(days: offset));
      if (openingHours.tradesOn(date)) dates.add(date);
    }

    return dates;
  }

  /// Half-open interval overlap: `[aStart, aEnd)` against `[bStart, bEnd)`.
  ///
  /// Half-open matters — an appointment ending at 10:00 and one starting at
  /// 10:00 do not conflict.
  static bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) => aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}
