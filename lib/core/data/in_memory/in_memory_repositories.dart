import '../../../features/auth/domain/app_user.dart';
import '../../../features/auth/domain/auth_repository.dart';
import '../../../features/bookings/domain/booking.dart';
import '../../../features/bookings/domain/booking_repository.dart';
import '../../../features/businesses/domain/business.dart';
import '../../../features/businesses/domain/business_repository.dart';
import '../../../features/businesses/domain/opening_hours.dart';
import '../../../features/businesses/domain/service_offering.dart';
import '../../../features/discovery/domain/location_service.dart';
import '../../../features/reviews/domain/review.dart';
import '../../../features/reviews/domain/review_repository.dart';
import '../../config/app_config.dart';
import '../../errors/app_failure.dart';
import '../../utils/geo.dart';
import 'in_memory_store.dart';

/// In-memory [AuthRepository].
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._store);

  final InMemoryStore _store;

  @override
  AppUser? get currentUser {
    final id = _store.signedInUserId;
    return id == null ? null : _store.users[id];
  }

  @override
  Stream<AppUser?> watchAuthState() => _store.watch(() => currentUser);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await _latency();

    final normalised = email.trim().toLowerCase();
    final expected = _store.passwords[normalised];

    if (expected == null || expected != password) {
      throw AuthFailure.invalidCredentials();
    }

    final user = _store.users.values.firstWhere(
      (u) => u.email.toLowerCase() == normalised,
    );

    _store.signedInUserId = user.id;
    _store.notifyChanged();
    return user;
  }

  @override
  Future<AppUser> signUp(SignUpRequest request) async {
    await _latency();

    final normalised = request.email.trim().toLowerCase();
    final errors = <String, String>{};

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalised)) {
      errors['email'] = 'Enter a valid email address';
    }
    if (request.password.length < 8) {
      errors['password'] = 'Use at least 8 characters';
    }
    if (request.displayName.trim().isEmpty) {
      errors['displayName'] = 'Enter your name';
    }
    if (errors.isNotEmpty) {
      throw ValidationFailure(
        message: 'Some details need fixing before you can continue.',
        fieldErrors: errors,
      );
    }
    if (_store.passwords.containsKey(normalised)) {
      throw AuthFailure.emailAlreadyInUse();
    }

    final user = AppUser(
      id: _store.nextId('user'),
      email: normalised,
      role: request.role,
      createdAt: DateTime.now(),
      displayName: request.displayName.trim(),
      phone: request.phone?.trim(),
    );

    _store.users[user.id] = user;
    _store.passwords[normalised] = request.password;
    _store.signedInUserId = user.id;
    _store.notifyChanged();
    return user;
  }

  @override
  Future<void> signOut() async {
    _store.signedInUserId = null;
    _store.notifyChanged();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _latency();
    // Succeeds regardless, matching the real implementation's refusal to
    // reveal whether an address has an account.
  }

  @override
  Future<AppUser> updateProfile({
    String? displayName,
    String? phone,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw AuthFailure.notSignedIn();

    final updated = user.copyWith(
      displayName: displayName?.trim(),
      phone: phone?.trim(),
      photoUrl: photoUrl,
    );

    _store.users[user.id] = updated;
    _store.notifyChanged();
    return updated;
  }

  @override
  Future<AppUser> linkBusiness(String businessId) async {
    final user = currentUser;
    if (user == null) throw AuthFailure.notSignedIn();

    final updated = user.copyWith(businessId: businessId);
    _store.users[user.id] = updated;
    _store.notifyChanged();
    return updated;
  }
}

/// In-memory [BusinessRepository].
class InMemoryBusinessRepository implements BusinessRepository {
  InMemoryBusinessRepository(this._store);

  final InMemoryStore _store;

  String get _requireUid {
    final id = _store.signedInUserId;
    if (id == null) throw AuthFailure.notSignedIn();
    return id;
  }

