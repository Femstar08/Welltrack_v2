import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/health/data/health_repository_impl.dart';
import 'package:welltrack/features/health/domain/baseline_entity.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

/// Progress information for a specific metric's baseline calibration
class CalibrationProgress {
  final int daysCaptured;
  final int dataPointsCount;
  final bool isReady;
  final double? baselineValue;
  final DateTime? captureStart;
  final DateTime? captureEnd;

  const CalibrationProgress({
    required this.daysCaptured,
    required this.dataPointsCount,
    required this.isReady,
    this.baselineValue,
    this.captureStart,
    this.captureEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'daysCaptured': daysCaptured,
      'dataPointsCount': dataPointsCount,
      'isReady': isReady,
      'baselineValue': baselineValue,
      'captureStart': captureStart?.toIso8601String(),
      'captureEnd': captureEnd?.toIso8601String(),
    };
  }
}

/// Service responsible for computing and managing baseline calibrations
/// for health metrics. Implements metric-specific computation strategies.
class BaselineCalibration {
  final HealthRepositoryImpl _healthRepo;
  final SupabaseClient _supabase;

  BaselineCalibration({
    HealthRepositoryImpl? healthRepository,
    SupabaseClient? supabase,
  })  : _healthRepo = healthRepository ?? HealthRepositoryImpl(),
        _supabase = supabase ?? Supabase.instance.client;

  /// Computes baseline for a specific metric type
  ///
  /// Requirements:
  /// - At least 14 days of data span
  /// - At least 10 validated data points
  ///
  /// Computation strategies by metric type:
  /// - sleep: MEDIAN of total duration in minutes (outlier-resistant)
  /// - steps: MEAN of daily totals (stable aggregates)
  /// - hr: 10th PERCENTILE of overnight readings (resting HR)
  /// - stress: MEDIAN of daily stress scores
  /// - vo2max: LATEST validated value (not averaged)
  ///
  /// Returns null if calibration requirements not met
  Future<BaselineEntity?> computeBaseline(
    String profileId,
    MetricType metricType,
  ) async {
    try {
      final now = DateTime.now();
      final fourteenDaysAgo = now.subtract(const Duration(days: 14));

      // Fetch validated metrics from last 14+ days
      final metrics = await _healthRepo.getMetricsByType(
        profileId,
        metricType,
        startDate: fourteenDaysAgo,
        endDate: now,
      );

      if (metrics.isEmpty) {
        print('No metrics found for $metricType in profile $profileId');
        return null;
      }

      // Check if we have sufficient data points
      if (metrics.length < 10) {
        print('Insufficient data points for $metricType: ${metrics.length} < 10');
        return null;
      }

      // Get time range
      final sortedMetrics = List<HealthMetricEntity>.from(metrics)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final captureStart = sortedMetrics.first.startTime;
      final captureEnd = sortedMetrics.last.startTime;
      final daysDuration = captureEnd.difference(captureStart).inDays;

      // Check if we have sufficient time span
      if (daysDuration < 14) {
        print('Insufficient time span for $metricType: $daysDuration days < 14');
        return null;
      }

      // Extract numeric values
      final values = metrics
          .where((m) => m.valueNum != null)
          .map((m) => m.valueNum!)
          .toList();

      if (values.isEmpty) {
        print('No valid numeric values for $metricType');
        return null;
      }

      // Compute baseline value based on metric type
      final baselineValue = _computeBaselineValue(metricType, values);

      if (baselineValue == null) {
        print('Failed to compute baseline value for $metricType');
        return null;
      }

      // Create baseline entity
      final baseline = BaselineEntity(
        profileId: profileId,
        metricType: metricType,
        baselineValue: baselineValue,
        dataPointsCount: metrics.length,
        captureStart: captureStart,
        captureEnd: captureEnd,
        isComplete: true,
        calibrationStatus: CalibrationStatus.complete,
        notes: 'Auto-computed on ${DateTime.now().toIso8601String()}',
      );

      // Upsert to database
      await _upsertBaseline(baseline);

      print('Baseline computed for $metricType: $baselineValue');
      return baseline;
    } catch (e) {
      print('Error computing baseline for $metricType: $e');
      return null;
    }
  }

