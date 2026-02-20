import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/insights/domain/recovery_score_entity.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared fixtures — reused across groups to avoid repetition
  // ---------------------------------------------------------------------------
  const kId = 'rec-score-id-001';
  const kProfileId = 'profile-abc-123';
  final kScoreDate = DateTime(2026, 2, 19);

  /// Builds a fully-populated [RecoveryScoreEntity] with sensible defaults.
  /// Individual test cases override only the fields they care about.
  RecoveryScoreEntity makeEntity({
    String id = kId,
    String profileId = kProfileId,
    DateTime? scoreDate,
    double? stressComponent = 75.0,
    double? sleepComponent = 80.0,
    double? hrComponent = 70.0,
    double? loadComponent = 65.0,
    double recoveryScore = 72.5,
    int componentsAvailable = 4,
    Map<String, dynamic>? rawData,
  }) {
    return RecoveryScoreEntity(
      id: id,
      profileId: profileId,
      scoreDate: scoreDate ?? kScoreDate,
      stressComponent: stressComponent,
      sleepComponent: sleepComponent,
      hrComponent: hrComponent,
      loadComponent: loadComponent,
      recoveryScore: recoveryScore,
      componentsAvailable: componentsAvailable,
      rawData: rawData,
    );
  }

  /// Canonical JSON that mirrors what Supabase would return for a complete row.
  Map<String, dynamic> fullJson() => {
        'id': kId,
        'profile_id': kProfileId,
        'score_date': '2026-02-19T00:00:00.000',
        'stress_component': 75.0,
        'sleep_component': 80.0,
        'hr_component': 70.0,
        'load_component': 65.0,
        'recovery_score': 72.5,
        'components_available': 4,
        'raw_data': {'source': 'garmin', 'stress_raw': 28},
      };

  // ===========================================================================
  // 1. fromJson
  // ===========================================================================
  group('fromJson', () {
    test('maps all fields correctly from a complete JSON map', () {
      final entity = RecoveryScoreEntity.fromJson(fullJson());

      expect(entity.id, kId);
      expect(entity.profileId, kProfileId);
      expect(entity.scoreDate, DateTime.parse('2026-02-19T00:00:00.000'));
      expect(entity.stressComponent, 75.0);
      expect(entity.sleepComponent, 80.0);
      expect(entity.hrComponent, 70.0);
      expect(entity.loadComponent, 65.0);
      expect(entity.recoveryScore, 72.5);
      expect(entity.componentsAvailable, 4);
      expect(entity.rawData, {'source': 'garmin', 'stress_raw': 28});
    });

    test('accepts an integer recovery_score and casts it to double', () {
      final json = fullJson()..['recovery_score'] = 85; // int literal
      final entity = RecoveryScoreEntity.fromJson(json);

      expect(entity.recoveryScore, 85.0);
      expect(entity.recoveryScore, isA<double>());
    });

    test('handles null optional component fields gracefully', () {
      final json = {
        'id': kId,
        'profile_id': kProfileId,
        'score_date': '2026-02-19T00:00:00.000',
        'stress_component': null,
        'sleep_component': null,
        'hr_component': null,
        'load_component': null,
        'recovery_score': 0.0,
        'components_available': 0,
        'raw_data': null,
      };

      final entity = RecoveryScoreEntity.fromJson(json);

      expect(entity.stressComponent, isNull);
      expect(entity.sleepComponent, isNull);
      expect(entity.hrComponent, isNull);
      expect(entity.loadComponent, isNull);
      expect(entity.rawData, isNull);
    });

    test('parses score_date as UTC-agnostic DateTime correctly', () {
      const dateStr = '2026-01-01T06:30:00.000';
      final json = fullJson()..['score_date'] = dateStr;
      final entity = RecoveryScoreEntity.fromJson(json);

      expect(entity.scoreDate, DateTime.parse(dateStr));
    });

    test('handles rawData with nested structure', () {
      final json = fullJson()
        ..['raw_data'] = {
          'garmin': {'stress': 28, 'hrv': 55},
          'calculated_at': '2026-02-19T01:00:00Z',
        };
      final entity = RecoveryScoreEntity.fromJson(json);

      expect(entity.rawData!['garmin'], {'stress': 28, 'hrv': 55});
    });
  });

  // ===========================================================================
  // 2. toJson
  // ===========================================================================
  group('toJson', () {
    test('produces a map with all expected DB column keys', () {
      final entity = makeEntity(rawData: {'debug': true});
      final json = entity.toJson();

      // All keys that must be present — mirrors the DB column names exactly.
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('profile_id'), isTrue);
      expect(json.containsKey('score_date'), isTrue);
      expect(json.containsKey('stress_component'), isTrue);
      expect(json.containsKey('sleep_component'), isTrue);
      expect(json.containsKey('hr_component'), isTrue);
      expect(json.containsKey('load_component'), isTrue);
      expect(json.containsKey('recovery_score'), isTrue);
      expect(json.containsKey('components_available'), isTrue);
      expect(json.containsKey('raw_data'), isTrue);
    });

    test('serializes scalar fields with correct values', () {
      final entity = makeEntity();
      final json = entity.toJson();

      expect(json['id'], kId);
      expect(json['profile_id'], kProfileId);
      expect(json['stress_component'], 75.0);
      expect(json['sleep_component'], 80.0);
      expect(json['hr_component'], 70.0);
      expect(json['load_component'], 65.0);
      expect(json['recovery_score'], 72.5);
      expect(json['components_available'], 4);
    });

    test('score_date is serialized as an ISO 8601 string', () {
      final entity = makeEntity(scoreDate: DateTime(2026, 2, 19));
      final json = entity.toJson();

      expect(json['score_date'], isA<String>());
      // Parsing it back must reconstruct the same moment.
      expect(
        DateTime.parse(json['score_date'] as String),
        DateTime(2026, 2, 19),
      );
    });

    test('null optional fields serialize as null — not omitted', () {
      final entity = makeEntity(
        stressComponent: null,
        sleepComponent: null,
        hrComponent: null,
        loadComponent: null,
        rawData: null,
      );
      final json = entity.toJson();

      expect(json['stress_component'], isNull);
      expect(json['sleep_component'], isNull);
      expect(json['hr_component'], isNull);
      expect(json['load_component'], isNull);
      expect(json['raw_data'], isNull);
    });

    test('rawData map is preserved as-is without transformation', () {
      final rawPayload = {'key': 'value', 'nested': {'a': 1}};
      final entity = makeEntity(rawData: rawPayload);
      final json = entity.toJson();

      expect(json['raw_data'], rawPayload);
    });
  });

  // ===========================================================================
  // 3. Roundtrip — fromJson(toJson) preserves all data
  // ===========================================================================
  group('Roundtrip serialization', () {
    test('fully-populated entity survives fromJson → toJson → fromJson', () {
      final original = makeEntity(
        rawData: {'audit': 'test', 'flags': [1, 2, 3]},
      );

      final restored = RecoveryScoreEntity.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.profileId, original.profileId);
      expect(restored.scoreDate, original.scoreDate);
      expect(restored.stressComponent, original.stressComponent);
      expect(restored.sleepComponent, original.sleepComponent);
      expect(restored.hrComponent, original.hrComponent);
      expect(restored.loadComponent, original.loadComponent);
      expect(restored.recoveryScore, original.recoveryScore);
      expect(restored.componentsAvailable, original.componentsAvailable);
      expect(restored.rawData, original.rawData);
    });

    test('entity with all null components survives roundtrip', () {
      final original = makeEntity(
        stressComponent: null,
        sleepComponent: null,
        hrComponent: null,
        loadComponent: null,
        recoveryScore: 0.0,
        componentsAvailable: 0,
      );

      final restored = RecoveryScoreEntity.fromJson(original.toJson());

      expect(restored.stressComponent, isNull);
      expect(restored.sleepComponent, isNull);
      expect(restored.hrComponent, isNull);
      expect(restored.loadComponent, isNull);
      expect(restored.recoveryScore, 0.0);
      expect(restored.componentsAvailable, 0);
    });

    test('boundary recovery score (100.0) survives roundtrip', () {
      final original = makeEntity(recoveryScore: 100.0);
      final restored = RecoveryScoreEntity.fromJson(original.toJson());

      expect(restored.recoveryScore, 100.0);
    });

    test('JSON from Supabase fixture roundtrips without data loss', () {
      final entity = RecoveryScoreEntity.fromJson(fullJson());
      final reJsoned = entity.toJson();
      final restored = RecoveryScoreEntity.fromJson(reJsoned);

      expect(restored.id, entity.id);
      expect(restored.recoveryScore, entity.recoveryScore);
      expect(restored.componentsAvailable, entity.componentsAvailable);
      expect(restored.rawData, entity.rawData);
    });
  });

  // ===========================================================================
  // 4. interpretationLabel
  // ===========================================================================
  group('interpretationLabel', () {
    test('returns Excellent for score of exactly 80', () {
      expect(makeEntity(recoveryScore: 80.0).interpretationLabel, 'Excellent');
    });

    test('returns Excellent for score of 95', () {
      expect(makeEntity(recoveryScore: 95.0).interpretationLabel, 'Excellent');
    });

    test('returns Excellent for score of 100', () {
      expect(makeEntity(recoveryScore: 100.0).interpretationLabel, 'Excellent');
    });

    test('returns Good for score of exactly 60', () {
      expect(makeEntity(recoveryScore: 60.0).interpretationLabel, 'Good');
    });

    test('returns Good for score of 79', () {
      expect(makeEntity(recoveryScore: 79.0).interpretationLabel, 'Good');
    });

    test('returns Moderate for score of exactly 40', () {
      expect(makeEntity(recoveryScore: 40.0).interpretationLabel, 'Moderate');
    });

    test('returns Moderate for score of 59', () {
      expect(makeEntity(recoveryScore: 59.0).interpretationLabel, 'Moderate');
    });

    test('returns Low for score of exactly 20', () {
      expect(makeEntity(recoveryScore: 20.0).interpretationLabel, 'Low');
    });

    test('returns Low for score of 39', () {
      expect(makeEntity(recoveryScore: 39.0).interpretationLabel, 'Low');
    });

    test('returns Critical for score of exactly 19', () {
      expect(makeEntity(recoveryScore: 19.0).interpretationLabel, 'Critical');
    });

    test('returns Critical for score of 0', () {
      expect(makeEntity(recoveryScore: 0.0).interpretationLabel, 'Critical');
    });

    test('boundary: 79.9 is Good not Excellent', () {
      expect(makeEntity(recoveryScore: 79.9).interpretationLabel, 'Good');
    });

    test('boundary: 59.9 is Moderate not Good', () {
      expect(makeEntity(recoveryScore: 59.9).interpretationLabel, 'Moderate');
    });

    test('boundary: 39.9 is Low not Moderate', () {
      expect(makeEntity(recoveryScore: 39.9).interpretationLabel, 'Low');
    });

    test('boundary: 19.9 is Critical not Low', () {
      expect(makeEntity(recoveryScore: 19.9).interpretationLabel, 'Critical');
    });
  });

  // ===========================================================================
  // 5. colorCode
  // ===========================================================================
  group('colorCode', () {
    test('score >= 80 maps to green', () {
      expect(makeEntity(recoveryScore: 80.0).colorCode, RecoveryScoreColor.green);
      expect(makeEntity(recoveryScore: 95.0).colorCode, RecoveryScoreColor.green);
      expect(makeEntity(recoveryScore: 100.0).colorCode, RecoveryScoreColor.green);
    });

    test('score in [60, 79] maps to lightGreen', () {
      expect(makeEntity(recoveryScore: 60.0).colorCode, RecoveryScoreColor.lightGreen);
      expect(makeEntity(recoveryScore: 70.0).colorCode, RecoveryScoreColor.lightGreen);
      expect(makeEntity(recoveryScore: 79.9).colorCode, RecoveryScoreColor.lightGreen);
    });

    test('score in [40, 59] maps to yellow', () {
      expect(makeEntity(recoveryScore: 40.0).colorCode, RecoveryScoreColor.yellow);
      expect(makeEntity(recoveryScore: 50.0).colorCode, RecoveryScoreColor.yellow);
      expect(makeEntity(recoveryScore: 59.9).colorCode, RecoveryScoreColor.yellow);
    });

    test('score in [20, 39] maps to orange', () {
      expect(makeEntity(recoveryScore: 20.0).colorCode, RecoveryScoreColor.orange);
      expect(makeEntity(recoveryScore: 30.0).colorCode, RecoveryScoreColor.orange);
      expect(makeEntity(recoveryScore: 39.9).colorCode, RecoveryScoreColor.orange);
    });

    test('score < 20 maps to red', () {
      expect(makeEntity(recoveryScore: 19.0).colorCode, RecoveryScoreColor.red);
      expect(makeEntity(recoveryScore: 10.0).colorCode, RecoveryScoreColor.red);
      expect(makeEntity(recoveryScore: 0.0).colorCode, RecoveryScoreColor.red);
    });

    test('colorCode is consistent with interpretationLabel for every range', () {
      final cases = <double, RecoveryScoreColor>{
        90.0: RecoveryScoreColor.green,
        65.0: RecoveryScoreColor.lightGreen,
        50.0: RecoveryScoreColor.yellow,
        25.0: RecoveryScoreColor.orange,
        5.0: RecoveryScoreColor.red,
      };

      for (final entry in cases.entries) {
        expect(
          makeEntity(recoveryScore: entry.key).colorCode,
          entry.value,
          reason: 'score ${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  // ===========================================================================
  // 6. description
  // ===========================================================================
  group('description', () {
    test('Excellent label returns intense-training recommendation', () {
      final desc = makeEntity(recoveryScore: 90.0).description;
      expect(
        desc,
        'Your body is well-recovered and ready for intense training.',
      );
    });

    test('Good label returns moderate-to-high intensity recommendation', () {
      final desc = makeEntity(recoveryScore: 65.0).description;
      expect(
        desc,
        'Good recovery. You can proceed with moderate to high intensity.',
      );
    });

    test('Moderate label returns lighter-training recommendation', () {
      final desc = makeEntity(recoveryScore: 50.0).description;
      expect(
        desc,
        'Moderate recovery. Consider lighter training or active recovery.',
      );
    });

    test('Low label returns rest-focus recommendation', () {
      final desc = makeEntity(recoveryScore: 30.0).description;
      expect(
        desc,
        'Low recovery. Focus on rest and recovery activities.',
      );
    });

    test('Critical label returns strongly-recommended rest message', () {
      final desc = makeEntity(recoveryScore: 10.0).description;
      expect(
        desc,
        'Critical recovery state. Rest is strongly recommended.',
      );
    });

    test('description is non-empty for every score boundary', () {
      for (final score in [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]) {
        expect(
          makeEntity(recoveryScore: score).description,
          isNotEmpty,
          reason: 'description should be non-empty for score $score',
        );
      }
    });
  });

  // ===========================================================================
  // 7. isComplete
  // ===========================================================================
  group('isComplete', () {
    test('returns true when exactly 4 components are available', () {
      expect(makeEntity(componentsAvailable: 4).isComplete, isTrue);
    });

    test('returns false when 3 components are available', () {
      expect(makeEntity(componentsAvailable: 3).isComplete, isFalse);
    });

    test('returns false when 2 components are available', () {
      expect(makeEntity(componentsAvailable: 2).isComplete, isFalse);
    });

    test('returns false when 1 component is available', () {
      expect(makeEntity(componentsAvailable: 1).isComplete, isFalse);
    });

    test('returns false when 0 components are available', () {
      expect(makeEntity(componentsAvailable: 0).isComplete, isFalse);
    });

    test('isComplete aligns with all four component fields being non-null', () {
      // Full set of components — both the field-based and count-based views agree.
      final complete = makeEntity(componentsAvailable: 4);
      expect(complete.isComplete, isTrue);
      expect(complete.missingComponents, isEmpty);
    });

    test('isComplete is false even when count disagrees with actual nulls', () {
      // Edge case: caller passes componentsAvailable: 3 but provides all 4 fields.
      // isComplete is driven purely by componentsAvailable, not by null inspection.
      final entity = makeEntity(componentsAvailable: 3);
      expect(entity.isComplete, isFalse);
    });
  });

  // ===========================================================================
  // 8. missingComponents
  // ===========================================================================
  group('missingComponents', () {
    test('returns empty list when all four components are provided', () {
      final entity = makeEntity(
        stressComponent: 75.0,
        sleepComponent: 80.0,
        hrComponent: 70.0,
        loadComponent: 65.0,
      );

      expect(entity.missingComponents, isEmpty);
    });

    test('returns [Stress] when stressComponent is null', () {
      final entity = makeEntity(stressComponent: null);

      expect(entity.missingComponents, ['Stress']);
    });

    test('returns [Sleep] when sleepComponent is null', () {
      final entity = makeEntity(sleepComponent: null);

      expect(entity.missingComponents, ['Sleep']);
    });

    test('returns [Heart Rate] when hrComponent is null', () {
      final entity = makeEntity(hrComponent: null);

      expect(entity.missingComponents, ['Heart Rate']);
    });

    test('returns [Training Load] when loadComponent is null', () {
      final entity = makeEntity(loadComponent: null);

      expect(entity.missingComponents, ['Training Load']);
    });

    test('returns multiple entries in insertion order when several are missing', () {
      final entity = makeEntity(
        stressComponent: null,
        hrComponent: null,
      );

      // Stress is checked before HR in the implementation.
      expect(entity.missingComponents, ['Stress', 'Heart Rate']);
    });

    test('returns all four labels in order when every component is null', () {
      final entity = makeEntity(
        stressComponent: null,
        sleepComponent: null,
        hrComponent: null,
        loadComponent: null,
      );

      expect(
        entity.missingComponents,
        ['Stress', 'Sleep', 'Heart Rate', 'Training Load'],
      );
    });

    test('list length equals (4 - componentsAvailable) for canonical inputs', () {
      // When the caller sets componentsAvailable correctly this invariant holds.
      final entity = makeEntity(
        stressComponent: null,
        sleepComponent: null,
        hrComponent: 70.0,
        loadComponent: 65.0,
        componentsAvailable: 2,
      );

      expect(entity.missingComponents.length, 4 - entity.componentsAvailable);
    });
  });

  // ===========================================================================
  // 9. getTrendComparedTo
  // ===========================================================================
  group('getTrendComparedTo', () {
    test('returns flat when previous is null', () {
      final current = makeEntity(recoveryScore: 70.0);
      expect(current.getTrendComparedTo(null), RecoveryTrend.flat);
    });

    test('returns up when difference is greater than 5', () {
      final current = makeEntity(recoveryScore: 80.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = +10
      expect(current.getTrendComparedTo(previous), RecoveryTrend.up);
    });

    test('returns up for a large positive difference', () {
      final current = makeEntity(recoveryScore: 100.0);
      final previous = makeEntity(recoveryScore: 50.0); // diff = +50
      expect(current.getTrendComparedTo(previous), RecoveryTrend.up);
    });

    test('returns down when difference is less than -5', () {
      final current = makeEntity(recoveryScore: 60.0);
      final previous = makeEntity(recoveryScore: 72.0); // diff = -12
      expect(current.getTrendComparedTo(previous), RecoveryTrend.down);
    });

    test('returns down for a large negative difference', () {
      final current = makeEntity(recoveryScore: 20.0);
      final previous = makeEntity(recoveryScore: 90.0); // diff = -70
      expect(current.getTrendComparedTo(previous), RecoveryTrend.down);
    });

    test('returns flat when difference is 0', () {
      final current = makeEntity(recoveryScore: 70.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = 0
      expect(current.getTrendComparedTo(previous), RecoveryTrend.flat);
    });

    test('returns flat when difference is within (-5, 5) range — positive side', () {
      final current = makeEntity(recoveryScore: 73.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = +3
      expect(current.getTrendComparedTo(previous), RecoveryTrend.flat);
    });

    test('returns flat when difference is within (-5, 5) range — negative side', () {
      final current = makeEntity(recoveryScore: 67.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = -3
      expect(current.getTrendComparedTo(previous), RecoveryTrend.flat);
    });

    test('boundary: exactly +5 returns flat (not up)', () {
      // diff > 5 required for up; exactly 5 does not satisfy >
      final current = makeEntity(recoveryScore: 75.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = exactly +5
      expect(current.getTrendComparedTo(previous), RecoveryTrend.flat);
    });

    test('boundary: exactly -5 returns flat (not down)', () {
      // diff < -5 required for down; exactly -5 does not satisfy <
      final current = makeEntity(recoveryScore: 65.0);
      final previous = makeEntity(recoveryScore: 70.0); // diff = exactly -5
      expect(current.getTrendComparedTo(previous), RecoveryTrend.flat);
    });

    test('boundary: +5.1 returns up', () {
      final current = makeEntity(recoveryScore: 75.1);
      final previous = makeEntity(recoveryScore: 70.0); // diff = +5.1
      expect(current.getTrendComparedTo(previous), RecoveryTrend.up);
    });

    test('boundary: -5.1 returns down', () {
      final current = makeEntity(recoveryScore: 64.9);
      final previous = makeEntity(recoveryScore: 70.0); // diff = -5.1
      expect(current.getTrendComparedTo(previous), RecoveryTrend.down);
    });
  });

  // ===========================================================================
  // 10. componentBreakdown
  // ===========================================================================
  group('componentBreakdown', () {
    test('formats all four components with bullet separator', () {
      final entity = makeEntity(
        stressComponent: 75.0,
        sleepComponent: 80.0,
        hrComponent: 70.0,
        loadComponent: 65.0,
      );

      expect(
        entity.componentBreakdown,
        'Stress: 75 • Sleep: 80 • HR: 70 • Load: 65',
      );
    });

    test('rounds fractional values to the nearest integer', () {
      final entity = makeEntity(
        stressComponent: 74.6,
        sleepComponent: 80.4,
        hrComponent: 70.5,
        loadComponent: 65.9,
      );

      // toStringAsFixed(0) rounds half-up; verify the expected strings.
      expect(entity.componentBreakdown, contains('Stress: 75'));
      expect(entity.componentBreakdown, contains('Sleep: 80'));
      expect(entity.componentBreakdown, contains('HR: 71'));
      expect(entity.componentBreakdown, contains('Load: 66'));
    });

    test('omits null stress component from output', () {
      final entity = makeEntity(stressComponent: null);
      final breakdown = entity.componentBreakdown;

      expect(breakdown, isNot(contains('Stress')));
      expect(breakdown, contains('Sleep'));
      expect(breakdown, contains('HR'));
      expect(breakdown, contains('Load'));
    });

    test('omits null sleep component from output', () {
      final entity = makeEntity(sleepComponent: null);
      final breakdown = entity.componentBreakdown;

      expect(breakdown, isNot(contains('Sleep')));
      expect(breakdown, contains('Stress'));
    });

    test('omits null HR component from output', () {
      final entity = makeEntity(hrComponent: null);
      final breakdown = entity.componentBreakdown;

      expect(breakdown, isNot(contains('HR')));
    });

    test('omits null load component from output', () {
      final entity = makeEntity(loadComponent: null);
      final breakdown = entity.componentBreakdown;

      expect(breakdown, isNot(contains('Load')));
    });

    test('returns empty string when all components are null', () {
      final entity = makeEntity(
        stressComponent: null,
        sleepComponent: null,
        hrComponent: null,
        loadComponent: null,
      );

      expect(entity.componentBreakdown, '');
    });

    test('returns single label without bullet when only one component present', () {
      final entity = makeEntity(
        stressComponent: 60.0,
        sleepComponent: null,
        hrComponent: null,
        loadComponent: null,
      );

      expect(entity.componentBreakdown, 'Stress: 60');
      expect(entity.componentBreakdown, isNot(contains('•')));
    });

    test('two components are separated by a single bullet', () {
      final entity = makeEntity(
        stressComponent: 60.0,
        sleepComponent: 70.0,
        hrComponent: null,
        loadComponent: null,
      );

      expect(entity.componentBreakdown, 'Stress: 60 • Sleep: 70');
    });

    test('three components have two bullets and correct ordering', () {
      final entity = makeEntity(
        stressComponent: 55.0,
        sleepComponent: 65.0,
        hrComponent: 75.0,
        loadComponent: null,
      );

      expect(entity.componentBreakdown, 'Stress: 55 • Sleep: 65 • HR: 75');
    });
  });

  // ===========================================================================
  // 11. copyWith
  // ===========================================================================
  group('copyWith', () {
    test('calling copyWith with no arguments returns an equivalent entity', () {
      final original = makeEntity(rawData: {'key': 'value'});
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.profileId, original.profileId);
      expect(copy.scoreDate, original.scoreDate);
      expect(copy.stressComponent, original.stressComponent);
      expect(copy.sleepComponent, original.sleepComponent);
      expect(copy.hrComponent, original.hrComponent);
      expect(copy.loadComponent, original.loadComponent);
      expect(copy.recoveryScore, original.recoveryScore);
      expect(copy.componentsAvailable, original.componentsAvailable);
      expect(copy.rawData, original.rawData);
    });

    test('copyWith returns a new instance, not the same reference', () {
      final original = makeEntity();
      final copy = original.copyWith();

      expect(identical(original, copy), isFalse);
    });

    test('can update a single field — recoveryScore', () {
      final original = makeEntity(recoveryScore: 72.5);
      final updated = original.copyWith(recoveryScore: 85.0);

      expect(updated.recoveryScore, 85.0);
      // All other fields remain unchanged.
      expect(updated.id, original.id);
      expect(updated.profileId, original.profileId);
      expect(updated.componentsAvailable, original.componentsAvailable);
    });

    test('can update id while keeping all other fields', () {
      final original = makeEntity();
      final updated = original.copyWith(id: 'new-id-999');

      expect(updated.id, 'new-id-999');
      expect(updated.profileId, original.profileId);
      expect(updated.recoveryScore, original.recoveryScore);
    });

    test('can update profileId while keeping all other fields', () {
      final original = makeEntity();
      final updated = original.copyWith(profileId: 'profile-xyz');

      expect(updated.profileId, 'profile-xyz');
      expect(updated.id, original.id);
    });

    test('can update scoreDate to a new date', () {
      final original = makeEntity();
      final newDate = DateTime(2026, 3, 1);
      final updated = original.copyWith(scoreDate: newDate);

      expect(updated.scoreDate, newDate);
      expect(updated.id, original.id);
    });

    test('can update stressComponent to a new value', () {
      final original = makeEntity(stressComponent: 75.0);
      final updated = original.copyWith(stressComponent: 90.0);

      expect(updated.stressComponent, 90.0);
      expect(updated.sleepComponent, original.sleepComponent);
    });

    test('can update componentsAvailable independently', () {
      final original = makeEntity(componentsAvailable: 4);
      final updated = original.copyWith(componentsAvailable: 2);

      expect(updated.componentsAvailable, 2);
      expect(updated.recoveryScore, original.recoveryScore);
    });

    test('can update multiple fields simultaneously', () {
      final original = makeEntity(recoveryScore: 72.5, componentsAvailable: 4);
      final updated = original.copyWith(
        recoveryScore: 55.0,
        componentsAvailable: 2,
        hrComponent: null,
        loadComponent: null,
      );

      // Updated fields.
      expect(updated.recoveryScore, 55.0);
      expect(updated.componentsAvailable, 2);
      // Unchanged fields.
      expect(updated.id, original.id);
      expect(updated.profileId, original.profileId);
      expect(updated.stressComponent, original.stressComponent);
      expect(updated.sleepComponent, original.sleepComponent);
    });

    test('can update rawData map', () {
      final original = makeEntity(rawData: {'old': true});
      final updated = original.copyWith(rawData: {'new': false, 'count': 5});

      expect(updated.rawData, {'new': false, 'count': 5});
      expect(original.rawData, {'old': true}); // original is immutable
    });

    test('updated entity produces correct interpretationLabel', () {
      final original = makeEntity(recoveryScore: 72.5); // Good
      final updated = original.copyWith(recoveryScore: 90.0); // Excellent

      expect(original.interpretationLabel, 'Good');
      expect(updated.interpretationLabel, 'Excellent');
    });

    test('updated entity produces correct colorCode', () {
      final original = makeEntity(recoveryScore: 72.5); // lightGreen
      final updated = original.copyWith(recoveryScore: 30.0); // orange

      expect(original.colorCode, RecoveryScoreColor.lightGreen);
      expect(updated.colorCode, RecoveryScoreColor.orange);
    });

    test('updated entity has correct isComplete based on new componentsAvailable', () {
      final original = makeEntity(componentsAvailable: 4);
      final updated = original.copyWith(componentsAvailable: 3);

      expect(original.isComplete, isTrue);
      expect(updated.isComplete, isFalse);
    });
  });
}
