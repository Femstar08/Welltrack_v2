/// API configuration constants for WellTrack
/// All Supabase endpoints and timeout configurations
class ApiConstants {
  ApiConstants._();

  // Supabase — values loaded from environment
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nppjffhzkzfduulbbcih.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wcGpmZmh6a3pmZHV1bGJiY2loIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyMjQ2MTAsImV4cCI6MjA2NTgwMDYxMH0.OrwLcR8sXcsyMUVEAXgw2WNureeAKrwgrhrPGT6lgTU',
  );

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
