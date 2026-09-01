import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../reviews/domain/review.dart';
import '../domain/business.dart';
import '../domain/service_offering.dart';

/// A single business listing, kept live.
///
/// A stream rather than a one-shot read so an owner editing their hours is
/// reflected on a customer's open profile without a manual refresh.
final businessProvider = StreamProvider.family<Business?, String>((ref, id) {
  return ref.watch(businessRepositoryProvider).watchBusiness(id);
});

/// The active services a business offers.
final businessServicesProvider =
    StreamProvider.family<List<ServiceOffering>, String>((ref, id) {
      return ref.watch(businessRepositoryProvider).watchServices(id);
    });

/// Recent reviews for a business.
final businessReviewsProvider = StreamProvider.family<List<Review>, String>((
  ref,
  id,
) {
  return ref.watch(reviewRepositoryProvider).watchBusinessReviews(id);
});

/// The business owned by the signed-in user.
///
/// Every owner screen reads from this, so the owner's own listing is fetched
/// once and shared.
final myBusinessProvider = StreamProvider<Business?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.role.isBusinessOwner) {
    return Stream.value(null);
  }
  return ref.watch(businessRepositoryProvider).watchBusinessForOwner(user.id);
});

/// Every service on the owner's listing, including deactivated ones.
final myServicesProvider = StreamProvider<List<ServiceOffering>>((ref) {
  final business = ref.watch(myBusinessProvider).value;
  if (business == null) return Stream.value(const []);
  return ref.watch(businessRepositoryProvider).watchAllServices(business.id);
});

/// Services for a business, fetched once for use as a preview.
///
/// A one-shot read rather than a stream: the discovery list shows a couple of
/// prices per card, and holding a live listener open for every visible card
/// would cost far more than the freshness is worth. The profile screen uses
/// [businessServicesProvider] where live updates do matter.
final businessServicesPreviewProvider =
    FutureProvider.family<List<ServiceOffering>, String>((ref, id) {
      return ref.watch(businessRepositoryProvider).getServices(id);
    });
