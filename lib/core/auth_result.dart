/// Result type for authentication operations.
/// Either Success<T> or Failure<E>
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
  String get message => 'No account found with this email';
}

final class AuthFailureWrongPassword extends AuthFailure {
  @override
  String get message => 'Incorrect password';
}

final class AuthFailureInvalidEmail extends AuthFailure {
  @override
  String get message => 'Please enter a valid email address';
}

final class AuthFailureWeakPassword extends AuthFailure {
  @override
  String get message => 'Password must be at least 6 characters';
}

final class AuthFailureEmailInUse extends AuthFailure {
  @override
  String get message => 'This email is already registered';
}

final class AuthFailureUserDisabled extends AuthFailure {
  @override
  String get message => 'This account has been disabled';
}

final class AuthFailureInvalidPhoneNumber extends AuthFailure {
  @override
  String get message => 'Invalid phone number';
}

final class AuthFailureTooManyRequests extends AuthFailure {
  @override
  String get message => 'Too many attempts. Please try again later';
}

final class AuthFailureInvalidVerificationCode extends AuthFailure {
  @override
  String get message => 'Invalid verification code';
}

final class AuthFailurePhoneVerificationFailed extends AuthFailure {
  @override
  String get message => 'Phone verification failed. Please try again';
}

final class AuthFailureNetwork extends AuthFailure {
  final String? details;

  AuthFailureNetwork([this.details]);

  @override
  String get message => 'Network error. Please check your connection';
}

final class AuthFailureUnknown extends AuthFailure {
  final String? details;

  AuthFailureUnknown([this.details]);

  @override
  String get message => details ?? 'An unexpected error occurred';
}
