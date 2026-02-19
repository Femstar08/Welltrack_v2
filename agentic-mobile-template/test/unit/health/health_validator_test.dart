import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/health/data/health_validator.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

void main() {
  group('HealthValidator', () {
    final baseTime = DateTime(2024, 1, 15, 10, 0);
    const userId = 'test-user-123';
    const profileId = 'test-profile-456';

    HealthMetricEntity createMetric(MetricType type, double? value) {
      return HealthMetricEntity(
        userId: userId,
        profileId: profileId,
        source: HealthSource.healthconnect,
        metricType: type,
        valueNum: value,
        unit: 'test',
        startTime: baseTime,
        recordedAt: baseTime,
      );
    }

    group('Sleep Validation', () {
      test('should validate sleep duration at lower boundary (0 minutes)', () {
        final metric = createMetric(MetricType.sleep, 0);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate sleep duration in valid range (480 minutes)', () {
        final metric = createMetric(MetricType.sleep, 480);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate sleep duration at upper boundary (1440 minutes)', () {
        final metric = createMetric(MetricType.sleep, 1440);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject negative sleep duration', () {
        final metric = createMetric(MetricType.sleep, -1);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject sleep duration above 1440 minutes', () {
        final metric = createMetric(MetricType.sleep, 1441);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('Steps Validation', () {
      test('should validate steps at lower boundary (0)', () {
        final metric = createMetric(MetricType.steps, 0);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate steps in valid range (10000)', () {
        final metric = createMetric(MetricType.steps, 10000);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate steps at upper boundary (100000)', () {
        final metric = createMetric(MetricType.steps, 100000);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject negative steps', () {
        final metric = createMetric(MetricType.steps, -1);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject steps above 100000', () {
        final metric = createMetric(MetricType.steps, 100001);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('Heart Rate Validation', () {
      test('should validate heart rate at lower boundary (30 bpm)', () {
        final metric = createMetric(MetricType.hr, 30);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate heart rate in valid range (72 bpm)', () {
        final metric = createMetric(MetricType.hr, 72);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate heart rate at upper boundary (250 bpm)', () {
        final metric = createMetric(MetricType.hr, 250);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject heart rate below 30 bpm', () {
        final metric = createMetric(MetricType.hr, 29);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject heart rate above 250 bpm', () {
        final metric = createMetric(MetricType.hr, 251);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('Stress Validation', () {
      test('should validate stress at lower boundary (0)', () {
        final metric = createMetric(MetricType.stress, 0);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate stress in valid range (50)', () {
        final metric = createMetric(MetricType.stress, 50);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate stress at upper boundary (100)', () {
        final metric = createMetric(MetricType.stress, 100);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject negative stress', () {
        final metric = createMetric(MetricType.stress, -1);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject stress above 100', () {
        final metric = createMetric(MetricType.stress, 101);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('VO2 Max Validation', () {
      test('should validate VO2 max at lower boundary (10)', () {
        final metric = createMetric(MetricType.vo2max, 10);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate VO2 max in valid range (45)', () {
        final metric = createMetric(MetricType.vo2max, 45);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate VO2 max at upper boundary (90)', () {
        final metric = createMetric(MetricType.vo2max, 90);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject VO2 max below 10', () {
        final metric = createMetric(MetricType.vo2max, 9);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject VO2 max above 90', () {
        final metric = createMetric(MetricType.vo2max, 91);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('SpO2 Validation', () {
      test('should validate SpO2 at lower boundary (70%)', () {
        final metric = createMetric(MetricType.spo2, 70);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate SpO2 in valid range (98%)', () {
        final metric = createMetric(MetricType.spo2, 98);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate SpO2 at upper boundary (100%)', () {
        final metric = createMetric(MetricType.spo2, 100);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject SpO2 below 70%', () {
        final metric = createMetric(MetricType.spo2, 69);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject SpO2 above 100%', () {
        final metric = createMetric(MetricType.spo2, 101);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('HRV Validation', () {
      test('should validate HRV at lower boundary (0 ms)', () {
        final metric = createMetric(MetricType.hrv, 0);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate HRV in valid range (50 ms)', () {
        final metric = createMetric(MetricType.hrv, 50);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate HRV at upper boundary (300 ms)', () {
        final metric = createMetric(MetricType.hrv, 300);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject negative HRV', () {
        final metric = createMetric(MetricType.hrv, -1);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject HRV above 300 ms', () {
        final metric = createMetric(MetricType.hrv, 301);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('Null Value Validation', () {
      test('should reject metric with null valueNum for sleep', () {
        final metric = createMetric(MetricType.sleep, null);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject metric with null valueNum for steps', () {
        final metric = createMetric(MetricType.steps, null);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject metric with null valueNum for heart rate', () {
        final metric = createMetric(MetricType.hr, null);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      test('should reject metric with null valueNum for stress', () {
        final metric = createMetric(MetricType.stress, null);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });
    });

    group('Additional Metric Types', () {
      test('should validate weight in valid range', () {
        final metric = createMetric(MetricType.weight, 75);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should reject weight below minimum', () {
        final metric = createMetric(MetricType.weight, 19);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.rejected,
        );
      });

      // test('should validate body fat percentage in valid range', () {
      //   final metric = createMetric(MetricType.bodyFat, 15);
      //   expect(
      //     HealthValidator.validateMetric(metric),
      //     ValidationStatus.validated,
      //   );
      // });
      //
      // test('should reject body fat percentage above maximum', () {
      //   final metric = createMetric(MetricType.bodyFat, 71);
      //   expect(
      //     HealthValidator.validateMetric(metric),
      //     ValidationStatus.rejected,
      //   );
      // });

      test('should validate calories in valid range', () {
        final metric = createMetric(MetricType.calories, 2500);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate distance in valid range', () {
        final metric = createMetric(MetricType.distance, 10000);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      test('should validate active minutes in valid range', () {
        final metric = createMetric(MetricType.activeMinutes, 60);
        expect(
          HealthValidator.validateMetric(metric),
          ValidationStatus.validated,
        );
      });

      // test('should validate blood pressure in valid range', () {
      //   final metric = createMetric(MetricType.bloodPressure, 120);
      //   expect(
      //     HealthValidator.validateMetric(metric),
      //     ValidationStatus.validated,
      //   );
      // });
    });
  });
}
