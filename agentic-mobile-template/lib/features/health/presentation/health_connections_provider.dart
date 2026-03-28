import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_connections_repository.dart';
import '../domain/health_connection_entity.dart';
import '../../../shared/core/logging/app_logger.dart';

final _logger = AppLogger();

// ---------------------------------------------------------------------------
// OAuth URL constants
// ---------------------------------------------------------------------------

/// Redirect URI registered with Garmin Connect for this app.
const _garminRedirectUri = 'welltrack://oauth/garmin/callback';

/// Redirect URI registered with Strava for this app.
const _stravaRedirectUri = 'welltrack://oauth/strava/callback';

/// Strava client_id is embedded in the authorization URL (not secret).
/// Injected via --dart-define at build time.
const _stravaClientId = String.fromEnvironment(
  'STRAVA_CLIENT_ID',
  defaultValue: '',
);

/// Garmin OAuth 2.0 authorize endpoint.
/// The `oauth_token` (request token) is obtained by the Edge Function during
/// the initiation step; the UI opens this URL after receiving it.
const _garminAuthorizeBase =
    'https://connect.garmin.com/oauthConfirm';

/// Strava OAuth 2.0 authorization URL (complete, ready for url_launcher).
String buildStravaAuthorizationUrl() {
  final params = Uri(queryParameters: {
    'client_id': _stravaClientId,
    'redirect_uri': _stravaRedirectUri,
    'response_type': 'code',
    'approval_prompt': 'auto',
    'scope': 'read,activity:read_all',
  }).query;
  return 'https://www.strava.com/oauth/authorize?$params';
}

