/// API configuration constants for WellTrack
/// All Supabase endpoints and timeout configurations
class ApiConstants {
  ApiConstants._();

  // Supabase — values MUST be provided via --dart-define-from-file=.env
  // Build will fail at runtime if these are empty, which is intentional —
  // never ship hardcoded credentials in the binary.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // AI Orchestrator
  static const String aiOrchestrateEndpoint = '/functions/v1/ai-orchestrate';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration aiReceiveTimeout = Duration(seconds: 60);

  // Sync
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxRetryAttempts = 5;
  static const Duration retryBaseDelay = Duration(seconds: 60);
}
