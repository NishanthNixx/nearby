import 'dart:typed_data';

// Firestore exports its own `GeoPoint`. Nearby stores plain latitude and
// longitude numbers instead, so that type is hidden to keep the domain
// `GeoPoint` unambiguous.
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/firebase_error_mapper.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/geo.dart';
import '../domain/business.dart';
import '../domain/business_repository.dart';
import '../domain/opening_hours.dart';
import '../domain/service_offering.dart';
import 'business_mapper.dart';

/// Firestore + Storage implementation of [BusinessRepository].
class FirebaseBusinessRepository implements BusinessRepository {
  FirebaseBusinessRepository({
    required FirebaseFirestore firestore,
    required fb.FirebaseAuth auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore,
       _auth = auth,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseStorage? _storage;

  CollectionReference<Map<String, dynamic>> get _businesses =>
      _firestore.collection(FirestorePaths.businesses);

  CollectionReference<Map<String, dynamic>> _servicesOf(String businessId) =>
      _businesses.doc(businessId).collection(FirestorePaths.services);

  String get _requireUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw AuthFailure.notSignedIn();
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  @override
  Future<List<NearbyBusiness>> findNearby(NearbyQuery query) {
    return FirebaseErrorMapper.guard(() async {
      final center = query.center;

      final businesses = center != null
          ? await _queryByProximity(center, query)
          : await _queryWithoutLocation(query);

      final now = DateTime.now();
      final results = <NearbyBusiness>[];

      for (final business in businesses) {
        if (!business.isPublishable) continue;
        if (query.openNowOnly && !business.isOpenAt(now)) continue;
        if (!_matchesSearchTerm(business, query.searchTerm)) continue;

        final distanceKm = center == null
            ? null
            : GeoDistance.kmBetween(center, business.location);

        // The geohash cells cover more ground than the requested circle, so
        // the exact distance is what actually decides inclusion.
        if (distanceKm != null && distanceKm > query.radiusKm) continue;

        results.add(NearbyBusiness(business: business, distanceKm: distanceKm));
      }

      results.sort(_byDistanceThenRating);
      return results;
    });
  }

  /// Runs one range query per covering geohash cell and merges the results.
  ///
  /// Nine small indexed range scans is the cheapest proximity search Firestore
  /// supports without adding a geospatial service.
  Future<List<Business>> _queryByProximity(
    GeoPoint center,
    NearbyQuery query,
  ) async {
    final prefixes = Geohash.coveringPrefixes(center, query.radiusKm);
    final perCellLimit = (AppConfig.nearbyResultLimit / prefixes.length)
        .ceil()
        .clamp(5, 50);

    final snapshots = await Future.wait(
      prefixes.map(
        (prefix) => _businesses
            .where(BusinessMapper.fieldCategory, isEqualTo: query.category.name)
            .where(BusinessMapper.fieldGeohash, isGreaterThanOrEqualTo: prefix)
            .where(
              BusinessMapper.fieldGeohash,
              isLessThanOrEqualTo: Geohash.rangeEnd(prefix),
            )
            .limit(perCellLimit)
            .get(),
      ),
    );

    // Adjacent prefixes can overlap, so de-duplicate by document id.
    final byId = <String, Business>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        byId[doc.id] = BusinessMapper.fromDocument(doc);
      }
    }
    return byId.values.toList(growable: false);
  }

  /// Fallback when the customer has no location fix.
  ///
  /// Returning nothing would make the app look broken for someone who declined
  /// the location prompt, so it lists by name prefix when they are searching
  /// and by rating otherwise.
  Future<List<Business>> _queryWithoutLocation(NearbyQuery query) async {
    final term = query.searchTerm?.trim().toLowerCase();

    Query<Map<String, dynamic>> base = _businesses.where(
      BusinessMapper.fieldCategory,
      isEqualTo: query.category.name,
    );

    if (term != null && term.isNotEmpty) {
      // '\uf8ff' sorts above any ordinary character, so this pair of bounds
      // selects exactly the names beginning with `term`.
      base = base
          .where(BusinessMapper.fieldNameLower, isGreaterThanOrEqualTo: term)
          .where(BusinessMapper.fieldNameLower, isLessThan: '$term\uf8ff')
          .orderBy(BusinessMapper.fieldNameLower);
    } else {
      base = base.orderBy(BusinessMapper.fieldRatingCount, descending: true);
    }

    final snapshot = await base.limit(AppConfig.nearbyResultLimit).get();
    return snapshot.docs
        .map(BusinessMapper.fromDocument)
        .toList(growable: false);
  }

