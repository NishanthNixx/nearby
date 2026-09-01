import 'dart:async';
import 'dart:math' as math;

import '../../../features/auth/domain/app_user.dart';
import '../../../features/bookings/domain/booking.dart';
import '../../../features/businesses/domain/business.dart';
import '../../../features/businesses/domain/opening_hours.dart';
import '../../../features/businesses/domain/service_offering.dart';
import '../../../features/reviews/domain/review.dart';
import '../../utils/geo.dart';

/// Shared mutable state for the in-memory backend.
///
/// Holds the same records Firestore would, in plain collections, and notifies
/// listeners on change so the in-memory repositories can expose real streams.
class InMemoryStore {
  InMemoryStore({GeoPoint? seedCenter}) {
    _seed(seedCenter ?? const GeoPoint(latitude: 12.9716, longitude: 77.5946));
  }

  final Map<String, AppUser> users = {};
  final Map<String, String> passwords = {};
  final Map<String, Business> businesses = {};
  final Map<String, ServiceOffering> services = {};
  final Map<String, Booking> bookings = {};
  final Map<String, Review> reviews = {};

  /// Claimed appointment slots, keyed exactly as the Firestore slot lock
  /// documents are. Mirroring the mechanism means the duplicate-booking tests
  /// exercise the same rule the real backend enforces.
  final Set<String> slotLocks = {};

  String? signedInUserId;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every mutation.
  Stream<void> get changes => _changes.stream;

  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  int _idCounter = 0;

  String nextId(String prefix) => '${prefix}_${++_idCounter}';

