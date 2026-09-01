import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// State of an in-flight authentication attempt.
class AuthFormState {
  const AuthFormState({this.isSubmitting = false, this.failure});

  final bool isSubmitting;

  /// The last failure, or null. Held in state rather than thrown so the form
  /// can render it inline next to the fields.
  final AppFailure? failure;

  /// Per-field messages, when the failure identified specific fields.
  Map<String, String> get fieldErrors {
    final current = failure;
    return current is ValidationFailure ? current.fieldErrors : const {};
  }

  AuthFormState copyWith({
    bool? isSubmitting,
    AppFailure? failure,
    bool clearFailure = false,
  }) => AuthFormState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Drives sign-in and sign-up.
///
/// The controller never navigates. It changes auth state, and the router's
/// redirect reacts — so there is exactly one place that decides where a signed-in
/// user belongs.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() => _repository.signIn(email: email, password: password));
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
  }) async {
    return _run(
      () => _repository.signUp(
        SignUpRequest(
          email: email,
          password: password,
          role: role,
          displayName: displayName,
          phone: phone,
        ),
      ),
    );
  }

  Future<bool> sendPasswordReset(String email) async {
    return _run(() => _repository.sendPasswordReset(email));
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  /// Clears the error once the user starts correcting it, so a stale message
  /// does not sit under a field they have already fixed.
  void clearFailure() {
    if (state.failure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AuthFormState(isSubmitting: true);
    try {
      await action();
      state = const AuthFormState();
      return true;
    } catch (error) {
      state = AuthFormState(failure: toAppFailure(error));
      return false;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(
  AuthController.new,
);
