/// Enum representing subscription plan tiers
enum PlanTier {
  free,
  pro;

  /// Whether the user can access Recovery Score feature
  bool get canAccessRecoveryScore => this == pro;

  /// Whether the user can access goal forecasting
  bool get canAccessForecasting => this == pro;

  /// Whether the user can access training load metrics
  bool get canAccessTrainingLoad => this == pro;

  /// Whether the user can access adaptive AI-generated plans
  bool get canAccessAdaptivePlans => this == pro;

  /// Whether the user can access full historical data
  bool get canAccessFullHistory => this == pro;

  /// Whether the user can create multiple profiles
  bool get canAccessMultipleProfiles => this == pro;

  /// Whether the user can access weekly AI summaries
  bool get canAccessWeeklyAISummaries => this == pro;

  /// Daily AI call limit
  int get dailyAICalls => this == free ? 3 : 999999;

  /// Number of days of historical data available
  int get historyDays => this == free ? 7 : 365;

  /// Nutrient tracking level ('macros' or 'full')
  String get nutrientLevel => this == free ? 'macros' : 'full';

  /// Maximum number of profiles allowed
  int get maxProfiles => this == free ? 1 : 5;

  /// Display name for the tier
  String get displayName {
    switch (this) {
      case PlanTier.free:
        return 'Free';
      case PlanTier.pro:
        return 'Pro';
    }
  }

  /// Price display (monthly)
  String get priceDisplay {
    switch (this) {
      case PlanTier.free:
        return 'Free';
      case PlanTier.pro:
        return '\$9.99/mo';
    }
  }

  /// Creates from string value
  static PlanTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pro':
        return PlanTier.pro;
      case 'free':
      default:
        return PlanTier.free;
    }
  }

  /// Converts to string for database storage
  String toDbString() {
    switch (this) {
      case PlanTier.free:
        return 'free';
      case PlanTier.pro:
        return 'pro';
    }
  }
}

/// Extension methods for feature availability checks
extension PlanTierFeatures on PlanTier {
  /// Checks if a specific feature is available for this tier
  bool isFeatureAvailable(String featureName) {
    switch (featureName) {
      case 'recovery_score':
        return canAccessRecoveryScore;
      case 'forecasting':
        return canAccessForecasting;
      case 'training_load':
        return canAccessTrainingLoad;
      case 'adaptive_plans':
        return canAccessAdaptivePlans;
      case 'full_history':
        return canAccessFullHistory;
      case 'multiple_profiles':
        return canAccessMultipleProfiles;
      case 'weekly_ai_summaries':
        return canAccessWeeklyAISummaries;
      case 'full_nutrients':
        return nutrientLevel == 'full';
      default:
        return true; // Unknown features default to available
    }
  }

  /// Gets user-friendly description of tier benefits
  List<String> get benefits {
    switch (this) {
      case PlanTier.free:
        return [
          'Basic meal and recipe tracking',
          'Macro nutrient tracking',
          'Manual workout logging',
          '3 AI calls per day',
          '7 days of history',
          '1 profile',
        ];
      case PlanTier.pro:
        return [
          'Advanced meal and recipe tracking',
          'Full micronutrient tracking',
          'Adaptive workout plans',
          'Unlimited AI calls',
          '1 year of history',
          'Up to 5 profiles',
          'Recovery score tracking',
          'Goal forecasting',
          'Training load metrics',
          'Weekly AI summaries',
        ];
    }
  }

  /// Gets the upgrade CTA message
  String get upgradeMessage {
    switch (this) {
      case PlanTier.free:
        return 'Upgrade to Pro for unlimited AI, advanced metrics, and more!';
      case PlanTier.pro:
        return 'You\'re on the Pro plan - enjoy all features!';
    }
  }
}