  @override
  Future<List<NearbyBusiness>> findNearby(NearbyQuery query) async {
    await _latency();

    final now = DateTime.now();
    final needle = query.searchTerm?.trim().toLowerCase();

    final results = <NearbyBusiness>[];

    for (final business in _store.businesses.values) {
      if (business.category != query.category) continue;
      if (!business.isPublishable) continue;
      if (query.openNowOnly && !business.isOpenAt(now)) continue;

      if (needle != null && needle.isNotEmpty) {
        final matches =
            business.name.toLowerCase().contains(needle) ||
            (business.tagline?.toLowerCase().contains(needle) ?? false);
        if (!matches) continue;
      }

      final distanceKm = query.center == null
          ? null
          : GeoDistance.kmBetween(query.center!, business.location);

      if (distanceKm != null && distanceKm > query.radiusKm) continue;

      results.add(NearbyBusiness(business: business, distanceKm: distanceKm));
    }

    results.sort((a, b) {
      final da = a.distanceKm;
      final db = b.distanceKm;
      if (da != null && db != null) {
        final byDistance = da.compareTo(db);
        if (byDistance != 0) return byDistance;
      }
      return b.business.ratingAverage.compareTo(a.business.ratingAverage);
    });

    return results;
  }

  @override
  Future<Business?> getBusiness(String businessId) async {
    await _latency();
    return _store.businesses[businessId];
  }

  @override
  Stream<Business?> watchBusiness(String businessId) =>
      _store.watch(() => _store.businesses[businessId]);

  @override
  Future<Business?> getBusinessForOwner(String ownerId) async {
    await _latency();
    return _businessForOwner(ownerId);
  }

  @override
  Stream<Business?> watchBusinessForOwner(String ownerId) =>
      _store.watch(() => _businessForOwner(ownerId));

  Business? _businessForOwner(String ownerId) {
    for (final business in _store.businesses.values) {
      if (business.ownerId == ownerId) return business;
    }
    return null;
  }

  @override
  Future<Business> createBusiness(BusinessDraft draft) async {
    final uid = _requireUid;

    final existing = _businessForOwner(uid);
    if (existing != null) return existing;

    final business = Business(
      id: _store.nextId('biz'),
      ownerId: uid,
      name: draft.name.trim(),
      category: draft.category,
      location: draft.location,
      geohash: Geohash.encode(draft.location),
      address: draft.address.trim(),
      openingHours: OpeningHours.standard(),
      isAcceptingBookings: draft.isAcceptingBookings ?? true,
      createdAt: DateTime.now(),
      tagline: draft.tagline?.trim(),
      description: draft.description?.trim(),
      phone: draft.phone?.trim(),
      photoUrl: draft.photoUrl,
      galleryUrls: draft.galleryUrls ?? const [],
    );

    _store.businesses[business.id] = business;
    _store.notifyChanged();
    return business;
  }

