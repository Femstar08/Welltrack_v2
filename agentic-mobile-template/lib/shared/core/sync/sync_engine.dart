import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/connectivity_service.dart';
import '../network/offline_queue.dart';
import '../network/dio_client.dart';
import '../storage/local_storage_service.dart';
import '../logging/app_logger.dart';
import '../constants/api_constants.dart';
import 'conflict_resolver.dart';

/// Sync status enumeration
enum SyncStatus { idle, syncing, error }

/// Sync state model
class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? lastError;
  final int pendingCount;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.lastError,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? lastError,
    int? pendingCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastSyncAt == other.lastSyncAt &&
          lastError == other.lastError &&
          pendingCount == other.pendingCount;

  @override
  int get hashCode =>
      status.hashCode ^
      lastSyncAt.hashCode ^
      lastError.hashCode ^
      pendingCount.hashCode;

  @override
  String toString() {
    return 'SyncState(status: $status, lastSyncAt: $lastSyncAt, '
        'lastError: $lastError, pendingCount: $pendingCount)';
  }
}

/// Sync engine for managing offline data synchronization
class SyncEngine extends StateNotifier<SyncState> {
  final ConnectivityService _connectivityService;
  final OfflineQueue _offlineQueue;
  final DioClient _dioClient;
  final ConflictResolver _conflictResolver;
  final AppLogger _logger = AppLogger();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isRunning = false;

  SyncEngine({
    required ConnectivityService connectivityService,
    required OfflineQueue offlineQueue,
    required DioClient dioClient,
    required ConflictResolver conflictResolver,
  })  : _connectivityService = connectivityService,
        _offlineQueue = offlineQueue,
        _dioClient = dioClient,
        _conflictResolver = conflictResolver,
        super(const SyncState());

  /// Start the sync engine
  Future<void> startSync() async {
    if (_isRunning) {
      _logger.info('Sync engine already running');
      return;
    }

    _logger.info('Starting sync engine');
    _isRunning = true;

    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (isOnline) {
        if (isOnline) {
          _logger.info('Connectivity restored, triggering sync');
          syncNow();
        } else {
          _logger.info('Device went offline');
        }
      },
    );

    // Set up periodic sync
    _periodicSyncTimer = Timer.periodic(
      ApiConstants.syncInterval,
      (_) => syncNow(),
    );

