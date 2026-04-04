/// Represents a Garmin or Strava OAuth connection record stored in wt_health_connections.
///
/// One record per (profile_id, provider) pair.
/// The back-end Edge Function owns token storage — this entity only tracks
/// connection status and metadata visible to the client.
class HealthConnectionEntity {
  const HealthConnectionEntity({
    required this.id,
    required this.profileId,
    required this.provider,
    required this.isConnected,
    this.lastSyncAt,
    this.connectionMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthConnectionEntity.fromJson(Map<String, dynamic> json) {
    return HealthConnectionEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      provider: json['provider'] as String,
      isConnected: json['is_connected'] as bool? ?? false,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'] as String)
          : null,
      connectionMetadata:
          json['connection_metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Row ID (UUID from wt_health_connections.id)
  final String id;

  /// Profile that owns this connection
  final String profileId;

  /// OAuth provider identifier — 'garmin' or 'strava'
  final String provider;

  /// Whether the OAuth token is currently active (not revoked / expired)
  final bool isConnected;

  /// Timestamp of the most-recent data pull from this provider
  final DateTime? lastSyncAt;

  /// Arbitrary provider-specific metadata (e.g. athlete name, scope list).
  /// Tokens are NEVER stored here — they live server-side.
  final Map<String, dynamic>? connectionMetadata;

  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'provider': provider,
      'is_connected': isConnected,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'connection_metadata': connectionMetadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HealthConnectionEntity copyWith({
    String? id,
    String? profileId,
    String? provider,
    bool? isConnected,
    DateTime? lastSyncAt,
    Map<String, dynamic>? connectionMetadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthConnectionEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      provider: provider ?? this.provider,
      isConnected: isConnected ?? this.isConnected,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      connectionMetadata: connectionMetadata ?? this.connectionMetadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
