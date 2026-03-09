import 'dart:math' as math;
import '../domain/recovery_score_entity.dart';
import '../domain/forecast_entity.dart';

/// Performance Engine — Phase 10
/// All calculations are deterministic. Zero AI involvement.
/// Formula: (sleep_score × 0.30) + (sleep_quality × 0.20) + (rhr_score × 0.25) + (load_score × 0.25)
class PerformanceEngine {
  // PRD Phase 10 weights
  static const double _sleepScoreWeight = 0.30;
  static const double _sleepQualityWeight = 0.20;
  static const double _rhrWeight = 0.25;
  static const double _loadWeight = 0.25;

  /// Calculate recovery score from available components.
  /// Uses partial scoring — re-normalises weights for available inputs.
  ///
  /// stressComponent DB slot is repurposed for sleepQualityComponent.
  ///
  /// Garmin inputs (Phase 11):
  ///   [garminBodyBattery]  — 0-100 Garmin body battery reading (higher = better).
  ///                          When present, it replaces the sleep-quality component
  ///                          because body battery correlates strongly with overnight
  ///                          sleep + stress recovery.
  ///   [garminStressScore]  — 0-100 Garmin stress score (LOWER = less stress = BETTER).
  ///                          When present, it replaces the HR-deviation-based stress
  ///                          estimate used for the RHR component.
  ///
  /// Source priority: Garmin data always takes precedence over Health Connect data
  /// for the metrics it provides (body battery, stress). Health Connect data is used
  /// as fallback when Garmin is not connected.
  static RecoveryScoreEntity calculateRecoveryScore({
    required String profileId,
    required DateTime date,
    double? sleepDurationHours,  // actual hours slept (e.g. 7.5)
    double? sleepQualityRatio,   // (REM + deep) / total sleep, e.g. 0.25
    double? restingHr,           // today's resting HR bpm
    double? baselineHr,          // 14-day average resting HR
    double? sevenDayLoad,        // rolling 7-day training load sum
    double? fourWeekAvgLoad,     // 4-week average weekly load
    // Garmin Phase 11 inputs — optional, take priority when present
    double? garminBodyBattery,   // 0-100 (higher = better recovery charge)
    double? garminStressScore,   // 0-100 (lower = less stress = better)
  }) {
    final components = <double>[];
    final weights = <double>[];

    // Track data sources for attribution display in the UI
    final sourcesUsed = <String, String>{};

    // Sleep score (30%) — duration-based; always from Health Connect / manual
    double? sleepScoreComponent;
    if (sleepDurationHours != null) {
      sleepScoreComponent = normalizeSleepDuration(sleepDurationHours);
      components.add(sleepScoreComponent);
      weights.add(_sleepScoreWeight);
      sourcesUsed['sleep_duration'] = 'healthconnect';
    }

    // Sleep quality / body battery (20%) — stored in stressComponent DB slot.
    // Garmin body battery takes priority over REM+deep ratio when available,
    // as it provides a holistic overnight recovery charge reading.
    double? sleepQualityComponent;
    if (garminBodyBattery != null) {
      // Body battery is already 0-100 (higher = better) — use directly
      sleepQualityComponent = garminBodyBattery.clamp(0.0, 100.0);
      components.add(sleepQualityComponent);
      weights.add(_sleepQualityWeight);
      sourcesUsed['sleep_quality'] = 'garmin';
    } else if (sleepQualityRatio != null) {
      sleepQualityComponent = normalizeSleepQuality(sleepQualityRatio);
      components.add(sleepQualityComponent);
      weights.add(_sleepQualityWeight);
      sourcesUsed['sleep_quality'] = 'healthconnect';
    }

    // RHR / stress score (25%).
    // Garmin stress score (lower = better) takes priority over resting-HR deviation
    // when available, as it is measured continuously throughout the day.
    double? rhrComponent;
    if (garminStressScore != null) {
      // Invert: stress 0 → score 100, stress 100 → score 0
      rhrComponent = normalizeStress(garminStressScore);
      components.add(rhrComponent);
      weights.add(_rhrWeight);
      sourcesUsed['hr_stress'] = 'garmin';
    } else if (restingHr != null && baselineHr != null) {
      rhrComponent = normalizeRHR(restingHr, baselineHr);
      components.add(rhrComponent);
      weights.add(_rhrWeight);
      sourcesUsed['hr_stress'] = 'healthconnect';
    }

    // Load score (25%)
    double? loadComponent;
    if (sevenDayLoad != null && fourWeekAvgLoad != null) {
      loadComponent = normalizeLoadScore(sevenDayLoad, fourWeekAvgLoad);
      components.add(loadComponent);
      weights.add(_loadWeight);
      sourcesUsed['training_load'] = 'internal';
    }

    final recoveryScore = _weightedAverage(components, weights);

    return RecoveryScoreEntity(
      id: '',
      profileId: profileId,
      scoreDate: date,
      stressComponent: sleepQualityComponent, // repurposed slot
      sleepComponent: sleepScoreComponent,
      hrComponent: rhrComponent,
      loadComponent: loadComponent,
      recoveryScore: recoveryScore,
      componentsAvailable: components.length,
      rawData: {
        'sleep_duration_hours': sleepDurationHours,
        'sleep_quality_ratio': sleepQualityRatio,
        'resting_hr': restingHr,
        'baseline_hr': baselineHr,
        'seven_day_load': sevenDayLoad,
        'four_week_avg_load': fourWeekAvgLoad,
        // Garmin inputs
        'garmin_body_battery': garminBodyBattery,
        'garmin_stress_score': garminStressScore,
        // Source attribution map — read by RecoveryDetailScreen
        'sources': sourcesUsed,
      },
    );
  }

