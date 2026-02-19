import '../logging/app_logger.dart';

/// Strategy for resolving conflicts between local and server data
enum ConflictResolutionStrategy {
  /// Last write wins based on updated_at timestamp
  lastWriteWins,

  /// Keep local version
  keepLocal,

  /// Keep server version
  keepServer,
}

/// Result of a conflict resolution
class ConflictResolution {

  const ConflictResolution({
    required this.localWins,
    required this.reason,
    this.localTimestamp,
    this.serverTimestamp,
  });
  final bool localWins;
  final String reason;
  final DateTime? localTimestamp;
  final DateTime? serverTimestamp;

  @override
  String toString() {
    return 'ConflictResolution(localWins: $localWins, reason: $reason, '
        'local: $localTimestamp, server: $serverTimestamp)';
  }
}

/// Service for resolving data conflicts between local and server
class ConflictResolver {
  final AppLogger _logger = AppLogger();

  /// Resolve a conflict between local and server data
  ///
  /// Uses last-write-wins strategy by default:
  /// - If local updated_at > server updated_at: local wins (overwrite server)
  /// - If server updated_at > local updated_at: server wins (discard local change)
  /// - If timestamps are equal: server wins (prefer canonical source)
  ConflictResolution resolve({
    required DateTime? localUpdatedAt,
    required DateTime? serverUpdatedAt,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.lastWriteWins,
  }) {
    // Handle null timestamps
    if (localUpdatedAt == null && serverUpdatedAt == null) {
      _logger.warning('Both timestamps are null, defaulting to server wins');
      return const ConflictResolution(
        localWins: false,
        reason: 'Both timestamps null, defaulting to server',
      );
    }

    if (localUpdatedAt == null) {
      _logger.warning('Local timestamp is null, server wins');
      return ConflictResolution(
        localWins: false,
        reason: 'Local timestamp is null',
        serverTimestamp: serverUpdatedAt,
      );
    }

    if (serverUpdatedAt == null) {
      _logger.warning('Server timestamp is null, local wins');
      return ConflictResolution(
        localWins: true,
        reason: 'Server timestamp is null',
        localTimestamp: localUpdatedAt,
      );
    }

    // Apply resolution strategy
    final resolution = _applyStrategy(
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
      strategy: strategy,
    );

    // Log conflict resolution
    _logConflict(resolution, localData, serverData);

    return resolution;
  }

  /// Apply the conflict resolution strategy
  ConflictResolution _applyStrategy({
    required DateTime localUpdatedAt,
    required DateTime serverUpdatedAt,
    required ConflictResolutionStrategy strategy,
  }) {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        if (localUpdatedAt.isAfter(serverUpdatedAt)) {
          return ConflictResolution(
            localWins: true,
            reason: 'Local update is newer',
            localTimestamp: localUpdatedAt,
            serverTimestamp: serverUpdatedAt,
          );
        } else if (serverUpdatedAt.isAfter(localUpdatedAt)) {
          return ConflictResolution(
            localWins: false,
            reason: 'Server update is newer',
            localTimestamp: localUpdatedAt,
            serverTimestamp: serverUpdatedAt,
          );
        } else {
          // Timestamps are equal, prefer server (canonical source)
          return ConflictResolution(
            localWins: false,
            reason: 'Timestamps equal, preferring server',
            localTimestamp: localUpdatedAt,
            serverTimestamp: serverUpdatedAt,
          );
        }

      case ConflictResolutionStrategy.keepLocal:
        return ConflictResolution(
          localWins: true,
          reason: 'Strategy: keep local',
          localTimestamp: localUpdatedAt,
          serverTimestamp: serverUpdatedAt,
        );

      case ConflictResolutionStrategy.keepServer:
        return ConflictResolution(
          localWins: false,
          reason: 'Strategy: keep server',
          localTimestamp: localUpdatedAt,
          serverTimestamp: serverUpdatedAt,
        );
    }
  }

  /// Log conflict resolution for debugging
  void _logConflict(
    ConflictResolution resolution,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) {
    _logger.info(
      'Conflict resolved: ${resolution.localWins ? "LOCAL WINS" : "SERVER WINS"} - ${resolution.reason}',
    );
    _logger.debug(
      'Local data: ${localData.toString().substring(0, localData.toString().length > 100 ? 100 : localData.toString().length)}',
    );
    _logger.debug(
      'Server data: ${serverData.toString().substring(0, serverData.toString().length > 100 ? 100 : serverData.toString().length)}',
    );
  }

  /// Check if two data objects have a conflict
  /// Returns true if timestamps differ, indicating a potential conflict
  bool hasConflict({
    required DateTime? localUpdatedAt,
    required DateTime? serverUpdatedAt,
  }) {
    if (localUpdatedAt == null || serverUpdatedAt == null) {
      return true; // Null timestamp is a conflict condition
    }

    return localUpdatedAt != serverUpdatedAt;
  }
}
