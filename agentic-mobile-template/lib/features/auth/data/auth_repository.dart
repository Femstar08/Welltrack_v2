import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_source.dart';
import '../domain/user_entity.dart';

/// Repository that handles authentication business logic
/// Uses SupabaseAuthSource for data operations
class AuthRepository {

  AuthRepository(this._authSource, this._supabase);
  final SupabaseAuthSource _authSource;
  final SupabaseClient _supabase;

  /// Sign up a new user
  Future<UserEntity> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await _authSource.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );

    // Fetch full user profile from database after signup
    return await fetchUserProfile(user.id);
  }

  /// Sign in an existing user
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _authSource.signIn(
      email: email,
      password: password,
    );

    // Fetch full user profile from database after signin
    return await fetchUserProfile(user.id);
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _authSource.signOut();
  }

  /// Get the current authenticated user
  UserEntity? getCurrentUser() {
    return _authSource.getCurrentUser();
  }

  /// Stream of auth state changes
  Stream<UserEntity?> onAuthStateChange() {
    return _authSource.onAuthStateChange();
  }

  /// Fetch full user profile from wt_users table
  /// Email comes from auth.users (not stored in wt_users)
  Future<UserEntity> fetchUserProfile(String userId) async {
    try {
      // Query wt_users table for user data
      final userData = await _supabase
          .from('wt_users')
          .select(
              'id, display_name, avatar_url, plan_tier, onboarding_completed')
          .eq('id', userId)
          .single();

      // Get email from the auth user (not in wt_users)
      final authEmail =
          _supabase.auth.currentUser?.email ?? '';

      return UserEntity(
        id: userData['id'] as String,
        email: authEmail,
        displayName: userData['display_name'] as String?,
        avatarUrl: userData['avatar_url'] as String?,
        planTier: userData['plan_tier'] as String? ?? 'free',
        onboardingCompleted:
            userData['onboarding_completed'] as bool? ?? false,
      );
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Update user profile
  Future<UserEntity> updateUserProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    bool? onboardingCompleted,
  }) async {
    try {
      // Update wt_users table
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (onboardingCompleted != null) {
        updates['onboarding_completed'] = onboardingCompleted;
      }

      if (updates.isNotEmpty) {
        await _supabase.from('wt_users').update(updates).eq('id', userId);
      }

      // Fetch and return updated profile
      return await fetchUserProfile(userId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _authSource.isAuthenticated;

  /// Refresh the current session
  Future<void> refreshSession() async {
    await _authSource.refreshSession();
  }
}

/// Riverpod provider for SupabaseAuthSource
final supabaseAuthSourceProvider = Provider<SupabaseAuthSource>((ref) {
  return SupabaseAuthSource(Supabase.instance.client);
});

/// Riverpod provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authSource = ref.watch(supabaseAuthSourceProvider);
  return AuthRepository(authSource, Supabase.instance.client);
});
