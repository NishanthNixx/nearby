import '../../../core/utils/geo.dart';
import 'opening_hours.dart';

/// Which vertical a business belongs to.
///
/// Only [tailoring] exists in the MVP. The enum is here because a business
/// record is meaningless without saying what kind of business it is — not as
/// scaffolding for verticals that do not exist yet. Adding one later is a new
/// enum value plus its own presentation, with no change to this model.
enum BusinessCategory {
  tailoring;

  String get label => switch (this) {
    BusinessCategory.tailoring => 'Tailoring',
  };
}

/// A local business listing.
///
/// Named [Business], not `Tailor`: the platform concept is a business that
/// offers services and takes bookings, and the tailoring specifics live in
/// [BusinessCategory] and the services it lists.
class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.location,
    required this.geohash,
    required this.address,
    required this.openingHours,
    required this.isAcceptingBookings,
    required this.createdAt,
    this.tagline,
    this.description,
    this.phone,
    this.photoUrl,
    this.galleryUrls = const [],
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  final String id;

  /// The [AppUser.id] allowed to edit this listing. Security rules key off it.
  final String ownerId;

  final String name;
  final BusinessCategory category;

  final GeoPoint location;

  /// Geohash of [location], stored so a proximity search is a range query on
  /// one indexed field. Always kept in sync with [location] by the data layer.
  final String geohash;

  /// Human-readable address for display and directions.
  final String address;

  final OpeningHours openingHours;

  /// An owner can pause bookings without deleting their listing — useful when
  /// they are away, and gentler than being delisted.
  final bool isAcceptingBookings;

  final DateTime createdAt;

  /// One line under the name: "Men's & women's tailoring".
  final String? tagline;

  final String? description;
  final String? phone;

  /// Main image. Also used as the discovery card thumbnail.
  final String? photoUrl;

  final List<String> galleryUrls;

  /// Aggregate rating, maintained by the reviews layer. Read-only here.
  final double ratingAverage;
  final int ratingCount;

  bool get hasRating => ratingCount > 0;

  /// Whether the listing is complete enough to show to customers.
  bool get isPublishable =>
      name.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      location.isValid &&
      openingHours.isValid;

  /// Open by the clock *and* willing to take bookings.
  bool isOpenAt(DateTime moment) =>
      isAcceptingBookings && openingHours.isOpenAt(moment);

  Business copyWith({
    String? name,
    BusinessCategory? category,
    GeoPoint? location,
    String? geohash,
    String? address,
    OpeningHours? openingHours,
    bool? isAcceptingBookings,
    String? tagline,
    String? description,
    String? phone,
    String? photoUrl,
    List<String>? galleryUrls,
    double? ratingAverage,
    int? ratingCount,
  }) => Business(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    category: category ?? this.category,
    location: location ?? this.location,
    geohash: geohash ?? this.geohash,
    address: address ?? this.address,
    openingHours: openingHours ?? this.openingHours,
    isAcceptingBookings: isAcceptingBookings ?? this.isAcceptingBookings,
    createdAt: createdAt,
    tagline: tagline ?? this.tagline,
    description: description ?? this.description,
    phone: phone ?? this.phone,
    photoUrl: photoUrl ?? this.photoUrl,
    galleryUrls: galleryUrls ?? this.galleryUrls,
    ratingAverage: ratingAverage ?? this.ratingAverage,
    ratingCount: ratingCount ?? this.ratingCount,
  );

  @override
  bool operator ==(Object other) => other is Business && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A business paired with how far away it is from the customer.
///
/// Distance is not a property of a business — it depends who is asking — so it
/// is attached at query time rather than stored on [Business].
class NearbyBusiness {
  const NearbyBusiness({required this.business, required this.distanceKm});

  final Business business;

  /// Kilometres from the customer's location. Null when the customer has no
  /// location fix and results are unsorted by distance.
  final double? distanceKm;
}