  @override
  Future<Business> updateBusiness(
    String businessId,
    BusinessDraft draft,
  ) async {
    final existing = _store.businesses[businessId];
    if (existing == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(existing);

    final updated = existing.copyWith(
      name: draft.name.trim(),
      category: draft.category,
      location: draft.location,
      geohash: Geohash.encode(draft.location),
      address: draft.address.trim(),
      tagline: draft.tagline?.trim(),
      description: draft.description?.trim(),
      phone: draft.phone?.trim(),
      photoUrl: draft.photoUrl,
      galleryUrls: draft.galleryUrls,
      isAcceptingBookings: draft.isAcceptingBookings,
    );

    _store.businesses[businessId] = updated;
    _store.notifyChanged();
    return updated;
  }

  @override
  Future<Business> updateOpeningHours(
    String businessId,
    OpeningHours hours,
  ) async {
    final existing = _store.businesses[businessId];
    if (existing == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(existing);

    if (!hours.isValid) {
      throw const ValidationFailure(
        message:
            'Opening hours are not usable. Each open day needs a closing time after its opening time, and at least one day must be open.',
      );
    }

    final updated = existing.copyWith(openingHours: hours);
    _store.businesses[businessId] = updated;
    _store.notifyChanged();
    return updated;
  }

  @override
  Future<Business> setAcceptingBookings(
    String businessId,
    bool accepting,
  ) async {
    final existing = _store.businesses[businessId];
    if (existing == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(existing);

    final updated = existing.copyWith(isAcceptingBookings: accepting);
    _store.businesses[businessId] = updated;
    _store.notifyChanged();
    return updated;
  }

  @override
  Future<List<ServiceOffering>> getServices(String businessId) async {
    await _latency();
    return _servicesOf(businessId, activeOnly: true);
  }

  @override
  Stream<List<ServiceOffering>> watchServices(String businessId) =>
      _store.watch(() => _servicesOf(businessId, activeOnly: true));

  @override
  Stream<List<ServiceOffering>> watchAllServices(String businessId) =>
      _store.watch(() => _servicesOf(businessId, activeOnly: false));

  List<ServiceOffering> _servicesOf(
    String businessId, {
    required bool activeOnly,
  }) {
    final result = _store.services.values
        .where((s) => s.businessId == businessId)
        .where((s) => !activeOnly || s.isActive)
        .toList();

    result.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  @override
  Future<ServiceOffering> addService({
    required String businessId,
    required String name,
    required int price,
    required int durationMinutes,
    String? description,
  }) async {
    final business = _store.businesses[businessId];
    if (business == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(business);

    final service = ServiceOffering(
      id: _store.nextId('svc'),
      businessId: businessId,
      name: name.trim(),
      price: price,
      durationMinutes: durationMinutes,
      isActive: true,
      description: description?.trim(),
    );

    if (!service.isValid) {
      throw const ValidationFailure(message: 'Check the service details.');
    }

    _store.services[service.id] = service;
    _store.notifyChanged();
    return service;
  }

  @override
  Future<ServiceOffering> updateService(ServiceOffering service) async {
    final business = _store.businesses[service.businessId];
    if (business == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(business);

    if (!service.isValid) {
      throw const ValidationFailure(message: 'Check the service details.');
    }

    _store.services[service.id] = service;
    _store.notifyChanged();
    return service;
  }

  @override
  Future<void> deactivateService({
    required String businessId,
    required String serviceId,
  }) async {
    final business = _store.businesses[businessId];
    if (business == null) throw const NotFoundFailure(what: 'business');
    _requireOwnership(business);

    final service = _store.services[serviceId];
    if (service == null) return;

    _store.services[serviceId] = service.copyWith(isActive: false);
    _store.notifyChanged();
  }

  @override
  Future<String> uploadImage({
    required String businessId,
    required List<int> bytes,
    required String fileExtension,
  }) async {
    await _latency();
    // No object store here. A stable placeholder URL keeps the flow intact so
    // the gallery screens can still be exercised.
    return 'memory://businesses/$businessId/${_store.nextId('img')}.$fileExtension';
  }

  void _requireOwnership(Business business) {
    if (business.ownerId != _store.signedInUserId) {
      throw const PermissionDeniedFailure();
    }
  }
}

/// In-memory [BookingRepository].
///
/// Slot claiming uses the same deterministic lock keys as the Firestore
/// implementation, so the duplicate-booking guarantee is exercised here too.
class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository(this._store);

  final InMemoryStore _store;

  String get _requireUid {
    final id = _store.signedInUserId;
    if (id == null) throw AuthFailure.notSignedIn();
    return id;
  }

  @override
  Stream<List<Booking>> watchCustomerBookings() =>
      _store.watch(() => _customerBookings());

  @override
  Future<List<Booking>> getCustomerBookings() async {
    await _latency();
    return _customerBookings();
  }

  List<Booking> _customerBookings() {
    final uid = _store.signedInUserId;
    if (uid == null) return const [];

    final result =
        _store.bookings.values.where((b) => b.customerId == uid).toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }

  @override
  Stream<List<Booking>> watchBusinessBookings(String businessId) =>
      _store.watch(() {
        final result =
            _store.bookings.values
                .where((b) => b.businessId == businessId)
                .toList()
              ..sort((a, b) => b.startTime.compareTo(a.startTime));
        return result;
      });

  @override
  Future<List<Booking>> getBookingsForDay({
    required String businessId,
    required DateTime date,
  }) async {
    await _latency();

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _store.bookings.values
        .where((b) => b.businessId == businessId)
        .where(
          (b) => b.endTime.isAfter(dayStart) && b.startTime.isBefore(dayEnd),
        )
        .toList(growable: false);
  }

  @override
  Future<Booking?> getBooking(String bookingId) async {
    await _latency();
    return _store.bookings[bookingId];
  }

  @override
  Future<Booking> createBooking(BookingRequest request) async {
    final uid = _requireUid;
    await _latency();

    final business = _store.businesses[request.businessId];
    if (business == null) throw const NotFoundFailure(what: 'tailor');

    final service = _store.services[request.serviceId];
    if (service == null) throw const NotFoundFailure(what: 'service');

    if (!business.isAcceptingBookings) {
      throw const BusinessUnavailableFailure();
    }
    if (!service.isActive) {
      throw const InvalidBookingFailure(
        message: 'This service is no longer offered. Choose another one.',
      );
    }

    final startTime = request.startTime;
    final endTime = startTime.add(Duration(minutes: service.durationMinutes));

    if (startTime.isBefore(
      DateTime.now().add(AppConfig.minimumBookingLeadTime),
    )) {
      throw const InvalidBookingFailure(
        message:
            'That time is too soon. Pick a slot at least half an hour from now.',
      );
    }
    if (!business.openingHours.tradesOn(startTime)) {
      throw const InvalidBookingFailure(
        message: 'The tailor is closed on that day.',
      );
    }

    final lockIds = slotLockKeys(
      businessId: request.businessId,
      startTime: startTime,
      endTime: endTime,
      cadenceMinutes: business.openingHours.slotDurationMinutes,
    );

    // The check and the claim happen with no await between them, so this is
    // atomic with respect to Dart's single-threaded event loop — the same
    // guarantee the Firestore transaction provides.
    if (lockIds.any(_store.slotLocks.contains)) {
      throw const SlotUnavailableFailure();
    }

    final customer = _store.users[uid];

    final booking = Booking(
      id: _store.nextId('bkg'),
      customerId: uid,
      businessId: request.businessId,
      serviceId: request.serviceId,
      startTime: startTime,
      endTime: endTime,
      status: BookingStatus.pending,
      createdAt: DateTime.now(),
      serviceName: service.name,
      servicePrice: service.price,
      businessName: business.name,
      customerName: customer?.name,
      customerPhone: customer?.phone,
      note: request.note?.trim().isEmpty ?? true ? null : request.note!.trim(),
    );

    _store.slotLocks.addAll(lockIds);
    _store.bookings[booking.id] = booking;
    _lockIdsByBooking[booking.id] = lockIds;
    _store.notifyChanged();

    return booking;
  }

  final Map<String, List<String>> _lockIdsByBooking = {};

  /// Mirrors the Firestore repository's lock key derivation.
  static List<String> slotLockKeys({
    required String businessId,
    required DateTime startTime,
    required DateTime endTime,
    required int cadenceMinutes,
  }) {
    final cadence = cadenceMinutes <= 0
        ? AppConfig.defaultSlotDurationMinutes
        : cadenceMinutes;
    final step = Duration(minutes: cadence);

    final keys = <String>[];
    for (var slot = startTime; slot.isBefore(endTime); slot = slot.add(step)) {
      keys.add(
        FirestorePaths.slotLockId(businessId: businessId, startTimeUtc: slot),
      );
    }
    if (keys.isEmpty) {
      keys.add(
        FirestorePaths.slotLockId(
          businessId: businessId,
          startTimeUtc: startTime,
        ),
      );
    }
    return keys;
  }

  @override
  Future<Booking> confirmBooking(String bookingId) =>
      _transition(bookingId, BookingStatus.confirmed);

  @override
  Future<Booking> completeBooking(String bookingId) =>
      _transition(bookingId, BookingStatus.completed);

  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    required CancelledBy by,
  }) async {
    final booking = _store.bookings[bookingId];
    if (booking == null) throw const NotFoundFailure(what: 'booking');

    if (!booking.status.canTransitionTo(BookingStatus.cancelled)) {
      throw InvalidBookingFailure(
        message:
            'This appointment is already ${booking.status.shortLabel.toLowerCase()} and cannot be cancelled.',
      );
    }

    if (by == CancelledBy.customer &&
        !booking.canCustomerCancel(
          now: DateTime.now(),
          cutoff: AppConfig.cancellationCutoff,
        )) {
      throw const InvalidBookingFailure(
        message:
            'Appointments can only be cancelled more than two hours ahead. Call the tailor to let them know.',
      );
    }

    final updated = booking.copyWith(
      status: BookingStatus.cancelled,
      cancelledBy: by,
      cancelledAt: DateTime.now(),
    );

    _store.bookings[bookingId] = updated;

    // Releasing the locks is what makes the slot bookable again.
    for (final lockId
        in _lockIdsByBooking.remove(bookingId) ?? const <String>[]) {
      _store.slotLocks.remove(lockId);
    }

    _store.notifyChanged();
    return updated;
  }

  Future<Booking> _transition(String bookingId, BookingStatus next) async {
    final booking = _store.bookings[bookingId];
    if (booking == null) throw const NotFoundFailure(what: 'booking');

    if (!booking.status.canTransitionTo(next)) {
      throw InvalidBookingFailure(
        message:
            'This appointment cannot go from ${booking.status.shortLabel.toLowerCase()} to ${next.shortLabel.toLowerCase()}.',
      );
    }
    if (next == BookingStatus.completed &&
        !booking.canComplete(DateTime.now())) {
      throw const InvalidBookingFailure(
        message:
            'This appointment has not finished yet, so it cannot be marked completed.',
      );
    }

    final updated = booking.copyWith(
      status: next,
      completedAt: next == BookingStatus.completed ? DateTime.now() : null,
    );

    _store.bookings[bookingId] = updated;
    _store.notifyChanged();
    return updated;
  }
}

/// In-memory [ReviewRepository].
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository(this._store);

  final InMemoryStore _store;

  @override
  Stream<List<Review>> watchBusinessReviews(
    String businessId, {
    int limit = 20,
  }) => _store.watch(() => _reviewsOf(businessId, limit));

  @override
  Future<List<Review>> getBusinessReviews(
    String businessId, {
    int limit = 20,
  }) async {
    await _latency();
    return _reviewsOf(businessId, limit);
  }

  List<Review> _reviewsOf(String businessId, int limit) {
    final result =
        _store.reviews.values.where((r) => r.businessId == businessId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<Review?> getReviewForBooking(String bookingId) async {
    await _latency();
    for (final review in _store.reviews.values) {
      if (review.bookingId == bookingId) return review;
    }
    return null;
  }

  @override
  Future<Review> submitReview(ReviewDraft draft) async {
    final uid = _store.signedInUserId;
    if (uid == null) throw AuthFailure.notSignedIn();

    if (draft.rating < 1 || draft.rating > 5) {
      throw const ValidationFailure(
        message: 'Choose between one and five stars.',
      );
    }

    final booking = _store.bookings[draft.bookingId];
    if (booking == null) throw const NotFoundFailure(what: 'appointment');
    if (booking.customerId != uid) throw const PermissionDeniedFailure();
    if (booking.status != BookingStatus.completed) {
      throw const InvalidBookingFailure(
        message:
            'You can leave a review once the appointment has been completed.',
      );
    }

    final duplicate = await getReviewForBooking(draft.bookingId);
    if (duplicate != null) {
      throw const InvalidBookingFailure(
        message: 'You have already reviewed this appointment.',
      );
    }

    final review = Review(
      id: _store.nextId('rev'),
      customerId: uid,
      businessId: draft.businessId,
      bookingId: draft.bookingId,
      rating: draft.rating,
      createdAt: DateTime.now(),
      comment: draft.comment?.trim().isEmpty ?? true
          ? null
          : draft.comment!.trim(),
      customerName: _store.users[uid]?.name,
    );

    _store.reviews[review.id] = review;
    _store.bookings[booking.id] = booking.copyWith(hasReview: true);

    // In the Firebase build a Cloud Function owns this aggregate, because a
    // client that can write its own rating can inflate it. Here there is no
    // server, so the store applies the same incremental update directly.
    final business = _store.businesses[draft.businessId];
    if (business != null) {
      final summary = RatingSummary(
        average: business.ratingAverage,
        count: business.ratingCount,
      ).withAdded(draft.rating);

      _store.businesses[business.id] = business.copyWith(
        ratingAverage: summary.average,
        ratingCount: summary.count,
      );
    }

    _store.notifyChanged();
    return review;
  }
}

/// A [LocationService] that returns a fixed position.
///
/// Lets the discovery screen be driven in tests and on a simulator with no
/// location permission dialog.
class FixedLocationService implements LocationService {
  const FixedLocationService({
    this.position = const GeoPoint(latitude: 12.9716, longitude: 77.5946),
    this.failure,
  });

  final GeoPoint position;

  /// When set, every call throws this instead — used to exercise the
  /// permission-denied states.
  final LocationFailure? failure;

  @override
  Future<GeoPoint> getCurrentPosition() async {
    await _latency();
    final f = failure;
    if (f != null) throw f;
    return position;
  }

  @override
  Future<GeoPoint?> getLastKnownPosition() async =>
      failure == null ? position : null;

  @override
  Future<bool> hasPermission() async => failure == null;

  @override
  Future<bool> requestPermission() async => failure == null;

  @override
  Future<void> openAppSettings() async {}
}

/// Artificial read latency for the in-memory backend.
///
/// A real delay is what makes the loading and skeleton states reachable when
/// running the app against sample data — without it every screen would snap
/// straight to its final state and those paths would never be seen.
///
/// Tests set this to [Duration.zero] when they only care about the settled
/// result, so no timer is left pending, and set it back when they want to
/// observe a loading state.
Duration inMemoryLatency = const Duration(milliseconds: 260);

Future<void> _latency() {
  if (inMemoryLatency == Duration.zero) return Future<void>.value();
  return Future<void>.delayed(inMemoryLatency);
}
