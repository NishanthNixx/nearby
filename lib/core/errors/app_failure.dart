/// A failure the app is prepared to explain to the user.
///
/// Design guideline — Feedback > Best practices: "Show people when a command
/// can't be carried out and help them understand why."
///
/// Nothing from the data layer escapes as a raw platform exception. Repository
/// implementations translate their own errors into one of these, so the UI can
/// render a real sentence without knowing whether the backend is Firebase or a
/// REST API.
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.title,
    required this.message,
    this.recovery,
    this.cause,
  });

  /// Short heading. Sentence case, no trailing period.
  final String title;

  /// One or two plain sentences describing what happened.
  final String message;

  /// What the user can do about it, when there is something. Drives the label
  /// on the recovery action in error states.
  final String? recovery;

  /// The original error, kept for logging and crash reporting only. Never
  /// shown to the user.
  final Object? cause;

  @override
  String toString() => '$runtimeType($title: $message)';
}

/// The device has no usable connection, or a request timed out.
class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause})
    : super(
        title: 'No connection',
        message:
            'Nearby could not reach the network. Check your connection and try again.',
        recovery: 'Try again',
      );
}

/// Sign-in, sign-up or session restoration failed.
class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.title,
    required super.message,
    super.recovery,
    super.cause,
  });

  factory AuthFailure.invalidCredentials({Object? cause}) => AuthFailure(
    title: 'Sign-in failed',
    message: 'That email and password combination does not match an account.',
    recovery: 'Try again',
    cause: cause,
  );

  factory AuthFailure.emailAlreadyInUse({Object? cause}) => AuthFailure(
    title: 'Email already registered',
    message: 'An account already exists for this email. Sign in instead.',
    recovery: 'Go to sign in',
    cause: cause,
  );

  factory AuthFailure.weakPassword({Object? cause}) => AuthFailure(
    title: 'Password too weak',
    message: 'Choose a password of at least 8 characters.',
    cause: cause,
  );

  factory AuthFailure.invalidEmail({Object? cause}) => AuthFailure(
    title: 'Check the email address',
    message: 'That does not look like a valid email address.',
    cause: cause,
  );

  factory AuthFailure.tooManyAttempts({Object? cause}) => AuthFailure(
    title: 'Too many attempts',
    message: 'Too many sign-in attempts. Wait a few minutes and try again.',
    cause: cause,
  );

  factory AuthFailure.sessionExpired({Object? cause}) => AuthFailure(
    title: 'Signed out',
    message: 'Your session has expired. Sign in again to continue.',
    recovery: 'Sign in',
    cause: cause,
  );

  factory AuthFailure.notSignedIn() => const AuthFailure(
    title: 'Sign in required',
    message: 'Sign in to continue.',
    recovery: 'Sign in',
  );

  factory AuthFailure.unknown({Object? cause}) => AuthFailure(
    title: 'Sign-in failed',
    message: 'Something went wrong signing you in. Try again.',
    recovery: 'Try again',
    cause: cause,
  );
}

/// The user declined location access, or the OS has it switched off.
class LocationFailure extends AppFailure {
  const LocationFailure({
    required super.title,
    required super.message,
    super.recovery,
    this.canOpenSettings = false,
    super.cause,
  });

  /// Whether the recovery action should deep-link into system settings, which
  /// is the only way out when permission is permanently denied.
  final bool canOpenSettings;

  factory LocationFailure.denied() => const LocationFailure(
    title: 'Location is off',
    message:
        'Nearby uses your location to find tailors close to you. You can also search by name instead.',
    recovery: 'Allow location',
  );

  factory LocationFailure.deniedForever() => const LocationFailure(
    title: 'Location access blocked',
    message:
        'Location permission is turned off for Nearby in your device settings.',
    recovery: 'Open settings',
    canOpenSettings: true,
  );

  factory LocationFailure.serviceDisabled() => const LocationFailure(
    title: 'Location services are off',
    message: 'Turn on location services to see tailors near you.',
    recovery: 'Open settings',
    canOpenSettings: true,
  );

  factory LocationFailure.unavailable({Object? cause}) => LocationFailure(
    title: 'Could not find your location',
    message:
        'Nearby could not get a location fix. Try again, or search by name.',
    recovery: 'Try again',
    cause: cause,
  );
}

/// Someone else took the slot between the customer opening the screen and
/// tapping confirm. Expected under normal use, not a bug.
class SlotUnavailableFailure extends AppFailure {
  const SlotUnavailableFailure({super.cause})
    : super(
        title: 'That time was just taken',
        message:
            'Someone booked this slot a moment ago. Pick another time — the list has been refreshed.',
        recovery: 'Choose another time',
      );
}

/// The requested booking does not make sense — a past time, outside opening
/// hours, or a service that is no longer offered.
class InvalidBookingFailure extends AppFailure {
  const InvalidBookingFailure({
    required super.message,
    super.recovery,
    super.cause,
  }) : super(title: 'Booking not possible');
}

/// The business cannot take bookings right now.
class BusinessUnavailableFailure extends AppFailure {
  const BusinessUnavailableFailure({super.cause})
    : super(
        title: 'Not accepting bookings',
        message:
            'This tailor is not taking appointments at the moment. Try another nearby tailor.',
      );
}

/// Form input the user needs to correct. [fieldErrors] lets a form highlight
/// the offending fields rather than only showing a banner.
class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const {},
    super.cause,
  }) : super(title: 'Check the details');

  final Map<String, String> fieldErrors;
}

/// The record is gone — deleted, or never existed.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({required String what, super.cause})
    : super(title: 'Not found', message: 'This $what is no longer available.');
}

/// The signed-in user is not allowed to do this. Usually means a security rule
/// rejected the write, which is the rules working as intended.
class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({super.cause})
    : super(
        title: 'Not allowed',
        message: 'You do not have permission to do this.',
      );
}

/// Anything not otherwise classified. Carries a generic message; the [cause]
/// goes to crash reporting.
class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause})
    : super(
        title: 'Something went wrong',
        message: 'An unexpected error occurred. Please try again.',
        recovery: 'Try again',
      );
}

/// Normalises an arbitrary caught object into an [AppFailure].
///
/// Every repository funnels through this so a stray exception can never reach
/// the UI as a stack trace.
AppFailure toAppFailure(Object error) {
  if (error is AppFailure) return error;
  return UnknownFailure(cause: error);
}

/// Backend quota exhausted. Rare, but worth its own message so the user is not
/// told to "try again" when trying again will not help immediately.
class QuotaFailure extends AppFailure {
  const QuotaFailure({super.cause})
    : super(
        title: 'Service busy',
        message:
            'Nearby is handling a lot of requests right now. Try again shortly.',
        recovery: 'Try again',
      );
}
