import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/bookings/data/firebase_booking_repository.dart';
import '../../features/bookings/domain/booking_repository.dart';
import '../../features/businesses/data/firebase_business_repository.dart';
import '../../features/businesses/domain/business_repository.dart';
import '../../features/discovery/data/geolocator_location_service.dart';
import '../../features/discovery/domain/location_service.dart';
import '../../features/notifications/data/fcm_push_notification_service.dart';
import '../../features/notifications/domain/push_notification_service.dart';
import '../../features/reviews/data/firebase_review_repository.dart';
import '../../features/reviews/domain/review_repository.dart';
import '../config/app_config.dart';
import '../data/in_memory/in_memory_repositories.dart';
import '../data/in_memory/in_memory_store.dart';

/// Composition root.
///
/// Every provider here returns an *interface*. Which implementation backs it is
/// decided in one place, from [AppConfig.dataSource]. That is what makes the
/// eventual REST + PostgreSQL migration a matter of adding a third branch here
/// rather than touching the screens.

// -----------------------------------------------------------------------------
// Firebase handles
//
// Read lazily, so nothing touches Firebase when the app is running against the
// in-memory backend.
// -----------------------------------------------------------------------------

final firebaseAuthProvider = Provider<fb.FirebaseAuth>(
  (ref) => fb.FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

// -----------------------------------------------------------------------------
// In-memory backend
// -----------------------------------------------------------------------------

/// The shared in-memory store. Overridden in tests to seed a specific scenario.
final inMemoryStoreProvider = Provider<InMemoryStore>((ref) {
  final store = InMemoryStore();
  ref.onDispose(store.dispose);
  return store;
});

// -----------------------------------------------------------------------------
// Repositories
// -----------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => FirebaseAuthRepository(
      auth: ref.watch(firebaseAuthProvider),
      firestore: ref.watch(firestoreProvider),
    ),
    DataSource.inMemory => InMemoryAuthRepository(
      ref.watch(inMemoryStoreProvider),
    ),
  };
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => FirebaseBusinessRepository(
      firestore: ref.watch(firestoreProvider),
      auth: ref.watch(firebaseAuthProvider),
      storage: ref.watch(firebaseStorageProvider),
    ),
    DataSource.inMemory => InMemoryBusinessRepository(
      ref.watch(inMemoryStoreProvider),
    ),
  };
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => FirebaseBookingRepository(
      firestore: ref.watch(firestoreProvider),
      auth: ref.watch(firebaseAuthProvider),
    ),
    DataSource.inMemory => InMemoryBookingRepository(
      ref.watch(inMemoryStoreProvider),
    ),
  };
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => FirebaseReviewRepository(
      firestore: ref.watch(firestoreProvider),
      auth: ref.watch(firebaseAuthProvider),
    ),
    DataSource.inMemory => InMemoryReviewRepository(
      ref.watch(inMemoryStoreProvider),
    ),
  };
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => const GeolocatorLocationService(),
    // A fixed position, so the in-memory build can be driven on a simulator
    // with no permission dialog.
    DataSource.inMemory => const FixedLocationService(),
  };
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return switch (AppConfig.dataSource) {
    DataSource.firebase => FcmPushNotificationService(
      messaging: ref.watch(firebaseMessagingProvider),
      firestore: ref.watch(firestoreProvider),
    ),
    DataSource.inMemory => const NoopPushNotificationService(),
  };
});

// -----------------------------------------------------------------------------
// Auth state
// -----------------------------------------------------------------------------

/// The signed-in user, or null. The single source of truth for routing.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

/// The current user once resolved, without the loading wrapper. Convenient in
/// screens that only render behind an authenticated route.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Keeps this device's push token attached to whoever is signed in.
///
/// Watched once from the app shell. Registering on sign-in and clearing on
/// sign-out means the next person to use the phone does not get the previous
/// user's appointment reminders.
final deviceRegistrationProvider = Provider<void>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);

  String? registeredUserId;

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
    final user = next.value;

    if (user == null) {
      final previousId = registeredUserId;
      registeredUserId = null;
      if (previousId != null) {
        service.unregisterDevice(previousId).catchError((_) {});
      }
      return;
    }

    if (registeredUserId == user.id) return;
    registeredUserId = user.id;
    service.registerDevice(user.id).catchError((_) {});
  }, fireImmediately: true);
});
