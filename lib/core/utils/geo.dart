import 'dart:math' as math;

/// A point on the earth's surface.
///
/// Deliberately a plain value type with no dependency on any mapping or
/// database package, so it travels through the domain layer unchanged.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
}

/// Great-circle distance helpers.
abstract final class GeoDistance {
  static const double _earthRadiusKm = 6371.0088;

  /// Distance in kilometres between two points, via the haversine formula.
  ///
  /// Accurate to well under a percent at city scale, which is all the
  /// "1.2 km away" label needs.
  static double kmBetween(GeoPoint a, GeoPoint b) {
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Geohash encoding and cell adjacency.
///
/// A geohash turns a latitude/longitude pair into a string whose prefix
/// identifies a rectangular cell — nearby points share a prefix. That makes a
/// proximity search expressible as an ordinary range query on one indexed
/// string field, which is exactly what Firestore can do natively.
///
/// This is the simplest reliable nearby implementation for Firestore: no
/// geospatial service, no extra dependency, and the `geohash` field is just as
/// meaningful to a future PostgreSQL schema (or replaceable there by PostGIS).
abstract final class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Precision used when storing a business location. About 4.8m x 4.8m —
  /// far finer than any query needs, so the stored value never limits recall.
  static const int storagePrecision = 9;

  /// Approximate cell size per precision, in kilometres, as
  /// `(width, height)`. Index 0 is unused so the list is indexed by precision.
  static const List<(double, double)> _cellSizeKm = [
    (0, 0),
    (5009.4, 4992.6),
    (1252.3, 624.1),
    (156.5, 156.0),
    (39.1, 19.5),
    (4.9, 4.9),
    (1.2, 0.6),
    (0.153, 0.153),
    (0.038, 0.019),
    (0.0048, 0.0048),
  ];

  /// Encodes [point] to a geohash of [precision] characters.
  static String encode(GeoPoint point, {int precision = storagePrecision}) {
    assert(precision >= 1 && precision <= 12, 'precision out of range');

    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;

    final hash = StringBuffer();
    var bit = 0;
    var charIndex = 0;
    var evenBit = true;

    while (hash.length < precision) {
      if (evenBit) {
        final mid = (lonMin + lonMax) / 2;
        if (point.longitude >= mid) {
          charIndex = charIndex * 2 + 1;
          lonMin = mid;
        } else {
          charIndex *= 2;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (point.latitude >= mid) {
          charIndex = charIndex * 2 + 1;
          latMin = mid;
        } else {
          charIndex *= 2;
          latMax = mid;
        }
      }
      evenBit = !evenBit;

      if (++bit == 5) {
        hash.write(_base32[charIndex]);
        bit = 0;
        charIndex = 0;
      }
    }

    return hash.toString();
  }

  /// The finest precision whose cell is still at least [radiusKm] across in
  /// both directions.
  ///
  /// Picking it this way guarantees the centre cell plus its eight neighbours
  /// fully contain a circle of that radius, so the range queries cannot miss a
  /// result that the exact distance filter would have kept.
  static int precisionForRadius(double radiusKm) {
    for (var precision = _cellSizeKm.length - 1; precision >= 1; precision--) {
      final (width, height) = _cellSizeKm[precision];
      if (width >= radiusKm && height >= radiusKm) return precision;
    }
    return 1;
  }

  /// The set of geohash prefixes covering a circle of [radiusKm] around
  /// [center] — the centre cell and its eight neighbours, de-duplicated.
  ///
  /// Each prefix becomes one Firestore range query
  /// (`>= prefix` and `<= prefix + '~'`). The caller still applies an exact
  /// distance filter afterwards, because these cells cover more than the
  /// circle.
  static List<String> coveringPrefixes(GeoPoint center, double radiusKm) {
    final precision = precisionForRadius(radiusKm);
    final centre = encode(center, precision: precision);

    final north = _adjacent(centre, _Direction.north);
    final south = _adjacent(centre, _Direction.south);

    final cells = <String>{
      centre,
      north,
      south,
      _adjacent(centre, _Direction.east),
      _adjacent(centre, _Direction.west),
      _adjacent(north, _Direction.east),
      _adjacent(north, _Direction.west),
      _adjacent(south, _Direction.east),
      _adjacent(south, _Direction.west),
    };

    return cells.toList(growable: false);
  }

  /// Upper bound for a prefix range query. `~` sorts after every base-32
  /// character, so `[prefix, prefix + '~']` selects exactly the hashes
  /// starting with `prefix`.
  static String rangeEnd(String prefix) => '$prefix~';

  // ---------------------------------------------------------------------------
  // Cell adjacency
  //
  // Standard geohash neighbour tables. Which table applies depends on the
  // parity of the hash length, because the encoding alternates between
  // bisecting longitude and latitude.
  // ---------------------------------------------------------------------------

  static const Map<_Direction, Map<bool, String>> _neighbours = {
    _Direction.north: {
      false: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
      true: 'bc01fg45238967deuvhjyznpkmstqrwx',
    },
    _Direction.south: {
      false: '14365h7k9dcfesgujnmqp0r2twvyx8zb',
      true: '238967debc01fg45kmstqrwxuvhjyznp',
    },
    _Direction.east: {
      false: 'bc01fg45238967deuvhjyznpkmstqrwx',
      true: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
    },
    _Direction.west: {
      false: '238967debc01fg45kmstqrwxuvhjyznp',
      true: '14365h7k9dcfesgujnmqp0r2twvyx8zb',
    },
  };

  static const Map<_Direction, Map<bool, String>> _borders = {
    _Direction.north: {false: 'prxz', true: 'bcfguvyz'},
    _Direction.south: {false: '028b', true: '0145hjnp'},
    _Direction.east: {false: 'bcfguvyz', true: 'prxz'},
    _Direction.west: {false: '0145hjnp', true: '028b'},
  };

  /// The hash of the cell adjacent to [hash] in [direction].
  ///
  /// When the last character sits on the edge of its parent cell, the parent
  /// has to step across too — hence the recursion.
  static String _adjacent(String hash, _Direction direction) {
    if (hash.isEmpty) return hash;

    final lastChar = hash[hash.length - 1];
    final isOddLength = hash.length.isOdd;
    var base = hash.substring(0, hash.length - 1);

    if (_borders[direction]![isOddLength]!.contains(lastChar)) {
      base = _adjacent(base, direction);
      // Stepped off the edge of the world; stay put rather than wrap.
      if (base.isEmpty) return hash;
    }

    final index = _neighbours[direction]![isOddLength]!.indexOf(lastChar);
    if (index < 0) return hash;

    return base + _base32[index];
  }
}

enum _Direction { north, south, east, west }
