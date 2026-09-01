// Firestore exports its own `GeoPoint`. Nearby stores plain latitude and
// longitude numbers instead, so that type is hidden to keep the domain
// `GeoPoint` unambiguous.
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../../../core/data/firebase_error_mapper.dart';
import '../../../core/utils/geo.dart';
import '../domain/business.dart';
import '../domain/business_repository.dart';
import '../domain/opening_hours.dart';
import '../domain/service_offering.dart';

/// Converts between Firestore documents and the business domain models.
///
/// Location is stored as two plain numbers plus a geohash string rather than a
/// Firestore `GeoPoint`. Plain numbers survive a move to PostgreSQL unchanged,
/// and the geohash is what makes the proximity query a range scan.
abstract final class BusinessMapper {
  static const String fieldOwnerId = 'ownerId';
  static const String fieldName = 'name';

  /// Lower-cased name, stored so a name search can be a prefix range query.
  /// Firestore cannot do case-insensitive or substring matching on its own.
  static const String fieldNameLower = 'nameLower';

  static const String fieldCategory = 'category';
  static const String fieldTagline = 'tagline';
  static const String fieldDescription = 'description';
  static const String fieldPhone = 'phone';
  static const String fieldAddress = 'address';
  static const String fieldLatitude = 'latitude';
  static const String fieldLongitude = 'longitude';
  static const String fieldGeohash = 'geohash';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldGalleryUrls = 'galleryUrls';
  static const String fieldAcceptingBookings = 'isAcceptingBookings';
  static const String fieldRatingAverage = 'ratingAverage';
  static const String fieldRatingCount = 'ratingCount';
  static const String fieldOpeningHours = 'openingHours';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';

  static const String _hoursSlotDuration = 'slotDurationMinutes';
  static const String _hoursDays = 'days';
  static const String _hoursBlockedDates = 'blockedDates';
  static const String _dayIsOpen = 'isOpen';
  static const String _dayOpensAt = 'opensAtMinutes';
  static const String _dayClosesAt = 'closesAtMinutes';

  // ---------------------------------------------------------------------------
  // Business
  // ---------------------------------------------------------------------------

  static Business fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    final location = GeoPoint(
      latitude: _toDouble(data[fieldLatitude]),
      longitude: _toDouble(data[fieldLongitude]),
    );

