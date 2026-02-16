import 'package:health/health.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

/// Normalizes raw health data into standardized HealthMetricEntity objects
class HealthNormalizer {
  /// Normalize sleep data from health package into HealthMetricEntity list
  /// Groups sleep segments into sessions and calculates total duration
  List<HealthMetricEntity> normalizeSleepData(
    List<HealthDataPoint> rawData,
    String userId,
    String profileId,
    HealthSource source,
  ) {
    if (rawData.isEmpty) return [];

    // Group sleep data points by date (session)
    final Map<DateTime, List<HealthDataPoint>> sessions = {};

    for (final point in rawData) {
      final sessionDate = DateTime(
        point.dateFrom.year,
        point.dateFrom.month,
        point.dateFrom.day,
      );

      sessions.putIfAbsent(sessionDate, () => []).add(point);
    }

    final List<HealthMetricEntity> normalized = [];

    for (final entry in sessions.entries) {
      final sessionPoints = entry.value;

      // Find earliest start and latest end time
      DateTime? sessionStart;
      DateTime? sessionEnd;

      for (final point in sessionPoints) {
        if (sessionStart == null || point.dateFrom.isBefore(sessionStart)) {
          sessionStart = point.dateFrom;
        }
        if (sessionEnd == null || point.dateTo.isAfter(sessionEnd)) {
          sessionEnd = point.dateTo;
        }
      }

      if (sessionStart == null || sessionEnd == null) continue;

      // Calculate total sleep duration in minutes
      final totalMinutes = sessionEnd.difference(sessionStart).inMinutes;

      // Build stage breakdown for raw payload
      final Map<String, int> stageBreakdown = {};
      for (final point in sessionPoints) {
        final stageName = point.type.name;
        final stageDuration = point.dateTo.difference(point.dateFrom).inMinutes;
        stageBreakdown[stageName] = (stageBreakdown[stageName] ?? 0) + stageDuration;
      }

      // Create dedupe hash
      final dedupeString = '$userId-$profileId-${source.name}-sleep-${sessionStart.toIso8601String()}-${sessionEnd.toIso8601String()}';
      final dedupeHash = md5.convert(utf8.encode(dedupeString)).toString();

      normalized.add(HealthMetricEntity(
        userId: userId,
        profileId: profileId,
        source: source,
        metricType: MetricType.sleep,
        valueNum: totalMinutes.toDouble(),
        unit: 'minutes',
        startTime: sessionStart,
        endTime: sessionEnd,
        recordedAt: DateTime.now(),
        rawPayload: {
          'stages': stageBreakdown,
          'total_points': sessionPoints.length,
        },
        dedupeHash: dedupeHash,
        validationStatus: ValidationStatus.raw,
        processingStatus: ProcessingStatus.pending,
      ));
    }

    return normalized;
  }

  /// Normalize steps data into daily totals
  List<HealthMetricEntity> normalizeStepsData(
    List<HealthDataPoint> rawData,
    String userId,
    String profileId,
    HealthSource source,
  ) {
    if (rawData.isEmpty) return [];

    // Aggregate steps by day
    final Map<DateTime, int> dailySteps = {};

    for (final point in rawData) {
      final day = DateTime(
        point.dateFrom.year,
        point.dateFrom.month,
        point.dateFrom.day,
      );

      final steps = (point.value as NumericHealthValue).numericValue.toInt();
      dailySteps[day] = (dailySteps[day] ?? 0) + steps;
    }

    final List<HealthMetricEntity> normalized = [];

    for (final entry in dailySteps.entries) {
      final date = entry.key;
      final totalSteps = entry.value;

      // Create dedupe hash
      final dedupeString = '$userId-$profileId-${source.name}-steps-${date.toIso8601String()}';
      final dedupeHash = md5.convert(utf8.encode(dedupeString)).toString();

      normalized.add(HealthMetricEntity(
        userId: userId,
        profileId: profileId,
        source: source,
        metricType: MetricType.steps,
        valueNum: totalSteps.toDouble(),
        unit: 'count',
        startTime: date,
        endTime: date.add(const Duration(days: 1)),
        recordedAt: DateTime.now(),
        dedupeHash: dedupeHash,
        validationStatus: ValidationStatus.raw,
        processingStatus: ProcessingStatus.pending,
      ));
    }

    return normalized;
  }