  /// Computes baseline value based on metric-specific strategy
  double? _computeBaselineValue(MetricType metricType, List<double> values) {
    if (values.isEmpty) return null;

    switch (metricType) {
      case MetricType.sleep:
        // MEDIAN - outlier resistant for sleep duration
        return _calculateMedian(values);

      case MetricType.steps:
        // MEAN - daily aggregates are stable
        return _calculateMean(values);

      case MetricType.hr:
        // 10th PERCENTILE - resting heart rate (low values during sleep)
        return _calculatePercentile(values, 10);

      case MetricType.stress:
        // MEDIAN - outlier resistant for stress scores
        return _calculateMedian(values);

      case MetricType.vo2max:
        // LATEST value - not averaged
        return values.last;

      case MetricType.hrv:
        // MEDIAN - outlier resistant
        return _calculateMedian(values);

      default:
        // Default to mean for other metrics
        return _calculateMean(values);
    }
  }

  /// Calculate mean (average) of values
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate median of values
  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;

    if (sorted.length % 2 == 1) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
  }

  /// Calculate percentile of values
  double _calculatePercentile(List<double> values, int percentile) {
    if (values.isEmpty) return 0.0;
    if (percentile < 0 || percentile > 100) {
      throw ArgumentError('Percentile must be between 0 and 100');
    }

    final sorted = List<double>.from(values)..sort();
    final index = (percentile / 100 * (sorted.length - 1)).round();
    return sorted[index];
  }

  /// Checks calibration status for all tracked metric types
  /// Returns progress information for each metric
  Future<Map<MetricType, CalibrationProgress>> checkCalibrationStatus(
    String profileId,
  ) async {
    try {
      final result = <MetricType, CalibrationProgress>{};

      // Metrics we track baselines for
      final trackedMetrics = [
        MetricType.sleep,
        MetricType.steps,
        MetricType.hr,
        MetricType.stress,
        MetricType.vo2max,
      ];

      for (final metricType in trackedMetrics) {
        final progress = await _getMetricProgress(profileId, metricType);
        result[metricType] = progress;
      }

      return result;
    } catch (e) {
      print('Error checking calibration status: $e');
      return {};
    }
  }

  /// Get calibration progress for a specific metric
  Future<CalibrationProgress> _getMetricProgress(
    String profileId,
    MetricType metricType,
  ) async {
    try {
      // Get time range for this metric
      final timeRange = await _healthRepo.getDataTimeRange(
        profileId,
        metricType,
      );

      if (timeRange == null || timeRange.first == null || timeRange.last == null) {
        return const CalibrationProgress(
          daysCaptured: 0,
          dataPointsCount: 0,
          isReady: false,
        );
      }

      // Get count of data points
      final count = await _healthRepo.getMetricCount(
        profileId,
        metricType,
        since: timeRange.first,
      );

      // Calculate days captured
      final daysCaptured = timeRange.last!.difference(timeRange.first!).inDays;

      // Check if ready for calibration
      final isReady = daysCaptured >= 14 && count >= 10;

      // Get existing baseline value if it exists
      double? baselineValue;
      final existingBaseline = await _getExistingBaseline(profileId, metricType);
      if (existingBaseline != null) {
        baselineValue = existingBaseline.baselineValue;
      }

      return CalibrationProgress(
        daysCaptured: daysCaptured,
        dataPointsCount: count,
        isReady: isReady,
        baselineValue: baselineValue,
        captureStart: timeRange.first,
        captureEnd: timeRange.last,
      );
    } catch (e) {
      print('Error getting metric progress for $metricType: $e');
      return const CalibrationProgress(
        daysCaptured: 0,
        dataPointsCount: 0,
        isReady: false,
      );
    }
  }

  /// Gets existing baseline from database
  Future<BaselineEntity?> _getExistingBaseline(
    String profileId,
    MetricType metricType,
  ) async {
    try {
      final response = await _supabase
          .from('wt_baselines')
          .select()
          .eq('profile_id', profileId)
          .eq('metric_type', metricType.name)
          .maybeSingle();

      if (response == null) return null;

      return BaselineEntity.fromSupabaseJson(response);
    } catch (e) {
      print('Error getting existing baseline: $e');
      return null;
    }
  }

  /// Forces recalibration of a specific baseline
  /// Useful for manual refresh or after significant health changes
  Future<BaselineEntity?> triggerRecalibration(
    String profileId,
    MetricType metricType,
  ) async {
    try {
      print('Triggering recalibration for $metricType in profile $profileId');

      // Delete existing baseline to force recomputation
      await _supabase
          .from('wt_baselines')
          .delete()
          .eq('profile_id', profileId)
          .eq('metric_type', metricType.name);

      // Compute new baseline
      return await computeBaseline(profileId, metricType);
    } catch (e) {
      print('Error triggering recalibration for $metricType: $e');
      return null;
    }
  }

  /// Computes all baselines for a profile in batch
  /// Typically called after background sync or historical backfill
  /// Returns map of metric types to their computed baselines
  Future<Map<MetricType, BaselineEntity>> computeAllBaselines(
    String profileId,
  ) async {
    try {
      print('Computing all baselines for profile $profileId');

      final result = <MetricType, BaselineEntity>{};

      // Metrics we track baselines for
      final trackedMetrics = [
        MetricType.sleep,
        MetricType.steps,
        MetricType.hr,
        MetricType.stress,
        MetricType.vo2max,
      ];

      for (final metricType in trackedMetrics) {
        final baseline = await computeBaseline(profileId, metricType);
        if (baseline != null) {
          result[metricType] = baseline;
        }
      }

      print('Computed ${result.length} baselines for profile $profileId');
      return result;
    } catch (e) {
      print('Error computing all baselines: $e');
      return {};
    }
  }

  /// Upserts baseline to database
  Future<void> _upsertBaseline(BaselineEntity baseline) async {
    try {
      // Check if baseline exists
      final existing = await _supabase
          .from('wt_baselines')
          .select('id')
          .eq('profile_id', baseline.profileId)
          .eq('metric_type', baseline.metricType.name)
          .maybeSingle();

      final json = baseline.toSupabaseJson();

      if (existing != null) {
        // Update existing
        json['id'] = existing['id'];
        await _supabase
            .from('wt_baselines')
            .update(json)
            .eq('id', existing['id']);
      } else {
        // Insert new
        await _supabase.from('wt_baselines').insert(json);
      }

      print('Upserted baseline for ${baseline.metricType}');
    } catch (e) {
      print('Error upserting baseline: $e');
      rethrow;
    }
  }

  /// Checks if a profile has all baselines computed
  Future<bool> hasAllBaselinesComplete(String profileId) async {
    try {
      final status = await checkCalibrationStatus(profileId);
      return status.values.every((progress) => progress.isReady);
    } catch (e) {
      print('Error checking if all baselines complete: $e');
      return false;
    }
  }

  /// Gets incomplete baselines for a profile
  /// Returns list of metric types that need more data
  Future<List<MetricType>> getIncompleteBaselines(String profileId) async {
    try {
      final status = await checkCalibrationStatus(profileId);
      return status.entries
          .where((entry) => !entry.value.isReady)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      print('Error getting incomplete baselines: $e');
      return [];
    }
  }
}

/// Riverpod provider for BaselineCalibration
final baselineCalibrationProvider = Provider<BaselineCalibration>((ref) {
  final healthRepo = ref.watch(healthRepositoryImplProvider);
  return BaselineCalibration(healthRepository: healthRepo);
});

/// Provider for calibration status (fetches current status)
final calibrationStatusProvider = FutureProvider.family<
    Map<MetricType, CalibrationProgress>,
    String>((ref, profileId) async {
  final calibration = ref.watch(baselineCalibrationProvider);
  return await calibration.checkCalibrationStatus(profileId);
});

/// Provider to check if all baselines are complete
final allBaselinesCompleteProvider = FutureProvider.family<bool, String>(
  (ref, profileId) async {
    final calibration = ref.watch(baselineCalibrationProvider);
    return await calibration.hasAllBaselinesComplete(profileId);
  },
);
