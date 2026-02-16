import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/health/data/health_data_source.dart';
import 'package:welltrack/features/health/data/health_normalizer.dart';
import 'package:welltrack/features/health/data/health_validator.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/features/health/domain/baseline_entity.dart';

/// Repository for managing health data sync and storage
class HealthRepository {
  final HealthDataSource _dataSource;
  final HealthNormalizer _normalizer;
  final SupabaseClient _supabase;

  HealthRepository({
    HealthDataSource? dataSource,
    HealthNormalizer? normalizer,
    SupabaseClient? supabase,
  })  : _dataSource = dataSource ?? HealthDataSource(),
        _normalizer = normalizer ?? HealthNormalizer(),
        _supabase = supabase ?? Supabase.instance.client;

  /// Sync health data for the last 24 hours
  Future<Map<String, int>> syncHealthData(String profileId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return await _syncDataForPeriod(userId, profileId, yesterday, now);
  }

  /// Sync historical health data (backfill)
  /// Max 90 days to avoid performance issues
  Future<Map<String, int>> syncHistoricalData(
    String profileId, {
    int days = 14,
  }) async {
    if (days > 90) {
      throw ArgumentError('Cannot sync more than 90 days of historical data');
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));

    return await _syncDataForPeriod(userId, profileId, start, now);
  }

  /// Internal method to sync data for a specific period
  Future<Map<String, int>> _syncDataForPeriod(
    String userId,
    String profileId,
    DateTime start,
    DateTime end,
  ) async {
    final source = _dataSource.getPlatformSource();
    int sleepCount = 0;
    int stepsCount = 0;
    int hrCount = 0;

    // Fetch and normalize sleep data
    final rawSleep = await _dataSource.fetchSleepData(start, end);
    final sleepMetrics = _normalizer.normalizeSleepData(
      rawSleep,
      userId,
      profileId,
      source,
    );
    sleepCount = await _upsertMetrics(sleepMetrics);

    // Fetch and normalize steps data
    final rawSteps = await _dataSource.fetchStepsData(start, end);
    final stepsMetrics = _normalizer.normalizeStepsData(
      rawSteps,
      userId,
      profileId,
      source,
    );
    stepsCount = await _upsertMetrics(stepsMetrics);

    // Fetch and normalize heart rate data
    final rawHR = await _dataSource.fetchHeartRateData(start, end);
    final hrMetrics = _normalizer.normalizeHeartRateData(
      rawHR,
      userId,
      profileId,
      source,
    );
    hrCount = await _upsertMetrics(hrMetrics);

    // Update baseline calibration progress
    await updateBaselineProgress(profileId);

    return {
      'sleep': sleepCount,
      'steps': stepsCount,
      'hr': hrCount,
    };
  }

  /// Upsert normalized metrics to Supabase
  /// Uses dedupe_hash for conflict resolution
  Future<int> _upsertMetrics(List<HealthMetricEntity> metrics) async {
    if (metrics.isEmpty) return 0;

    int upsertedCount = 0;

    for (final metric in metrics) {
      // Validate before upserting
      final validationStatus = HealthValidator.validateMetric(metric);

      final validatedMetric = HealthMetricEntity(
        id: metric.id,
        userId: metric.userId,
        profileId: metric.profileId,
        source: metric.source,
        metricType: metric.metricType,
        valueNum: metric.valueNum,
        valueText: metric.valueText,
        unit: metric.unit,
        startTime: metric.startTime,
        endTime: metric.endTime,
        recordedAt: metric.recordedAt,
        rawPayload: metric.rawPayload,
        dedupeHash: metric.dedupeHash,
        validationStatus: validationStatus,
        processingStatus: validationStatus == ValidationStatus.validated
            ? ProcessingStatus.processed
            : ProcessingStatus.error,
        ingestionSourceVersion: '1.0.0',
      );

      try {
        await _supabase.from('wt_health_metrics').upsert(
              validatedMetric.toSupabaseJson(),
              onConflict: 'dedupe_hash',
            );
        upsertedCount++;
      } catch (e) {
        print('Error upserting metric: $e');
      }
    }

    return upsertedCount;
  }

  /// Get health metrics for a profile and date range
  Future<List<HealthMetricEntity>> getMetrics(
    String profileId,
    MetricType metricType, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (profileId.isEmpty) return [];
    try {
      var query = _supabase
          .from('wt_health_metrics')
          .select()
          .eq('profile_id', profileId)
          .eq('metric_type', metricType.name)
          .eq('validation_status', ValidationStatus.validated.name);

      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('start_time', endDate.toIso8601String());
      }

      final response = await query.order('start_time', ascending: false);

      return (response as List)
          .map((json) => HealthMetricEntity.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      print('Error fetching metrics: $e');
      return [];
    }
  }

  /// Get baseline calibration status for a profile
  Future<Map<MetricType, BaselineEntity>> getBaselineStatus(
    String profileId,
  ) async {
    if (profileId.isEmpty) return {};
    try {
      final response = await _supabase
          .from('wt_health_baselines')
          .select()
          .eq('profile_id', profileId);

      final baselines = (response as List)
          .map((json) => BaselineEntity.fromSupabaseJson(json))
          .toList();

      return {
        for (final baseline in baselines) baseline.metricType: baseline,
      };
    } catch (e) {
      print('Error fetching baseline status: $e');
      return {};
    }
  }

  /// Update baseline calibration progress
  /// Recalculates baseline if requirements are met
  Future<void> updateBaselineProgress(String profileId) async {
    // Metrics we track baselines for
    final metricsToTrack = [
      MetricType.sleep,
      MetricType.steps,
      MetricType.hr,
    ];

    for (final metricType in metricsToTrack) {
      await _updateBaselineForMetric(profileId, metricType);
    }
  }

  Future<void> _updateBaselineForMetric(
    String profileId,
    MetricType metricType,
  ) async {
    try {
      // Get or create baseline record
      final existingResponse = await _supabase
          .from('wt_health_baselines')
          .select()
          .eq('profile_id', profileId)
          .eq('metric_type', metricType.name)
          .maybeSingle();

      BaselineEntity? baseline;
      if (existingResponse != null) {
        baseline = BaselineEntity.fromSupabaseJson(existingResponse);
      }

      // Count validated data points
      final metricsResponse = await _supabase
          .from('wt_health_metrics')
          .select('id, start_time, value_num')
          .eq('profile_id', profileId)
          .eq('metric_type', metricType.name)
          .eq('validation_status', ValidationStatus.validated.name)
          .order('start_time', ascending: true);

      final dataPoints = metricsResponse as List;

      if (dataPoints.isEmpty) return;

      final firstDataTime = DateTime.parse(dataPoints.first['start_time']);
      final lastDataTime = DateTime.parse(dataPoints.last['start_time']);
      final dataPointsCount = dataPoints.length;

      // Calculate baseline value (mean)
      final values = dataPoints
          .map((dp) => (dp['value_num'] as num?)?.toDouble())
          .where((v) => v != null)
          .cast<double>()
          .toList();

      final baselineValue = values.isNotEmpty
          ? values.reduce((a, b) => a + b) / values.length
          : null;

      final newBaseline = BaselineEntity(
        id: baseline?.id,
        profileId: profileId,
        metricType: metricType,
        baselineValue: baselineValue,
        dataPointsCount: dataPointsCount,
        captureStart: baseline?.captureStart ?? firstDataTime,
        captureEnd: lastDataTime,
        isComplete: dataPointsCount >= 10 &&
            lastDataTime.difference(firstDataTime).inDays >= 14,
        calibrationStatus: _getCalibrationStatus(
          dataPointsCount,
          lastDataTime.difference(firstDataTime).inDays,
        ),
      );

      await _supabase.from('wt_health_baselines').upsert(
            newBaseline.toSupabaseJson(),
          );
    } catch (e) {
      print('Error updating baseline for $metricType: $e');
    }
  }

  CalibrationStatus _getCalibrationStatus(int dataPoints, int days) {
    if (dataPoints >= 10 && days >= 14) {
      return CalibrationStatus.complete;
    } else if (dataPoints > 0) {
      return CalibrationStatus.inProgress;
    }
    return CalibrationStatus.pending;
  }
}

/// Riverpod provider for HealthRepository
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository();
});