  /// Normalize heart rate data
  /// Extracts resting HR (lowest values from overnight/morning periods)
  List<HealthMetricEntity> normalizeHeartRateData(
    List<HealthDataPoint> rawData,
    String userId,
    String profileId,
    HealthSource source,
  ) {
    if (rawData.isEmpty) return [];

    // Group HR data by day
    final Map<DateTime, List<HealthDataPoint>> dailyHR = {};

    for (final point in rawData) {
      final day = DateTime(
        point.dateFrom.year,
        point.dateFrom.month,
        point.dateFrom.day,
      );

      dailyHR.putIfAbsent(day, () => []).add(point);
    }

    final List<HealthMetricEntity> normalized = [];

    for (final entry in dailyHR.entries) {
      final date = entry.key;
      final hrPoints = entry.value;

      // Filter for overnight/morning readings (11pm-9am)
      final overnightPoints = hrPoints.where((point) {
        final hour = point.dateFrom.hour;
        return hour >= 23 || hour <= 9;
      }).toList();

      if (overnightPoints.isEmpty) continue;

      // Find minimum HR (resting HR)
      double minHR = double.infinity;
      DateTime? minHRTime;

      for (final point in overnightPoints) {
        final hr = (point.value as NumericHealthValue).numericValue.toDouble();
        if (hr < minHR) {
          minHR = hr;
          minHRTime = point.dateFrom;
        }
      }

      if (minHRTime == null) continue;

      // Create dedupe hash
      final dedupeString = '$userId-$profileId-${source.name}-hr-${date.toIso8601String()}';
      final dedupeHash = md5.convert(utf8.encode(dedupeString)).toString();

      normalized.add(HealthMetricEntity(
        userId: userId,
        profileId: profileId,
        source: source,
        metricType: MetricType.hr,
        valueNum: minHR,
        valueText: 'resting',
        unit: 'bpm',
        startTime: minHRTime,
        recordedAt: DateTime.now(),
        rawPayload: {
          'total_readings': overnightPoints.length,
          'is_resting': true,
        },
        dedupeHash: dedupeHash,
        validationStatus: ValidationStatus.raw,
        processingStatus: ProcessingStatus.pending,
      ));
    }

    return normalized;
  }

  /// Resolve conflict when two metrics have overlapping time ranges.
  ///
  /// Priority rules:
  /// 1. If sources differ: prefer healthconnect over healthkit
  /// 2. If same source: keep the one with the most recent recordedAt
  /// 3. For sleep: prefer record with non-null rawPayload stages data
  static HealthMetricEntity resolveConflict(
    HealthMetricEntity existing,
    HealthMetricEntity incoming,
  ) {
    // Rule 1: Source priority (healthconnect > healthkit)
    if (existing.source != incoming.source) {
      const sourcePriority = {
        HealthSource.garmin: 4,
        HealthSource.strava: 3,
        HealthSource.healthconnect: 2,
        HealthSource.healthkit: 1,
        HealthSource.manual: 0,
      };
      final existingPriority = sourcePriority[existing.source] ?? 0;
      final incomingPriority = sourcePriority[incoming.source] ?? 0;
      if (incomingPriority > existingPriority) return incoming;
      if (existingPriority > incomingPriority) return existing;
    }

    // Rule 2: For sleep, prefer record with detailed stages
    if (existing.metricType == MetricType.sleep) {
      final existingHasStages = existing.rawPayload?['stages'] != null &&
          (existing.rawPayload!['stages'] as Map).isNotEmpty;
      final incomingHasStages = incoming.rawPayload?['stages'] != null &&
          (incoming.rawPayload!['stages'] as Map).isNotEmpty;
      if (incomingHasStages && !existingHasStages) return incoming;
      if (existingHasStages && !incomingHasStages) return existing;
    }

    // Rule 3: Keep the most recent recordedAt
    if (incoming.recordedAt.isAfter(existing.recordedAt)) return incoming;
    return existing;
  }
}