    return Business(
      id: doc.id,
      ownerId: (data[fieldOwnerId] as String?) ?? '',
      name: (data[fieldName] as String?) ?? '',
      category: categoryFromString(data[fieldCategory] as String?),
      location: location,
      geohash: (data[fieldGeohash] as String?) ?? Geohash.encode(location),
      address: (data[fieldAddress] as String?) ?? '',
      openingHours: _hoursFromMap(data[fieldOpeningHours]),
      isAcceptingBookings: (data[fieldAcceptingBookings] as bool?) ?? true,
      createdAt: FirestoreTime.toDateTimeOr(
        data[fieldCreatedAt],
        DateTime.now(),
      ),
      tagline: data[fieldTagline] as String?,
      description: data[fieldDescription] as String?,
      phone: data[fieldPhone] as String?,
      photoUrl: data[fieldPhotoUrl] as String?,
      galleryUrls: _toStringList(data[fieldGalleryUrls]),
      ratingAverage: _toDouble(data[fieldRatingAverage]),
      ratingCount: _toInt(data[fieldRatingCount]),
    );
  }

  /// Payload for creating a listing.
  ///
  /// Rating fields are seeded to zero here and never included in an update
  /// payload — the rules reject client writes to them, so a business cannot
  /// inflate its own rating.
  static Map<String, Object?> toCreatePayload({
    required String ownerId,
    required BusinessDraft draft,
  }) {
    return {
      fieldOwnerId: ownerId,
      ...toUpdatePayload(draft),
      fieldRatingAverage: 0,
      fieldRatingCount: 0,
      fieldOpeningHours: hoursToMap(OpeningHours.standard()),
      fieldCreatedAt: FieldValue.serverTimestamp(),
      fieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  /// Payload for editing a listing. Excludes ownership, ratings and hours,
  /// each of which has its own guarded path.
  static Map<String, Object?> toUpdatePayload(BusinessDraft draft) {
    final trimmedName = draft.name.trim();
    return {
      fieldName: trimmedName,
      fieldNameLower: trimmedName.toLowerCase(),
      fieldCategory: draft.category.name,
      fieldAddress: draft.address.trim(),
      fieldLatitude: draft.location.latitude,
      fieldLongitude: draft.location.longitude,
      fieldGeohash: Geohash.encode(draft.location),
      fieldTagline: draft.tagline?.trim(),
      fieldDescription: draft.description?.trim(),
      fieldPhone: draft.phone?.trim(),
      if (draft.photoUrl != null) fieldPhotoUrl: draft.photoUrl,
      if (draft.galleryUrls != null) fieldGalleryUrls: draft.galleryUrls,
      if (draft.isAcceptingBookings != null)
        fieldAcceptingBookings: draft.isAcceptingBookings,
      fieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  static BusinessCategory categoryFromString(String? value) => switch (value) {
    'tailoring' => BusinessCategory.tailoring,
    _ => BusinessCategory.tailoring,
  };

  // ---------------------------------------------------------------------------
  // Opening hours
  // ---------------------------------------------------------------------------

  static Map<String, Object?> hoursToMap(OpeningHours hours) => {
    _hoursSlotDuration: hours.slotDurationMinutes,
    _hoursDays: {
      for (final entry in hours.byWeekday.entries)
        entry.key.toString(): {
          _dayIsOpen: entry.value.isOpen,
          _dayOpensAt: entry.value.opensAt.minutesFromMidnight,
          _dayClosesAt: entry.value.closesAt.minutesFromMidnight,
        },
    },
    // ISO date strings, so a blocked date is human-readable in the console
    // and unambiguous across time zones.
    _hoursBlockedDates: hours.blockedDates
        .map((d) => _dateKey(d))
        .toList(growable: false),
  };

  static OpeningHours _hoursFromMap(Object? raw) {
    if (raw is! Map) return OpeningHours.standard();
    final map = raw.cast<String, dynamic>();

    final daysRaw = map[_hoursDays];
    final byWeekday = <int, DayHours>{};

    if (daysRaw is Map) {
      for (final entry in daysRaw.cast<String, dynamic>().entries) {
        final weekday = int.tryParse(entry.key);
        final value = entry.value;
        if (weekday == null || weekday < 1 || weekday > 7 || value is! Map) {
          continue;
        }
        final day = value.cast<String, dynamic>();
        byWeekday[weekday] = DayHours(
          isOpen: (day[_dayIsOpen] as bool?) ?? false,
          opensAt: TimeOfDayValue.fromMinutes(_toInt(day[_dayOpensAt], 9 * 60)),
          closesAt: TimeOfDayValue.fromMinutes(
            _toInt(day[_dayClosesAt], 20 * 60),
          ),
        );
      }
    }

    if (byWeekday.isEmpty) return OpeningHours.standard();

    return OpeningHours(
      byWeekday: byWeekday,
      slotDurationMinutes: _toInt(map[_hoursSlotDuration], 30),
      blockedDates: _toStringList(
        map[_hoursBlockedDates],
      ).map(_parseDateKey).whereType<DateTime>().toSet(),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDateKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  static const String fieldServicePrice = 'price';
  static const String fieldServiceDuration = 'durationMinutes';
  static const String fieldServiceActive = 'isActive';

  static ServiceOffering serviceFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String businessId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ServiceOffering(
      id: doc.id,
      businessId: businessId,
      name: (data[fieldName] as String?) ?? '',
      price: _toInt(data[fieldServicePrice]),
      durationMinutes: _toInt(data[fieldServiceDuration], 30),
      isActive: (data[fieldServiceActive] as bool?) ?? true,
      description: data[fieldDescription] as String?,
    );
  }

  static Map<String, Object?> serviceToPayload(ServiceOffering service) => {
    fieldName: service.name.trim(),
    fieldDescription: service.description?.trim(),
    fieldServicePrice: service.price,
    fieldServiceDuration: service.durationMinutes,
    fieldServiceActive: service.isActive,
    fieldUpdatedAt: FieldValue.serverTimestamp(),
  };

  // ---------------------------------------------------------------------------
  // Coercion helpers
  //
  // Firestore returns `num` for any number field, and a document written by an
  // older app version may be missing a field entirely. Coercing rather than
  // casting means one malformed document does not crash a whole list.
  // ---------------------------------------------------------------------------

  static double _toDouble(Object? value, [double fallback = 0]) =>
      switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? fallback,
        _ => fallback,
      };

  static int _toInt(Object? value, [int fallback = 0]) => switch (value) {
    final num n => n.round(),
    final String s => int.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static List<String> _toStringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
