import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/features/bookings/domain/availability_calculator.dart';
import 'package:nearby/features/bookings/domain/booking.dart';
import 'package:nearby/features/businesses/domain/opening_hours.dart';

/// Slot generation is the fiddliest logic in the product, and it is pure, so it
/// gets the most thorough tests.
void main() {
  // A Wednesday, so weekday arithmetic is unambiguous.
  final wednesday = DateTime(2026, 3, 11);
  final sunday = DateTime(2026, 3, 15);

  OpeningHours hoursWith({
    int slotMinutes = 30,
    int openHour = 9,
    int closeHour = 12,
    Set<DateTime> blocked = const {},
  }) {
    final day = DayHours(
      isOpen: true,
      opensAt: TimeOfDayValue(hour: openHour, minute: 0),
      closesAt: TimeOfDayValue(hour: closeHour, minute: 0),
    );

    return OpeningHours(
      byWeekday: {
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.saturday;
          weekday++
        )
          weekday: day,
        DateTime.sunday: const DayHours.closed(),
      },
      slotDurationMinutes: slotMinutes,
      blockedDates: blocked,
    );
  }

  Booking bookingAt(
    DateTime start,
    int durationMinutes, {
    BookingStatus status = BookingStatus.confirmed,
  }) {
    return Booking(
      id: 'b_${start.millisecondsSinceEpoch}',
      customerId: 'c1',
      businessId: 'biz1',
      serviceId: 's1',
      startTime: start,
      endTime: start.add(Duration(minutes: durationMinutes)),
      status: status,
      createdAt: start.subtract(const Duration(days: 1)),
      serviceName: 'Shirt stitching',
      servicePrice: 350,
      businessName: 'Test Tailors',
    );
  }

  group('slotsForDay', () {
    test('returns nothing on a day the business does not trade', () {
      final slots = AvailabilityCalculator.slotsForDay(
        date: sunday,
        openingHours: hoursWith(),
        serviceDurationMinutes: 30,
        existingBookings: const [],
        now: sunday.subtract(const Duration(days: 7)),
      );

      expect(slots, isEmpty);
    });

    test('returns nothing on a specifically blocked date', () {
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(blocked: {wednesday}),
        serviceDurationMinutes: 30,
        existingBookings: const [],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      expect(slots, isEmpty);
    });

    test('generates one slot per cadence step within opening hours', () {
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
        serviceDurationMinutes: 30,
        existingBookings: const [],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      // 9:00 to 12:00 at 30 minutes = 6 slots, last starting at 11:30.
      expect(slots.length, 6);
      expect(slots.first.start, DateTime(2026, 3, 11, 9));
      expect(slots.last.start, DateTime(2026, 3, 11, 11, 30));
      expect(slots.last.end, DateTime(2026, 3, 11, 12));
      expect(slots.every((s) => s.isAvailable), isTrue);
    });

    test('never offers a slot that would run past closing time', () {
      // A 60-minute service on a 30-minute cadence: the 11:30 start is dropped
      // because it would end at 12:30, after the 12:00 close.
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
        serviceDurationMinutes: 60,
        existingBookings: const [],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      expect(slots.last.start, DateTime(2026, 3, 11, 11));
      expect(slots.last.end, DateTime(2026, 3, 11, 12));
      expect(
        slots.any((s) => s.start == DateTime(2026, 3, 11, 11, 30)),
        isFalse,
      );
    });

    test('marks slots overlapping an existing booking unavailable', () {
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
        serviceDurationMinutes: 30,
        existingBookings: [bookingAt(DateTime(2026, 3, 11, 10), 30)],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      final tenOClock = slots.firstWhere(
        (s) => s.start == DateTime(2026, 3, 11, 10),
      );
      final nineThirty = slots.firstWhere(
        (s) => s.start == DateTime(2026, 3, 11, 9, 30),
      );

      expect(tenOClock.isAvailable, isFalse);
      expect(nineThirty.isAvailable, isTrue);
    });

    test(
      'treats intervals as half-open, so adjacent appointments do not clash',
      () {
        // An existing booking runs 10:00–10:30. A candidate starting at 10:30
        // does not overlap it.
        final slots = AvailabilityCalculator.slotsForDay(
          date: wednesday,
          openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
          serviceDurationMinutes: 30,
          existingBookings: [bookingAt(DateTime(2026, 3, 11, 10), 30)],
          now: wednesday.subtract(const Duration(days: 1)),
        );

        final tenThirty = slots.firstWhere(
          (s) => s.start == DateTime(2026, 3, 11, 10, 30),
        );
        expect(tenThirty.isAvailable, isTrue);
      },
    );

    test('a long appointment blocks every cadence slot it spans', () {
      // 10:00–11:30 must knock out 10:00, 10:30 and 11:00.
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
        serviceDurationMinutes: 30,
        existingBookings: [bookingAt(DateTime(2026, 3, 11, 10), 90)],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      final blocked = slots
          .where((s) => !s.isAvailable)
          .map((s) => s.start)
          .toList();

      expect(blocked, [
        DateTime(2026, 3, 11, 10),
        DateTime(2026, 3, 11, 10, 30),
        DateTime(2026, 3, 11, 11),
      ]);
    });

    test('a cancelled booking releases its slot', () {
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(),
        serviceDurationMinutes: 30,
        existingBookings: [
          bookingAt(
            DateTime(2026, 3, 11, 10),
            30,
            status: BookingStatus.cancelled,
          ),
        ],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      expect(
        slots
            .firstWhere((s) => s.start == DateTime(2026, 3, 11, 10))
            .isAvailable,
        isTrue,
      );
    });

    test('a completed booking releases its slot', () {
      // A completed appointment can only be marked done after its end time has
      // passed, and nothing can be booked into the past, so releasing the slot
      // is safe — and it keeps the lock collection from growing forever.
      final slots = AvailabilityCalculator.slotsForDay(
        date: wednesday,
        openingHours: hoursWith(),
        serviceDurationMinutes: 30,
        existingBookings: [
          bookingAt(
            DateTime(2026, 3, 11, 10),
            30,
            status: BookingStatus.completed,
          ),
        ],
        now: wednesday.subtract(const Duration(days: 1)),
      );

      // A completed booking is terminal, so it no longer holds the slot — the
      // day is in the past and the lead-time rule is what stops rebooking.
      expect(
        slots
            .firstWhere((s) => s.start == DateTime(2026, 3, 11, 10))
            .isAvailable,
        isTrue,
      );
    });

    test(
      'slots inside the minimum lead time are unavailable but still shown',
      () {
        // Standing at 9:40 on the day, with a 30-minute lead time, the 10:00 slot
        // is too soon but 10:30 is fine.
        final slots = AvailabilityCalculator.slotsForDay(
          date: wednesday,
          openingHours: hoursWith(slotMinutes: 30, openHour: 9, closeHour: 12),
          serviceDurationMinutes: 30,
          existingBookings: const [],
          now: DateTime(2026, 3, 11, 9, 40),
          minimumLeadTime: const Duration(minutes: 30),
        );

        // Every slot is still rendered — a day shown as empty reads as broken.
        expect(slots.length, 6);
        expect(
          slots
              .firstWhere((s) => s.start == DateTime(2026, 3, 11, 9))
              .isAvailable,
          isFalse,
        );
        expect(
          slots
              .firstWhere((s) => s.start == DateTime(2026, 3, 11, 10))
              .isAvailable,
          isFalse,
        );
        expect(
          slots
              .firstWhere((s) => s.start == DateTime(2026, 3, 11, 10, 30))
              .isAvailable,
          isTrue,
        );
      },
    );

    test('returns nothing for a non-positive service duration', () {
      expect(
        AvailabilityCalculator.slotsForDay(
          date: wednesday,
          openingHours: hoursWith(),
          serviceDurationMinutes: 0,
          existingBookings: const [],
          now: wednesday,
        ),
        isEmpty,
      );
    });
  });

  group('hasAvailability', () {
    test('is false once every slot is taken', () {
      final fullDay = [
        for (var hour = 9; hour < 12; hour++)
          for (final minute in [0, 30])
            bookingAt(DateTime(2026, 3, 11, hour, minute), 30),
      ];

      expect(
        AvailabilityCalculator.hasAvailability(
          date: wednesday,
          openingHours: hoursWith(),
          serviceDurationMinutes: 30,
          existingBookings: fullDay,
          now: wednesday.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('is true while one slot remains', () {
      final almostFull = [
        for (var hour = 9; hour < 12; hour++)
          for (final minute in [0, 30])
            if (!(hour == 11 && minute == 30))
              bookingAt(DateTime(2026, 3, 11, hour, minute), 30),
      ];

      expect(
        AvailabilityCalculator.hasAvailability(
          date: wednesday,
          openingHours: hoursWith(),
          serviceDurationMinutes: 30,
          existingBookings: almostFull,
          now: wednesday.subtract(const Duration(days: 1)),
        ),
        isTrue,
      );
    });
  });

  group('selectableDates', () {
    test('skips days the business never trades', () {
      final dates = AvailabilityCalculator.selectableDates(
        from: wednesday,
        openingHours: hoursWith(),
        horizonDays: 14,
      );

      expect(dates.any((d) => d.weekday == DateTime.sunday), isFalse);
      expect(dates.first, DateTime(2026, 3, 11));
    });

    test('stays within the horizon and the requested count', () {
      final dates = AvailabilityCalculator.selectableDates(
        from: wednesday,
        openingHours: hoursWith(),
        horizonDays: 7,
        count: 100,
      );

      // Seven days from a Wednesday contains one Sunday.
      expect(dates.length, 6);
      expect(dates.last.difference(DateTime(2026, 3, 11)).inDays, lessThan(7));
    });
  });
}