  /// Substring match on the name, applied on the client.
  ///
  /// Firestore has no substring index. With result sets this small the client
  /// filter is the simpler trade than adding a search service.
  static bool _matchesSearchTerm(Business business, String? term) {
    final needle = term?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return true;
    return business.name.toLowerCase().contains(needle) ||
        (business.tagline?.toLowerCase().contains(needle) ?? false);
  }

  static int _byDistanceThenRating(NearbyBusiness a, NearbyBusiness b) {
    final da = a.distanceKm;
    final db = b.distanceKm;
    if (da != null && db != null) {
      final byDistance = da.compareTo(db);
      if (byDistance != 0) return byDistance;
    }
    return b.business.ratingAverage.compareTo(a.business.ratingAverage);
  }

  // ---------------------------------------------------------------------------
  // Reading a listing
  // ---------------------------------------------------------------------------

  @override
  Future<Business?> getBusiness(String businessId) {
    return FirebaseErrorMapper.guard(() async {
      final doc = await _businesses.doc(businessId).get();
      return doc.exists ? BusinessMapper.fromDocument(doc) : null;
    });
  }

  @override
  Stream<Business?> watchBusiness(String businessId) {
    return FirebaseErrorMapper.guardStream(
      _businesses
          .doc(businessId)
          .snapshots()
          .map((doc) => doc.exists ? BusinessMapper.fromDocument(doc) : null),
    );
  }

