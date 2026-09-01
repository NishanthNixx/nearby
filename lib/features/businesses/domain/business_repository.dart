import '../../../core/utils/geo.dart';
import 'business.dart';
import 'opening_hours.dart';
import 'service_offering.dart';

/// Parameters for a discovery query.
class NearbyQuery {
  const NearbyQuery({
    required this.radiusKm,
    this.center,
    this.searchTerm,
    this.category = BusinessCategory.tailoring,
    this.openNowOnly = false,
  });

  /// The customer's position. Null when there is no location fix, in which case
  /// the implementation falls back to a non-proximity listing rather than
  /// returning nothing.
  final GeoPoint? center;

  final double radiusKm;

  /// Free-text filter on the business name.
  final String? searchTerm;

  final BusinessCategory category;

  final bool openNowOnly;
}

/// Draft used when an owner creates or edits their listing.
class BusinessDraft {
  const BusinessDraft({
    required this.name,
    required this.address,
    required this.location,
    this.category = BusinessCategory.tailoring,
    this.tagline,
    this.description,
    this.phone,
    this.photoUrl,
    this.galleryUrls,
    this.isAcceptingBookings,
  });

  final String name;
  final String address;
  final GeoPoint location;
  final BusinessCategory category;
  final String? tagline;
  final String? description;
  final String? phone;
  final String? photoUrl;
  final List<String>? galleryUrls;
  final bool? isAcceptingBookings;
}

/// Business listings, their services and their opening hours.
abstract interface class BusinessRepository {
  // --- Discovery -------------------------------------------------------------

  /// Businesses matching [query], nearest first.
  ///
  /// Distance filtering is exact; any cell-based prefilter in the
  /// implementation is an optimisation the caller never sees.
  Future<List<NearbyBusiness>> findNearby(NearbyQuery query);

  // --- Reading a listing -----------------------------------------------------

  Future<Business?> getBusiness(String businessId);

  Stream<Business?> watchBusiness(String businessId);

  /// The listing owned by [ownerId], or null if they have not created one.
  Future<Business?> getBusinessForOwner(String ownerId);

  Stream<Business?> watchBusinessForOwner(String ownerId);

  // --- Editing a listing -----------------------------------------------------

  /// Creates the listing for the signed-in owner and returns it.
  Future<Business> createBusiness(BusinessDraft draft);

  Future<Business> updateBusiness(String businessId, BusinessDraft draft);

  Future<Business> updateOpeningHours(String businessId, OpeningHours hours);

  /// Pauses or resumes taking bookings.
  Future<Business> setAcceptingBookings(String businessId, bool accepting);

  // --- Services --------------------------------------------------------------

  /// Active services only, for the customer-facing profile.
  Future<List<ServiceOffering>> getServices(String businessId);

  Stream<List<ServiceOffering>> watchServices(String businessId);

  /// Every service including inactive ones, for the owner's own management
  /// screen.
  Stream<List<ServiceOffering>> watchAllServices(String businessId);

  Future<ServiceOffering> addService({
    required String businessId,
    required String name,
    required int price,
    required int durationMinutes,
    String? description,
  });

  Future<ServiceOffering> updateService(ServiceOffering service);

  /// Deactivates rather than deletes, so booking history stays intact.
  Future<void> deactivateService({
    required String businessId,
    required String serviceId,
  });

  // --- Images ----------------------------------------------------------------

  /// Uploads image bytes and returns a URL for [Business.photoUrl] or
  /// [Business.galleryUrls]. Bytes rather than a File keeps this testable and
  /// platform-independent.
  Future<String> uploadImage({
    required String businessId,
    required List<int> bytes,
    required String fileExtension,
  });
}
