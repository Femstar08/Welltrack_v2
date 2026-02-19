import 'user_entity.dart';

/// Authentication state for the entire app
/// Uses sealed classes for exhaustive pattern matching
sealed class AuthState {
  const AuthState();
}

/// Initial state when auth status is unknown
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during authentication operations
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated with a valid session
class AuthAuthenticated extends AuthState {

  const AuthAuthenticated(this.user);
  final UserEntity user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

/// User is not authenticated
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication error occurred
class AuthError extends AuthState {

  const AuthError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
