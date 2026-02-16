import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../logging/app_logger.dart';

/// Service for managing Supabase client and authentication
class SupabaseService {
  SupabaseClient? _client;
  final AppLogger _logger = AppLogger();

  /// Get Supabase client instance
  SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase not initialized. Call init() first.');
    }
    return _client!;
  }

  /// Get current session
  Session? get currentSession => _client?.auth.currentSession;

  /// Get current user
  User? get currentUser => _client?.auth.currentUser;

  /// Get anon key for headers
  String get anonKey => ApiConstants.supabaseAnonKey;

  /// Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  /// Initialize Supabase
  Future<void> init() async {
    try {
      if (_client != null) {
        _logger.info('Supabase already initialized');
        return;
      }

      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
        storageOptions: const StorageClientOptions(
          retryAttempts: 3,
        ),
      );

      _client = Supabase.instance.client;
      _logger.info('Supabase initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error initializing Supabase', e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.info('Signing in with email: $email');
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _logger.info('Sign in successful');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Error signing in', e, stackTrace);
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.info('Signing up with email: $email');
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
      _logger.info('Sign up successful');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Error signing up', e, stackTrace);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.info('Signing out');
      await client.auth.signOut();
      _logger.info('Sign out successful');
    } catch (e, stackTrace) {
      _logger.error('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  /// Refresh session
  Future<AuthResponse> refreshSession() async {
    try {
      _logger.info('Refreshing session');
      final response = await client.auth.refreshSession();
      _logger.info('Session refreshed successfully');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Error refreshing session', e, stackTrace);
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPasswordForEmail(String email) async {
    try {
      _logger.info('Sending password reset email to: $email');
      await client.auth.resetPasswordForEmail(email);
      _logger.info('Password reset email sent');
    } catch (e, stackTrace) {
      _logger.error('Error sending password reset email', e, stackTrace);
      rethrow;
    }
  }

  /// Update user
  Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.info('Updating user');
      final response = await client.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
          data: data,
        ),
      );
      _logger.info('User updated successfully');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Error updating user', e, stackTrace);
      rethrow;
    }
  }

  /// Get auth state changes stream
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}

/// Riverpod provider for SupabaseService
/// Uses the already-initialized Supabase.instance.client from main.dart
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final service = SupabaseService();
  // Supabase.initialize() is called in main.dart before ProviderScope,
  // so Supabase.instance.client is already available here.
  service._client = Supabase.instance.client;
  return service;
});
