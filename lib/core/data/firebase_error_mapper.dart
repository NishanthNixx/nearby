import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../errors/app_failure.dart';

/// Translates Firebase and platform errors into [AppFailure].
///
/// This is the only place in the app that knows what a `FirebaseException`
/// looks like. Every Firebase repository funnels its errors through here, which
/// is what lets the layers above stay unaware of the backend — and means the
/// future REST implementation supplies its own mapper without touching the UI.
abstract final class FirebaseErrorMapper {
  /// Runs [action], converting anything it throws into an [AppFailure].
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(map(error), stackTrace);
    }
  }

  /// Wraps a stream so subscribers only ever see [AppFailure] in the error
  /// channel.
  static Stream<T> guardStream<T>(Stream<T> source) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(map(error), stackTrace);
        },
      ),
    );
  }

  static AppFailure map(Object error) {
    if (error is AppFailure) return error;

    if (error is FirebaseAuthException) return _mapAuth(error);
    if (error is FirebaseException) return _mapFirebase(error);
    if (error is SocketException) return NetworkFailure(cause: error);
    if (error is TimeoutException) return NetworkFailure(cause: error);

    return UnknownFailure(cause: error);
  }

  static AppFailure _mapAuth(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => AuthFailure.invalidCredentials(cause: error),
      'email-already-in-use' => AuthFailure.emailAlreadyInUse(cause: error),
      'weak-password' => AuthFailure.weakPassword(cause: error),
      'invalid-email' => AuthFailure.invalidEmail(cause: error),
      'too-many-requests' => AuthFailure.tooManyAttempts(cause: error),
      'user-disabled' => AuthFailure(
        title: 'Account disabled',
        message: 'This account has been disabled. Contact support for help.',
        cause: error,
      ),
      'requires-recent-login' => AuthFailure.sessionExpired(cause: error),
      'network-request-failed' => NetworkFailure(cause: error),
      _ => AuthFailure.unknown(cause: error),
    };
  }

  static AppFailure _mapFirebase(FirebaseException error) {
    return switch (error.code) {
      // A rejected write usually means the security rules did their job.
      'permission-denied' => PermissionDeniedFailure(cause: error),
      'not-found' => NotFoundFailure(what: 'record', cause: error),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(cause: error),
      'cancelled' => NetworkFailure(cause: error),
      'already-exists' => const SlotUnavailableFailure(),
      'resource-exhausted' => QuotaFailure(cause: error),
      'unauthenticated' => AuthFailure.sessionExpired(cause: error),
      _ => UnknownFailure(cause: error),
    };
  }
}

/// Firestore [Timestamp] and [DateTime] conversion.
///
/// Kept here so `Timestamp` never appears in a domain model.
abstract final class FirestoreTime {
  /// Reads a stored value as a local [DateTime]. Tolerates the millisecond
  /// integers written by older records or by tests.
  static DateTime? toDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime toDateTimeOr(Object? value, DateTime fallback) =>
      toDateTime(value) ?? fallback;

  static Timestamp fromDateTime(DateTime value) => Timestamp.fromDate(value);
}
