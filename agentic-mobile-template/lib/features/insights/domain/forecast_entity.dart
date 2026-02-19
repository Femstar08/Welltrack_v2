/// Forecast Entity
/// Linear regression forecast for goal achievement
class ForecastEntity {

  const ForecastEntity({
    required this.id,
    required this.profileId,
    this.goalForecastId,
    required this.metricType,
    required this.currentValue,
    required this.targetValue,
    required this.slope,
    required this.intercept,
    required this.rSquared,
    this.projectedDate,
    required this.confidence,
    required this.dataPoints,
    required this.modelType,
    required this.calculatedAt,
  });

  factory ForecastEntity.fromJson(Map<String, dynamic> json) {
    return ForecastEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      goalForecastId: json['goal_forecast_id'] as String?,
      metricType: json['metric_type'] as String,
      currentValue: (json['current_value'] as num).toDouble(),
      targetValue: (json['target_value'] as num).toDouble(),
      slope: (json['slope'] as num).toDouble(),
      intercept: (json['intercept'] as num).toDouble(),
      rSquared: (json['r_squared'] as num).toDouble(),
      projectedDate: json['projected_date'] != null
          ? DateTime.parse(json['projected_date'] as String)
          : null,
      confidence: ForecastConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => ForecastConfidence.low,
      ),
      dataPoints: json['data_points'] as int,
      modelType: json['model_type'] as String,
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
    );
  }
  final String id;
  final String profileId;
  final String? goalForecastId; // Link to wt_goal_forecasts if applicable
  final String metricType; // e.g., 'vo2max', 'weight', 'sleep_duration'
  final double currentValue;
  final double targetValue;
  final double slope; // Regression slope (rate of change per day)
  final double intercept; // Regression intercept
  final double rSquared; // R² goodness of fit (0-1)
  final DateTime? projectedDate; // When target will be reached (null if not achievable)
  final ForecastConfidence confidence; // Based on R² and data points
  final int dataPoints; // Number of historical data points used
  final String modelType; // 'linear_regression'
  final DateTime calculatedAt;

  /// Check if target is achievable based on current trend
  bool get isAchievable => projectedDate != null;

  /// Get days until projected achievement
  int? get daysUntilTarget {
    if (projectedDate == null) return null;
    return projectedDate!.difference(DateTime.now()).inDays;
  }

  /// Get progress percentage toward target
  double get progressPercentage {
    final range = (targetValue - currentValue).abs();
    if (range == 0) return 100.0;
    final progress = (currentValue - currentValue).abs();
    return (progress / range * 100).clamp(0, 100);
  }

  /// Check if moving toward target
  bool get isMovingTowardTarget {
    if (targetValue > currentValue) {
      return slope > 0; // Need positive slope to increase
    } else {
      return slope < 0; // Need negative slope to decrease
    }
  }

  /// Get trend direction description
  String get trendDescription {
    if (slope.abs() < 0.01) return 'Stable';
    if (slope > 0) return 'Increasing';
    return 'Decreasing';
  }

  /// Get confidence description
  String get confidenceDescription {
    switch (confidence) {
      case ForecastConfidence.high:
        return 'High confidence (R² ≥ 0.7, sufficient data)';
      case ForecastConfidence.medium:
        return 'Medium confidence (R² 0.4-0.7 or limited data)';
      case ForecastConfidence.low:
        return 'Low confidence (R² < 0.4 or insufficient data)';
    }
  }

  /// Get formatted projection message
  String get projectionMessage {
    if (!isAchievable) {
      return 'Current trend does not project achievement. Consider adjusting your approach.';
    }

    final days = daysUntilTarget;
    if (days == null) return 'Projection unavailable';

    if (days <= 0) {
      return 'Target achieved or overdue';
    } else if (days <= 7) {
      return 'Projected in $days days';
    } else if (days <= 30) {
      final weeks = (days / 7).round();
      return 'Projected in ~$weeks weeks';
    } else if (days <= 365) {
      final months = (days / 30).round();
      return 'Projected in ~$months months';
    } else {
      final years = (days / 365).round();
      return 'Projected in ~$years years';
    }
  }

  /// Get model quality assessment
  String get modelQuality {
    if (rSquared >= 0.7) return 'Excellent fit';
    if (rSquared >= 0.5) return 'Good fit';
    if (rSquared >= 0.3) return 'Fair fit';
    return 'Poor fit';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'goal_forecast_id': goalForecastId,
      'metric_type': metricType,
      'current_value': currentValue,
      'target_value': targetValue,
      'slope': slope,
      'intercept': intercept,
      'r_squared': rSquared,
      'projected_date': projectedDate?.toIso8601String(),
      'confidence': confidence.name,
      'data_points': dataPoints,
      'model_type': modelType,
      'calculated_at': calculatedAt.toIso8601String(),
    };
  }

  ForecastEntity copyWith({
    String? id,
    String? profileId,
    String? goalForecastId,
    String? metricType,
    double? currentValue,
    double? targetValue,
    double? slope,
    double? intercept,
    double? rSquared,
    DateTime? projectedDate,
    ForecastConfidence? confidence,
    int? dataPoints,
    String? modelType,
    DateTime? calculatedAt,
  }) {
    return ForecastEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      goalForecastId: goalForecastId ?? this.goalForecastId,
      metricType: metricType ?? this.metricType,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      slope: slope ?? this.slope,
      intercept: intercept ?? this.intercept,
      rSquared: rSquared ?? this.rSquared,
      projectedDate: projectedDate ?? this.projectedDate,
      confidence: confidence ?? this.confidence,
      dataPoints: dataPoints ?? this.dataPoints,
      modelType: modelType ?? this.modelType,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }
}

enum ForecastConfidence {
  high, // R² ≥ 0.7 and data_points ≥ 14
  medium, // R² 0.4-0.7 or data_points 7-13
  low, // R² < 0.4 or data_points < 7
}

/// Data point for regression calculations
class DataPoint {

  const DataPoint({
    required this.date,
    required this.value,
  });

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
  final DateTime date;
  final double value;

  /// Convert date to days since baseline for regression
  int daysSince(DateTime baseline) {
    return date.difference(baseline).inDays;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'value': value,
    };
  }
}

/// Linear regression result
class RegressionResult {

  const RegressionResult({
    required this.slope,
    required this.intercept,
    required this.rSquared,
    required this.dataPoints,
  });
  final double slope;
  final double intercept;
  final double rSquared;
  final int dataPoints;

  /// Predict value at given x (days since baseline)
  double predict(int x) {
    return slope * x + intercept;
  }

  /// Get confidence level based on R² and data points
  ForecastConfidence get confidence {
    if (rSquared >= 0.7 && dataPoints >= 14) {
      return ForecastConfidence.high;
    } else if (rSquared >= 0.4 || dataPoints >= 7) {
      return ForecastConfidence.medium;
    }
    return ForecastConfidence.low;
  }
}