  /// sleep_score = (hours / 7.5).clamp(0, 1) × 100
  static double normalizeSleepDuration(double hours) {
    return ((hours / 7.5).clamp(0.0, 1.0) * 100);
  }

  /// sleep_quality = ((REM + deep) / total / 0.40).clamp(0, 1) × 100
  /// qualityRatio: (rem_minutes + deep_minutes) / total_sleep_minutes
  static double normalizeSleepQuality(double qualityRatio) {
    return ((qualityRatio / 0.40).clamp(0.0, 1.0) * 100);
  }

  /// rhr_score = (1 − (today − baseline) / baseline).clamp(0, 1) × 100
  static double normalizeRHR(double currentHr, double baselineHr) {
    if (baselineHr <= 0) return 100.0;
    final score = 1.0 - ((currentHr - baselineHr) / baselineHr);
    return (score.clamp(0.0, 1.0) * 100);
  }

  /// load_score = (1 − sevenDayLoad / fourWeekAvgLoad).clamp(0, 1) × 100
  static double normalizeLoadScore(double sevenDayLoad, double fourWeekAvgLoad) {
    if (fourWeekAvgLoad <= 0) return sevenDayLoad == 0 ? 100.0 : 80.0;
    final score = 1.0 - (sevenDayLoad / fourWeekAvgLoad);
    return (score.clamp(0.0, 1.0) * 100);
  }

  // ---------------------------------------------------------------------------
  // Legacy normalizers — kept for chart widgets and backward compat
  // ---------------------------------------------------------------------------

  /// Normalize stress to 0-100 (inverted: low stress = high recovery)
  static double normalizeStress(double stressAvg) {
    return (100.0 - stressAvg).clamp(0.0, 100.0);
  }

  /// Normalize sleep duration to 0-100 (legacy bell-curve)
  static double normalizeSleep(double durationMin, {double? qualityScore}) {
    double durationScore;
    if (durationMin >= 420 && durationMin <= 540) {
      durationScore = 100.0;
    } else if (durationMin < 420) {
      durationScore = (durationMin / 420 * 100).clamp(0.0, 100.0);
    } else {
      final excess = durationMin - 540;
      durationScore = (100.0 - (excess / 60 * 10)).clamp(50.0, 100.0);
    }
    if (qualityScore != null) {
      return (durationScore * 0.7 + qualityScore * 0.3).clamp(0.0, 100.0);
    }
    return durationScore;
  }

  /// Normalize HR deviation to 0-100 (legacy)
  static double normalizeHR(double currentHr, double baselineHr) {
    final deviation = currentHr - baselineHr;
    if (deviation <= 0) return 100.0;
    return (100.0 - (deviation * 4)).clamp(0.0, 100.0);
  }

