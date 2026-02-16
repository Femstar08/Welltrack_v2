import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/auth/data/auth_repository.dart';
import 'package:welltrack/features/auth/domain/auth_state.dart';
import 'package:welltrack/features/auth/domain/user_entity.dart';

/// StateNotifier that manages authentication state
/// Watches Supabase auth state and provides auth operations
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<UserEntity?>? _authStateSubscription;

  AuthNotifier(this._repository) : super(const AuthInitial()) {
    _initialize();
  }

  /// Initialize auth state by checking current session
  /// and setting up auth state change listener
  void _initialize() async {
    try {
      final currentUser = _repository.getCurrentUser();
      if (currentUser != null) {
        // User has active session, fetch full profile
        final user = await _repository.fetchUserProfile(currentUser.id);
        state = AuthAuthenticated(user);
      } else {
        state = const AuthUnauthenticated();
      }

      // Listen to auth state changes
      _authStateSubscription = _repository.onAuthStateChange().listen(
        (user) async {
          if (user != null) {
            // User signed in, fetch full profile
            try {
              final fullUser = await _repository.fetchUserProfile(user.id);
              state = AuthAuthenticated(fullUser);
            } catch (e) {
              state = AuthError('Failed to load user profile: $e');
            }
          } else {
            // User signed out
            state = const AuthUnauthenticated();
          }
        },
        onError: (error) {
          state = AuthError('Auth state error: $error');
        },
      );
    } catch (e) {
      state = AuthError('Failed to initialize auth: $e');
    }
  }

  /// Sign up a new user with email and password
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(_extractErrorMessage(e));
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.signIn(
        email: email,
        password: password,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(_extractErrorMessage(e));
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    state = const AuthLoading();
    try {
      await _repository.signOut();
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(_extractErrorMessage(e));
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? onboardingCompleted,
  }) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    state = const AuthLoading();
    try {
      final updatedUser = await _repository.updateUserProfile(
        userId: currentState.user.id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        onboardingCompleted: onboardingCompleted,
      );
      state = AuthAuthenticated(updatedUser);
    } catch (e) {
      state = AuthError(_extractErrorMessage(e));
      // Restore previous state after a delay
      Future.delayed(const Duration(seconds: 2), () {
        state = currentState;
      });
    }
  }

  /// Clear error state and return to unauthenticated
  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(dynamic error) {
    final errorString = error.toString();

    // Common Supabase auth errors
    if (errorString.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (errorString.contains('Email not confirmed')) {
      return 'Please confirm your email address';
    }
    if (errorString.contains('User already registered')) {
      return 'An account with this email already exists';
    }
    if (errorString.contains('Password should be at least')) {
      return 'Password must be at least 6 characters';
    }
    if (errorString.contains('Network request failed')) {
      return 'Network error. Please check your connection';
    }

    // Default error message
    return errorString.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Helper provider to get current user if authenticated
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authProvider);
  return authState is AuthAuthenticated ? authState.user : null;
});

/// Helper provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is AuthAuthenticated;
});
