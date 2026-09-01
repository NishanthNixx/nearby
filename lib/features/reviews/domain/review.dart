/// A customer's rating of a business after a completed appointment.
class Review {
  const Review({
    required this.id,
    required this.customerId,
    required this.businessId,
    required this.bookingId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.customerName,
  });

  final String id;
  final String customerId;
  final String businessId;

  /// The appointment being reviewed. One review per booking — enforced by
  /// deriving the review's identifier from this value, so a duplicate write
  /// collides instead of creating a second review.
  final String bookingId;

  /// Whole stars, 1 to 5.
  final int rating;

  final DateTime createdAt;
  final String? comment;

  /// Denormalised for display, so rendering a review list needs one read.
  final String? customerName;

  bool get isValid => rating >= 1 && rating <= 5;

  @override
  bool operator ==(Object other) => other is Review && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A business's aggregate rating.
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  const RatingSummary.empty() : average = 0, count = 0;

  final double average;
  final int count;

  bool get hasRatings => count > 0;

  /// The summary after folding in one more rating.
  ///
  /// Incremental, so adding a review does not require reading every existing
  /// one. Applied inside the same transaction that writes the review, which is
  /// what keeps the counter honest under concurrent writes.
  RatingSummary withAdded(int rating) {
    final total = average * count + rating;
    final newCount = count + 1;
    return RatingSummary(average: total / newCount, count: newCount);
  }
}
