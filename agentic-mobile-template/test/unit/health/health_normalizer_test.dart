import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/health/data/health_normalizer.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

void main() {
  group('HealthNormalizer.resolveConflict', () {
    final baseTime = DateTime(2024, 1, 15, 10, 0);
    final userId = 'test-user-123';
    final profileId = 'test-profile-456';

    group('Source Priority', () {
      test('should prefer Garmin over all other sources', () {
        final garminMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.garmin,
          metricType: MetricType.sleep,
          valueNum: 480.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final stravaMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.strava,
          metricType: MetricType.sleep,
          valueNum: 420.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final result = HealthNormalizer.resolveConflict(stravaMetric, garminMetric);
        expect(result.source, HealthSource.garmin);
        expect(result.valueNum, 480.0);
      });

      test('should prefer Strava over HealthConnect', () {
        final stravaMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.strava,
          metricType: MetricType.steps,
          valueNum: 12000.0,
          unit: 'count',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final healthConnectMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.steps,
          valueNum: 10000.0,
          unit: 'count',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final result = HealthNormalizer.resolveConflict(
          healthConnectMetric,
          stravaMetric,
        );
        expect(result.source, HealthSource.strava);
        expect(result.valueNum, 12000.0);
      });

      test('should prefer HealthConnect over HealthKit', () {
        final healthConnectMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.hr,
          valueNum: 65.0,
          unit: 'bpm',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final healthKitMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthkit,
          metricType: MetricType.hr,
          valueNum: 68.0,
          unit: 'bpm',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final result = HealthNormalizer.resolveConflict(
          healthKitMetric,
          healthConnectMetric,
        );
        expect(result.source, HealthSource.healthconnect);
        expect(result.valueNum, 65.0);
      });

      test('should prefer HealthKit over Manual', () {
        final healthKitMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthkit,
          metricType: MetricType.weight,
          valueNum: 75.0,
          unit: 'kg',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final manualMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.manual,
          metricType: MetricType.weight,
          valueNum: 76.0,
          unit: 'kg',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final result = HealthNormalizer.resolveConflict(manualMetric, healthKitMetric);
        expect(result.source, HealthSource.healthkit);
        expect(result.valueNum, 75.0);
      });
    });

    group('Sleep Stage Data Priority', () {
      test('should prefer sleep record with stage data over one without', () {
        final withStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.sleep,
          valueNum: 480.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: {
            'stages': {'deep': 120, 'light': 240, 'rem': 120},
          },
        );

        final withoutStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.sleep,
          valueNum: 480.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: {},
        );

        final result = HealthNormalizer.resolveConflict(withoutStages, withStages);
        expect(result.rawPayload?['stages'], isNotNull);
        expect(result.rawPayload?['stages'], isNotEmpty);
      });

      test('should prefer sleep record with stage data when existing has null payload', () {
        final withStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthkit,
          metricType: MetricType.sleep,
          valueNum: 420.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: {
            'stages': {'awake': 30, 'core': 300, 'rem': 90},
          },
        );

        final withoutStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthkit,
          metricType: MetricType.sleep,
          valueNum: 420.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: null,
        );

        final result = HealthNormalizer.resolveConflict(withoutStages, withStages);
        expect(result.rawPayload?['stages'], isNotNull);
      });

      test('should not apply stage priority to non-sleep metrics', () {
        final hrWithPayload = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.hr,
          valueNum: 65.0,
          unit: 'bpm',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: {'stages': {'test': 100}},
        );

        final hrWithoutPayload = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.hr,
          valueNum: 68.0,
          unit: 'bpm',
          startTime: baseTime,
          recordedAt: baseTime.add(const Duration(minutes: 1)),
          rawPayload: null,
        );

        // Should use recordedAt time priority, not stage data
        final result = HealthNormalizer.resolveConflict(hrWithPayload, hrWithoutPayload);
        expect(result.valueNum, 68.0); // More recent one wins
      });
    });

    group('RecordedAt Time Priority', () {
      test('should prefer more recent recordedAt when same source', () {
        final olderMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.steps,
          valueNum: 8000.0,
          unit: 'count',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final newerMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.steps,
          valueNum: 10000.0,
          unit: 'count',
          startTime: baseTime,
          recordedAt: baseTime.add(const Duration(hours: 1)),
        );

        final result = HealthNormalizer.resolveConflict(olderMetric, newerMetric);
        expect(result.valueNum, 10000.0);
        expect(result.recordedAt, newerMetric.recordedAt);
      });

      test('should prefer older recordedAt when newer is not more recent', () {
        final newerMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.manual,
          metricType: MetricType.weight,
          valueNum: 80.0,
          unit: 'kg',
          startTime: baseTime,
          recordedAt: baseTime.add(const Duration(hours: 2)),
        );

        final olderMetric = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.manual,
          metricType: MetricType.weight,
          valueNum: 78.0,
          unit: 'kg',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final result = HealthNormalizer.resolveConflict(newerMetric, olderMetric);
        expect(result.valueNum, 80.0);
        expect(result.recordedAt, newerMetric.recordedAt);
      });
    });

    group('Combined Priority Rules', () {
      test('should apply source priority before recordedAt time', () {
        final garminOlder = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.garmin,
          metricType: MetricType.stress,
          valueNum: 45.0,
          unit: 'score',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final manualNewer = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.manual,
          metricType: MetricType.stress,
          valueNum: 50.0,
          unit: 'score',
          startTime: baseTime,
          recordedAt: baseTime.add(const Duration(hours: 5)),
        );

        final result = HealthNormalizer.resolveConflict(manualNewer, garminOlder);
        expect(result.source, HealthSource.garmin);
        expect(result.valueNum, 45.0);
      });

      test('should apply stage priority after source priority for sleep', () {
        final sleepWithoutStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.sleep,
          valueNum: 450.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime.add(const Duration(hours: 1)),
          rawPayload: {},
        );

        final sleepWithStages = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.sleep,
          valueNum: 460.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
          rawPayload: {
            'stages': {'deep': 100, 'light': 250, 'rem': 110},
          },
        );

        final result = HealthNormalizer.resolveConflict(
          sleepWithoutStages,
          sleepWithStages,
        );
        expect(result.rawPayload?['stages'], isNotNull);
        expect(result.valueNum, 460.0);
      });
    });
  });
}
