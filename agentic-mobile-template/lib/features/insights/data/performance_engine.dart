import 'dart:math' as math;
import '../domain/recovery_score_entity.dart';
import '../domain/forecast_entity.dart';

/// Performance Engine
/// Deterministic calculations for recovery scores, training load, and forecasts.
/// All math is client-side; no AI involved in calculations.
class PerformanceEngine {
  /// Weights for recovery score components
  static const double _stressWeight = 0.25;
  static const double _sleepWeight = 0.30;
  static const double _hrWeight = 0.20;
  static const double _loadWeight = 0.25;

  /// Calculate recovery score from available components
  /// Returns RecoveryScoreEntity with weighted average of available components
  static RecoveryScoreEntity calculateRecoveryScore({
    required String profileId,
    required DateTime date,
    double? stressAvg, // Garmin 0-100 (low stress = low number)
    double? sleepDurationMin, // Total sleep minutes
    double? sleepQualityScore, // Optional 0-100
    double? restingHr, // Current resting HR
    double? baselineHr, // Baseline resting HR for normalization
    double? currentWeekLoad, // 7-day rolling sum
    double? previousWeekLoad, // Previous 7-day rolling sum
  }) {
    final components = <double>[];
    final weights = <double>[];

    // Stress component (inverted: low stress = high recovery)
    double? stressComponent;
    if (stressAvg != null) {
      stressComponent = normalizeStress(stressAvg);
      components.add(stressComponent);
      weights.add(_stressWeight);
    }

    // Sleep component
    double? sleepComponent;
    if (sleepDurationMin != null) {
      sleepComponent = normalizeSleep(
        sleepDurationMin,
        qualityScore: sleepQualityScore,
      );
      components.add(sleepComponent);
      weights.add(_sleepWeight);
    }

    // HR component
    double? hrComponent;
    if (restingHr != null && baselineHr != null) {
      hrComponent = normalizeHR(restingHr, baselineHr);
      components.add(hrComponent);
      weights.add(_hrWeight);
    }

    // Load component
    double? loadComponent;
    if (currentWeekLoad != null && previousWeekLoad != null) {
      loadComponent = normalizeLoad(currentWeekLoad, previousWeekLoad);
      components.add(loadComponent);
      weights.add(_loadWeight);
    }

    // Calculate weighted average of available components
    final recoveryScore = _weightedAverage(components, weights);

    return RecoveryScoreEntity(
      id: '', // Should be set by repository
      profileId: profileId,
      scoreDate: date,
      stressComponent: stressComponent,
      sleepComponent: sleepComponent,
      hrComponent: hrComponent,
      loadComponent: loadComponent,
      recoveryScore: recoveryScore,
      componentsAvailable: components.length,
      rawData: {
        'stress_avg': stressAvg,
        'sleep_duration_min': sleepDurationMin,
        'sleep_quality_score': sleepQualityScore,
        'resting_hr': restingHr,
        'baseline_hr': baselineHr,
        'current_week_load': currentWeekLoad,
        'previous_week_load': previousWeekLoad,
      },
    );
  }

  /// Normalize stress to 0-100 (inverted: low stress = high recovery)
  static double normalizeStress(double stressAvg) {
    // Garmin stress: 0-25 = rest, 26-50 = low, 51-75 = medium, 76-100 = high
    // Invert so high stress gives low recovery score
    return (100.0 - stressAvg).clamp(0.0, 100.0);
  }

  /// Normalize sleep to 0-100
  /// Optimal sleep: 7-9 hours (420-540 minutes)
  /// Quality score (if available) adjusts the result
  static double normalizeSleep(
    double durationMin, {
    double? qualityScore,
  }) {
    // Duration score: bell curve around 7-9 hours
    double durationScore;
    if (durationMin >= 420 && durationMin <= 540) {
      durationScore = 100.0; // Optimal range
    } else if (durationMin < 420) {
      // Too little sleep: linear penalty below 7 hours
      durationScore = (durationMin / 420 * 100).clamp(0.0, 100.0);
    } else {
      // Too much sleep: gentle penalty above 9 hours
      final excess = durationMin - 540;
      durationScore = (100.0 - (excess / 60 * 10)).clamp(50.0, 100.0);
    }

    // If quality score available, blend 70% duration + 30% quality
    if (qualityScore != null) {
      return (durationScore * 0.7 + qualityScore * 0.3).clamp(0.0, 100.0);
    }

    return durationScore;
  }

  /// Normalize HR deviation to 0-100
  /// Lower resting HR relative to baseline = better recovery
  static double normalizeHR(double currentHr, double baselineHr) {
    final deviation = currentHr - baselineHr;

    // HR same or lower than baseline = perfect recovery
    if (deviation <= 0) return 100.0;

    // Penalty for elevated HR
    // +5 bpm = 80, +10 bpm = 60, +15 bpm = 40, +20+ bpm = 20
    final score = 100.0 - (deviation * 4);
    return score.clamp(0.0, 100.0);
  }

  /// Normalize training load to 0-100
  /// Load ratio < 1.0 = recovering (high score)
  /// Load ratio 1.0-1.2 = maintaining (medium score)
  /// Load ratio > 1.3 = overreaching (low score)
  static double normalizeLoad(double currentLoad, double previousLoad) {
    // Handle edge cases
    if (previousLoad == 0) {
      return currentLoad == 0 ? 100.0 : 80.0;
    }

    final ratio = currentLoad / previousLoad;

    if (ratio < 0.7) {
      return 100.0; // Significant recovery week
    } else if (ratio < 1.0) {
      return 90.0; // Light recovery week
    } else if (ratio <= 1.2) {
      return 75.0; // Maintaining load
    } else if (ratio <= 1.3) {
      return 60.0; // Slight increase
    } else if (ratio <= 1.5) {
      return 40.0; // Overreaching
    } else {
      return 20.0; // Potential overtraining
    }
  }

