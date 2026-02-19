import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_entity.dart';

/// Data source that wraps Supabase Auth client
/// Handles all authentication operations with Supabase backend
class SupabaseAuthSource {

  SupabaseAuthSource(this._supabase);
  final SupabaseClient _supabase;

  /// Sign up a new user with email and password
  /// After successful signup, the DB trigger auto-creates wt_users + wt_profiles
  Future<UserEntity> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
        },
      );

      if (response.user == null) {
        throw Exception('Sign up failed: No user returned');
      }

      return _mapToUserEntity(response.user!);
    } on AuthException catch (e) {
      throw Exception('Sign up failed: ${e.message}');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Sign in an existing user with email and password
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      return _mapToUserEntity(response.user!);
    } on AuthException catch (e) {
      throw Exception('Sign in failed: ${e.message}');
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Get the current authenticated user
  /// Returns null if no user is signed in
  UserEntity? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return _mapToUserEntity(user);
  }

  /// Stream of auth state changes
  /// Emits a UserEntity when user signs in, null when user signs out
  Stream<UserEntity?> onAuthStateChange() {
    return _supabase.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return _mapToUserEntity(user);
    });
  }

  /// Check if a user is currently authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Map Supabase User to UserEntity
  UserEntity _mapToUserEntity(User user) {
    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      onboardingCompleted:
          user.userMetadata?['onboarding_completed'] as bool? ?? false,
      planTier: user.userMetadata?['plan_tier'] as String? ?? 'free',
    );
  }

  /// Refresh the current session
  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (e) {
      throw Exception('Failed to refresh session: $e');
    }
  }
}
