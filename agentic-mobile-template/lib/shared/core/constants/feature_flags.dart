/// Feature flags for Pro-gated features
class FeatureFlags {
  // Advanced metrics
  static const String recoveryScore = 'recovery_score';
  static const String forecasting = 'forecasting';
  static const String trainingLoad = 'training_load';

  // AI features
  static const String adaptivePlans = 'adaptive_plans';
  static const String weeklyAISummaries = 'weekly_ai_summaries';

  // Data access
  static const String fullHistory = 'full_history';
  static const String fullNutrients = 'full_nutrients';

  // Profile features
  static const String multipleProfiles = 'multiple_profiles';

  /// All Pro-gated features
  static const List<String> proFeatures = [
    recoveryScore,
    forecasting,
    trainingLoad,
    adaptivePlans,
    weeklyAISummaries,
    fullHistory,
    fullNutrients,
    multipleProfiles,
  ];

  /// Gets user-friendly display name for a feature
  static String getFeatureDisplayName(String feature) {
    switch (feature) {
      case recoveryScore:
        return 'Recovery Score';
      case forecasting:
        return 'Goal Forecasting';
      case trainingLoad:
        return 'Training Load';
      case adaptivePlans:
        return 'Adaptive Plans';
      case weeklyAISummaries:
        return 'Weekly AI Summaries';
      case fullHistory:
        return 'Full History';
      case fullNutrients:
        return 'Full Nutrient Tracking';
      case multipleProfiles:
        return 'Multiple Profiles';
      default:
        return feature;
    }
  }

  /// Gets description for a feature
  static String getFeatureDescription(String feature) {
    switch (feature) {
      case recoveryScore:
        return 'Track your daily recovery based on sleep, stress, and activity';
      case forecasting:
        return 'Predict when you\'ll reach your wellness goals';
      case trainingLoad:
        return 'Monitor training intensity and prevent overtraining';
      case adaptivePlans:
        return 'AI-generated weekly plans that adapt to your progress';
      case weeklyAISummaries:
        return 'Get AI-powered weekly insights and recommendations';
      case fullHistory:
        return 'Access up to 1 year of historical data';
      case fullNutrients:
        return 'Track all vitamins and minerals, not just macros';
      case multipleProfiles:
        return 'Manage up to 5 profiles under one account';
      default:
        return '';
    }
  }
}
