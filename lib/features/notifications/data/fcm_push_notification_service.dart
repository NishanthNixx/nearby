import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../domain/push_notification_service.dart';

/// Firebase Cloud Messaging implementation.
///
/// Tokens live at `users/{uid}/deviceTokens/{token}`, which the security rules
/// restrict to the owning user — so one account cannot register a device against
/// another.
class FcmPushNotificationService implements PushNotificationService {
  FcmPushNotificationService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
  }) : _messaging = messaging,
       _firestore = firestore;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tokensOf(String userId) =>
      _firestore
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection(FirestorePaths.deviceTokens);

  @override
  Future<bool> ensurePermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return _isAuthorised(settings.authorizationStatus);
    } catch (error) {
      // A declined or unavailable permission is not an app failure — bookings
      // still work, the customer just checks the app instead of being told.
      debugPrint('Nearby: notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return _isAuthorised(settings.authorizationStatus);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> registerDevice(String userId) async {
    try {
      if (!await hasPermission()) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await _writeToken(userId, token);

      // The token can rotate at any time; without this the device silently
      // stops receiving notifications.
      _messaging.onTokenRefresh.listen((refreshed) {
        _writeToken(userId, refreshed).catchError((_) {});
      });
    } catch (error) {
      debugPrint('Nearby: could not register for notifications: $error');
    }
  }

  @override
  Future<void> unregisterDevice(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _tokensOf(userId).doc(token).delete();
    } catch (error) {
      debugPrint('Nearby: could not unregister for notifications: $error');
    }
  }

  Future<void> _writeToken(String userId, String token) {
    // Keyed by the token itself, so re-registering overwrites rather than
    // accumulating a row per launch.
    return _tokensOf(userId).doc(token).set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static bool _isAuthorised(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// A no-op implementation for the in-memory backend and for tests.
///
/// Reports permission as denied rather than pretending to be granted, so the
/// UI exercises its "notifications are off" path honestly.
class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> registerDevice(String userId) async {}

  @override
  Future<void> unregisterDevice(String userId) async {}
}