    // Do initial sync if online
    final isOnline = await _connectivityService.checkConnectivity();
    if (isOnline) {
      await syncNow();
    }
  }

  /// Stop the sync engine
  void stopSync() {
    if (!_isRunning) {
      _logger.info('Sync engine not running');
      return;
    }

    _logger.info('Stopping sync engine');
    _isRunning = false;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;

    state = state.copyWith(status: SyncStatus.idle);
  }

  /// Trigger a sync now
  Future<void> syncNow() async {
    // Prevent concurrent syncs
    if (state.status == SyncStatus.syncing) {
      _logger.info('Sync already in progress, skipping');
      return;
    }

    // Check connectivity
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      _logger.info('Device is offline, cannot sync');
      return;
    }

    try {
      state = state.copyWith(status: SyncStatus.syncing);
      _logger.info('Starting sync');

      // Get pending requests
      final pendingRequests = await _offlineQueue.getPendingRequests();
      _logger.info('Processing ${pendingRequests.length} pending requests');

      state = state.copyWith(pendingCount: pendingRequests.length);

      // Process queue items in FIFO order
      int successCount = 0;
      int failureCount = 0;
      int conflictCount = 0;

      for (final request in pendingRequests) {
        try {
          final result = await _processQueueItem(request);

          if (result.success) {
            successCount++;
            await _offlineQueue.markCompleted(request.id);
          } else if (result.isConflict) {
            conflictCount++;
            // Conflict resolved, remove from queue
            await _offlineQueue.markCompleted(request.id);
          } else {
            failureCount++;
            await _offlineQueue.markFailed(request.id, result.error ?? 'Unknown error');
          }
        } catch (e, stackTrace) {
          failureCount++;
          _logger.error('Error processing queued request', e, stackTrace);
          await _offlineQueue.markFailed(request.id, e.toString());
        }
      }

      _logger.info(
        'Sync completed: $successCount succeeded, $failureCount failed, $conflictCount conflicts resolved',
      );

      state = state.copyWith(
        status: SyncStatus.idle,
        lastSyncAt: DateTime.now(),
        lastError: null,
        pendingCount: await _offlineQueue.getQueueSize(),
      );
    } catch (e, stackTrace) {
      _logger.error('Sync error', e, stackTrace);
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
    }
  }

  /// Process a single queue item
  Future<_ProcessResult> _processQueueItem(QueuedRequest request) async {
    try {
      // Parse headers
      Map<String, dynamic>? headers;
      if (request.headers != null) {
        headers = jsonDecode(request.headers!);
      }

      // Execute request
      final response = await _dioClient.instance.request(
        request.url,
        data: request.body,
        options: Options(
          method: request.method,
          headers: headers,
        ),
      );

      _logger.info('Request succeeded: ${request.method} ${request.url}');
      return _ProcessResult(success: true);
    } on DioException catch (e) {
      // Check for conflict (409 status or version mismatch)
      if (e.response?.statusCode == 409) {
        _logger.info('Conflict detected for ${request.method} ${request.url}');
        return await _handleConflict(request, e);
      }

      _logger.error('Request failed: ${request.method} ${request.url}', e);
      return _ProcessResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      _logger.error('Unexpected error processing request', e);
      return _ProcessResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Handle conflict using conflict resolver
  Future<_ProcessResult> _handleConflict(
    QueuedRequest request,
    DioException error,
  ) async {
    try {
      // Parse local data from request body
      Map<String, dynamic> localData = {};
      if (request.body != null) {
        localData = jsonDecode(request.body!);
      }

      // Get server data from error response
      Map<String, dynamic> serverData = {};
      if (error.response?.data != null) {
        serverData = error.response!.data is Map
            ? error.response!.data as Map<String, dynamic>
            : {};
      }

      // Extract timestamps
      final localUpdatedAt = _parseTimestamp(localData['updated_at']);
      final serverUpdatedAt = _parseTimestamp(serverData['updated_at']);

      // Resolve conflict
      final resolution = _conflictResolver.resolve(
        localUpdatedAt: localUpdatedAt,
        serverUpdatedAt: serverUpdatedAt,
        localData: localData,
        serverData: serverData,
      );

      if (resolution.localWins) {
        // Local wins: retry with force flag or higher version
        _logger.info('Conflict resolved: local wins, retrying with force');

        // Add force flag to headers
        final headers = request.headers != null
            ? jsonDecode(request.headers!)
            : <String, dynamic>{};
        headers['X-Force-Update'] = 'true';

        await _dioClient.instance.request(
          request.url,
          data: request.body,
          options: Options(
            method: request.method,
            headers: headers,
          ),
        );

        return _ProcessResult(success: true, isConflict: true);
      } else {
        // Server wins: discard local change
        _logger.info('Conflict resolved: server wins, discarding local change');
        return _ProcessResult(success: false, isConflict: true);
      }
    } catch (e, stackTrace) {
      _logger.error('Error handling conflict', e, stackTrace);
      return _ProcessResult(
        success: false,
        error: 'Conflict resolution failed: ${e.toString()}',
      );
    }
  }

  /// Parse timestamp from dynamic value
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        _logger.warning('Failed to parse timestamp: $value');
        return null;
      }
    }

    return null;
  }

  /// Get current sync status
  SyncState getSyncStatus() => state;

  @override
  void dispose() {
    stopSync();
    super.dispose();
  }
}

/// Result of processing a queue item
class _ProcessResult {
  final bool success;
  final bool isConflict;
  final String? error;

  _ProcessResult({
    required this.success,
    this.isConflict = false,
    this.error,
  });
}

/// Riverpod provider for ConflictResolver
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

/// Riverpod provider for SyncEngine
final syncEngineProvider = StateNotifierProvider<SyncEngine, SyncState>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  final offlineQueue = ref.watch(offlineQueueProvider);
  final dioClient = ref.watch(dioClientProvider);
  final conflictResolver = ref.watch(conflictResolverProvider);

  return SyncEngine(
    connectivityService: connectivityService,
    offlineQueue: offlineQueue,
    dioClient: dioClient,
    conflictResolver: conflictResolver,
  );
});
