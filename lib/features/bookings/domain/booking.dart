/// Where an appointment stands.
///
/// Four states, deliberately. Anything richer (rescheduled, no-show, in
/// progress) can be added when there is evidence it is needed.
enum BookingStatus {
  /// Created by the customer, not yet acknowledged by the business.
  pending,

  /// The business has accepted it.
  confirmed,

  /// Called off by either side. Terminal.
  cancelled,

  /// The appointment happened. Terminal, and the point at which the customer
  /// may leave a review.
  completed;

  String get label => switch (this) {
    BookingStatus.pending => 'Awaiting confirmation',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
  };

  /// Short form for a badge.
  String get shortLabel => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
  };

  bool get isTerminal =>
      this == BookingStatus.cancelled || this == BookingStatus.completed;

  /// Whether this state still occupies the slot. Terminal states release it.
  bool get holdsSlot =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;

  /// The transitions the app permits. Enforced in the domain and mirrored in
  /// the security rules, so a client cannot invent a state change.
  bool canTransitionTo(BookingStatus next) => switch (this) {
    BookingStatus.pending =>
      next == BookingStatus.confirmed ||
          next == BookingStatus.cancelled ||
          next == BookingStatus.completed,
    BookingStatus.confirmed =>
      next == BookingStatus.cancelled || next == BookingStatus.completed,
    BookingStatus.cancelled => false,
    BookingStatus.completed => false,
  };
}

/// Who called an appointment off. Shown to the other party so a cancellation
/// is never ambiguous.
enum CancelledBy { customer, business }

/// A booked appointment.
///
/// Service name, price and duration are copied onto the booking rather than
/// referenced. A business editing its price list must not retroactively change
/// what a customer already agreed to, and a deactivated service must still
/// render correctly in booking history.
class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.businessId,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.serviceName,
    required this.servicePrice,
    required this.businessName,
    this.customerName,
    this.customerPhone,
    this.note,
    this.cancelledBy,
    this.cancelledAt,
    this.completedAt,
    this.hasReview = false,
  });

  final String id;
  final String customerId;
  final String businessId;
  final String serviceId;

  /// Local wall-clock start of the appointment.
  final DateTime startTime;
  final DateTime endTime;

  final BookingStatus status;
  final DateTime createdAt;

  // Snapshot of the service and business at the time of booking.
  final String serviceName;
  final int servicePrice;
  final String businessName;

  /// Denormalised so the business's booking list needs one read, not two.
  final String? customerName;
  final String? customerPhone;

  /// Optional free text from the customer: "Need it before Diwali".
  final String? note;

  final CancelledBy? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  /// Whether a review already exists, so the UI does not offer to write a
  /// second one. The authoritative guard is the deterministic review ID.
  final bool hasReview;

  Duration get duration => endTime.difference(startTime);
  int get durationMinutes => duration.inMinutes;

  bool isUpcoming(DateTime now) => status.holdsSlot && endTime.isAfter(now);

  bool isPast(DateTime now) => !isUpcoming(now);

  /// Whether the customer may still call it off.
  ///
  /// Cancelling minutes before the appointment leaves the business with a hole
  /// they cannot fill, so there is a cutoff. Expressed here rather than in the
  /// UI so both roles and the tests agree on one rule.
  bool canCustomerCancel({required DateTime now, required Duration cutoff}) =>
      status.holdsSlot && startTime.subtract(cutoff).isAfter(now);

  /// The business can call it off any time before it starts — they may have an
  /// emergency, and the customer is better off knowing.
  bool canBusinessCancel(DateTime now) =>
      status.holdsSlot && startTime.isAfter(now);

  /// A business marks an appointment done once its end time has passed.
  bool canComplete(DateTime now) => status.holdsSlot && !endTime.isAfter(now);

  /// A review is offered only for a completed appointment with none yet.
  bool get canReview => status == BookingStatus.completed && !hasReview;

  Booking copyWith({
    BookingStatus? status,
    CancelledBy? cancelledBy,
    DateTime? cancelledAt,
    DateTime? completedAt,
    bool? hasReview,
  }) => Booking(
    id: id,
    customerId: customerId,
    businessId: businessId,
    serviceId: serviceId,
    startTime: startTime,
    endTime: endTime,
    status: status ?? this.status,
    createdAt: createdAt,
    serviceName: serviceName,
    servicePrice: servicePrice,
    businessName: businessName,
    customerName: customerName,
    customerPhone: customerPhone,
    note: note,
    cancelledBy: cancelledBy ?? this.cancelledBy,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    completedAt: completedAt ?? this.completedAt,
    hasReview: hasReview ?? this.hasReview,
  );

  @override
  bool operator ==(Object other) => other is Booking && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What the customer is asking for, before it becomes a [Booking].
///
/// Carries only the customer's choices. The repository is responsible for
/// stamping identity, timestamps and the service snapshot, so a client cannot
/// claim a booking belongs to someone else or invent a price.
class BookingRequest {
  const BookingRequest({
    required this.businessId,
    required this.serviceId,
    required this.startTime,
    this.note,
  });

  final String businessId;
  final String serviceId;
  final DateTime startTime;
  final String? note;
}

/// One candidate appointment time.
class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    required this.isAvailable,
  });

  final DateTime start;
  final DateTime end;

  /// False when something already occupies it, or it falls inside the
  /// minimum lead time. Unavailable slots are still rendered — visibly
  /// disabled — because showing a full day as an empty list looks broken.
  final bool isAvailable;

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
