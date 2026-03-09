import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/health_connection_entity.dart';
import '../../../shared/core/logging/app_logger.dart';

final _logger = AppLogger();

/// Riverpod provider for [HealthConnectionsRepository].
final healthConnectionsRepositoryProvider =
    Provider<HealthConnectionsRepository>((ref) {
  return HealthConnectionsRepository(Supabase.instance.client);
});

/// Data layer for Garmin and Strava OAuth connections.
///
/// All OAuth token exchange is delegated to Supabase Edge Functions
/// (`oauth-garmin` and `oauth-strava`). This repository only:
///   - reads connection status from `wt_health_connections`
///   - invokes Edge Functions to initiate / revoke connections
///
/// Tokens are NEVER handled client-side.
class HealthConnectionsRepository {
  HealthConnectionsRepository(this._client);

  final SupabaseClient _client;

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  /// Returns all OAuth connection records for [profileId].
  ///
  /// Queries the `wt_health_connections` table which the Edge Function
  /// populates after a successful token exchange.
  Future<List<HealthConnectionEntity>> getConnections(
      String profileId) async {
    try {
      final response = await _client
          .from('wt_health_connections')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) =>
              HealthConnectionEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('HealthConnectionsRepository.getConnections failed: $e');
      throw Exception('Failed to fetch health connections: $e');
    }
  }

  /// Returns `true` if [profileId] has an active connection for [provider].
  ///
  /// [provider] must be `'garmin'` or `'strava'`.
  Future<bool> isConnected(String profileId, String provider) async {
    try {
      final response = await _client
          .from('wt_health_connections')
          .select('is_connected')
          .eq('profile_id', profileId)
          .eq('provider', provider)
          .limit(1);

      final list = response as List;
      if (list.isEmpty) return false;
      return (list.first as Map<String, dynamic>)['is_connected'] as bool? ??
          false;
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.isConnected ($provider) failed: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Garmin
  // -------------------------------------------------------------------------

  /// Calls the `oauth-garmin` Edge Function with `action: initiate` to obtain
  /// a Garmin OAuth 1.0a request token.
  ///
  /// Returns the `oauth_token` string that the UI uses to build the
  /// Garmin authorization URL before opening the browser.
  Future<String> getGarminRequestToken(String profileId) async {
    try {
      _logger.info(
          'HealthConnectionsRepository: initiating Garmin OAuth for profile $profileId');

      final response = await _client.functions.invoke(
        'oauth-garmin',
        body: {
          'action': 'initiate',
          'profile_id': profileId,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final token = data?['oauth_token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception(
            'oauth-garmin initiate returned no oauth_token: ${response.data}');
      }
      return token;
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.getGarminRequestToken failed: $e');
      throw Exception('Failed to start Garmin authorization: $e');
    }
  }

  /// Completes the Garmin OAuth flow by forwarding the authorization code to
  /// the `oauth-garmin` Edge Function.
  ///
  /// The Edge Function exchanges the code for tokens, stores them server-side,
  /// and upserts a row in `wt_health_connections`.
  ///
  /// [authorizationCode] — the `code` query parameter received via deep link.
  /// [redirectUri] — must match the URI registered with Garmin (e.g.
  ///   `welltrack://oauth/garmin/callback`).
  Future<HealthConnectionEntity> connectGarmin(
    String profileId,
    String authorizationCode,
    String redirectUri,
  ) async {
    try {
      _logger.info(
          'HealthConnectionsRepository: invoking oauth-garmin for profile $profileId');

      final response = await _client.functions.invoke(
        'oauth-garmin',
        body: {
          'action': 'connect',
          'profile_id': profileId,
          'authorization_code': authorizationCode,
          'redirect_uri': redirectUri,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['connection'] == null) {
        throw Exception(
            'oauth-garmin returned no connection data: ${response.data}');
      }

      return HealthConnectionEntity.fromJson(
          data['connection'] as Map<String, dynamic>);
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.connectGarmin failed: $e');
      throw Exception('Failed to connect Garmin: $e');
    }
  }

  /// Revokes the Garmin connection for [profileId].
  ///
  /// Calls the `oauth-garmin` Edge Function with `action: delete`, which
  /// revokes the access token server-side and marks the row as disconnected.
  Future<void> disconnectGarmin(String profileId) async {
    try {
      _logger.info(
          'HealthConnectionsRepository: disconnecting Garmin for profile $profileId');

      await _client.functions.invoke(
        'oauth-garmin',
        body: {
          'action': 'disconnect',
          'profile_id': profileId,
        },
      );
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.disconnectGarmin failed: $e');
      throw Exception('Failed to disconnect Garmin: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Strava
  // -------------------------------------------------------------------------

  /// Completes the Strava OAuth flow by forwarding the authorization code to
  /// the `oauth-strava` Edge Function.
  ///
  /// Strava does not require a `redirect_uri` in the token-exchange request;
  /// it is embedded in the authorization URL only.
  ///
  /// [authorizationCode] — the `code` query parameter received via deep link.
  Future<HealthConnectionEntity> connectStrava(
    String profileId,
    String authorizationCode,
  ) async {
    try {
      _logger.info(
          'HealthConnectionsRepository: invoking oauth-strava for profile $profileId');

      final response = await _client.functions.invoke(
        'oauth-strava',
        body: {
          'action': 'connect',
          'profile_id': profileId,
          'authorization_code': authorizationCode,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['connection'] == null) {
        throw Exception(
            'oauth-strava returned no connection data: ${response.data}');
      }

      return HealthConnectionEntity.fromJson(
          data['connection'] as Map<String, dynamic>);
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.connectStrava failed: $e');
      throw Exception('Failed to connect Strava: $e');
    }
  }

  /// Revokes the Strava connection for [profileId].
  Future<void> disconnectStrava(String profileId) async {
    try {
      _logger.info(
          'HealthConnectionsRepository: disconnecting Strava for profile $profileId');

      await _client.functions.invoke(
        'oauth-strava',
        body: {
          'action': 'disconnect',
          'profile_id': profileId,
        },
      );
    } catch (e) {
      _logger.error(
          'HealthConnectionsRepository.disconnectStrava failed: $e');
      throw Exception('Failed to disconnect Strava: $e');
    }
  }
}
