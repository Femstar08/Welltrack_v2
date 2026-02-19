import 'dart:convert';
import 'package:hive/hive.dart';
import '../logging/app_logger.dart';
import '../constants/api_constants.dart';

/// Model for storing offline API requests
class QueuedRequest {

  QueuedRequest({
    required this.id,
    required this.createdAt,
    required this.method,
    required this.url,
    this.body,
    this.headers,
    this.retryCount = 0,
    this.isPending = true,
    this.errorMessage,
    this.lastAttemptAt,
  });

  /// Deserialize from Hive map
  factory QueuedRequest.fromMap(Map<dynamic, dynamic> map) {
    return QueuedRequest(
      id: map['id'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      method: map['method'] as String,
      url: map['url'] as String,
      body: map['body'] as String?,
      headers: map['headers'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
      isPending: map['isPending'] as bool? ?? true,
      errorMessage: map['errorMessage'] as String?,
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.parse(map['lastAttemptAt'] as String)
          : null,
    );
  }
  final int id;
  final DateTime createdAt;
  final String method; // GET, POST, PUT, DELETE, PATCH
  final String url;
  final String? body;
  final String? headers; // JSON encoded Map<String, dynamic>
  int retryCount;
  bool isPending;
  String? errorMessage;
  DateTime? lastAttemptAt;

  /// Serialize to map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'method': method,
      'url': url,
      'body': body,
      'headers': headers,
      'retryCount': retryCount,
      'isPending': isPending,
      'errorMessage': errorMessage,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    };
  }
}

/// Service for managing offline request queue using Hive
class OfflineQueue {

  OfflineQueue(this._box);
  final Box _box;
  final AppLogger _logger = AppLogger();

  /// Box name constant
  static const String boxName = 'offline_queue';

  /// Auto-incrementing ID counter
  int _nextId() {
    final currentMax = _box.get('_next_id', defaultValue: 1) as int;
    _box.put('_next_id', currentMax + 1);
    return currentMax;
  }

  /// Add a request to the offline queue
  Future<void> enqueue({
    required String method,
    required String url,
    String? body,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final id = _nextId();
      final request = QueuedRequest(
        id: id,
        createdAt: DateTime.now(),
        method: method,
        url: url,
        body: body,
        headers: headers != null ? jsonEncode(headers) : null,
        isPending: true,
        retryCount: 0,
      );

      await _box.put('request_$id', request.toMap());
      _logger.info('Request queued: $method $url');
    } catch (e, stackTrace) {
      _logger.error('Error enqueuing request', e, stackTrace);
    }
  }

  /// Get all pending requests (FIFO order)
  Future<List<QueuedRequest>> getPendingRequests() async {
    final requests = <QueuedRequest>[];

    for (final key in _box.keys) {
      if (key is String && key.startsWith('request_')) {
        final map = _box.get(key) as Map<dynamic, dynamic>?;
        if (map != null) {
          final request = QueuedRequest.fromMap(map);
          if (request.isPending) {
            requests.add(request);
          }
        }
      }
    }

    // Sort by creation date (FIFO)
    requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return requests;
  }

  /// Mark request as completed and remove from queue
  Future<void> markCompleted(int requestId) async {
    try {
      await _box.delete('request_$requestId');
      _logger.info('Request completed and removed: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error marking request completed', e, stackTrace);
    }
  }

  /// Mark request as failed and increment retry count
  Future<void> markFailed(int requestId, String error) async {
    try {
      final map = _box.get('request_$requestId') as Map<dynamic, dynamic>?;
      if (map == null) return;

      final request = QueuedRequest.fromMap(map);
      request.retryCount++;
      request.errorMessage = error;
      request.lastAttemptAt = DateTime.now();

      // Remove if max retries exceeded
      if (request.retryCount >= ApiConstants.maxRetryAttempts) {
        await _box.delete('request_$requestId');
        _logger.warning(
          'Request removed after max retries: $requestId',
        );
      } else {
        await _box.put('request_$requestId', request.toMap());
        _logger.info(
          'Request retry count updated: $requestId (${request.retryCount}/${ApiConstants.maxRetryAttempts})',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error marking request failed', e, stackTrace);
    }
  }

  /// Clear all pending requests
  Future<void> clearAll() async {
    try {
      final keysToDelete = _box.keys
          .where((key) => key is String && key.startsWith('request_'))
          .toList();
      await _box.deleteAll(keysToDelete);
      _logger.info('All queued requests cleared');
    } catch (e, stackTrace) {
      _logger.error('Error clearing queue', e, stackTrace);
    }
  }

  /// Get queue size
  Future<int> getQueueSize() async {
    int count = 0;
    for (final key in _box.keys) {
      if (key is String && key.startsWith('request_')) {
        final map = _box.get(key) as Map<dynamic, dynamic>?;
        if (map != null) {
          final isPending = map['isPending'] as bool? ?? true;
          if (isPending) count++;
        }
      }
    }
    return count;
  }
}