  /// Normalize training load to 0-100 via step function (legacy)
  static double normalizeLoad(double currentLoad, double previousLoad) {
    if (previousLoad == 0) return currentLoad == 0 ? 100.0 : 80.0;
    final ratio = currentLoad / previousLoad;
    if (ratio < 0.7) return 100.0;
    if (ratio < 1.0) return 90.0;
    if (ratio <= 1.2) return 75.0;
    if (ratio <= 1.3) return 60.0;
    if (ratio <= 1.5) return 40.0;
    return 20.0;
  }

  // ---------------------------------------------------------------------------
  // Weighted average helper
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Training Load
  // ---------------------------------------------------------------------------

  /// Calculate training load: duration × intensity_factor
  /// Intensity factors: easy=0.5, moderate=1.0, hard=1.5, max=2.0
  static double calculateTrainingLoad(
    double durationMinutes,
    double intensityFactor,
  ) {
    return durationMinutes * intensityFactor;
  }

  /// Map workout intensity string to factor per PRD
  static double intensityFactorFromString(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'easy':
        return 0.5;
      case 'moderate':
        return 1.0;
      case 'hard':
        return 1.5;
      case 'max':
        return 2.0;
      default:
        return 1.0;
    }
  }

  /// Get intensity factor from HR zones (Karvonen)
  static double intensityFromHR(
    double avgHr,
    double restingHr,
    double maxHr,
  ) {
    final hrReserve = maxHr - restingHr;
    if (hrReserve <= 0) return 1.0;
    final intensity = (avgHr - restingHr) / hrReserve;
    if (intensity < 0.6) return 0.5;
    if (intensity < 0.7) return 0.75;
    if (intensity < 0.8) return 1.0;
    if (intensity < 0.9) return 1.5;
    return 2.0;
  }

  // ---------------------------------------------------------------------------
  // Overtraining
  // ---------------------------------------------------------------------------

  /// Detect overtraining risk based on load ratio (current / previous)
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

  // ---------------------------------------------------------------------------
  // Trend calculations (US-004)
  // ---------------------------------------------------------------------------

  /// Classify a trend as improving, worsening, or stable.
  /// [currentAvg] vs [previousAvg], [lowerIsBetter] for metrics like stress/RHR.
  static TrendDirection classifyTrend({
    required double currentAvg,
    required double previousAvg,
    bool lowerIsBetter = false,
    double threshold = 0.03, // 3% change = meaningful
  }) {
    if (previousAvg == 0) return TrendDirection.stable;
    final change = (currentAvg - previousAvg) / previousAvg;
    if (change.abs() < threshold) return TrendDirection.stable;
    final improving = lowerIsBetter ? change < 0 : change > 0;
    return improving ? TrendDirection.improving : TrendDirection.worsening;
  }

  /// Calculate daily VO2 max slope (delta over period / days).
  static double calculateVo2Slope(List<DataPoint> points) {
    if (points.length < 2) return 0.0;
    final sorted = List<DataPoint>.from(points)
      ..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first;
    final last = sorted.last;
    final days = last.date.difference(first.date).inDays;
    if (days == 0) return 0.0;
    return (last.value - first.value) / days;
  }

  // ---------------------------------------------------------------------------
  // Forecasting
  // ---------------------------------------------------------------------------

  /// Linear regression forecast
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

    final sortedPoints = List<DataPoint>.from(dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    final currentValue = sortedPoints.last.value;
    final regression = _linearRegression(sortedPoints, baselineDate);

    DateTime? projectedDate;
    if (regression.slope != 0) {
      final daysToTarget =
          ((targetValue - regression.intercept) / regression.slope).round();
      if (daysToTarget > 0 && daysToTarget < 3650) {
        projectedDate = baselineDate.add(Duration(days: daysToTarget));
      }
    }

    return ForecastEntity(
      id: '',
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

    final x = points.map((p) => p.daysSince(baseline).toDouble()).toList();
    final y = points.map((p) => p.value).toList();

    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double denominator = 0.0;
    for (int i = 0; i < n; i++) {
      numerator += (x[i] - xMean) * (y[i] - yMean);
      denominator += (x[i] - xMean) * (x[i] - xMean);
    }

    final slope = denominator != 0 ? numerator / denominator : 0.0;
    final intercept = yMean - slope * xMean;

    double ssRes = 0.0;
    double ssTot = 0.0;
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
}

enum OvertrainingRisk { none, moderate, high }

enum TrendDirection { improving, worsening, stable }
