import 'review.dart';

/// What the customer submits.
class ReviewDraft {
  const ReviewDraft({
    required this.bookingId,
    required this.businessId,
    required this.rating,
    this.comment,
  });

  final String bookingId;
  final String businessId;
  final int rating;
  final String? comment;
}

abstract interface class ReviewRepository {
  /// Reviews for a business, newest first.
  Stream<List<Review>> watchBusinessReviews(
    String businessId, {
    int limit = 20,
  });

  Future<List<Review>> getBusinessReviews(String businessId, {int limit = 20});

  /// Writes the review and updates the business's aggregate rating atomically.
  ///
  /// Throws if the booking is not the caller's, is not completed, or has
  /// already been reviewed.
  Future<Review> submitReview(ReviewDraft draft);

  /// The signed-in customer's review of a booking, if there is one.
  Future<Review?> getReviewForBooking(String bookingId);
}