  @override
  Future<Business?> getBusinessForOwner(String ownerId) {
    return FirebaseErrorMapper.guard(() async {
      final snapshot = await _businesses
          .where(BusinessMapper.fieldOwnerId, isEqualTo: ownerId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return BusinessMapper.fromDocument(snapshot.docs.first);
    });
  }

  @override
  Stream<Business?> watchBusinessForOwner(String ownerId) {
    return FirebaseErrorMapper.guardStream(
      _businesses
          .where(BusinessMapper.fieldOwnerId, isEqualTo: ownerId)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.isEmpty
                ? null
                : BusinessMapper.fromDocument(snapshot.docs.first),
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Editing a listing
  // ---------------------------------------------------------------------------

  @override
  Future<Business> createBusiness(BusinessDraft draft) {
    return FirebaseErrorMapper.guard(() async {
      final uid = _requireUid;
      _validateDraft(draft);

      // One listing per owner. Checked here for a clear message; the rules
      // enforce it too, since a client check alone is not a guarantee.
      final existing = await getBusinessForOwner(uid);
      if (existing != null) return existing;

      final ref = _businesses.doc();
      await ref.set(BusinessMapper.toCreatePayload(ownerId: uid, draft: draft));

      final doc = await ref.get();
      return BusinessMapper.fromDocument(doc);
    });
  }

  @override
  Future<Business> updateBusiness(String businessId, BusinessDraft draft) {
    return FirebaseErrorMapper.guard(() async {
      _validateDraft(draft);
      await _businesses
          .doc(businessId)
          .update(BusinessMapper.toUpdatePayload(draft));
      final doc = await _businesses.doc(businessId).get();
      return BusinessMapper.fromDocument(doc);
    });
  }

  @override
  Future<Business> updateOpeningHours(String businessId, OpeningHours hours) {
    return FirebaseErrorMapper.guard(() async {
      if (!hours.isValid) {
        throw const ValidationFailure(
          message:
              'Opening hours are not usable. Each open day needs a closing time after its opening time, and at least one day must be open.',
        );
      }

      await _businesses.doc(businessId).update({
        BusinessMapper.fieldOpeningHours: BusinessMapper.hoursToMap(hours),
        BusinessMapper.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });

      final doc = await _businesses.doc(businessId).get();
      return BusinessMapper.fromDocument(doc);
    });
  }

  @override
  Future<Business> setAcceptingBookings(String businessId, bool accepting) {
    return FirebaseErrorMapper.guard(() async {
      await _businesses.doc(businessId).update({
        BusinessMapper.fieldAcceptingBookings: accepting,
        BusinessMapper.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
      final doc = await _businesses.doc(businessId).get();
      return BusinessMapper.fromDocument(doc);
    });
  }

  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  @override
  Future<List<ServiceOffering>> getServices(String businessId) {
    return FirebaseErrorMapper.guard(() async {
      final snapshot = await _servicesOf(
        businessId,
      ).where(BusinessMapper.fieldServiceActive, isEqualTo: true).get();
      return _sortedServices(snapshot, businessId);
    });
  }

  @override
  Stream<List<ServiceOffering>> watchServices(String businessId) {
    return FirebaseErrorMapper.guardStream(
      _servicesOf(businessId)
          .where(BusinessMapper.fieldServiceActive, isEqualTo: true)
          .snapshots()
          .map((snapshot) => _sortedServices(snapshot, businessId)),
    );
  }

  @override
  Stream<List<ServiceOffering>> watchAllServices(String businessId) {
    return FirebaseErrorMapper.guardStream(
      _servicesOf(
        businessId,
      ).snapshots().map((snapshot) => _sortedServices(snapshot, businessId)),
    );
  }

  @override
  Future<ServiceOffering> addService({
    required String businessId,
    required String name,
    required int price,
    required int durationMinutes,
    String? description,
  }) {
    return FirebaseErrorMapper.guard(() async {
      final ref = _servicesOf(businessId).doc();
      final service = ServiceOffering(
        id: ref.id,
        businessId: businessId,
        name: name,
        price: price,
        durationMinutes: durationMinutes,
        isActive: true,
        description: description,
      );

      _validateService(service);

      await ref.set({
        ...BusinessMapper.serviceToPayload(service),
        BusinessMapper.fieldCreatedAt: FieldValue.serverTimestamp(),
      });

      return service;
    });
  }

  @override
  Future<ServiceOffering> updateService(ServiceOffering service) {
    return FirebaseErrorMapper.guard(() async {
      _validateService(service);
      await _servicesOf(
        service.businessId,
      ).doc(service.id).update(BusinessMapper.serviceToPayload(service));
      return service;
    });
  }

  @override
  Future<void> deactivateService({
    required String businessId,
    required String serviceId,
  }) {
    return FirebaseErrorMapper.guard(() async {
      // Deactivated, not deleted: existing bookings reference this service and
      // must keep rendering.
      await _servicesOf(businessId).doc(serviceId).update({
        BusinessMapper.fieldServiceActive: false,
        BusinessMapper.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  List<ServiceOffering> _sortedServices(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String businessId,
  ) {
    final services = snapshot.docs
        .map((doc) => BusinessMapper.serviceFromDocument(doc, businessId))
        .toList();
    // Sorted here rather than with orderBy, so no composite index is needed
    // for a list that is only ever a handful of items long.
    services.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return services;
  }

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------

  @override
  Future<String> uploadImage({
    required String businessId,
    required List<int> bytes,
    required String fileExtension,
  }) {
    return FirebaseErrorMapper.guard(() async {
      final storage = _storage;
      if (storage == null) {
        throw const UnknownFailure();
      }

      final safeExtension = fileExtension.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}.${safeExtension.isEmpty ? 'jpg' : safeExtension}';

      final ref = storage.ref('businesses/$businessId/$filename');
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/$safeExtension'),
      );

      return ref.getDownloadURL();
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateDraft(BusinessDraft draft) {
    final errors = <String, String>{};

    if (draft.name.trim().length < 2) {
      errors['name'] = 'Enter your business name';
    }
    if (draft.address.trim().length < 5) {
      errors['address'] = 'Enter an address customers can find';
    }
    if (!draft.location.isValid) {
      errors['location'] = 'Set your location on the map';
    }

    if (errors.isNotEmpty) {
      throw ValidationFailure(
        message: 'Some details are missing from your business profile.',
        fieldErrors: errors,
      );
    }
  }

  void _validateService(ServiceOffering service) {
    final errors = <String, String>{};

    if (service.name.trim().isEmpty) {
      errors['name'] = 'Enter a service name';
    }
    if (service.price < 0) {
      errors['price'] = 'Price cannot be negative';
    }
    if (service.durationMinutes <= 0) {
      errors['duration'] = 'Set how long this takes';
    }

    if (errors.isNotEmpty) {
      throw ValidationFailure(
        message: 'Check the service details.',
        fieldErrors: errors,
      );
    }
  }
}
