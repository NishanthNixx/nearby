import '../../../core/utils/geo.dart';

/// Access to the device's location.
///
/// An interface for the same reason the repositories are: the UI asks for a
/// [GeoPoint] and handles a [LocationFailure], and never imports a platform
/// plugin. Tests supply a fake instead of a permission dialog.
abstract interface class LocationService {
  /// The device's current position.
  ///
  /// Throws a [LocationFailure] describing exactly which of the several ways
  /// this can fail happened — services off, permission denied, permission
  /// permanently denied, or no fix — because each needs different wording and a
  /// different recovery action.
  Future<GeoPoint> getCurrentPosition();

  /// The last known position, if the platform has one cached.
  ///
  /// Returns immediately, so discovery can render something while a fresh fix
  /// is still being acquired.
  Future<GeoPoint?> getLastKnownPosition();

  /// Whether permission is already granted, without prompting.
  Future<bool> hasPermission();

  /// Prompts for permission. Returns whether it was granted.
  Future<bool> requestPermission();

  /// Opens the OS settings page for the app. The only way out of a permanent
  /// denial.
  Future<void> openAppSettings();
}
