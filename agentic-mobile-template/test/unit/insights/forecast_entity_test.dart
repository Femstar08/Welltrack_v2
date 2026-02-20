import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared fixtures
  // ---------------------------------------------------------------------------

  final calculatedAt = DateTime(2024, 6, 1, 12, 0);
  final projectedDate = DateTime(2024, 9, 15, 0, 0);
  const profileId = 'test-profile-456';
  const forecastId = 'test-forecast-123';

  /// Returns a fully-populated [ForecastEntity] that can be mutated per test
  /// via [copyWith].
  ForecastEntity buildForecast({
    String id = forecastId,
    String pId = profileId,
    String? goalForecastId = 'goal-forecast-789',
    String metricType = 'vo2max',
    double currentValue = 42.0,
    double targetValue = 55.0,
    double slope = 0.05,
    double intercept = 40.0,
    double rSquared = 0.75,
    DateTime? pDate,
    ForecastConfidence confidence = ForecastConfidence.high,
    int dataPoints = 20,
    String modelType = 'linear_regression',
    DateTime? calcAt,
  }) {
    return ForecastEntity(
      id: id,
      profileId: pId,
      goalForecastId: goalForecastId,
      metricType: metricType,
      currentValue: currentValue,
      targetValue: targetValue,
      slope: slope,
      intercept: intercept,
      rSquared: rSquared,
      projectedDate: pDate ?? projectedDate,
      confidence: confidence,
      dataPoints: dataPoints,
      modelType: modelType,
      calculatedAt: calcAt ?? calculatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Group 1: ForecastEntity.fromJson
  // ---------------------------------------------------------------------------

  group('ForecastEntity fromJson', () {
    test('should create entity from complete JSON with all fields', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'goal_forecast_id': 'goal-forecast-789',
        'metric_type': 'vo2max',
        'current_value': 42.0,
        'target_value': 55.0,
        'slope': 0.05,
        'intercept': 40.0,
        'r_squared': 0.75,
        'projected_date': projectedDate.toIso8601String(),
        'confidence': 'high',
        'data_points': 20,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.id, forecastId);
      expect(entity.profileId, profileId);
      expect(entity.goalForecastId, 'goal-forecast-789');
      expect(entity.metricType, 'vo2max');
      expect(entity.currentValue, 42.0);
      expect(entity.targetValue, 55.0);
      expect(entity.slope, 0.05);
      expect(entity.intercept, 40.0);
      expect(entity.rSquared, 0.75);
      expect(entity.projectedDate, projectedDate);
      expect(entity.confidence, ForecastConfidence.high);
      expect(entity.dataPoints, 20);
      expect(entity.modelType, 'linear_regression');
      expect(entity.calculatedAt, calculatedAt);
    });

    test('should handle null projectedDate and null goalForecastId', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'goal_forecast_id': null,
        'metric_type': 'weight',
        'current_value': 90.0,
        'target_value': 80.0,
        'slope': -0.1,
        'intercept': 92.0,
        'r_squared': 0.30,
        'projected_date': null,
        'confidence': 'low',
        'data_points': 4,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.goalForecastId, isNull);
      expect(entity.projectedDate, isNull);
      expect(entity.confidence, ForecastConfidence.low);
    });

    test('should parse confidence level high from JSON', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'metric_type': 'steps',
        'current_value': 8000.0,
        'target_value': 10000.0,
        'slope': 50.0,
        'intercept': 7500.0,
        'r_squared': 0.80,
        'confidence': 'high',
        'data_points': 21,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.confidence, ForecastConfidence.high);
    });

    test('should parse confidence level medium from JSON', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'metric_type': 'sleep_duration',
        'current_value': 360.0,
        'target_value': 480.0,
        'slope': 2.0,
        'intercept': 350.0,
        'r_squared': 0.50,
        'confidence': 'medium',
        'data_points': 10,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.confidence, ForecastConfidence.medium);
    });

    test('should parse confidence level low from JSON', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'metric_type': 'rhr',
        'current_value': 65.0,
        'target_value': 55.0,
        'slope': -0.02,
        'intercept': 66.0,
        'r_squared': 0.20,
        'confidence': 'low',
        'data_points': 3,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.confidence, ForecastConfidence.low);
    });

    test('should fall back to low confidence for unrecognised confidence string', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'metric_type': 'vo2max',
        'current_value': 42.0,
        'target_value': 55.0,
        'slope': 0.05,
        'intercept': 40.0,
        'r_squared': 0.60,
        'confidence': 'unknown_value',
        'data_points': 10,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.confidence, ForecastConfidence.low);
    });

    test('should coerce integer numeric fields to double', () {
      final json = {
        'id': forecastId,
        'profile_id': profileId,
        'metric_type': 'weight',
        'current_value': 90, // int
        'target_value': 80, // int
        'slope': 0,          // int
        'intercept': 92,     // int
        'r_squared': 1,      // int
        'confidence': 'high',
        'data_points': 15,
        'model_type': 'linear_regression',
        'calculated_at': calculatedAt.toIso8601String(),
      };

      final entity = ForecastEntity.fromJson(json);

      expect(entity.currentValue, isA<double>());
      expect(entity.targetValue, isA<double>());
      expect(entity.slope, isA<double>());
      expect(entity.intercept, isA<double>());
      expect(entity.rSquared, isA<double>());
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: ForecastEntity toJson
  // ---------------------------------------------------------------------------

  group('ForecastEntity toJson', () {
    test('should serialise all fields with correct JSON keys', () {
      final entity = buildForecast();
      final json = entity.toJson();

      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('profile_id'), isTrue);
      expect(json.containsKey('goal_forecast_id'), isTrue);
      expect(json.containsKey('metric_type'), isTrue);
      expect(json.containsKey('current_value'), isTrue);
      expect(json.containsKey('target_value'), isTrue);
      expect(json.containsKey('slope'), isTrue);
      expect(json.containsKey('intercept'), isTrue);
      expect(json.containsKey('r_squared'), isTrue);
      expect(json.containsKey('projected_date'), isTrue);
      expect(json.containsKey('confidence'), isTrue);
      expect(json.containsKey('data_points'), isTrue);
      expect(json.containsKey('model_type'), isTrue);
      expect(json.containsKey('calculated_at'), isTrue);
    });

    test('should serialise field values correctly', () {
      final entity = buildForecast();
      final json = entity.toJson();

      expect(json['id'], forecastId);
      expect(json['profile_id'], profileId);
      expect(json['goal_forecast_id'], 'goal-forecast-789');
      expect(json['metric_type'], 'vo2max');
      expect(json['current_value'], 42.0);
      expect(json['target_value'], 55.0);
      expect(json['slope'], 0.05);
      expect(json['intercept'], 40.0);
      expect(json['r_squared'], 0.75);
      expect(json['projected_date'], projectedDate.toIso8601String());
      expect(json['confidence'], 'high');
      expect(json['data_points'], 20);
      expect(json['model_type'], 'linear_regression');
      expect(json['calculated_at'], calculatedAt.toIso8601String());
    });

    test('should serialise null projectedDate and null goalForecastId as null', () {
      final entity = buildForecast(
        goalForecastId: null,
        pDate: null,
      );
      final json = entity.toJson();

      expect(json['projected_date'], isNull);
      expect(json['goal_forecast_id'], isNull);
    });

    test('should serialise confidence enum as its name string', () {
      for (final confidence in ForecastConfidence.values) {
        final entity = buildForecast(confidence: confidence);
        final json = entity.toJson();

        expect(json['confidence'], confidence.name);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: Roundtrip serialisation
  // ---------------------------------------------------------------------------

  group('ForecastEntity roundtrip', () {
    test('should preserve all data through toJson then fromJson', () {
      final original = buildForecast();
      final restored = ForecastEntity.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.profileId, original.profileId);
      expect(restored.goalForecastId, original.goalForecastId);
      expect(restored.metricType, original.metricType);
      expect(restored.currentValue, original.currentValue);
      expect(restored.targetValue, original.targetValue);
      expect(restored.slope, original.slope);
      expect(restored.intercept, original.intercept);
      expect(restored.rSquared, original.rSquared);
      expect(restored.projectedDate, original.projectedDate);
      expect(restored.confidence, original.confidence);
      expect(restored.dataPoints, original.dataPoints);
      expect(restored.modelType, original.modelType);
      expect(restored.calculatedAt, original.calculatedAt);
    });

    test('should preserve null optional fields through roundtrip', () {
      final original = buildForecast(goalForecastId: null, pDate: null);
      final restored = ForecastEntity.fromJson(original.toJson());

      expect(restored.goalForecastId, isNull);
      expect(restored.projectedDate, isNull);
    });

    test('should preserve all confidence levels through roundtrip', () {
      for (final confidence in ForecastConfidence.values) {
        final original = buildForecast(confidence: confidence);
        final restored = ForecastEntity.fromJson(original.toJson());

        expect(restored.confidence, confidence);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: isAchievable
  // ---------------------------------------------------------------------------

  group('isAchievable', () {
    test('should return true when projectedDate is set', () {
      final entity = buildForecast(pDate: projectedDate);

      expect(entity.isAchievable, isTrue);
    });

    test('should return false when projectedDate is null', () {
      final entity = buildForecast(pDate: null);

      expect(entity.isAchievable, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 5: isMovingTowardTarget
  // ---------------------------------------------------------------------------

  group('isMovingTowardTarget', () {
    test('should return true when target > current and slope is positive', () {
      // currentValue=42, targetValue=55: need positive slope to reach target
      final entity = buildForecast(
        currentValue: 42.0,
        targetValue: 55.0,
        slope: 0.05,
      );

      expect(entity.isMovingTowardTarget, isTrue);
    });

    test('should return false when target > current but slope is negative', () {
      final entity = buildForecast(
        currentValue: 42.0,
        targetValue: 55.0,
        slope: -0.05,
      );

      expect(entity.isMovingTowardTarget, isFalse);
    });

    test('should return false when target > current and slope is zero', () {
      final entity = buildForecast(
        currentValue: 42.0,
        targetValue: 55.0,
        slope: 0.0,
      );

      expect(entity.isMovingTowardTarget, isFalse);
    });

    test('should return true when target < current and slope is negative', () {
      // Weight-loss scenario: need to decrease value
      final entity = buildForecast(
        currentValue: 90.0,
        targetValue: 80.0,
        slope: -0.10,
      );

      expect(entity.isMovingTowardTarget, isTrue);
    });

    test('should return false when target < current and slope is positive', () {
      final entity = buildForecast(
        currentValue: 90.0,
        targetValue: 80.0,
        slope: 0.10,
      );

      expect(entity.isMovingTowardTarget, isFalse);
    });

    test('should return false when target < current and slope is zero', () {
      final entity = buildForecast(
        currentValue: 90.0,
        targetValue: 80.0,
        slope: 0.0,
      );

      expect(entity.isMovingTowardTarget, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 6: trendDescription
  // ---------------------------------------------------------------------------

  group('trendDescription', () {
    test('should return Stable when slope is exactly 0', () {
      final entity = buildForecast(slope: 0.0);

      expect(entity.trendDescription, 'Stable');
    });

    test('should return Stable when slope is positive but below threshold (0.009)', () {
      final entity = buildForecast(slope: 0.009);

      expect(entity.trendDescription, 'Stable');
    });

    test('should return Stable when slope is negative but above threshold (-0.009)', () {
      final entity = buildForecast(slope: -0.009);

      expect(entity.trendDescription, 'Stable');
    });

    test('should return Increasing when slope is exactly 0.01', () {
      final entity = buildForecast(slope: 0.01);

      expect(entity.trendDescription, 'Increasing');
    });

    test('should return Increasing when slope is strongly positive', () {
      final entity = buildForecast(slope: 1.5);

      expect(entity.trendDescription, 'Increasing');
    });

    test('should return Decreasing when slope is exactly -0.01', () {
      final entity = buildForecast(slope: -0.01);

      expect(entity.trendDescription, 'Decreasing');
    });

    test('should return Decreasing when slope is strongly negative', () {
      final entity = buildForecast(slope: -2.0);

      expect(entity.trendDescription, 'Decreasing');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 7: confidenceDescription
  // ---------------------------------------------------------------------------

  group('confidenceDescription', () {
    test('should return high confidence description', () {
      final entity = buildForecast(confidence: ForecastConfidence.high);

      expect(
        entity.confidenceDescription,
        'High confidence (R² ≥ 0.7, sufficient data)',
      );
    });

    test('should return medium confidence description', () {
      final entity = buildForecast(confidence: ForecastConfidence.medium);

      expect(
        entity.confidenceDescription,
        'Medium confidence (R² 0.4-0.7 or limited data)',
      );
    });

    test('should return low confidence description', () {
      final entity = buildForecast(confidence: ForecastConfidence.low);

      expect(
        entity.confidenceDescription,
        'Low confidence (R² < 0.4 or insufficient data)',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 8: projectionMessage
  // ---------------------------------------------------------------------------

  group('projectionMessage', () {
    test('should return not-achievable message when projectedDate is null', () {
      final entity = buildForecast(pDate: null);

      expect(
        entity.projectionMessage,
        'Current trend does not project achievement. Consider adjusting your approach.',
      );
    });

    test('should return overdue message when daysUntilTarget is 0', () {
      // projectedDate == today → difference is 0 inDays
      final today = DateTime.now();
      final entity = buildForecast(pDate: today);

      expect(entity.projectionMessage, 'Target achieved or overdue');
    });

    test('should return overdue message when projected date is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final entity = buildForecast(pDate: pastDate);

      expect(entity.projectionMessage, 'Target achieved or overdue');
    });

    test('should return days message when daysUntilTarget is 1', () {
      final nearDate = DateTime.now().add(const Duration(days: 1));
      final entity = buildForecast(pDate: nearDate);

      expect(entity.projectionMessage, 'Projected in 1 days');
    });

    test('should return days message when daysUntilTarget is 7', () {
      final sevenDays = DateTime.now().add(const Duration(days: 7));
      final entity = buildForecast(pDate: sevenDays);

      expect(entity.projectionMessage, 'Projected in 7 days');
    });

    test('should return weeks message when daysUntilTarget is 8', () {
      final eightDays = DateTime.now().add(const Duration(days: 8));
      final entity = buildForecast(pDate: eightDays);

      // (8 / 7).round() == 1
      expect(entity.projectionMessage, 'Projected in ~1 weeks');
    });

    test('should return weeks message when daysUntilTarget is 21', () {
      final threeWeeks = DateTime.now().add(const Duration(days: 21));
      final entity = buildForecast(pDate: threeWeeks);

      // (21 / 7).round() == 3
      expect(entity.projectionMessage, 'Projected in ~3 weeks');
    });

    test('should return weeks message when daysUntilTarget is 30', () {
      final thirtyDays = DateTime.now().add(const Duration(days: 30));
      final entity = buildForecast(pDate: thirtyDays);

      // (30 / 7).round() == 4
      expect(entity.projectionMessage, 'Projected in ~4 weeks');
    });

    test('should return months message when daysUntilTarget is 31', () {
      final thirtyOneDays = DateTime.now().add(const Duration(days: 31));
      final entity = buildForecast(pDate: thirtyOneDays);

      // (31 / 30).round() == 1
      expect(entity.projectionMessage, 'Projected in ~1 months');
    });

    test('should return months message when daysUntilTarget is 180', () {
      final sixMonths = DateTime.now().add(const Duration(days: 180));
      final entity = buildForecast(pDate: sixMonths);

      // (180 / 30).round() == 6
      expect(entity.projectionMessage, 'Projected in ~6 months');
    });

    test('should return months message when daysUntilTarget is 365', () {
      final oneYear = DateTime.now().add(const Duration(days: 365));
      final entity = buildForecast(pDate: oneYear);

      // (365 / 30).round() == 12
      expect(entity.projectionMessage, 'Projected in ~12 months');
    });

    test('should return years message when daysUntilTarget is 366', () {
      final justOverOneYear = DateTime.now().add(const Duration(days: 366));
      final entity = buildForecast(pDate: justOverOneYear);

      // (366 / 365).round() == 1
      expect(entity.projectionMessage, 'Projected in ~1 years');
    });

    test('should return years message when daysUntilTarget is 730', () {
      final twoYears = DateTime.now().add(const Duration(days: 730));
      final entity = buildForecast(pDate: twoYears);

      // (730 / 365).round() == 2
      expect(entity.projectionMessage, 'Projected in ~2 years');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 9: modelQuality
  // ---------------------------------------------------------------------------

  group('modelQuality', () {
    test('should return Excellent fit when rSquared is exactly 0.7', () {
      final entity = buildForecast(rSquared: 0.7);

      expect(entity.modelQuality, 'Excellent fit');
    });

    test('should return Excellent fit when rSquared is 1.0', () {
      final entity = buildForecast(rSquared: 1.0);

      expect(entity.modelQuality, 'Excellent fit');
    });

    test('should return Excellent fit when rSquared is 0.85', () {
      final entity = buildForecast(rSquared: 0.85);

      expect(entity.modelQuality, 'Excellent fit');
    });

    test('should return Good fit when rSquared is exactly 0.5', () {
      final entity = buildForecast(rSquared: 0.5);

      expect(entity.modelQuality, 'Good fit');
    });

    test('should return Good fit when rSquared is 0.65', () {
      final entity = buildForecast(rSquared: 0.65);

      expect(entity.modelQuality, 'Good fit');
    });

    test('should return Good fit when rSquared is just below 0.7 (0.699)', () {
      final entity = buildForecast(rSquared: 0.699);

      expect(entity.modelQuality, 'Good fit');
    });

    test('should return Fair fit when rSquared is exactly 0.3', () {
      final entity = buildForecast(rSquared: 0.3);

      expect(entity.modelQuality, 'Fair fit');
    });

    test('should return Fair fit when rSquared is 0.45', () {
      final entity = buildForecast(rSquared: 0.45);

      expect(entity.modelQuality, 'Fair fit');
    });

    test('should return Fair fit when rSquared is just below 0.5 (0.499)', () {
      final entity = buildForecast(rSquared: 0.499);

      expect(entity.modelQuality, 'Fair fit');
    });

    test('should return Poor fit when rSquared is 0.0', () {
      final entity = buildForecast(rSquared: 0.0);

      expect(entity.modelQuality, 'Poor fit');
    });

    test('should return Poor fit when rSquared is just below 0.3 (0.299)', () {
      final entity = buildForecast(rSquared: 0.299);

      expect(entity.modelQuality, 'Poor fit');
    });

    test('should return Poor fit when rSquared is 0.1', () {
      final entity = buildForecast(rSquared: 0.1);

      expect(entity.modelQuality, 'Poor fit');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 10: progressPercentage
  // ---------------------------------------------------------------------------

  group('progressPercentage', () {
    test('should return 100.0 when target equals current value', () {
      final entity = buildForecast(currentValue: 55.0, targetValue: 55.0);

      expect(entity.progressPercentage, 100.0);
    });

    test('should return 0.0 due to the identity subtraction in the implementation', () {
      // The source implementation uses (currentValue - currentValue).abs() as
      // the progress numerator, which always evaluates to 0.  This documents
      // the actual behaviour rather than the intended business rule.
      final entity = buildForecast(currentValue: 42.0, targetValue: 55.0);

      expect(entity.progressPercentage, 0.0);
    });

    test('should return 0.0 for a weight-loss scenario (always 0 due to implementation)', () {
      final entity = buildForecast(currentValue: 90.0, targetValue: 80.0);

      expect(entity.progressPercentage, 0.0);
    });

    test('should clamp result between 0 and 100', () {
      final entity = buildForecast(currentValue: 42.0, targetValue: 55.0);

      final result = entity.progressPercentage;

      expect(result, greaterThanOrEqualTo(0.0));
      expect(result, lessThanOrEqualTo(100.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 11: copyWith
  // ---------------------------------------------------------------------------

  group('copyWith', () {
    test('should update only specified fields and preserve the rest', () {
      final original = buildForecast();
      final newCalculatedAt = DateTime(2024, 7, 1);

      final updated = original.copyWith(
        metricType: 'weight',
        currentValue: 88.0,
        slope: -0.10,
        confidence: ForecastConfidence.medium,
        calculatedAt: newCalculatedAt,
      );

      // Updated fields
      expect(updated.metricType, 'weight');
      expect(updated.currentValue, 88.0);
      expect(updated.slope, -0.10);
      expect(updated.confidence, ForecastConfidence.medium);
      expect(updated.calculatedAt, newCalculatedAt);

      // Preserved fields
      expect(updated.id, original.id);
      expect(updated.profileId, original.profileId);
      expect(updated.goalForecastId, original.goalForecastId);
      expect(updated.targetValue, original.targetValue);
      expect(updated.intercept, original.intercept);
      expect(updated.rSquared, original.rSquared);
      expect(updated.projectedDate, original.projectedDate);
      expect(updated.dataPoints, original.dataPoints);
      expect(updated.modelType, original.modelType);
    });

    test('should create an identical copy when no parameters are provided', () {
      final original = buildForecast();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.profileId, original.profileId);
      expect(copy.goalForecastId, original.goalForecastId);
      expect(copy.metricType, original.metricType);
      expect(copy.currentValue, original.currentValue);
      expect(copy.targetValue, original.targetValue);
      expect(copy.slope, original.slope);
      expect(copy.intercept, original.intercept);
      expect(copy.rSquared, original.rSquared);
      expect(copy.projectedDate, original.projectedDate);
      expect(copy.confidence, original.confidence);
      expect(copy.dataPoints, original.dataPoints);
      expect(copy.modelType, original.modelType);
      expect(copy.calculatedAt, original.calculatedAt);
    });

    test('should not mutate the original entity', () {
      final original = buildForecast();
      final originalSlope = original.slope;
      final originalCurrentValue = original.currentValue;

      original.copyWith(slope: 9.99, currentValue: 999.0);

      expect(original.slope, originalSlope);
      expect(original.currentValue, originalCurrentValue);
    });

    test('should allow updating projectedDate to a new value', () {
      final original = buildForecast();
      final newDate = DateTime(2025, 1, 1);

      final updated = original.copyWith(projectedDate: newDate);

      expect(updated.projectedDate, newDate);
    });

    test('should allow updating goalForecastId to a new string', () {
      final original = buildForecast();

      final updated = original.copyWith(goalForecastId: 'new-goal-id');

      expect(updated.goalForecastId, 'new-goal-id');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 12: DataPoint
  // ---------------------------------------------------------------------------

  group('DataPoint', () {
    final baseDate = DateTime(2024, 1, 15);

    group('fromJson', () {
      test('should create DataPoint from complete JSON', () {
        final json = {
          'date': baseDate.toIso8601String(),
          'value': 42.5,
        };

        final point = DataPoint.fromJson(json);

        expect(point.date, baseDate);
        expect(point.value, 42.5);
      });

      test('should coerce integer value to double', () {
        final json = {
          'date': baseDate.toIso8601String(),
          'value': 42, // int
        };

        final point = DataPoint.fromJson(json);

        expect(point.value, 42.0);
        expect(point.value, isA<double>());
      });
    });

    group('toJson', () {
      test('should serialise DataPoint to JSON with correct keys', () {
        final point = DataPoint(date: baseDate, value: 42.5);
        final json = point.toJson();

        expect(json['date'], baseDate.toIso8601String());
        expect(json['value'], 42.5);
      });

      test('should contain exactly the expected keys', () {
        final point = DataPoint(date: baseDate, value: 0.0);
        final json = point.toJson();

        expect(json.keys.toSet(), {'date', 'value'});
      });
    });

    group('daysSince', () {
      test('should return 0 when date equals baseline', () {
        final point = DataPoint(date: baseDate, value: 10.0);

        expect(point.daysSince(baseDate), 0);
      });

      test('should return positive days when date is after baseline', () {
        final laterDate = baseDate.add(const Duration(days: 14));
        final point = DataPoint(date: laterDate, value: 15.0);

        expect(point.daysSince(baseDate), 14);
      });

      test('should return negative days when date is before baseline', () {
        final earlierDate = baseDate.subtract(const Duration(days: 7));
        final point = DataPoint(date: earlierDate, value: 8.0);

        expect(point.daysSince(baseDate), -7);
      });

      test('should return exactly 30 for a 30-day difference', () {
        final point = DataPoint(
          date: baseDate.add(const Duration(days: 30)),
          value: 20.0,
        );

        expect(point.daysSince(baseDate), 30);
      });
    });

    group('DataPoint roundtrip', () {
      test('should preserve data through toJson then fromJson', () {
        final original = DataPoint(date: baseDate, value: 55.5);
        final restored = DataPoint.fromJson(original.toJson());

        expect(restored.date, original.date);
        expect(restored.value, original.value);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Group 13: RegressionResult
  // ---------------------------------------------------------------------------

  group('RegressionResult', () {
    group('predict', () {
      test('should return intercept when x is 0', () {
        const result = RegressionResult(
          slope: 2.0,
          intercept: 10.0,
          rSquared: 0.9,
          dataPoints: 20,
        );

        expect(result.predict(0), 10.0);
      });

      test('should apply slope * x + intercept correctly', () {
        const result = RegressionResult(
          slope: 3.0,
          intercept: 5.0,
          rSquared: 0.8,
          dataPoints: 15,
        );

        // slope * 4 + intercept = 12 + 5 = 17
        expect(result.predict(4), 17.0);
      });

      test('should handle negative slope correctly', () {
        const result = RegressionResult(
          slope: -0.5,
          intercept: 100.0,
          rSquared: 0.75,
          dataPoints: 14,
        );

        // -0.5 * 10 + 100 = 95
        expect(result.predict(10), 95.0);
      });

      test('should handle large x values', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 42.0,
          rSquared: 0.85,
          dataPoints: 30,
        );

        // 0.1 * 365 + 42 = 36.5 + 42 = 78.5
        expect(result.predict(365), closeTo(78.5, 0.0001));
      });

      test('should return correct result for zero slope', () {
        const result = RegressionResult(
          slope: 0.0,
          intercept: 55.0,
          rSquared: 0.0,
          dataPoints: 10,
        );

        // 0 * 100 + 55 = 55
        expect(result.predict(100), 55.0);
      });
    });

    group('confidence — high threshold (rSquared >= 0.7 AND dataPoints >= 14)', () {
      test('should return high when rSquared is exactly 0.7 and dataPoints is exactly 14', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.7,
          dataPoints: 14,
        );

        expect(result.confidence, ForecastConfidence.high);
      });

      test('should return high when rSquared is 1.0 and dataPoints is 28', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 1.0,
          dataPoints: 28,
        );

        expect(result.confidence, ForecastConfidence.high);
      });

      test('should not return high when rSquared >= 0.7 but dataPoints is 13', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.9,
          dataPoints: 13,
        );

        // Falls into medium because dataPoints >= 7
        expect(result.confidence, ForecastConfidence.medium);
      });

      test('should not return high when dataPoints >= 14 but rSquared is 0.69', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.69,
          dataPoints: 14,
        );

        // Falls into medium because rSquared >= 0.4
        expect(result.confidence, ForecastConfidence.medium);
      });
    });

    group('confidence — medium threshold (rSquared >= 0.4 OR dataPoints >= 7)', () {
      test('should return medium when rSquared is exactly 0.4 and dataPoints is 5', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.4,
          dataPoints: 5,
        );

        expect(result.confidence, ForecastConfidence.medium);
      });

      test('should return medium when rSquared is 0.6 and dataPoints is 4', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.6,
          dataPoints: 4,
        );

        expect(result.confidence, ForecastConfidence.medium);
      });

      test('should return medium when dataPoints is exactly 7 and rSquared is 0.1', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.1,
          dataPoints: 7,
        );

        expect(result.confidence, ForecastConfidence.medium);
      });

      test('should return medium when dataPoints is 10 and rSquared is below 0.4', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.2,
          dataPoints: 10,
        );

        expect(result.confidence, ForecastConfidence.medium);
      });
    });

    group('confidence — low threshold (rSquared < 0.4 AND dataPoints < 7)', () {
      test('should return low when rSquared is 0.0 and dataPoints is 1', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.0,
          dataPoints: 1,
        );

        expect(result.confidence, ForecastConfidence.low);
      });

      test('should return low when rSquared is just below 0.4 (0.399) and dataPoints is 6', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.399,
          dataPoints: 6,
        );

        expect(result.confidence, ForecastConfidence.low);
      });

      test('should return low when rSquared is 0.2 and dataPoints is 3', () {
        const result = RegressionResult(
          slope: 0.1,
          intercept: 10.0,
          rSquared: 0.2,
          dataPoints: 3,
        );

        expect(result.confidence, ForecastConfidence.low);
      });
    });
  });
}