/// Builds a Garmin authorization URL from a server-issued request token.
///
/// [requestToken] is retrieved from the `oauth-garmin` Edge Function
/// `initiate` action before opening the browser.
String buildGarminAuthorizationUrl(String requestToken) {
  return '$_garminAuthorizeBase?oauth_token=$requestToken';
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for [HealthConnectionsNotifier].
class HealthConnectionsState {
  const HealthConnectionsState({
    this.garminConnected = false,
    this.stravaConnected = false,
    this.garminLastSync,
    this.stravaLastSync,
    this.isLoading = false,
    this.isConnecting = false,
    this.error,
  });

  /// Whether Garmin OAuth token is active on the server
  final bool garminConnected;

  /// Whether Strava OAuth token is active on the server
  final bool stravaConnected;

  /// Timestamp of the most-recent Garmin data pull
  final DateTime? garminLastSync;

  /// Timestamp of the most-recent Strava data pull
  final DateTime? stravaLastSync;

  /// True while the initial [loadConnections] call is in flight
  final bool isLoading;

  /// True while a connect / disconnect call is in flight
  final bool isConnecting;

  /// Non-null when the last operation produced an error
  final String? error;

  HealthConnectionsState copyWith({
    bool? garminConnected,
    bool? stravaConnected,
    DateTime? garminLastSync,
    DateTime? stravaLastSync,
    bool? isLoading,
    bool? isConnecting,
    String? error,
    bool clearError = false,
  }) {
    return HealthConnectionsState(
      garminConnected: garminConnected ?? this.garminConnected,
      stravaConnected: stravaConnected ?? this.stravaConnected,
      garminLastSync: garminLastSync ?? this.garminLastSync,
      stravaLastSync: stravaLastSync ?? this.stravaLastSync,
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      // null clears error; clearError flag also clears it
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages Garmin and Strava connection state for a single profile.
///
/// Keyed by profileId via [healthConnectionsProvider].
class HealthConnectionsNotifier
    extends StateNotifier<HealthConnectionsState> {
  HealthConnectionsNotifier({
    required String profileId,
    required HealthConnectionsRepository repository,
  })  : _profileId = profileId,
        _repository = repository,
        super(const HealthConnectionsState()) {
    loadConnections();
  }

  final String _profileId;
  final HealthConnectionsRepository _repository;

  // -------------------------------------------------------------------------
  // Public methods
  // -------------------------------------------------------------------------

  /// Loads current connection status from `wt_health_connections` and
  /// populates [garminConnected], [stravaConnected], and last-sync timestamps.
  Future<void> loadConnections() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final connections = await _repository.getConnections(_profileId);
      _applyConnections(connections);
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.loadConnections failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load connection status. Please try again.',
      );
    }
  }

  /// Fetches a Garmin OAuth authorization URL from the Edge Function.
  ///
  /// The Edge Function builds the URL server-side so the client_id stays
  /// secret. Returns the full URL ready to open in the browser.
  ///
  /// Sets [isConnecting] to true while the request is in flight so the UI
  /// can show a loading indicator.  On failure, sets [error] and returns null.
  Future<String?> initiateGarminOAuth() async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      // The Edge Function's initiate action returns the full auth URL
      // in the oauth_token field.
      final authUrl =
          await _repository.getGarminRequestToken(_profileId);
      state = state.copyWith(isConnecting: false);
      return authUrl;
    } catch (e) {
      _logger.error('HealthConnectionsNotifier.initiateGarminOAuth failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to start Garmin authorization. Please try again.',
      );
      return null;
    }
  }

  /// Completes the Garmin OAuth flow after the user is redirected back from
  /// Garmin Connect.
  ///
  /// [authCode] — the `code` (or `oauth_verifier` for OAuth 1) value extracted
  ///   from the deep-link URI `welltrack://oauth/garmin/callback`.
  /// [redirectUri] — must equal [_garminRedirectUri]; exposed here so callers
  ///   can pass the exact URI they registered.
  Future<void> connectGarmin(String authCode, String redirectUri) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      final connection = await _repository.connectGarmin(
        _profileId,
        authCode,
        redirectUri,
      );
      state = state.copyWith(
        garminConnected: connection.isConnected,
        garminLastSync: connection.lastSyncAt,
        isConnecting: false,
      );
      _logger.info(
          'HealthConnectionsNotifier: Garmin connected for profile $_profileId');
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.connectGarmin failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect Garmin. Please try again.',
      );
    }
  }

  /// Revokes the Garmin OAuth token and marks the connection as inactive.
  Future<void> disconnectGarmin() async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      await _repository.disconnectGarmin(_profileId);
      state = state.copyWith(
        garminConnected: false,
        garminLastSync: null,
        isConnecting: false,
      );
      _logger.info(
          'HealthConnectionsNotifier: Garmin disconnected for profile $_profileId');
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.disconnectGarmin failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to disconnect Garmin. Please try again.',
      );
    }
  }

  /// Completes the Strava OAuth flow after the user is redirected back from
  /// Strava.
  ///
  /// [authCode] — the `code` value extracted from the deep-link URI
  ///   `welltrack://oauth/strava/callback?code=<authCode>`.
  Future<void> connectStrava(String authCode) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      final connection =
          await _repository.connectStrava(_profileId, authCode);
      state = state.copyWith(
        stravaConnected: connection.isConnected,
        stravaLastSync: connection.lastSyncAt,
        isConnecting: false,
      );
      _logger.info(
          'HealthConnectionsNotifier: Strava connected for profile $_profileId');
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.connectStrava failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect Strava. Please try again.',
      );
    }
  }

  /// Revokes the Strava OAuth token and marks the connection as inactive.
  Future<void> disconnectStrava() async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      await _repository.disconnectStrava(_profileId);
      state = state.copyWith(
        stravaConnected: false,
        stravaLastSync: null,
        isConnecting: false,
      );
      _logger.info(
          'HealthConnectionsNotifier: Strava disconnected for profile $_profileId');
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.disconnectStrava failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to disconnect Strava. Please try again.',
      );
    }
  }

  /// Triggers a manual sync for [provider] via the backfill-health-data
  /// Edge Function.
  ///
  /// Returns `true` if sync was triggered, `false` if rate-limited (< 24h).
  Future<bool> triggerManualSync(String provider) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      final triggered =
          await _repository.triggerManualSync(_profileId, provider);
      state = state.copyWith(isConnecting: false);
      if (triggered) {
        // Update lastSync optimistically
        final now = DateTime.now();
        if (provider == 'garmin') {
          state = state.copyWith(garminLastSync: now);
        } else {
          state = state.copyWith(stravaLastSync: now);
        }
      }
      return triggered;
    } catch (e) {
      _logger.error(
          'HealthConnectionsNotifier.triggerManualSync ($provider) failed: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to sync $provider data. Please try again.',
      );
      return false;
    }
  }

  /// Clears any displayed error without changing connection state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _applyConnections(List<HealthConnectionEntity> connections) {
    var garminConnected = false;
    DateTime? garminLastSync;
    var stravaConnected = false;
    DateTime? stravaLastSync;

    for (final conn in connections) {
      if (conn.provider == 'garmin') {
        garminConnected = conn.isConnected;
        garminLastSync = conn.lastSyncAt;
      } else if (conn.provider == 'strava') {
        stravaConnected = conn.isConnected;
        stravaLastSync = conn.lastSyncAt;
      }
    }

    state = state.copyWith(
      garminConnected: garminConnected,
      stravaConnected: stravaConnected,
      garminLastSync: garminLastSync,
      stravaLastSync: stravaLastSync,
      isLoading: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// StateNotifierProvider keyed by profileId.
///
/// Usage:
/// ```dart
/// final state = ref.watch(healthConnectionsProvider('profile-uuid'));
/// final notifier = ref.read(healthConnectionsProvider('profile-uuid').notifier);
/// ```
final healthConnectionsProvider = StateNotifierProvider.family<
    HealthConnectionsNotifier,
    HealthConnectionsState,
    String>((ref, profileId) {
  final repository = ref.watch(healthConnectionsRepositoryProvider);
  return HealthConnectionsNotifier(
    profileId: profileId,
    repository: repository,
  );
});

/// Convenience provider that resolves the Garmin redirect URI constant.
/// Consumed by the OAuth deep-link handler to pass back to the notifier.
const garminOAuthRedirectUri = _garminRedirectUri;

/// Convenience provider that resolves the Strava redirect URI constant.
const stravaOAuthRedirectUri = _stravaRedirectUri;
