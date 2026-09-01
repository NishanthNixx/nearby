/// Registration and permission for push notifications.
///
/// An interface like the repositories, so the UI never imports a messaging
/// plugin and tests need no platform channel.
abstract interface class PushNotificationService {
  /// Asks the platform for permission, if it has not been decided already.
  ///
  /// Design guideline — Managing notifications: ask at a moment when the value
  /// is obvious rather than on first launch. Nearby asks right after a customer
  /// books, when "we will tell you when the tailor confirms" is self-evidently
  /// worth a yes.
  ///
  /// Returns whether notifications are permitted.
  Future<bool> ensurePermission();

  /// Whether permission has already been granted, without prompting.
  Future<bool> hasPermission();

  /// Records this device against [userId] so the server can reach it.
  ///
  /// Safe to call repeatedly; re-registering an existing token is a no-op.
  Future<void> registerDevice(String userId);

  /// Removes this device's token. Called on sign-out, so the next person to use
  /// the phone does not receive the previous user's appointment reminders.
  Future<void> unregisterDevice(String userId);
}
