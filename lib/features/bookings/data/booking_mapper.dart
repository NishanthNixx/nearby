import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firebase_error_mapper.dart';
import '../domain/booking.dart';

/// Converts between Firestore booking documents and [Booking].
abstract final class BookingMapper {
  static const String fieldCustomerId = 'customerId';
  static const String fieldBusinessId = 'businessId';
  static const String fieldServiceId = 'serviceId';
  static const String fieldStartTime = 'startTime';
  static const String fieldEndTime = 'endTime';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldServiceName = 'serviceName';
  static const String fieldServicePrice = 'servicePrice';
  static const String fieldBusinessName = 'businessName';
  static const String fieldCustomerName = 'customerName';
  static const String fieldCustomerPhone = 'customerPhone';
  static const String fieldNote = 'note';
  static const String fieldCancelledBy = 'cancelledBy';
  static const String fieldCancelledAt = 'cancelledAt';
  static const String fieldCompletedAt = 'completedAt';
  static const String fieldHasReview = 'hasReview';

  /// IDs of the slot lock documents this booking holds.
  ///
  /// Stored on the booking so cancelling releases exactly the locks it took,
  /// even if the business later changes its appointment cadence.
  static const String fieldSlotLockIds = 'slotLockIds';

  static Booking fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return Booking(
      id: doc.id,
      customerId: (data[fieldCustomerId] as String?) ?? '',
      businessId: (data[fieldBusinessId] as String?) ?? '',
      serviceId: (data[fieldServiceId] as String?) ?? '',
      startTime: FirestoreTime.toDateTimeOr(data[fieldStartTime], now),
      endTime: FirestoreTime.toDateTimeOr(data[fieldEndTime], now),
      status: statusFromString(data[fieldStatus] as String?),
      createdAt: FirestoreTime.toDateTimeOr(data[fieldCreatedAt], now),
      serviceName: (data[fieldServiceName] as String?) ?? 'Service',
      servicePrice: (data[fieldServicePrice] as num?)?.round() ?? 0,
      businessName: (data[fieldBusinessName] as String?) ?? '',
      customerName: data[fieldCustomerName] as String?,
      customerPhone: data[fieldCustomerPhone] as String?,
      note: data[fieldNote] as String?,
      cancelledBy: cancelledByFromString(data[fieldCancelledBy] as String?),
      cancelledAt: FirestoreTime.toDateTime(data[fieldCancelledAt]),
      completedAt: FirestoreTime.toDateTime(data[fieldCompletedAt]),
      hasReview: (data[fieldHasReview] as bool?) ?? false,
    );
  }

  /// The document written when a booking is created.
  ///
  /// Every value here is derived on the writing side from records it has just
  /// read in the same transaction — the client cannot supply its own price,
  /// customer id or status.
  static Map<String, Object?> toCreatePayload({
    required Booking booking,
    required List<String> slotLockIds,
  }) {
    return {
      fieldCustomerId: booking.customerId,
      fieldBusinessId: booking.businessId,
      fieldServiceId: booking.serviceId,
      fieldStartTime: FirestoreTime.fromDateTime(booking.startTime),
      fieldEndTime: FirestoreTime.fromDateTime(booking.endTime),
      fieldStatus: booking.status.name,
      fieldServiceName: booking.serviceName,
      fieldServicePrice: booking.servicePrice,
      fieldBusinessName: booking.businessName,
      fieldCustomerName: booking.customerName,
      fieldCustomerPhone: booking.customerPhone,
      fieldNote: booking.note,
      fieldHasReview: false,
      fieldSlotLockIds: slotLockIds,
      fieldCreatedAt: FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> toStatusPayload({
    required BookingStatus status,
    CancelledBy? cancelledBy,
  }) {
    return {
      fieldStatus: status.name,
      if (status == BookingStatus.cancelled) ...{
        fieldCancelledBy: cancelledBy?.name,
        fieldCancelledAt: FieldValue.serverTimestamp(),
      },
      if (status == BookingStatus.completed)
        fieldCompletedAt: FieldValue.serverTimestamp(),
    };
  }

  static List<String> slotLockIdsFrom(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = doc.data()?[fieldSlotLockIds];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  static BookingStatus statusFromString(String? value) => switch (value) {
    'confirmed' => BookingStatus.confirmed,
    'cancelled' => BookingStatus.cancelled,
    'completed' => BookingStatus.completed,
    _ => BookingStatus.pending,
  };

  static CancelledBy? cancelledByFromString(String? value) => switch (value) {
    'customer' => CancelledBy.customer,
    'business' => CancelledBy.business,
    _ => null,
  };
}

/// Fields on a slot lock document.
///
/// A lock exists purely to make slot claiming atomic. It carries enough
/// context for the security rules to verify the writer owns the booking it
/// points at.
abstract final class SlotLockMapper {
  static const String fieldBookingId = 'bookingId';
  static const String fieldBusinessId = 'businessId';
  static const String fieldCustomerId = 'customerId';
  static const String fieldSlotStart = 'slotStart';
  static const String fieldCreatedAt = 'createdAt';

  static Map<String, Object?> toPayload({
    required String bookingId,
    required String businessId,
    required String customerId,
    required DateTime slotStart,
  }) => {
    fieldBookingId: bookingId,
    fieldBusinessId: businessId,
    fieldCustomerId: customerId,
    fieldSlotStart: FirestoreTime.fromDateTime(slotStart),
    fieldCreatedAt: FieldValue.serverTimestamp(),
  };
}