  /// Builds a stream that emits [read] now and again after every change.
  ///
  /// The distinct-by-identity behaviour of a real snapshot listener is not
  /// reproduced; emitting on every change is simpler and correct, just chattier.
  Stream<T> watch<T>(T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? subscription;

    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = changes.listen((_) {
          if (!controller.isClosed) controller.add(read());
        });
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Seed data
  //
  // Six tailors scattered around [center] at realistic distances, with real
  // service lists, varied opening hours and a handful of reviews. Enough for
  // every screen state — including a business that is closed right now and one
  // that has no reviews yet — to be seen without touching a backend.
  // ---------------------------------------------------------------------------

  void _seed(GeoPoint center) {
    final now = DateTime.now();

    final owners = <String, String>{
      'Sri Lakshmi Tailors': 'lakshmi@example.com',
      'Ashraf Master Tailors': 'ashraf@example.com',
      'Vasantha Ladies Tailoring': 'vasantha@example.com',
      'New Style Stitching Centre': 'newstyle@example.com',
      'Anand Alterations': 'anand@example.com',
      'Bismillah Tailors': 'bismillah@example.com',
    };

    final seeds = <_BusinessSeed>[
      _BusinessSeed(
        name: 'Sri Lakshmi Tailors',
        tagline: "Men's & women's tailoring",
        description:
            'Family-run tailoring shop, three generations in the same lane. '
            'Specialists in blouse stitching and saree falls. Same-day '
            'alterations on request.',
        address: '14, 3rd Cross, Malleshwaram, Bengaluru 560003',
        offsetKm: (0.9, 0.8),
        imageTopic: 'tailor,sewing',
        rating: 4.7,
        ratingCount: 128,
        hours: OpeningHours.standard(),
        services: [
          ('Shirt stitching', 'Cotton or linen, your cloth', 350, 30),
          ('Blouse stitching', 'Includes one fitting', 500, 45),
          ('Saree fall & pico', null, 120, 15),
          ('Pant alteration', 'Length, waist or taper', 150, 30),
        ],
      ),
      _BusinessSeed(
        name: 'Ashraf Master Tailors',
        tagline: 'Suits, sherwanis & formal wear',
        description:
            'Bespoke formal wear cut by hand. Ashraf has been a master tailor '
            'for twenty-two years. Two fittings included on all suits.',
        address: '221, Commercial Street, Bengaluru 560001',
        offsetKm: (-1.6, 2.1),
        imageTopic: 'suit,menswear',
        rating: 4.9,
        ratingCount: 76,
        hours: OpeningHours.standard().copyWith(slotDurationMinutes: 60),
        services: [
          ('Two-piece suit', 'Includes two fittings', 4500, 60),
          ('Sherwani stitching', null, 6500, 60),
          ('Formal shirt', null, 600, 30),
          ('Trouser stitching', null, 900, 30),
        ],
      ),
      const _BusinessSeed(
        name: 'Vasantha Ladies Tailoring',
        tagline: 'Blouses, kurtis & lehengas',
        description:
            'Ladies-only tailoring with a private fitting room. Known for '
            'pattern-matched blouse work and quick turnarounds before festivals.',
        address: '7, Gandhi Bazaar Main Road, Basavanagudi, Bengaluru 560004',
        offsetKm: (2.7, -1.4),
        imageTopic: 'textile,fabric',
        rating: 4.5,
        ratingCount: 214,
        hours: OpeningHours(
          byWeekday: {
            DateTime.monday: DayHours.closed(),
            DateTime.tuesday: DayHours.standard(),
            DateTime.wednesday: DayHours.standard(),
            DateTime.thursday: DayHours.standard(),
            DateTime.friday: DayHours.standard(),
            DateTime.saturday: DayHours(
              isOpen: true,
              opensAt: TimeOfDayValue(hour: 10, minute: 0),
              closesAt: TimeOfDayValue(hour: 18, minute: 0),
            ),
            DateTime.sunday: DayHours(
              isOpen: true,
              opensAt: TimeOfDayValue(hour: 11, minute: 0),
              closesAt: TimeOfDayValue(hour: 16, minute: 0),
            ),
          },
          slotDurationMinutes: 30,
        ),
        services: [
          ('Blouse stitching', 'Lining included', 550, 45),
          ('Kurti stitching', null, 700, 45),
          ('Lehenga stitching', 'Three fittings', 3200, 60),
          ('Measurements only', 'Keep on file for later', 0, 15),
        ],
      ),
      _BusinessSeed(
        name: 'New Style Stitching Centre',
        tagline: 'School uniforms & everyday stitching',
        description:
            'Bulk uniform orders and everyday stitching at fair rates. '
            'Walk-ins welcome, but appointments are faster.',
        address: '92, Sampige Road, Malleshwaram, Bengaluru 560003',
        offsetKm: (-0.4, -3.2),
        imageTopic: 'sewing,machine',
        rating: 4.1,
        ratingCount: 43,
        hours: OpeningHours.standard().copyWith(
          byWeekday: {
            ...OpeningHours.standard().byWeekday,
            DateTime.thursday: const DayHours.closed(),
          },
        ),
        services: [
          ('School uniform set', 'Shirt and shorts or skirt', 450, 30),
          ('Shirt stitching', null, 300, 30),
          ('Zip replacement', null, 80, 15),
          ('Hemming', null, 60, 15),
        ],
      ),
      _BusinessSeed(
        name: 'Anand Alterations',
        tagline: 'Fast alterations & repairs',
        description:
            'Alterations while you wait. No stitching from scratch — repairs, '
            'resizing and repairs only.',
        address: '5, 8th Main, Jayanagar, Bengaluru 560011',
        offsetKm: (4.4, 3.1),
        imageTopic: 'thread,needle',
        rating: 4.3,
        ratingCount: 61,
        hours: OpeningHours.standard().copyWith(slotDurationMinutes: 15),
        services: [
          ('Trouser taper', null, 180, 15),
          ('Waist adjustment', null, 200, 15),
          ('Sleeve shortening', null, 150, 15),
          ('Zip replacement', null, 100, 15),
        ],
      ),
      // Deliberately has no reviews, so the empty rating state is visible.
      _BusinessSeed(
        name: 'Bismillah Tailors',
        tagline: 'Kurta, pyjama & everyday wear',
        description:
            'Newly opened on the main road. Kurta-pyjama sets, everyday '
            'stitching and simple alterations.',
        address: '38, Shivajinagar, Bengaluru 560051',
        offsetKm: (-2.2, -0.6),
        imageTopic: 'cloth,tailoring',
        rating: 0,
        ratingCount: 0,
        hours: OpeningHours.standard(),
        services: [
          ('Kurta stitching', null, 550, 45),
          ('Pyjama stitching', null, 300, 30),
          ('Shirt stitching', null, 320, 30),
        ],
      ),
    ];

    for (var seedIndex = 0; seedIndex < seeds.length; seedIndex++) {
      final seed = seeds[seedIndex];
      final ownerId = nextId('owner');
      final businessId = nextId('biz');

      users[ownerId] = AppUser(
        id: ownerId,
        email: owners[seed.name]!,
        role: UserRole.businessOwner,
        createdAt: now.subtract(const Duration(days: 120)),
        displayName: seed.name,
        businessId: businessId,
      );
      passwords[owners[seed.name]!] = 'password123';

      final location = _offset(center, seed.offsetKm.$1, seed.offsetKm.$2);

      businesses[businessId] = Business(
        id: businessId,
        ownerId: ownerId,
        name: seed.name,
        category: BusinessCategory.tailoring,
        location: location,
        geohash: Geohash.encode(location),
        address: seed.address,
        openingHours: seed.hours,
        isAcceptingBookings: true,
        createdAt: now.subtract(const Duration(days: 120)),
        tagline: seed.tagline,
        description: seed.description,
        phone: '+91 98${_random.nextInt(90000000) + 10000000}',
        photoUrl: _demoPhoto(seed.imageTopic, seedIndex * 3 + 1),
        galleryUrls: [
          _demoPhoto(seed.imageTopic, seedIndex * 3 + 1),
          _demoPhoto(seed.imageTopic, seedIndex * 3 + 2),
          _demoPhoto(seed.imageTopic, seedIndex * 3 + 3),
        ],
        ratingAverage: seed.rating,
        ratingCount: seed.ratingCount,
      );

      for (final (name, description, price, duration) in seed.services) {
        final serviceId = nextId('svc');
        services[serviceId] = ServiceOffering(
          id: serviceId,
          businessId: businessId,
          name: name,
          price: price,
          durationMinutes: duration,
          isActive: true,
          description: description,
        );
      }

      if (seed.ratingCount > 0) {
        _seedReviews(businessId, seed.rating, now);
      }
    }

    // A demo customer, so the app can be opened straight into the customer
    // experience without signing up first.
    const demoCustomerId = 'customer_demo';
    users[demoCustomerId] = AppUser(
      id: demoCustomerId,
      email: 'customer@example.com',
      role: UserRole.customer,
      createdAt: now.subtract(const Duration(days: 30)),
      displayName: 'Demo Customer',
      phone: '+91 9800000000',
    );
    passwords['customer@example.com'] = 'password123';
  }

  void _seedReviews(String businessId, double average, DateTime now) {
    const comments = [
      'Excellent fit, exactly what I asked for. Ready a day early.',
      'Very neat stitching and fair pricing. Will come back.',
      'Good work overall. The fitting took an extra visit.',
      'Been going here for years. Never disappointed.',
      'Quick alteration while I waited. Friendly service.',
    ];
    const names = [
      'Priya R.',
      'Karthik S.',
      'Meena D.',
      'Arjun V.',
      'Fatima K.',
    ];

    for (var i = 0; i < math.min(3, comments.length); i++) {
      final id = nextId('rev');
      reviews[id] = Review(
        id: id,
        customerId: 'seed_reviewer_$i',
        businessId: businessId,
        bookingId: 'seed_booking_${businessId}_$i',
        rating: average >= 4.5 ? 5 : 4,
        createdAt: now.subtract(Duration(days: 3 + i * 9)),
        comment: comments[i],
        customerName: names[i],
      );
    }
  }

  /// A demo photograph for a sample shop.
  ///
  /// Sample data only. Real businesses upload their own images to Storage, and
  /// the app never depends on these resolving — a shop with no reachable photo
  /// falls back to its generated identity, which is the same path a real tailor
  /// who has not uploaded anything takes.
  ///
  /// `lock` makes the choice deterministic, so a shop keeps the same photo
  /// across launches rather than reshuffling on every build.
  static String _demoPhoto(String topic, int lock) =>
      'https://loremflickr.com/800/600/$topic?lock=$lock';

  /// Shifts a point by a distance in kilometres.
  ///
  /// One degree of latitude is about 111km; longitude shrinks with the cosine
  /// of latitude. Good enough to place seed data at believable distances.
  static GeoPoint _offset(GeoPoint from, double northKm, double eastKm) {
    const kmPerDegreeLat = 110.574;
    final kmPerDegreeLon = 111.320 * math.cos(from.latitude * math.pi / 180);

    return GeoPoint(
      latitude: from.latitude + northKm / kmPerDegreeLat,
      longitude: from.longitude + eastKm / kmPerDegreeLon,
    );
  }

  static final math.Random _random = math.Random(42);
}

class _BusinessSeed {
  const _BusinessSeed({
    required this.name,
    required this.tagline,
    required this.description,
    required this.address,
    required this.offsetKm,
    required this.rating,
    required this.ratingCount,
    required this.hours,
    required this.services,
    required this.imageTopic,
  });

  final String name;
  final String tagline;
  final String description;
  final String address;

  /// (north, east) in kilometres from the seed centre.
  final (double, double) offsetKm;

  final double rating;
  final int ratingCount;
  final OpeningHours hours;

  /// Keyword used to pick this shop's demo photography.
  final String imageTopic;

  /// (name, description, price, durationMinutes)
  final List<(String, String?, int, int)> services;
}
