import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

const _goalId = 'goal-abc-123';
const _profileId = 'profile-xyz-456';
final _createdAt = DateTime(2026, 1, 1, 0, 0, 0);
final _updatedAt = DateTime(2026, 2, 1, 0, 0, 0);
final _deadline = DateTime(2026, 9, 1);
final _expectedDate = DateTime(2026, 8, 15);

/// A fully-populated [GoalEntity] used across multiple test groups.
GoalEntity _fullGoal({ForecastEntity? forecast}) {
  return GoalEntity(
    id: _goalId,
    profileId: _profileId,
    metricType: 'weight',
    goalDescription: 'Reach target weight',
    targetValue: 80.0,
    currentValue: 90.0,
    initialValue: 100.0,
    unit: 'kg',
    deadline: _deadline,
    priority: 2,
    expectedDate: _expectedDate,
    confidenceScore: 0.85,
    isActive: true,
    createdAt: _createdAt,
    updatedAt: _updatedAt,
    forecast: forecast,
  );
}

/// A minimal [GoalEntity] with only required fields and all defaults.
GoalEntity _minimalGoal() {
  return GoalEntity(
    id: 'g-min',
    profileId: 'p-min',
    metricType: 'steps',
    targetValue: 10000.0,
    currentValue: 7000.0,
    unit: 'steps',
    createdAt: _createdAt,
    updatedAt: _updatedAt,
  );
}

/// A complete JSON map representing the full goal fixture above.
Map<String, dynamic> _fullJson() {
  return {
    'id': _goalId,
    'profile_id': _profileId,
    'metric_type': 'weight',
    'goal_description': 'Reach target weight',
    'target_value': 80.0,
    'current_value': 90.0,
    'initial_value': 100.0,
    'unit': 'kg',
    'deadline': '2026-09-01',
    'priority': 2,
    'expected_date': '2026-08-15',
    'confidence_score': 0.85,
    'is_active': true,
    'created_at': _createdAt.toIso8601String(),
    'updated_at': _updatedAt.toIso8601String(),
  };
}

/// A minimal JSON map with only the truly required DB columns.
Map<String, dynamic> _minimalJson() {
  return {
    'id': 'g-min',
    'profile_id': 'p-min',
    'created_at': _createdAt.toIso8601String(),
    'updated_at': _updatedAt.toIso8601String(),
  };
}

// ---------------------------------------------------------------------------
// ForecastEntity helpers — constructed inline, no mocking library used
// ---------------------------------------------------------------------------

/// Forecast: weight goal (target < current → need negative slope), achievable,
/// moving toward target, high confidence.
ForecastEntity _forecastOnTrack() {
  return ForecastEntity(
    id: 'f-on-track',
    profileId: _profileId,
    metricType: 'weight',
    currentValue: 90.0,
    targetValue: 80.0,
    slope: -0.1, // negative → moving toward lower target
    intercept: 90.0,
    rSquared: 0.85,
    projectedDate: DateTime(2026, 9, 1), // non-null → isAchievable = true
    confidence: ForecastConfidence.high,
    dataPoints: 20,
    modelType: 'linear_regression',
    calculatedAt: DateTime(2026, 2, 19),
  );
}

/// Forecast: achievable, moving toward target, but low confidence.
ForecastEntity _forecastSlightlyBehind() {
  return ForecastEntity(
    id: 'f-slightly-behind',
    profileId: _profileId,
    metricType: 'weight',
    currentValue: 90.0,
    targetValue: 80.0,
    slope: -0.05,
    intercept: 90.0,
    rSquared: 0.45,
    projectedDate: DateTime(2026, 12, 1), // achievable
    confidence: ForecastConfidence.low,
    dataPoints: 10,
    modelType: 'linear_regression',
    calculatedAt: DateTime(2026, 2, 19),
  );
}

/// Forecast: achievable, moving toward target, medium confidence
/// (also maps to "Slightly Behind" per statusLabel logic).
ForecastEntity _forecastMediumConfidence() {
  return ForecastEntity(
    id: 'f-medium',
    profileId: _profileId,
    metricType: 'weight',
    currentValue: 90.0,
    targetValue: 80.0,
    slope: -0.07,
    intercept: 90.0,
    rSquared: 0.55,
    projectedDate: DateTime(2026, 11, 1),
    confidence: ForecastConfidence.medium,
    dataPoints: 12,
    modelType: 'linear_regression',
    calculatedAt: DateTime(2026, 2, 19),
  );
}

