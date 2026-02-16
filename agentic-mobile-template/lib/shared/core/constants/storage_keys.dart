/// Storage keys for secure storage and shared preferences
/// All keys are prefixed with 'wt_' to avoid conflicts
class StorageKeys {
  StorageKeys._();

  // Secure storage (flutter_secure_storage)
  static const String accessToken = 'wt_access_token';
  static const String refreshToken = 'wt_refresh_token';
  static const String userId = 'wt_user_id';
  static const String profileId = 'wt_active_profile_id';
  static const String encryptionKey = 'wt_encryption_key';

  // Local preferences (shared_preferences)
  static const String onboardingComplete = 'wt_onboarding_complete';
  static const String themeMode = 'wt_theme_mode';
  static const String lastSyncAt = 'wt_last_sync_at';
}
