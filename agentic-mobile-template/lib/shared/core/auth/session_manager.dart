import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';
import '../constants/storage_keys.dart';
import '../storage/secure_storage_service.dart';
import 'supabase_service.dart';

/// Manager for handling authentication session state and persistence
class SessionManager {

  SessionManager({
    required SupabaseService supabaseService,
    required SecureStorageService secureStorage,
  })  : _supabaseService = supabaseService,
        _secureStorage = secureStorage;
  final SupabaseService _supabaseService;
  final SecureStorageService _secureStorage;
  final AppLogger _logger = AppLogger();

  StreamSubscription<AuthState>? _authSubscription;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  /// Get auth state changes stream
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// Get current user ID
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Get current session
  Session? get currentSession => _supabaseService.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  /// Initialize session manager and listen to auth changes
  Future<void> init() async {
    try {
      _logger.info('Initializing SessionManager');

      // Listen to auth state changes
      _authSubscription = _supabaseService.authStateChanges.listen(
        _handleAuthStateChange,
        onError: (error, stackTrace) {
          _logger.error('Auth state change error', error, stackTrace);
        },
      );

      // Check for existing session
      final session = _supabaseService.currentSession;
      if (session != null) {
        await _persistSession(session);
        _logger.info('Existing session found for user: ${session.user.id}');
      }

      _logger.info('SessionManager initialized');
    } catch (e, stackTrace) {
      _logger.error('Error initializing SessionManager', e, stackTrace);
      rethrow;
    }
  }

  /// Handle auth state changes
  Future<void> _handleAuthStateChange(AuthState authState) async {
    try {
      _logger.info('Auth state changed: ${authState.event}');

      switch (authState.event) {
        case AuthChangeEvent.signedIn:
          if (authState.session != null) {
            await _persistSession(authState.session!);
            _logger.info('User signed in: ${authState.session!.user.id}');
          }
          break;

        case AuthChangeEvent.signedOut:
          await _clearSession();
          _logger.info('User signed out');
          break;

        case AuthChangeEvent.tokenRefreshed:
          if (authState.session != null) {
            await _persistSession(authState.session!);
            _logger.info('Token refreshed');
          }
          break;

        case AuthChangeEvent.userUpdated:
          _logger.info('User updated');
          break;

        default:
          _logger.debug('Unhandled auth event: ${authState.event}');
      }

      // Emit the auth state change
      _authStateController.add(authState);
    } catch (e, stackTrace) {
      _logger.error('Error handling auth state change', e, stackTrace);
    }
  }

  /// Persist session data to secure storage
  Future<void> _persistSession(Session session) async {
    try {
      await _secureStorage.write(
        key: StorageKeys.accessToken,
        value: session.accessToken,
      );

      if (session.refreshToken != null) {
        await _secureStorage.write(
          key: StorageKeys.refreshToken,
          value: session.refreshToken!,
        );
      }

      await _secureStorage.write(
        key: StorageKeys.userId,
        value: session.user.id,
      );

      _logger.debug('Session persisted to secure storage');
    } catch (e, stackTrace) {
      _logger.error('Error persisting session', e, stackTrace);
    }
  }

  /// Clear session data from secure storage
  Future<void> _clearSession() async {
    try {
      await _secureStorage.delete(key: StorageKeys.accessToken);
      await _secureStorage.delete(key: StorageKeys.refreshToken);
      await _secureStorage.delete(key: StorageKeys.userId);
      await _secureStorage.delete(key: StorageKeys.profileId);

      _logger.debug('Session cleared from secure storage');
    } catch (e, stackTrace) {
      _logger.error('Error clearing session', e, stackTrace);
    }
  }

  /// Get active profile ID from secure storage
  Future<String?> getActiveProfileId() async {
    try {
      return await _secureStorage.read(key: StorageKeys.profileId);
    } catch (e, stackTrace) {
      _logger.error('Error getting active profile ID', e, stackTrace);
      return null;
    }
  }

  /// Set active profile ID in secure storage
  Future<void> setActiveProfileId(String profileId) async {
    try {
      await _secureStorage.write(
        key: StorageKeys.profileId,
        value: profileId,
      );
      _logger.info('Active profile set: $profileId');
    } catch (e, stackTrace) {
      _logger.error('Error setting active profile ID', e, stackTrace);
      rethrow;
    }
  }

  /// Refresh current session
  Future<void> refreshSession() async {
    try {
      await _supabaseService.refreshSession();
      _logger.info('Session refresh triggered');
    } catch (e, stackTrace) {
      _logger.error('Error refreshing session', e, stackTrace);
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _authStateController.close();
    _logger.info('SessionManager disposed');
  }
}

/// Riverpod provider for SessionManager
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final manager = SessionManager(
    supabaseService: supabaseService,
    secureStorage: secureStorage,
  );

  // Dispose when provider is disposed
  ref.onDispose(() => manager.dispose());

  return manager;
});

/// Riverpod StreamProvider for auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.authStateChanges;
});

/// Riverpod provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.currentUserId;
});
