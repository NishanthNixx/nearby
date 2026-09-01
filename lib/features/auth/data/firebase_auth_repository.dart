import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/config/app_config.dart';
import '../../../core/data/firebase_error_mapper.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'user_mapper.dart';

/// Firebase Auth + Firestore implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _cached;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  @override
  AppUser? get currentUser => _cached;

  @override
  Stream<AppUser?> watchAuthState() {
    // The signed-in identity comes from Auth, but the role and profile live in
    // Firestore. Switching to the profile document whenever the identity
    // changes means a profile edit is reflected without a separate refresh.
    final stream = _auth.authStateChanges().asyncExpand((account) {
      if (account == null) {
        _cached = null;
        return Stream<AppUser?>.value(null);
      }

      return _users.doc(account.uid).snapshots().map((doc) {
        if (!doc.exists) {
          // An auth account with no profile document is an incomplete signup.
          // Treating it as signed out is deterministic; the alternative is a
          // user stuck on a screen with no role.
          _cached = null;
          return null;
        }
        final user = UserMapper.fromDocument(doc);
        _cached = user;
        return user;
      });
    });

    return FirebaseErrorMapper.guardStream(stream);
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) {
    return FirebaseErrorMapper.guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) throw AuthFailure.unknown();

      final doc = await _users.doc(uid).get();
      if (!doc.exists) {
        // No profile means the account cannot be routed. Sign back out rather
        // than leaving a half-authenticated session behind.
        await _auth.signOut();
        throw const AuthFailure(
          title: 'Account incomplete',
          message:
              'This account is missing its profile. Sign up again or contact support.',
        );
      }

      final user = UserMapper.fromDocument(doc);
      _cached = user;
      return user;
    });
  }

  @override
  Future<AppUser> signUp(SignUpRequest request) {
    return FirebaseErrorMapper.guard(() async {
      _validateSignUp(request);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: request.email.trim(),
        password: request.password,
      );

      final account = credential.user;
      if (account == null) throw AuthFailure.unknown();

      final user = AppUser(
        id: account.uid,
        email: request.email.trim(),
        role: request.role,
        createdAt: DateTime.now(),
        displayName: request.displayName.trim(),
        phone: request.phone?.trim(),
      );

      try {
        await _users.doc(account.uid).set(UserMapper.toCreatePayload(user));
      } catch (error) {
        // The auth account exists but the profile write failed. Remove the
        // account so the user can retry cleanly instead of being locked out by
        // an "email already in use" error on their next attempt.
        await account.delete().catchError((_) {});
        throw FirebaseErrorMapper.map(error);
      }

      await account.updateDisplayName(request.displayName.trim());

      _cached = user;
      return user;
    });
  }

  @override
  Future<void> signOut() {
    return FirebaseErrorMapper.guard(() async {
      await _auth.signOut();
      _cached = null;
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return FirebaseErrorMapper.guard(() async {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on fb.FirebaseAuthException catch (error) {
        // Succeeding silently for an unknown address stops this endpoint from
        // being used to discover which emails have accounts.
        if (error.code == 'user-not-found') return;
        rethrow;
      }
    });
  }

  @override
  Future<AppUser> updateProfile({
    String? displayName,
    String? phone,
    String? photoUrl,
  }) {
    return FirebaseErrorMapper.guard(() async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw AuthFailure.notSignedIn();

      final payload = UserMapper.toProfileUpdatePayload(
        displayName: displayName?.trim(),
        phone: phone?.trim(),
        photoUrl: photoUrl,
      );

      if (payload.isNotEmpty) {
        await _users.doc(uid).update(payload);
      }

      final doc = await _users.doc(uid).get();
      final user = UserMapper.fromDocument(doc);
      _cached = user;
      return user;
    });
  }

  @override
  Future<AppUser> linkBusiness(String businessId) {
    return FirebaseErrorMapper.guard(() async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw AuthFailure.notSignedIn();

      await _users
          .doc(uid)
          .update(UserMapper.toBusinessLinkPayload(businessId));

      final doc = await _users.doc(uid).get();
      final user = UserMapper.fromDocument(doc);
      _cached = user;
      return user;
    });
  }

  void _validateSignUp(SignUpRequest request) {
    final errors = <String, String>{};

    if (!_looksLikeEmail(request.email)) {
      errors['email'] = 'Enter a valid email address';
    }
    if (request.password.length < 8) {
      errors['password'] = 'Use at least 8 characters';
    }
    if (request.displayName.trim().isEmpty) {
      errors['displayName'] = 'Enter your name';
    }

    if (errors.isNotEmpty) {
      throw ValidationFailure(
        message: 'Some details need fixing before you can continue.',
        fieldErrors: errors,
      );
    }
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}
