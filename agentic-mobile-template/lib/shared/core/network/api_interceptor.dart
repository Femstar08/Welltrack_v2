import 'package:dio/dio.dart';
import '../auth/supabase_service.dart';
import '../logging/app_logger.dart';

/// Interceptor that adds authentication token to requests
class ApiInterceptor extends Interceptor {
  final SupabaseService _supabaseService;
  final AppLogger _logger = AppLogger();

  ApiInterceptor(this._supabaseService);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Get current session
      final session = _supabaseService.currentSession;

      if (session != null) {
        // Add authorization header
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        _logger.debug('Added auth token to request: ${options.path}');
      }

      // Add apikey header for Supabase
      final apiKey = _supabaseService.anonKey;
      if (apiKey.isNotEmpty) {
        options.headers['apikey'] = apiKey;
      }

      // Add standard headers
      options.headers['Content-Type'] = 'application/json';
      options.headers['Accept'] = 'application/json';

      handler.next(options);
    } catch (e, stackTrace) {
      _logger.error('Error in API interceptor', e, stackTrace);
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.error(
      'API error: ${err.requestOptions.path}',
      err.message,
      err.stackTrace,
    );
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.debug(
      'API response: ${response.requestOptions.path} - ${response.statusCode}',
    );
    handler.next(response);
  }
}
