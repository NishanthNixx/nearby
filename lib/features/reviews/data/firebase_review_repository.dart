import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/config/app_config.dart';
import '../../../core/data/firebase_error_mapper.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/data/user_mapper.dart';
import '../../bookings/data/booking_mapper.dart';
import '../../bookings/domain/booking.dart';
import '../domain/review.dart';
import '../domain/review_repository.dart';

/// Firestore implementation of [ReviewRepository].
///
/// Two things make duplicate reviews impossible: the review document's ID is
/// derived from the booking ID, so a second write collides rather than adding a
/// row; and the booking's `hasReview` flag is flipped in the same transaction.
///
/// The business's aggregate rating is deliberately *not* written here. Letting
/// a client write a rating average would let anyone set their own score, so
/// that field is denied to clients in the security rules and maintained by a
/// Cloud Function that reacts to review creation. This is one of the few places
/// where server-side logic is genuinely required.
class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({
    required FirebaseFirestore firestore,
    required fb.FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  static const String _fieldCustomerId = 'customerId';
  static const String _fieldBusinessId = 'businessId';
  static const String _fieldBookingId = 'bookingId';
  static const String _fieldRating = 'rating';
  static const String _fieldComment = 'comment';
  static const String _fieldCustomerName = 'customerName';
  static const String _fieldCreatedAt = 'createdAt';

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection(FirestorePaths.reviews);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirestorePaths.bookings);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  String get _requireUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw AuthFailure.notSignedIn();
    return uid;
  }

  /// One review per booking, expressed as the document's identity.
  static String reviewIdFor(String bookingId) => 'booking_$bookingId';

  @override
  Stream<List<Review>> watchBusinessReviews(
    String businessId, {
    int limit = 20,
  }) {
    return FirebaseErrorMapper.guardStream(
      _reviews
          .where(_fieldBusinessId, isEqualTo: businessId)
          .orderBy(_fieldCreatedAt, descending: true)
          .limit(limit)
          .snapshots()
          .map(_toReviews),
    );
  }

  @override
  Future<List<Review>> getBusinessReviews(String businessId, {int limit = 20}) {
    return FirebaseErrorMapper.guard(() async {
      final snapshot = await _reviews
          .where(_fieldBusinessId, isEqualTo: businessId)
          .orderBy(_fieldCreatedAt, descending: true)
          .limit(limit)
          .get();
      return _toReviews(snapshot);
    });
  }

  @override
  Future<Review?> getReviewForBooking(String bookingId) {
    return FirebaseErrorMapper.guard(() async {
      final doc = await _reviews.doc(reviewIdFor(bookingId)).get();
      return doc.exists ? _fromDocument(doc) : null;
    });
  }

  @override
  Future<Review> submitReview(ReviewDraft draft) {
    return FirebaseErrorMapper.guard(() async {
      final uid = _requireUid;
      _validate(draft);

      final reviewRef = _reviews.doc(reviewIdFor(draft.bookingId));
      final bookingRef = _bookings.doc(draft.bookingId);

      final customerDoc = await _users.doc(uid).get();
      final customerName = customerDoc.exists
          ? UserMapper.fromDocument(customerDoc).name
          : null;

      return _firestore.runTransaction<Review>((transaction) async {
        final bookingDoc = await transaction.get(bookingRef);
        if (!bookingDoc.exists) {
          throw const NotFoundFailure(what: 'appointment');
        }

        final booking = BookingMapper.fromDocument(bookingDoc);

        if (booking.customerId != uid) {
          throw const PermissionDeniedFailure();
        }
        if (booking.status != BookingStatus.completed) {
          throw const InvalidBookingFailure(
            message:
                'You can leave a review once the appointment has been completed.',
          );
        }
        if (booking.businessId != draft.businessId) {
          throw const PermissionDeniedFailure();
        }

        final existing = await transaction.get(reviewRef);
        if (existing.exists) {
          throw const InvalidBookingFailure(
            message: 'You have already reviewed this appointment.',
          );
        }

        final createdAt = DateTime.now();

        transaction.set(reviewRef, {
          _fieldCustomerId: uid,
          _fieldBusinessId: draft.businessId,
          _fieldBookingId: draft.bookingId,
          _fieldRating: draft.rating,
          _fieldComment: draft.comment?.trim().isEmpty ?? true
              ? null
              : draft.comment!.trim(),
          _fieldCustomerName: customerName,
          _fieldCreatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(bookingRef, {BookingMapper.fieldHasReview: true});

        return Review(
          id: reviewRef.id,
          customerId: uid,
          businessId: draft.businessId,
          bookingId: draft.bookingId,
          rating: draft.rating,
          createdAt: createdAt,
          comment: draft.comment,
          customerName: customerName,
        );
      });
    });
  }

  void _validate(ReviewDraft draft) {
    final errors = <String, String>{};

    if (draft.rating < 1 || draft.rating > 5) {
      errors['rating'] = 'Choose between one and five stars';
    }
    if ((draft.comment?.length ?? 0) > AppConfig.maxReviewLength) {
      errors['comment'] =
          'Keep your review under ${AppConfig.maxReviewLength} characters';
    }

    if (errors.isNotEmpty) {
      throw ValidationFailure(
        message: 'Check your review before submitting.',
        fieldErrors: errors,
      );
    }
  }

  Review _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Review(
      id: doc.id,
      customerId: (data[_fieldCustomerId] as String?) ?? '',
      businessId: (data[_fieldBusinessId] as String?) ?? '',
      bookingId: (data[_fieldBookingId] as String?) ?? '',
      rating: (data[_fieldRating] as num?)?.round() ?? 0,
      createdAt: FirestoreTime.toDateTimeOr(
        data[_fieldCreatedAt],
        DateTime.now(),
      ),
      comment: data[_fieldComment] as String?,
      customerName: data[_fieldCustomerName] as String?,
    );
  }

  List<Review> _toReviews(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map(_fromDocument).toList(growable: false);
}
