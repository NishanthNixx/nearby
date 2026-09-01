import 'app_user.dart';

/// Credentials for creating an account.
class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.password,
    required this.role,
    required this.displayName,
    this.phone,
  });

  final String email;
  final String password;
  final UserRole role;
  final String displayName;
  final String? phone;
}

/// Authentication and the signed-in user's profile record.
///
/// The interface speaks only in [AppUser] and plain values. Swapping the
/// Firebase implementation for one backed by a REST API and PostgreSQL means
/// writing a second class against this contract — no change above it.
abstract interface class AuthRepository {
  /// Emits the current user, or null when signed out.
  ///
  /// Emits at least once after subscribing, so the splash screen can decide
  /// where to route without a separate call.
  Stream<AppUser?> watchAuthState();

  /// The current user, or null. Synchronous read of the cached state.
  AppUser? get currentUser;

  /// Throws [AuthFailure] on bad credentials.
  Future<AppUser> signIn({required String email, required String password});

  /// Creates the account and its profile record together.
  Future<AppUser> signUp(SignUpRequest request);

  Future<void> signOut();

  /// Sends a password reset email. Succeeds silently for unknown addresses so
  /// the endpoint cannot be used to enumerate accounts.
  Future<void> sendPasswordReset(String email);

  /// Updates the mutable parts of the signed-in user's own profile.
  Future<AppUser> updateProfile({
    String? displayName,
    String? phone,
    String? photoUrl,
  });

  /// Links an owner account to the business listing they just created.
  Future<AppUser> linkBusiness(String businessId);
}
