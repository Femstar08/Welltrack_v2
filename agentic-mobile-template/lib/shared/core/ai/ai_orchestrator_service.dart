import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/shared/core/ai/ai_models.dart';
import 'package:welltrack/shared/core/constants/api_constants.dart';
import 'package:welltrack/shared/core/network/connectivity_service.dart';
import 'package:welltrack/shared/core/network/dio_client.dart';
import 'package:welltrack/shared/core/logging/app_logger.dart';

// --- AI Exception hierarchy ---

/// Base class for AI-specific exceptions
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

/// Device is offline — AI calls are not queued
class AiOfflineException extends AiException {
  const AiOfflineException()
      : super('You are offline. AI features require an internet connection.');
}

/// User has exceeded their AI usage limit (429)
class AiRateLimitException extends AiException {
  final AiUsageInfo? usage;
  const AiRateLimitException({this.usage})
      : super('AI usage limit reached. Please upgrade or try again later.');
}

/// OpenAI timed out (504 from edge function)
class AiTimeoutException extends AiException {
  const AiTimeoutException()
      : super('AI request timed out. Please try again.');
}

/// OpenAI returned empty/malformed response (502 from edge function)
class AiFallbackException extends AiException {
  const AiFallbackException()
      : super('AI returned an incomplete response. Using fallback data.');
}

/// Safety flag blocked the response
class AiBlockedException extends AiException {
  final List<AiSafetyFlag> flags;
  const AiBlockedException(this.flags)
      : super('Response was blocked due to safety concerns.');
}

// --- Service ---

/// Single Dart entry point for all AI orchestrator calls.
/// Handles connectivity checks, timeouts, and typed error mapping.
class AiOrchestratorService {
  final Dio _dio;
  final ConnectivityService _connectivity;
  final AppLogger _logger = AppLogger();

  AiOrchestratorService({
    required Dio dio,
    required ConnectivityService connectivity,
  })  : _dio = dio,
        _connectivity = connectivity;

  /// Call the AI orchestrator edge function.
  ///
  /// [workflowType] — the tool/workflow to run (e.g. 'generate_pantry_recipes')
  /// [message] — user prompt text
  /// [contextOverride] — extra context merged into the AI context snapshot
  ///
  /// Throws [AiOfflineException], [AiRateLimitException],
  /// [AiTimeoutException], [AiFallbackException], or [AiBlockedException].
  Future<AiOrchestrateResponse> orchestrate({
    required String userId,
    required String profileId,
    String? workflowType,
    String? message,
    Map<String, dynamic>? contextOverride,
  }) async {
    // Pre-flight: AI is online-only
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      throw const AiOfflineException();
    }

    final request = AiOrchestrateRequest(
      userId: userId,
      profileId: profileId,
      message: message,
      workflowType: workflowType,
      contextOverride: contextOverride,
    );

    try {
      final response = await _dio.post(
        ApiConstants.aiOrchestrateEndpoint,
        data: request.toJson(),
        options: Options(
          receiveTimeout: ApiConstants.aiReceiveTimeout,
        ),
      );

      final parsed = AiOrchestrateResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (parsed.isBlocked) {
        throw AiBlockedException(parsed.safetyFlags);
      }

      return parsed;
    } on DioException catch (e) {
      _logger.error('AI orchestrate DioException', e, e.stackTrace);
      _mapDioException(e);
      rethrow; // unreachable but satisfies control flow
    }
  }

  /// Maps Dio status codes to typed AI exceptions. Always throws.
  Never _mapDioException(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode == 429) {
      // Parse usage info from error body if available
      AiUsageInfo? usage;
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['usage'] != null) {
        usage = AiUsageInfo.fromJson(data['usage'] as Map<String, dynamic>);
      }
      throw AiRateLimitException(usage: usage);
    }

    if (statusCode == 504) {
      throw const AiTimeoutException();
    }

    if (statusCode == 502) {
      throw const AiFallbackException();
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw const AiTimeoutException();
    }

    if (e.type == DioExceptionType.connectionError) {
      throw const AiOfflineException();
    }

    // Fallback: wrap in generic AiException
    throw AiException(
      e.response?.data?['message']?.toString() ??
          e.message ??
          'Unknown AI error',
    );
  }
}

/// Riverpod provider for AiOrchestratorService
final aiOrchestratorServiceProvider = Provider<AiOrchestratorService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return AiOrchestratorService(
    dio: dioClient.instance,
    connectivity: connectivity,
  );
});
