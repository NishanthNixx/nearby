/// Which data layer implementation the app runs against.
enum DataSource {
  /// Cloud Firestore + Firebase Auth. The MVP backend.
  firebase,

  /// In-memory implementations seeded with sample data. Used for widget tests
  /// and for running the app before Firebase credentials are configured.
  ///
  /// This is not a speculative abstraction: it is a second real implementation
  /// of every repository interface, which is what proves the interfaces are
  /// genuinely free of Firebase concepts.
  inMemory,
}

/// Firestore collection and field names.
///
/// Collection names live here rather than being repeated as string literals
/// across the data layer, so a schema rename is a single edit and the future
/// REST implementation has an obvious list of resources to mirror.
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String businesses = 'businesses';

  /// Subcollection of a business. Services only ever belong to one business,
  /// so nesting keeps ownership explicit and makes security rules simpler.
  static const String services = 'services';

  static const String bookings = 'bookings';
  static const String reviews = 'reviews';

  /// One document per claimed appointment slot, with a deterministic ID.
  /// Creating it inside a transaction is what makes booking atomic.
  static const String slotLocks = 'slotLocks';

  /// Per-user device tokens for push notifications.
  static const String deviceTokens = 'deviceTokens';

  /// Deterministic slot lock ID. Two customers racing for the same slot
  /// generate the same ID, so exactly one `create` can win.
  static String slotLockId({
    required String businessId,
    required DateTime startTimeUtc,
  }) => '${businessId}_${startTimeUtc.toUtc().millisecondsSinceEpoch}';
}

/// Application-wide configuration.
///
/// Values that vary by environment or that a product decision might change are
/// gathered here instead of being embedded in business logic.
abstract final class AppConfig {
  /// Active data layer.
  ///
  /// Defaults to [DataSource.firebase]; falls back to [DataSource.inMemory]
  /// automatically at startup when Firebase cannot be initialised, so the app
  /// stays usable rather than showing a dead screen.
  static DataSource dataSource = DataSource.firebase;

  /// Currency symbol for prices. Single-currency by design for the MVP.
  static const String currencySymbol = '₹';

  /// Default radius for the nearby search, in kilometres.
  static const double defaultSearchRadiusKm = 5;

  /// Radii the customer can choose between.
  static const List<double> searchRadiusOptionsKm = [2, 5, 10, 25];

  /// Upper bound on results from one nearby query. Keeps the client-side
  /// distance filter cheap.
  static const int nearbyResultLimit = 50;

  /// How far ahead a customer may book.
  static const int bookingHorizonDays = 30;

  /// A slot must start at least this far in the future to be bookable, so a
  /// customer cannot book a time that is already passing.
  static const Duration minimumBookingLeadTime = Duration(minutes: 30);

  /// A customer may cancel up to this long before the appointment.
  static const Duration cancellationCutoff = Duration(hours: 2);

  /// Fallback slot length when a business has not set one.
  static const int defaultSlotDurationMinutes = 30;

  /// Bounds on a business's configurable slot length.
  static const int minSlotDurationMinutes = 15;
  static const int maxSlotDurationMinutes = 120;

  /// Maximum gallery images per business.
  static const int maxGalleryImages = 6;

  /// Longest allowed review comment.
  static const int maxReviewLength = 500;

  /// Text scale is clamped to this range. The upper bound is well past the
  /// standard sizes and the layouts have been checked against it; clamping
  /// prevents pathological scale factors from breaking a screen entirely.
  static const double minTextScale = 0.85;
  static const double maxTextScale = 2.0;
}