  /// Calculate weighted average
  static double _weightedAverage(List<double> values, List<double> weights) {
    if (values.isEmpty) return 0.0;

    double sum = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < values.length; i++) {
      sum += values[i] * weights[i];
      totalWeight += weights[i];
    }

    return totalWeight > 0 ? sum / totalWeight : 0.0;
  }

  /// Calculate training load: duration × intensity_factor
  static double calculateTrainingLoad(
    double durationMinutes,
    double intensityFactor,
  ) {
    return durationMinutes * intensityFactor;
  }

  /// Get intensity factor from HR zones
  /// Uses Karvonen formula: (HR - resting) / (max - resting)
  static double intensityFromHR(
    double avgHr,
    double restingHr,
    double maxHr,
  ) {
    final hrReserve = maxHr - restingHr;
    if (hrReserve <= 0) return 1.0;

    final intensity = (avgHr - restingHr) / hrReserve;

    // Map HR zones to intensity factors
    // Zone 1 (50-60%): 0.5
    // Zone 2 (60-70%): 0.75
    // Zone 3 (70-80%): 1.0
    // Zone 4 (80-90%): 1.5
    // Zone 5 (90-100%): 2.0
    if (intensity < 0.6) return 0.5;
    if (intensity < 0.7) return 0.75;
    if (intensity < 0.8) return 1.0;
    if (intensity < 0.9) return 1.5;
    return 2.0;
  }

  /// Simple linear regression for forecasting
  /// Returns ForecastEntity with regression parameters
  static ForecastEntity calculateForecast({
    required String profileId,
    required String metricType,
    required double targetValue,
    required List<DataPoint> dataPoints,
    required DateTime baselineDate,
    String? goalForecastId,
  }) {
    if (dataPoints.isEmpty) {
      throw ArgumentError('Cannot calculate forecast with no data points');
    }

    // Get current value (most recent data point)
    final sortedPoints = List<DataPoint>.from(dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    final currentValue = sortedPoints.last.value;

    // Perform linear regression
    final regression = _linearRegression(sortedPoints, baselineDate);

    // Calculate projected date
    DateTime? projectedDate;
    if (regression.slope != 0) {
      final daysToTarget = ((targetValue - regression.intercept) / regression.slope).round();
      if (daysToTarget > 0 && daysToTarget < 3650) {
        // Only project if within 10 years
        projectedDate = baselineDate.add(Duration(days: daysToTarget));
      }
    }

    return ForecastEntity(
      id: '', // Should be set by repository
      profileId: profileId,
      goalForecastId: goalForecastId,
      metricType: metricType,
      currentValue: currentValue,
      targetValue: targetValue,
      slope: regression.slope,
      intercept: regression.intercept,
      rSquared: regression.rSquared,
      projectedDate: projectedDate,
      confidence: regression.confidence,
      dataPoints: dataPoints.length,
      modelType: 'linear_regression',
      calculatedAt: DateTime.now(),
    );
  }

  /// Perform linear regression on data points
  static RegressionResult _linearRegression(
    List<DataPoint> points,
    DateTime baseline,
  ) {
    final n = points.length;
    if (n < 2) {
      return const RegressionResult(
        slope: 0,
        intercept: 0,
        rSquared: 0,
        dataPoints: 0,
      );
    }

    // Convert dates to days since baseline
    final x = points.map((p) => p.daysSince(baseline).toDouble()).toList();
    final y = points.map((p) => p.value).toList();

    // Calculate means
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    // Calculate slope and intercept
    double numerator = 0.0;
    double denominator = 0.0;

    for (int i = 0; i < n; i++) {
      numerator += (x[i] - xMean) * (y[i] - yMean);
      denominator += (x[i] - xMean) * (x[i] - xMean);
    }

    final slope = denominator != 0 ? numerator / denominator : 0.0;
    final intercept = yMean - slope * xMean;

    // Calculate R²
    double ssRes = 0.0; // Sum of squared residuals
    double ssTot = 0.0; // Total sum of squares

    for (int i = 0; i < n; i++) {
      final predicted = slope * x[i] + intercept;
      ssRes += math.pow(y[i] - predicted, 2);
      ssTot += math.pow(y[i] - yMean, 2);
    }

    final rSquared = ssTot != 0 ? 1 - (ssRes / ssTot) : 0.0;

    return RegressionResult(
      slope: slope,
      intercept: intercept,
      rSquared: rSquared.clamp(0.0, 1.0),
      dataPoints: n,
    );
  }

  /// Detect overtraining risk based on load ratio
  static OvertrainingRisk checkOvertrainingRisk(
    double currentLoad,
    double previousLoad,
  ) {
    if (previousLoad == 0) return OvertrainingRisk.none;

    final ratio = currentLoad / previousLoad;

    if (ratio > 1.5) return OvertrainingRisk.high;
    if (ratio > 1.3) return OvertrainingRisk.moderate;
    return OvertrainingRisk.none;
  }
}

enum OvertrainingRisk {
  none,
  moderate,
  high,
}