/// Forecast: NOT achievable (projectedDate == null) → isAchievable = false.
ForecastEntity _forecastNotAchievable() {
  return ForecastEntity(
    id: 'f-not-achievable',
    profileId: _profileId,
    metricType: 'weight',
    currentValue: 90.0,
    targetValue: 80.0,
    slope: 0.1, // positive slope when we need negative → not moving toward target
    intercept: 90.0,
    rSquared: 0.6,
    projectedDate: null, // not achievable
    confidence: ForecastConfidence.high,
    dataPoints: 20,
    modelType: 'linear_regression',
    calculatedAt: DateTime(2026, 2, 19),
  );
}

/// Forecast: achievable but NOT moving toward target (wrong slope direction).
ForecastEntity _forecastWrongDirection() {
  return ForecastEntity(
    id: 'f-wrong-dir',
    profileId: _profileId,
    metricType: 'weight',
    currentValue: 90.0,
    targetValue: 80.0,
    slope: 0.2, // positive when negative needed → isMovingTowardTarget = false
    intercept: 90.0,
    rSquared: 0.7,
    projectedDate: DateTime(2026, 10, 1), // projectedDate set but trend is wrong
    confidence: ForecastConfidence.high,
    dataPoints: 20,
    modelType: 'linear_regression',
    calculatedAt: DateTime(2026, 2, 19),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GoalEntity', () {
    // -----------------------------------------------------------------------
    // 1. fromJson
    // -----------------------------------------------------------------------
    group('fromJson', () {
      test('parses a complete JSON map correctly', () {
        final entity = GoalEntity.fromJson(_fullJson());

        expect(entity.id, _goalId);
        expect(entity.profileId, _profileId);
        expect(entity.metricType, 'weight');
        expect(entity.goalDescription, 'Reach target weight');
        expect(entity.targetValue, 80.0);
        expect(entity.currentValue, 90.0);
        expect(entity.initialValue, 100.0);
        expect(entity.unit, 'kg');
        expect(entity.deadline, DateTime(2026, 9, 1));
        expect(entity.priority, 2);
        expect(entity.expectedDate, DateTime(2026, 8, 15));
        expect(entity.confidenceScore, 0.85);
        expect(entity.isActive, true);
        expect(entity.createdAt, _createdAt);
        expect(entity.updatedAt, _updatedAt);
        expect(entity.forecast, isNull);
      });

      test('applies default values for optional/missing fields', () {
        final entity = GoalEntity.fromJson(_minimalJson());

        expect(entity.id, 'g-min');
        expect(entity.profileId, 'p-min');
        expect(entity.metricType, ''); // defaults to empty string
        expect(entity.goalDescription, isNull);
        expect(entity.targetValue, 0.0);
        expect(entity.currentValue, 0.0);
        expect(entity.initialValue, isNull);
        expect(entity.unit, '');
        expect(entity.deadline, isNull);
        expect(entity.priority, 0);
        expect(entity.expectedDate, isNull);
        expect(entity.confidenceScore, isNull);
        expect(entity.isActive, true); // default
        expect(entity.forecast, isNull);
      });

      test('accepts null for all nullable optional fields explicitly', () {
        final json = {
          'id': 'g-nulls',
          'profile_id': 'p-nulls',
          'metric_type': 'steps',
          'goal_description': null,
          'target_value': 5000.0,
          'current_value': 3000.0,
          'unit': 'steps',
          'deadline': null,
          'priority': 0,
          'expected_date': null,
          'confidence_score': null,
          'is_active': false,
          'created_at': _createdAt.toIso8601String(),
          'updated_at': _updatedAt.toIso8601String(),
        };

        final entity = GoalEntity.fromJson(json);

        expect(entity.goalDescription, isNull);
        expect(entity.deadline, isNull);
        expect(entity.expectedDate, isNull);
        expect(entity.confidenceScore, isNull);
        expect(entity.isActive, false);
      });

      test('accepts an integer target_value and converts to double', () {
        final json = _fullJson();
        json['target_value'] = 80; // int not double
        json['current_value'] = 90; // int not double

        final entity = GoalEntity.fromJson(json);

        expect(entity.targetValue, 80.0);
        expect(entity.targetValue, isA<double>());
        expect(entity.currentValue, 90.0);
        expect(entity.currentValue, isA<double>());
      });

      test('injects a supplied forecast into the entity', () {
        final forecast = _forecastOnTrack();
        final entity = GoalEntity.fromJson(_fullJson(), forecast: forecast);

        expect(entity.forecast, isNotNull);
        expect(entity.forecast!.id, 'f-on-track');
      });
    });

    // -----------------------------------------------------------------------
    // 2. toJson
    // -----------------------------------------------------------------------
    group('toJson', () {
      test('produces all expected DB column keys', () {
        final json = _fullGoal().toJson();

        expect(json.containsKey('id'), isTrue);
        expect(json.containsKey('profile_id'), isTrue);
        expect(json.containsKey('metric_type'), isTrue);
        expect(json.containsKey('goal_description'), isTrue);
        expect(json.containsKey('target_value'), isTrue);
        expect(json.containsKey('current_value'), isTrue);
        expect(json.containsKey('initial_value'), isTrue);
        expect(json.containsKey('unit'), isTrue);
        expect(json.containsKey('deadline'), isTrue);
        expect(json.containsKey('priority'), isTrue);
        expect(json.containsKey('expected_date'), isTrue);
        expect(json.containsKey('confidence_score'), isTrue);
        expect(json.containsKey('is_active'), isTrue);
        expect(json.containsKey('created_at'), isTrue);
        expect(json.containsKey('updated_at'), isTrue);
      });

      test('serializes all field values correctly', () {
        final json = _fullGoal().toJson();

        expect(json['id'], _goalId);
        expect(json['profile_id'], _profileId);
        expect(json['metric_type'], 'weight');
        expect(json['goal_description'], 'Reach target weight');
        expect(json['target_value'], 80.0);
        expect(json['current_value'], 90.0);
        expect(json['initial_value'], 100.0);
        expect(json['unit'], 'kg');
        expect(json['deadline'], '2026-09-01'); // date-only format
        expect(json['priority'], 2);
        expect(json['expected_date'], '2026-08-15'); // date-only format
        expect(json['confidence_score'], 0.85);
        expect(json['is_active'], true);
        expect(json['created_at'], _createdAt.toIso8601String());
        expect(json['updated_at'], _updatedAt.toIso8601String());
      });

      test('serializes deadline and expectedDate as date-only strings (no time component)', () {
        final json = _fullGoal().toJson();

        final deadline = json['deadline'] as String;
        final expectedDate = json['expected_date'] as String;

        expect(deadline.contains('T'), isFalse,
            reason: 'deadline should be YYYY-MM-DD, not ISO 8601 with time');
        expect(expectedDate.contains('T'), isFalse,
            reason: 'expected_date should be YYYY-MM-DD, not ISO 8601 with time');
        expect(deadline, '2026-09-01');
        expect(expectedDate, '2026-08-15');
      });

      test('serializes null optional fields as null', () {
        final json = _minimalGoal().toJson();

        expect(json['goal_description'], isNull);
        expect(json['initial_value'], isNull);
        expect(json['deadline'], isNull);
        expect(json['expected_date'], isNull);
        expect(json['confidence_score'], isNull);
      });

      test('does not include the forecast field in toJson output', () {
        // forecast is a transient join and must not be persisted directly
        final json = _fullGoal(forecast: _forecastOnTrack()).toJson();
        expect(json.containsKey('forecast'), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // 3. Roundtrip serialization
    // -----------------------------------------------------------------------
    group('Roundtrip', () {
      test('fromJson(toJson(entity)) preserves all scalar fields', () {
        final original = _fullGoal();
        final restored = GoalEntity.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.profileId, original.profileId);
        expect(restored.metricType, original.metricType);
        expect(restored.goalDescription, original.goalDescription);
        expect(restored.targetValue, original.targetValue);
        expect(restored.currentValue, original.currentValue);
        expect(restored.initialValue, original.initialValue);
        expect(restored.unit, original.unit);
        expect(restored.priority, original.priority);
        expect(restored.confidenceScore, original.confidenceScore);
        expect(restored.isActive, original.isActive);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });

      test('roundtrip preserves deadline and expectedDate as date-only (midnight UTC)', () {
        final original = _fullGoal();
        final restored = GoalEntity.fromJson(original.toJson());

        // After roundtrip, date-only strings are parsed as midnight UTC
        expect(restored.deadline, DateTime(2026, 9, 1));
        expect(restored.expectedDate, DateTime(2026, 8, 15));
      });

      test('roundtrip with null optional fields stays null', () {
        final original = _minimalGoal();
        final restored = GoalEntity.fromJson(original.toJson());

        expect(restored.goalDescription, isNull);
        expect(restored.deadline, isNull);
        expect(restored.expectedDate, isNull);
        expect(restored.confidenceScore, isNull);
      });

      test('forecast is not present after roundtrip (transient field)', () {
        // The forecast comes from a joined query, not stored in toJson
        final original = _fullGoal(forecast: _forecastOnTrack());
        final restored = GoalEntity.fromJson(original.toJson());
        expect(restored.forecast, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // 4. progressPercentage
    // -----------------------------------------------------------------------
    group('progressPercentage', () {
      test('returns 100.0 when targetValue equals currentValue', () {
        final goal = GoalEntity(
          id: 'g1',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 80.0,
          initialValue: 100.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 100.0);
      });

      test('returns 0.0 when currentValue equals initialValue and differs from target', () {
        final goal = GoalEntity(
          id: 'g2',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 100.0,
          initialValue: 100.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 0.0);
      });

      test('calculates correct progress for decrease goal (weight loss)', () {
        // Started at 100, now at 90, target is 80 → 50% progress
        final goal = GoalEntity(
          id: 'g3',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 90.0,
          initialValue: 100.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 50.0);
      });

      test('calculates correct progress for increase goal (VO2 max)', () {
        // Started at 40, now at 46, target is 55 → 40%
        final goal = GoalEntity(
          id: 'g4',
          profileId: 'p1',
          metricType: 'vo2max',
          targetValue: 55.0,
          currentValue: 46.0,
          initialValue: 40.0,
          unit: 'mL/kg/min',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 40.0);
      });

      test('falls back to 0% when initialValue is null (no baseline data)', () {
        // Without initialValue, start = currentValue, so progress is 0
        final goal = GoalEntity(
          id: 'g5',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 90.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 0.0);
      });

      test('clamps to 100% when overshoot occurs', () {
        // Started at 100, target is 80, now at 75 → past target
        final goal = GoalEntity(
          id: 'g6',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 75.0,
          initialValue: 100.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 100.0);
      });

      test('returns 100.0 when initialValue equals targetValue (zero range)', () {
        final goal = GoalEntity(
          id: 'g7',
          profileId: 'p1',
          metricType: 'weight',
          targetValue: 80.0,
          currentValue: 85.0,
          initialValue: 80.0,
          unit: 'kg',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.progressPercentage, 100.0);
      });
    });

    // -----------------------------------------------------------------------
    // 5. statusLabel
    // -----------------------------------------------------------------------
    group('statusLabel', () {
      test('returns "No Data" when forecast is null', () {
        expect(_minimalGoal().statusLabel, 'No Data');
      });

      test('returns "Off Track" when forecast is not achievable', () {
        final goal = _fullGoal(forecast: _forecastNotAchievable());
        expect(goal.statusLabel, 'Off Track');
      });

      test('returns "On Track" when achievable, moving toward target, and high confidence', () {
        final goal = _fullGoal(forecast: _forecastOnTrack());
        expect(goal.statusLabel, 'On Track');
      });

      test('returns "Slightly Behind" when achievable, moving toward target, but low confidence', () {
        final goal = _fullGoal(forecast: _forecastSlightlyBehind());
        expect(goal.statusLabel, 'Slightly Behind');
      });

      test('returns "Slightly Behind" when achievable, moving toward target, but medium confidence', () {
        final goal = _fullGoal(forecast: _forecastMediumConfidence());
        expect(goal.statusLabel, 'Slightly Behind');
      });

      test('returns "Off Track" when achievable but NOT moving toward target', () {
        final goal = _fullGoal(forecast: _forecastWrongDirection());
        expect(goal.statusLabel, 'Off Track');
      });
    });

    // -----------------------------------------------------------------------
    // 6. statusColor
    // -----------------------------------------------------------------------
    group('statusColor', () {
      test('returns "green" for "On Track" status', () {
        final goal = _fullGoal(forecast: _forecastOnTrack());
        expect(goal.statusLabel, 'On Track');
        expect(goal.statusColor, 'green');
      });

      test('returns "amber" for "Slightly Behind" status', () {
        final goal = _fullGoal(forecast: _forecastSlightlyBehind());
        expect(goal.statusLabel, 'Slightly Behind');
        expect(goal.statusColor, 'amber');
      });

      test('returns "red" for "Off Track" status (not achievable)', () {
        final goal = _fullGoal(forecast: _forecastNotAchievable());
        expect(goal.statusLabel, 'Off Track');
        expect(goal.statusColor, 'red');
      });

      test('returns "red" for "Off Track" status (wrong direction)', () {
        final goal = _fullGoal(forecast: _forecastWrongDirection());
        expect(goal.statusLabel, 'Off Track');
        expect(goal.statusColor, 'red');
      });

      test('returns "grey" for "No Data" status (no forecast)', () {
        final goal = _minimalGoal();
        expect(goal.statusLabel, 'No Data');
        expect(goal.statusColor, 'grey');
      });
    });

    // -----------------------------------------------------------------------
    // 7. metricDisplayName and displayNameForMetricType
    // -----------------------------------------------------------------------
    group('metricDisplayName and displayNameForMetricType', () {
      // Map of all known metric types to their expected display names
      const knownTypes = {
        'weight': 'Weight',
        'vo2max': 'VO2 Max',
        'steps': 'Daily Steps',
        'sleep': 'Sleep Duration',
        'hr': 'Resting Heart Rate',
        'hrv': 'Heart Rate Variability',
        'calories': 'Calories',
        'distance': 'Distance',
        'active_minutes': 'Active Minutes',
        'body_fat': 'Body Fat',
        'blood_pressure': 'Blood Pressure',
        'spo2': 'SpO2',
        'stress': 'Stress Score',
      };

      for (final entry in knownTypes.entries) {
        test('displayNameForMetricType("${entry.key}") returns "${entry.value}"', () {
          expect(GoalEntity.displayNameForMetricType(entry.key), entry.value);
        });
      }

      test('displayNameForMetricType returns the raw type string for unknown types', () {
        const unknownType = 'unknown_metric_xyz';
        expect(GoalEntity.displayNameForMetricType(unknownType), unknownType);
      });

      test('metricDisplayName instance getter delegates to displayNameForMetricType', () {
        for (final entry in knownTypes.entries) {
          final goal = GoalEntity(
            id: 'g-dn',
            profileId: 'p-dn',
            metricType: entry.key,
            targetValue: 100.0,
            currentValue: 50.0,
            unit: '',
            createdAt: _createdAt,
            updatedAt: _updatedAt,
          );

          expect(goal.metricDisplayName, entry.value);
        }
      });

      test('metricDisplayName returns raw type for unknown metric', () {
        final goal = GoalEntity(
          id: 'g-unk',
          profileId: 'p-unk',
          metricType: 'custom_metric',
          targetValue: 1.0,
          currentValue: 0.0,
          unit: '',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );

        expect(goal.metricDisplayName, 'custom_metric');
      });
    });

    // -----------------------------------------------------------------------
    // 8. defaultUnitForMetricType
    // -----------------------------------------------------------------------
    group('defaultUnitForMetricType', () {
      const knownUnits = {
        'weight': 'kg',
        'vo2max': 'mL/kg/min',
        'steps': 'steps',
        'sleep': 'hours',
        'hr': 'bpm',
        'hrv': 'ms',
        'calories': 'kcal',
        'distance': 'km',
        'active_minutes': 'min',
        'body_fat': '%',
        'blood_pressure': 'mmHg',
        'spo2': '%',
        'stress': '',
      };

      for (final entry in knownUnits.entries) {
        test('defaultUnitForMetricType("${entry.key}") returns "${entry.value}"', () {
          expect(GoalEntity.defaultUnitForMetricType(entry.key), entry.value);
        });
      }

      test('defaultUnitForMetricType returns empty string for unknown type', () {
        expect(GoalEntity.defaultUnitForMetricType('completely_unknown'), '');
      });
    });

    // -----------------------------------------------------------------------
    // 9. copyWith
    // -----------------------------------------------------------------------
    group('copyWith', () {
      test('partial update changes only the specified fields', () {
        final original = _fullGoal();
        final updated = original.copyWith(
          targetValue: 75.0,
          currentValue: 85.0,
          priority: 5,
        );

        // Changed fields
        expect(updated.targetValue, 75.0);
        expect(updated.currentValue, 85.0);
        expect(updated.priority, 5);

        // Unchanged fields — id and profileId are never parameters of copyWith
        expect(updated.id, original.id);
        expect(updated.profileId, original.profileId);
        expect(updated.metricType, original.metricType);
        expect(updated.goalDescription, original.goalDescription);
        expect(updated.initialValue, original.initialValue);
        expect(updated.unit, original.unit);
        expect(updated.deadline, original.deadline);
        expect(updated.expectedDate, original.expectedDate);
        expect(updated.confidenceScore, original.confidenceScore);
        expect(updated.isActive, original.isActive);
        expect(updated.createdAt, original.createdAt);
      });

      test('full update applies all copyWith parameters', () {
        final original = _minimalGoal();
        final newDeadline = DateTime(2027, 1, 1);
        final newExpectedDate = DateTime(2026, 12, 15);
        final forecast = _forecastOnTrack();

        final updated = original.copyWith(
          metricType: 'vo2max',
          goalDescription: 'Increase VO2 max',
          targetValue: 55.0,
          currentValue: 48.0,
          unit: 'mL/kg/min',
          deadline: newDeadline,
          priority: 3,
          expectedDate: newExpectedDate,
          confidenceScore: 0.9,
          isActive: false,
          forecast: forecast,
        );

        expect(updated.metricType, 'vo2max');
        expect(updated.goalDescription, 'Increase VO2 max');
        expect(updated.targetValue, 55.0);
        expect(updated.currentValue, 48.0);
        expect(updated.unit, 'mL/kg/min');
        expect(updated.deadline, newDeadline);
        expect(updated.priority, 3);
        expect(updated.expectedDate, newExpectedDate);
        expect(updated.confidenceScore, 0.9);
        expect(updated.isActive, false);
        expect(updated.forecast, forecast);
      });

      test('no-args copy preserves all field values (except updatedAt which refreshes)', () {
        final original = _fullGoal();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.profileId, original.profileId);
        expect(copy.metricType, original.metricType);
        expect(copy.goalDescription, original.goalDescription);
        expect(copy.targetValue, original.targetValue);
        expect(copy.currentValue, original.currentValue);
        expect(copy.initialValue, original.initialValue);
        expect(copy.unit, original.unit);
        expect(copy.deadline, original.deadline);
        expect(copy.priority, original.priority);
        expect(copy.expectedDate, original.expectedDate);
        expect(copy.confidenceScore, original.confidenceScore);
        expect(copy.isActive, original.isActive);
        expect(copy.createdAt, original.createdAt);
        // copyWith always sets updatedAt = DateTime.now(), so we only assert it is recent
        expect(
          copy.updatedAt.difference(DateTime.now()).abs().inSeconds,
          lessThan(5),
        );
      });

      test('original entity is not mutated after copyWith', () {
        final original = _fullGoal();
        final _ = original.copyWith(targetValue: 70.0, priority: 9);

        // Original must remain unchanged
        expect(original.targetValue, 80.0);
        expect(original.priority, 2);
      });

      test('copyWith can update forecast to a new instance', () {
        final original = _fullGoal();
        expect(original.forecast, isNull);

        final withForecast = original.copyWith(forecast: _forecastOnTrack());
        expect(withForecast.forecast, isNotNull);
        expect(withForecast.forecast!.id, 'f-on-track');
      });
    });
  });
}
