import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nearby/core/utils/geo.dart';

void main() {
  // Bengaluru city centre, used as the reference point throughout.
  const bengaluru = GeoPoint(latitude: 12.9716, longitude: 77.5946);

  group('GeoDistance', () {
    test('is zero for the same point', () {
      expect(GeoDistance.kmBetween(bengaluru, bengaluru), closeTo(0, 0.0001));
    });

    test('matches a known city-to-city distance', () {
      const chennai = GeoPoint(latitude: 13.0827, longitude: 80.2707);
      // Bengaluru to Chennai is about 290km great-circle.
      expect(GeoDistance.kmBetween(bengaluru, chennai), closeTo(290, 8));
    });

    test('is symmetric', () {
      const other = GeoPoint(latitude: 12.99, longitude: 77.62);
      expect(
        GeoDistance.kmBetween(bengaluru, other),
        closeTo(GeoDistance.kmBetween(other, bengaluru), 0.0001),
      );
    });

    test('resolves neighbourhood-scale distances', () {
      // Roughly 1.1km north.
      const nearby = GeoPoint(latitude: 12.9816, longitude: 77.5946);
      expect(GeoDistance.kmBetween(bengaluru, nearby), closeTo(1.11, 0.05));
    });
  });

  group('Geohash.encode', () {
    test('produces a hash of the requested precision', () {
      expect(Geohash.encode(bengaluru, precision: 5).length, 5);
      expect(Geohash.encode(bengaluru, precision: 9).length, 9);
    });

    test('matches the reference encoding for known points', () {
      // Cross-checked against an independent implementation of the standard
      // algorithm, which also reproduces the widely published hash for London.
      expect(Geohash.encode(bengaluru, precision: 7), 'tdr1v9q');
      expect(Geohash.encode(bengaluru, precision: 9), 'tdr1v9qtj');
      expect(
        Geohash.encode(
          const GeoPoint(latitude: 51.5074, longitude: -0.1278),
          precision: 7,
        ),
        'gcpvj0d',
      );
      expect(
        Geohash.encode(
          const GeoPoint(latitude: -33.8688, longitude: 151.2093),
          precision: 7,
        ),
        'r3gx2f7',
      );
    });

    test('nearby points share a prefix, distant points do not', () {
      const nextStreet = GeoPoint(latitude: 12.9720, longitude: 77.5950);
      const chennai = GeoPoint(latitude: 13.0827, longitude: 80.2707);

      final a = Geohash.encode(bengaluru, precision: 5);
      final b = Geohash.encode(nextStreet, precision: 5);
      final far = Geohash.encode(chennai, precision: 5);

      expect(a, b);
      expect(a, isNot(far));
    });

    test('is deterministic', () {
      expect(Geohash.encode(bengaluru), Geohash.encode(bengaluru));
    });
  });

  group('Geohash.precisionForRadius', () {
    test('picks a cell at least as large as the radius in both directions', () {
      // A 2km radius fits inside a precision-5 cell (about 4.9km square).
      expect(Geohash.precisionForRadius(2), 5);
      // 5km does not, so it steps out to precision 4.
      expect(Geohash.precisionForRadius(5), 4);
      expect(Geohash.precisionForRadius(10), 4);
      // 25km exceeds precision 4's 19.5km height.
      expect(Geohash.precisionForRadius(25), 3);
    });

    test('gets coarser as the radius grows', () {
      var previous = 13;
      for (final radius in [1.0, 2.0, 5.0, 10.0, 25.0, 100.0, 500.0]) {
        final precision = Geohash.precisionForRadius(radius);
        expect(precision, lessThanOrEqualTo(previous));
        previous = precision;
      }
    });
  });

  group('Geohash.coveringPrefixes', () {
    test('returns exactly the centre cell and its eight neighbours', () {
      // Pins the cell-adjacency walk. Each of these was verified to share an
      // edge with the centre cell geometrically, by decoding the cell bounds.
      final prefixes = Geohash.coveringPrefixes(bengaluru, 5).toList()..sort();

      expect(prefixes, [
        'tdqb',
        'tdqc',
        'tdqf',
        'tdr0',
        'tdr1',
        'tdr2',
        'tdr3',
        'tdr4',
        'tdr6',
      ]);
      expect(prefixes, contains(Geohash.encode(bengaluru, precision: 4)));
    });

    test('all prefixes share the chosen precision', () {
      final prefixes = Geohash.coveringPrefixes(bengaluru, 2);
      final precision = Geohash.precisionForRadius(2);
      expect(prefixes.every((p) => p.length == precision), isTrue);
    });

    test('covers every point inside the radius', () {
      // The whole point of the covering set: a business within the radius must
      // fall into one of the queried cells, or the search silently misses it.
      const radiusKm = 5.0;
      final prefixes = Geohash.coveringPrefixes(bengaluru, radiusKm).toSet();
      final precision = Geohash.precisionForRadius(radiusKm);

      // Sample a grid of points inside the circle.
      var checked = 0;
      for (var northKm = -radiusKm; northKm <= radiusKm; northKm += 0.5) {
        for (var eastKm = -radiusKm; eastKm <= radiusKm; eastKm += 0.5) {
          final candidate = _offset(bengaluru, northKm, eastKm);
          if (GeoDistance.kmBetween(bengaluru, candidate) > radiusKm) continue;

          final hash = Geohash.encode(candidate, precision: precision);
          expect(
            prefixes,
            contains(hash),
            reason:
                'point $northKm km N, $eastKm km E fell outside the '
                'covering cells — a nearby business here would be missed',
          );
          checked++;
        }
      }

      expect(checked, greaterThan(100), reason: 'sanity: the grid ran');
    });

    test('de-duplicates when neighbours share a prefix', () {
      // At a very coarse precision the neighbours collapse together; the result
      // must not contain repeats, or the same cell is queried twice.
      final prefixes = Geohash.coveringPrefixes(bengaluru, 500);
      expect(prefixes.length, prefixes.toSet().length);
    });
  });

  group('Geohash.rangeEnd', () {
    test('sorts above every base-32 character', () {
      const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';
      final end = Geohash.rangeEnd('tdr');
      for (final char in alphabet.split('')) {
        expect('tdr$char'.compareTo(end), lessThan(0));
      }
    });
  });

  group('GeoPoint.isValid', () {
    test('rejects out-of-range coordinates', () {
      expect(const GeoPoint(latitude: 91, longitude: 0).isValid, isFalse);
      expect(const GeoPoint(latitude: 0, longitude: 181).isValid, isFalse);
    });

    test('rejects the null island, which means "never set"', () {
      expect(const GeoPoint(latitude: 0, longitude: 0).isValid, isFalse);
    });

    test('accepts a real location', () {
      expect(bengaluru.isValid, isTrue);
    });
  });
}

/// Shifts a point by a distance in kilometres, for building test fixtures.
GeoPoint _offset(GeoPoint from, double northKm, double eastKm) {
  const kmPerDegreeLat = 110.574;
  final kmPerDegreeLon = 111.320 * math.cos(from.latitude * math.pi / 180);
  return GeoPoint(
    latitude: from.latitude + northKm / kmPerDegreeLat,
    longitude: from.longitude + eastKm / kmPerDegreeLon,
  );
}
