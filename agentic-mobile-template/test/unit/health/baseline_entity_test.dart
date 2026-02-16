import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/health/domain/baseline_entity.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

void main() {
  group('BaselineEntity', () {
    final baseTime = DateTime(2024, 1, 1);
    const profileId = 'test-profile-456';

    group('isCalibrationReady', () {
      test('should return false when captureEnd is null', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 15,
          captureStart: baseTime,
          captureEnd: null,
        );

        expect(baseline.isCalibrationReady(), false);
      });

      test('should return false when time span is less than 14 days', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 15,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 13)),
        );

        expect(baseline.isCalibrationReady(), false);
      });

      test('should return false when data points count is less than 10', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 9,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 14)),
        );

        expect(baseline.isCalibrationReady(), false);
      });

      test('should return false when both time span and data points are insufficient', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 5,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 7)),
        );

        expect(baseline.isCalibrationReady(), false);
      });

      test('should return true when time span is exactly 14 days and data points is exactly 10', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 10,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 14)),
        );

        expect(baseline.isCalibrationReady(), true);
      });

      test('should return true when time span is 14+ days and data points is 10+', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 15,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 20)),
        );

        expect(baseline.isCalibrationReady(), true);
      });

      test('should return true with 30 days of data and 25 data points', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.steps,
          dataPointsCount: 25,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 30)),
        );

        expect(baseline.isCalibrationReady(), true);
      });

      test('should return false when time span is sufficient but data points is 9', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.hr,
          dataPointsCount: 9,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 20)),
        );

        expect(baseline.isCalibrationReady(), false);
      });

      test('should return false when data points is sufficient but time span is 13 days', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.stress,
          dataPointsCount: 20,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 13)),
        );

        expect(baseline.isCalibrationReady(), false);
      });
    });

    group('toSupabaseJson', () {
      test('should produce correct JSON with all required fields', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 15,
          captureStart: baseTime,
        );

        final json = baseline.toSupabaseJson();

        expect(json['profile_id'], profileId);
        expect(json['metric_type'], 'sleep');
        expect(json['data_points_count'], 15);
        expect(json['capture_start'], baseTime.toIso8601String());
        expect(json['is_complete'], false);
        expect(json['calibration_status'], 'pending');
      });

      test('should include optional fields when provided', () {
        final captureEnd = baseTime.add(const Duration(days: 20));
        final baseline = BaselineEntity(
          id: 'test-baseline-123',
          profileId: profileId,
          metricType: MetricType.hr,
          baselineValue: 65.5,
          dataPointsCount: 25,
          captureStart: baseTime,
          captureEnd: captureEnd,
          isComplete: true,
          calibrationStatus: CalibrationStatus.complete,
          notes: 'Baseline computed successfully',
        );

        final json = baseline.toSupabaseJson();

        expect(json['id'], 'test-baseline-123');
        expect(json['baseline_value'], 65.5);
        expect(json['capture_end'], captureEnd.toIso8601String());
        expect(json['is_complete'], true);
        expect(json['calibration_status'], 'complete');
        expect(json['notes'], 'Baseline computed successfully');
      });

      test('should handle null optional fields correctly', () {
        final baseline = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.steps,
          dataPointsCount: 0,
          captureStart: baseTime,
        );

        final json = baseline.toSupabaseJson();

        expect(json.containsKey('id'), false);
        expect(json['baseline_value'], null);
        expect(json['capture_end'], null);
        expect(json['notes'], null);
      });
    });

    group('fromSupabaseJson', () {
      test('should create baseline from complete JSON', () {
        final captureEnd = baseTime.add(const Duration(days: 20));
        final json = {
          'id': 'baseline-id-789',
          'profile_id': profileId,
          'metric_type': 'sleep',
          'baseline_value': 450.5,
          'data_points_count': 20,
          'capture_start': baseTime.toIso8601String(),
          'capture_end': captureEnd.toIso8601String(),
          'is_complete': true,
          'calibration_status': 'complete',
          'notes': 'Test baseline',
        };

        final baseline = BaselineEntity.fromSupabaseJson(json);

        expect(baseline.id, 'baseline-id-789');
        expect(baseline.profileId, profileId);
        expect(baseline.metricType, MetricType.sleep);
        expect(baseline.baselineValue, 450.5);
        expect(baseline.dataPointsCount, 20);
        expect(baseline.captureStart, baseTime);
        expect(baseline.captureEnd, captureEnd);
        expect(baseline.isComplete, true);
        expect(baseline.calibrationStatus, CalibrationStatus.complete);
        expect(baseline.notes, 'Test baseline');
      });

      test('should handle missing optional fields with defaults', () {
        final json = {
          'profile_id': profileId,
          'metric_type': 'steps',
          'capture_start': baseTime.toIso8601String(),
        };

        final baseline = BaselineEntity.fromSupabaseJson(json);

        expect(baseline.id, null);
        expect(baseline.baselineValue, null);
        expect(baseline.dataPointsCount, 0);
        expect(baseline.captureEnd, null);
        expect(baseline.isComplete, false);
        expect(baseline.calibrationStatus, CalibrationStatus.pending);
        expect(baseline.notes, null);
      });

      test('should convert numeric baselineValue to double', () {
        final json = {
          'profile_id': profileId,
          'metric_type': 'hr',
          'baseline_value': 65, // int instead of double
          'data_points_count': 15,
          'capture_start': baseTime.toIso8601String(),
        };

        final baseline = BaselineEntity.fromSupabaseJson(json);

        expect(baseline.baselineValue, 65.0);
        expect(baseline.baselineValue, isA<double>());
      });
    });

    group('Roundtrip Serialization', () {
      test('should maintain all data through toJson -> fromJson cycle', () {
        final captureEnd = baseTime.add(const Duration(days: 30));
        final original = BaselineEntity(
          id: 'roundtrip-id-999',
          profileId: profileId,
          metricType: MetricType.vo2max,
          baselineValue: 55.5,
          dataPointsCount: 30,
          captureStart: baseTime,
          captureEnd: captureEnd,
          isComplete: true,
          calibrationStatus: CalibrationStatus.complete,
          notes: 'Roundtrip test baseline',
        );

        final json = original.toSupabaseJson();
        final restored = BaselineEntity.fromSupabaseJson(json);

        expect(restored.id, original.id);
        expect(restored.profileId, original.profileId);
        expect(restored.metricType, original.metricType);
        expect(restored.baselineValue, original.baselineValue);
        expect(restored.dataPointsCount, original.dataPointsCount);
        expect(restored.captureStart, original.captureStart);
        expect(restored.captureEnd, original.captureEnd);
        expect(restored.isComplete, original.isComplete);
        expect(restored.calibrationStatus, original.calibrationStatus);
        expect(restored.notes, original.notes);
      });

      test('should maintain minimal data through roundtrip', () {
        final original = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.stress,
          dataPointsCount: 0,
          captureStart: baseTime,
        );

        final json = original.toSupabaseJson();
        final restored = BaselineEntity.fromSupabaseJson(json);

        expect(restored.profileId, original.profileId);
        expect(restored.metricType, original.metricType);
        expect(restored.dataPointsCount, original.dataPointsCount);
        expect(restored.captureStart, original.captureStart);
        expect(restored.isComplete, original.isComplete);
        expect(restored.calibrationStatus, original.calibrationStatus);
      });
    });

    group('copyWith', () {
      test('should update only specified fields', () {
        final original = BaselineEntity(
          id: 'original-id',
          profileId: profileId,
          metricType: MetricType.sleep,
          baselineValue: 450.0,
          dataPointsCount: 15,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 15)),
          isComplete: false,
          calibrationStatus: CalibrationStatus.pending,
          notes: 'Original notes',
        );

        final updated = original.copyWith(
          baselineValue: 480.0,
          dataPointsCount: 20,
          isComplete: true,
        );

        expect(updated.id, original.id);
        expect(updated.profileId, original.profileId);
        expect(updated.metricType, original.metricType);
        expect(updated.baselineValue, 480.0);
        expect(updated.dataPointsCount, 20);
        expect(updated.captureStart, original.captureStart);
        expect(updated.captureEnd, original.captureEnd);
        expect(updated.isComplete, true);
        expect(updated.calibrationStatus, original.calibrationStatus);
        expect(updated.notes, original.notes);
      });

      test('should update all fields when all parameters provided', () {
        final original = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          dataPointsCount: 10,
          captureStart: baseTime,
        );

        final newCaptureEnd = baseTime.add(const Duration(days: 30));
        final updated = original.copyWith(
          id: 'new-id',
          profileId: 'new-profile',
          metricType: MetricType.hr,
          baselineValue: 70.0,
          dataPointsCount: 30,
          captureStart: baseTime.add(const Duration(days: 1)),
          captureEnd: newCaptureEnd,
          isComplete: true,
          calibrationStatus: CalibrationStatus.complete,
          notes: 'New notes',
        );

        expect(updated.id, 'new-id');
        expect(updated.profileId, 'new-profile');
        expect(updated.metricType, MetricType.hr);
        expect(updated.baselineValue, 70.0);
        expect(updated.dataPointsCount, 30);
        expect(updated.captureStart, baseTime.add(const Duration(days: 1)));
        expect(updated.captureEnd, newCaptureEnd);
        expect(updated.isComplete, true);
        expect(updated.calibrationStatus, CalibrationStatus.complete);
        expect(updated.notes, 'New notes');
      });

      test('should leave original unchanged', () {
        final original = BaselineEntity(
          profileId: profileId,
          metricType: MetricType.sleep,
          baselineValue: 450.0,
          dataPointsCount: 15,
          captureStart: baseTime,
        );

        final updated = original.copyWith(
          baselineValue: 500.0,
          dataPointsCount: 20,
        );

        expect(original.baselineValue, 450.0);
        expect(original.dataPointsCount, 15);
        expect(updated.baselineValue, 500.0);
        expect(updated.dataPointsCount, 20);
      });

      test('should create identical copy when no parameters provided', () {
        final original = BaselineEntity(
          id: 'test-id',
          profileId: profileId,
          metricType: MetricType.steps,
          baselineValue: 10000.0,
          dataPointsCount: 25,
          captureStart: baseTime,
          captureEnd: baseTime.add(const Duration(days: 25)),
          isComplete: true,
          calibrationStatus: CalibrationStatus.complete,
          notes: 'Test notes',
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.profileId, original.profileId);
        expect(copy.metricType, original.metricType);
        expect(copy.baselineValue, original.baselineValue);
        expect(copy.dataPointsCount, original.dataPointsCount);
        expect(copy.captureStart, original.captureStart);
        expect(copy.captureEnd, original.captureEnd);
        expect(copy.isComplete, original.isComplete);
        expect(copy.calibrationStatus, original.calibrationStatus);
        expect(copy.notes, original.notes);
      });
    });

    group('CalibrationStatus Enum', () {
      test('should serialize and deserialize all CalibrationStatus values', () {
        for (final status in CalibrationStatus.values) {
          final baseline = BaselineEntity(
            profileId: profileId,
            metricType: MetricType.sleep,
            dataPointsCount: 15,
            captureStart: baseTime,
            calibrationStatus: status,
          );

          final json = baseline.toSupabaseJson();
          final restored = BaselineEntity.fromSupabaseJson(json);

          expect(restored.calibrationStatus, status);
        }
      });
    });

    group('MetricType Integration', () {
      test('should handle all MetricType values in baseline entity', () {
        final relevantMetrics = [
          MetricType.sleep,
          MetricType.steps,
          MetricType.hr,
          MetricType.stress,
          MetricType.vo2max,
        ];

        for (final metricType in relevantMetrics) {
          final baseline = BaselineEntity(
            profileId: profileId,
            metricType: metricType,
            dataPointsCount: 15,
            captureStart: baseTime,
          );

          final json = baseline.toSupabaseJson();
          final restored = BaselineEntity.fromSupabaseJson(json);

          expect(restored.metricType, metricType);
        }
      });
    });
  });
}
