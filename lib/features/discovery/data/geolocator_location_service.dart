import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/geo.dart';
import '../domain/location_service.dart';

/// [LocationService] backed by the geolocator plugin.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> getCurrentPosition() async {
    await _ensureUsable();

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          // Neighbourhood accuracy is plenty for "1.2 km away", and asking for
          // less precision returns a fix faster and uses less battery.
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      throw LocationFailure.unavailable(cause: error);
    }
  }

  @override
  Future<GeoPoint?> getLastKnownPosition() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return null;

      final permission = await geo.Geolocator.checkPermission();
      if (!_isGranted(permission)) return null;

      final position = await geo.Geolocator.getLastKnownPosition();
      if (position == null) return null;

      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // A cached position is an optimisation. If it is unavailable the caller
      // simply waits for a real fix, so this never surfaces an error.
      return null;
    }
  }

  @override
  Future<bool> hasPermission() async {
    final permission = await geo.Geolocator.checkPermission();
    return _isGranted(permission);
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _isGranted(permission);
  }

  @override
  Future<void> openAppSettings() async {
    await geo.Geolocator.openAppSettings();
  }

  /// Distinguishes the failure modes so each gets its own message and recovery.
  Future<void> _ensureUsable() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw LocationFailure.serviceDisabled();
    }

    var permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      throw LocationFailure.deniedForever();
    }
    if (!_isGranted(permission)) {
      throw LocationFailure.denied();
    }
  }

  static bool _isGranted(geo.LocationPermission permission) =>
      permission == geo.LocationPermission.always ||
      permission == geo.LocationPermission.whileInUse;
}
