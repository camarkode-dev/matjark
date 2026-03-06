/// Result type for authentication operations.
/// Either Success or Failure
sealed class Result<S, F> {
  const Result();

  /// Get success value or null
  S? getOrNull() => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  /// Get failure value or null
  F? getErrorOrNull() => switch (this) {
        Success() => null,
        Failure(failure: final f) => f,
      };

  /// Map success to another type
  Result<T, F> map<T>(T Function(S) f) => switch (this) {
        Success(value: final v) => Success(f(v)),
        Failure(failure: final err) => Failure(err),
      };

  /// Execute side effect on success
  Result<S, F> onSuccess(void Function(S) f) {
    if (this is Success<S, F>) {
      f((this as Success<S, F>).value);
    }
    return this;
  }

  /// Execute side effect on failure
  Result<S, F> onFailure(void Function(F) f) {
    if (this is Failure<S, F>) {
      f((this as Failure<S, F>).failure);
    }
    return this;
  }
}

/// Success result
final class Success<S, F> extends Result<S, F> {
  final S value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Failure result
final class Failure<S, F> extends Result<S, F> {
  final F failure;

  const Failure(this.failure);

  @override
  String toString() => 'Failure($failure)';
}

/// Authentication failure reasons
sealed class AuthFailure {
  const AuthFailure();

  /// User-friendly error message
  String get message;
}

final class AuthFailureEmailNotFound extends AuthFailure {
  @override
  String get message => 'auth.errors.email_not_found';
}

final class AuthFailureWrongPassword extends AuthFailure {
  @override
  String get message => 'auth.errors.wrong_password';
}

final class AuthFailureInvalidEmail extends AuthFailure {
  @override
  String get message => 'auth.errors.invalid_email';
}

final class AuthFailureWeakPassword extends AuthFailure {
  @override
  String get message => 'auth.errors.weak_password';
}

final class AuthFailureEmailInUse extends AuthFailure {
  @override
  String get message => 'auth.errors.email_in_use';
}

final class AuthFailureUserDisabled extends AuthFailure {
  @override
  String get message => 'auth.errors.user_disabled';
}

final class AuthFailureInvalidPhoneNumber extends AuthFailure {
  @override
  String get message => 'auth.errors.invalid_phone_number';
}

final class AuthFailureTooManyRequests extends AuthFailure {
  @override
  String get message => 'auth.errors.too_many_requests';
}

final class AuthFailureInvalidVerificationCode extends AuthFailure {
  @override
  String get message => 'auth.errors.invalid_verification_code';
}

final class AuthFailurePhoneVerificationFailed extends AuthFailure {
  @override
  String get message => 'auth.errors.phone_verification_failed';
}

final class AuthFailureGoogleClientIdMissing extends AuthFailure {
  @override
  String get message => 'auth.errors.google_client_id_missing';
}

final class AuthFailurePhoneSetupRequired extends AuthFailure {
  @override
  String get message => 'auth.errors.phone_setup_required';
}

final class AuthFailureRecaptchaCheckFailed extends AuthFailure {
  @override
  String get message => 'auth.errors.recaptcha_check_failed';
}

final class AuthFailureNetwork extends AuthFailure {
  final String? details;

  AuthFailureNetwork([this.details]);

  @override
  String get message =>
      _normalizeAuthMessageKey(details, 'auth.errors.network');
}

final class AuthFailureUnknown extends AuthFailure {
  final String? details;

  AuthFailureUnknown([this.details]);

  @override
  String get message =>
      _normalizeAuthMessageKey(details, 'auth.errors.unexpected');
}

String _normalizeAuthMessageKey(String? details, String fallback) {
  final value = details?.trim();
  if (value == null || value.isEmpty) return fallback;
  if (value.startsWith('auth.')) return value;
  return fallback;
}
