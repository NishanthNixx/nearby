import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// Formatting for the values Nearby shows most: money, distance, dates, times.
///
/// Centralised so the same value never appears two different ways on two
/// different screens.
abstract final class Fmt {
  // ---------------------------------------------------------------------------
  // Money
  // ---------------------------------------------------------------------------

  /// `₹350`, or `₹1,250`. Whole rupees — tailoring prices are not quoted in
  /// paise, and dropping the decimals removes visual noise from price columns.
  static String price(int amount) {
    final formatted = NumberFormat.decimalPattern('en_IN').format(amount);
    return '${AppConfig.currencySymbol}$formatted';
  }

  /// `₹350+` — a starting price, where the final quote depends on the garment.
  static String priceFrom(int amount) => '${price(amount)}+';

  // ---------------------------------------------------------------------------
  // Distance
  // ---------------------------------------------------------------------------

  /// `250 m`, `1.2 km`, `12 km`.
  ///
  /// Precision drops as distance grows, because "12.4 km away" implies an
  /// accuracy the underlying location fix does not have.
  static String distance(double km) {
    if (km < 1) {
      final metres = (km * 1000).round();
      final rounded = metres < 100 ? metres : (metres / 10).round() * 10;
      return '$rounded m';
    }
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// `1.2 km away` — the full phrase used on discovery cards.
  static String distanceAway(double km) => '${distance(km)} away';

  // ---------------------------------------------------------------------------
  // Time of day
  // ---------------------------------------------------------------------------

  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _timeCompact = DateFormat('h:mm');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _dayMonthYear = DateFormat('d MMM yyyy');
  static final DateFormat _weekdayShort = DateFormat('EEE');
  static final DateFormat _weekdayLong = DateFormat('EEEE');
  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM');

  /// `9:00 AM`.
  static String time(DateTime dt) => _time.format(dt);

  /// `9:00` — used when the meridiem is shown once for a whole row.
  static String timeCompact(DateTime dt) => _timeCompact.format(dt);

  /// `9:00 AM – 8:00 PM`. Uses an en dash, not a hyphen.
  static String timeRange(DateTime start, DateTime end) =>
      '${time(start)} – ${time(end)}';

  /// `12 Mar`.
  static String dayMonth(DateTime dt) => _dayMonth.format(dt);

  /// `12 Mar 2026`.
  static String dayMonthYear(DateTime dt) => _dayMonthYear.format(dt);

  /// `Mon`.
  static String weekdayShort(DateTime dt) => _weekdayShort.format(dt);

  /// `Monday`.
  static String weekdayLong(DateTime dt) => _weekdayLong.format(dt);

  /// `Thursday, 12 March`.
  static String fullDate(DateTime dt) => _fullDate.format(dt);

  /// Prefers a relative word where one reads better than a date.
  ///
  /// `Today`, `Tomorrow`, `Yesterday`, otherwise `Thu, 12 Mar`.
  static String friendlyDate(DateTime dt, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(dt);
    final days = target.difference(today).inDays;

    return switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => '${weekdayShort(dt)}, ${dayMonth(dt)}',
    };
  }

  /// `Today, 5:00 PM` — the phrasing used on booking cards.
  static String friendlyDateTime(DateTime dt, {DateTime? now}) =>
      '${friendlyDate(dt, now: now)}, ${time(dt)}';

  /// `in 2 hours`, `in 3 days`, `2 days ago`.
  ///
  /// Used for review timestamps and appointment countdowns.
  static String relative(DateTime dt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = dt.difference(reference);
    final future = !diff.isNegative;
    final abs = diff.abs();

    String phrase;
    if (abs.inMinutes < 1) {
      return 'just now';
    } else if (abs.inMinutes < 60) {
      phrase = _plural(abs.inMinutes, 'minute');
    } else if (abs.inHours < 24) {
      phrase = _plural(abs.inHours, 'hour');
    } else if (abs.inDays < 30) {
      phrase = _plural(abs.inDays, 'day');
    } else if (abs.inDays < 365) {
      phrase = _plural(abs.inDays ~/ 30, 'month');
    } else {
      phrase = _plural(abs.inDays ~/ 365, 'year');
    }

    return future ? 'in $phrase' : '$phrase ago';
  }

  /// `30 min`, `1 hr`, `1 hr 30 min`.
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    final hourPart = '$hours hr';
    return remainder == 0 ? hourPart : '$hourPart $remainder min';
  }

  // ---------------------------------------------------------------------------
  // Ratings
  // ---------------------------------------------------------------------------

  /// `4.7`. A rating always shows one decimal so the column does not jitter
  /// between `5` and `4.7`.
  static String rating(double value) => value.toStringAsFixed(1);

  /// `128 reviews`, `1 review`, `No reviews yet`.
  static String reviewCount(int count) => switch (count) {
    0 => 'No reviews yet',
    1 => '1 review',
    _ => '$count reviews',
  };

  static String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
