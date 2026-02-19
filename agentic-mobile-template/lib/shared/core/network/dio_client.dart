import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../auth/supabase_service.dart';
import '../logging/app_logger.dart';
import '../storage/local_storage_service.dart';
import 'api_interceptor.dart';
import 'offline_queue.dart';
import 'connectivity_service.dart';

/// Configured Dio client for API requests
class DioClient {

  DioClient({
    required SupabaseService supabaseService,
    required OfflineQueue offlineQueue,
    required ConnectivityService connectivityService,
  })  : _offlineQueue = offlineQueue,
        _connectivityService = connectivityService,
        _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.supabaseUrl,
            connectTimeout: ApiConstants.connectionTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
          ),
        ) {
    // Add interceptors
    _dio.interceptors.add(ApiInterceptor(supabaseService));
    _dio.interceptors.add(_RetryInterceptor(_logger));
    _dio.interceptors.add(_OfflineInterceptor(
      offlineQueue,
      connectivityService,
      _logger,
    ));
  }
  final Dio _dio;
  final OfflineQueue _offlineQueue;
  final ConnectivityService _connectivityService;
  final AppLogger _logger = AppLogger();

  Dio get instance => _dio;

  /// Replay queued requests when connectivity is restored
  Future<void> replayQueue() async {
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      _logger.info('Cannot replay queue: device is offline');
      return;
    }

    final pendingRequests = await _offlineQueue.getPendingRequests();
    _logger.info('Replaying ${pendingRequests.length} queued requests');

    for (final request in pendingRequests) {
      try {
        final options = Options(method: request.method);

        // Parse headers if available (stored as JSON string)
        if (request.headers != null) {
          options.headers = Map<String, dynamic>.from(
            jsonDecode(request.headers!) as Map,
          );
        }

        // Execute request
        await _dio.request(
          request.url,
          data: request.body,
          options: options,
        );

        await _offlineQueue.markCompleted(request.id);
        _logger.info('Replayed request: ${request.method} ${request.url}');
      } catch (e, stackTrace) {
        _logger.error('Error replaying request', e, stackTrace);
        await _offlineQueue.markFailed(request.id, e.toString());
      }
    }
  }
}

/// Retry interceptor for handling transient failures
class _RetryInterceptor extends Interceptor {

  _RetryInterceptor(this._logger);
  final AppLogger _logger;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

      if (retryCount < ApiConstants.maxRetryAttempts) {
        _logger.info(
          'Retrying request: ${err.requestOptions.path} (attempt ${retryCount + 1})',
        );

        // Exponential backoff
        final delay = ApiConstants.retryBaseDelay * (retryCount + 1);
        await Future.delayed(delay);

        err.requestOptions.extra['retryCount'] = retryCount + 1;

        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // Continue to next retry or return error
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    // Retry on 429 (rate limit) and 5xx server errors
    return err.response?.statusCode == 429 ||
        (err.response?.statusCode != null &&
            err.response!.statusCode! >= 500);
  }
}

/// Offline interceptor for queueing requests when offline
class _OfflineInterceptor extends Interceptor {

  _OfflineInterceptor(
    this._offlineQueue,
    this._connectivityService,
    this._logger,
  );
  final OfflineQueue _offlineQueue;
  final ConnectivityService _connectivityService;
  final AppLogger _logger;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Queue request if offline and it's a mutation
    if (_isNetworkError(err) && _isMutation(err.requestOptions.method)) {
      final isOnline = await _connectivityService.checkConnectivity();

      if (!isOnline) {
        _logger.info('Queueing offline request: ${err.requestOptions.path}');

        await _offlineQueue.enqueue(
          method: err.requestOptions.method,
          url: err.requestOptions.path,
          body: err.requestOptions.data?.toString(),
          headers: err.requestOptions.headers,
        );

        // Return a custom error indicating request was queued
        handler.resolve(
          Response(
            requestOptions: err.requestOptions,
            statusCode: 202,
            statusMessage: 'Request queued for later',
          ),
        );
        return;
      }
    }

    handler.next(err);
  }

  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;
  }

  bool _isMutation(String method) {
    return method.toLowerCase() != 'get' && method.toLowerCase() != 'head';
  }
}

/// Riverpod provider for DioClient
final dioClientProvider = Provider<DioClient>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final offlineQueue = ref.watch(offlineQueueProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  return DioClient(
    supabaseService: supabaseService,
    offlineQueue: offlineQueue,
    connectivityService: connectivityService,
  );
});
