import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/insights/data/performance_engine.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/features/insights/domain/recovery_score_entity.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

const _kProfileId = 'test-profile-001';
final _kDate = DateTime(2026, 2, 19);

/// Creates a [DataPoint] anchored [daysOffset] days after [baseline].
DataPoint makePoint(DateTime baseline, int daysOffset, double value) {
  return DataPoint(
    date: baseline.add(Duration(days: daysOffset)),
    value: value,
  );
}

void main() {
  // =========================================================================
  // 1. normalizeStress
  // =========================================================================

  group('PerformanceEngine.normalizeStress', () {
    test('stress of 0 produces maximum recovery score of 100', () {
      expect(PerformanceEngine.normalizeStress(0.0), 100.0);
    });

    test('stress of 50 produces mid-point score of 50', () {
      expect(PerformanceEngine.normalizeStress(50.0), 50.0);
    });

    test('stress of 100 produces minimum score of 0', () {
      expect(PerformanceEngine.normalizeStress(100.0), 0.0);
    });

    test('negative stress value is clamped to 100', () {
      // (100 - (-10)) = 110 → clamped to 100
      expect(PerformanceEngine.normalizeStress(-10.0), 100.0);
    });

    test('stress above 100 is clamped to 0', () {
      // (100 - 110) = -10 → clamped to 0
      expect(PerformanceEngine.normalizeStress(110.0), 0.0);
    });

    test('intermediate stress value of 25 produces score of 75', () {
      expect(PerformanceEngine.normalizeStress(25.0), 75.0);
    });

    test('intermediate stress value of 75 produces score of 25', () {
      expect(PerformanceEngine.normalizeStress(75.0), 25.0);
    });

    test('result is always within the 0–100 range for any input', () {
      for (final stress in [-100.0, 0.0, 25.0, 50.0, 75.0, 100.0, 200.0]) {
        final result = PerformanceEngine.normalizeStress(stress);
        expect(
          result,
          inInclusiveRange(0.0, 100.0),
          reason: 'stress=$stress produced out-of-range result $result',
        );
      }
    });
  });

  // =========================================================================
  // 2. normalizeSleep
  // =========================================================================

  group('PerformanceEngine.normalizeSleep', () {
    group('Optimal range (420–540 minutes)', () {
      test('lower boundary 420 minutes produces 100', () {
        expect(PerformanceEngine.normalizeSleep(420.0), 100.0);
      });

      test('midpoint 480 minutes (8 hours) produces 100', () {
        expect(PerformanceEngine.normalizeSleep(480.0), 100.0);
      });

      test('upper boundary 540 minutes produces 100', () {
        expect(PerformanceEngine.normalizeSleep(540.0), 100.0);
      });
    });

    group('Below 420 minutes — linear penalty', () {
      test('zero minutes of sleep produces score of 0', () {
        // 0 / 420 * 100 = 0
        expect(PerformanceEngine.normalizeSleep(0.0), 0.0);
      });

      test('210 minutes (half of optimal lower bound) produces score of 50', () {
        // 210 / 420 * 100 = 50
        expect(PerformanceEngine.normalizeSleep(210.0), 50.0);
      });

      test('300 minutes produces score of approximately 71.43', () {
        // 300 / 420 * 100 ≈ 71.43
        expect(
          PerformanceEngine.normalizeSleep(300.0),
          closeTo(71.43, 0.01),
        );
      });

      test('score increases proportionally as duration approaches 420 minutes', () {
        final score315 = PerformanceEngine.normalizeSleep(315.0);
        final score360 = PerformanceEngine.normalizeSleep(360.0);
        expect(score360, greaterThan(score315));
      });
    });

    group('Above 540 minutes — gentle penalty (floor at 50)', () {
      test('600 minutes (1 hour over max) produces score of 90', () {
        // excess = 60; 100 - (60/60 * 10) = 90
        expect(PerformanceEngine.normalizeSleep(600.0), 90.0);
      });

      test('660 minutes (2 hours over max) produces score of 80', () {
        // excess = 120; 100 - (120/60 * 10) = 80
        expect(PerformanceEngine.normalizeSleep(660.0), 80.0);
      });

      test('840 minutes (5 hours over max) reaches the floor at 50', () {
        // excess = 300; 100 - (300/60 * 10) = 50
        expect(PerformanceEngine.normalizeSleep(840.0), 50.0);
      });

      test('extreme over-sleep (900 minutes) is clamped to floor of 50', () {
        // excess = 360; 100 - (360/60 * 10) = 40 → clamped to 50
        expect(PerformanceEngine.normalizeSleep(900.0), 50.0);
      });

      test('score never drops below 50 regardless of over-sleep amount', () {
        for (final duration in [840.0, 900.0, 1080.0, 1440.0]) {
          final result = PerformanceEngine.normalizeSleep(duration);
          expect(
            result,
            greaterThanOrEqualTo(50.0),
            reason: 'duration=$duration produced score below 50',
          );
        }
      });
    });

    group('With qualityScore — 70% duration + 30% quality blend', () {
      test('optimal duration with quality=70 blends to 91', () {
        // 100*0.7 + 70*0.3 = 70 + 21 = 91
        expect(
          PerformanceEngine.normalizeSleep(480.0, qualityScore: 70.0),
          closeTo(91.0, 0.001),
        );
      });

      test('optimal duration with quality=100 blends to 100', () {
        // 100*0.7 + 100*0.3 = 70 + 30 = 100
        expect(
          PerformanceEngine.normalizeSleep(480.0, qualityScore: 100.0),
          100.0,
        );
      });

      test('optimal duration with quality=0 blends to 70', () {
        // 100*0.7 + 0*0.3 = 70
        expect(
          PerformanceEngine.normalizeSleep(480.0, qualityScore: 0.0),
          70.0,
        );
      });

      test('sub-optimal duration 210min with quality=80 blends to 59', () {
        // durationScore=50; 50*0.7 + 80*0.3 = 35 + 24 = 59
        expect(
          PerformanceEngine.normalizeSleep(210.0, qualityScore: 80.0),
          closeTo(59.0, 0.001),
        );
      });

      test('result is clamped to 0–100 even with extreme quality inputs', () {
        final result = PerformanceEngine.normalizeSleep(480.0, qualityScore: 150.0);
        expect(result, lessThanOrEqualTo(100.0));
      });
    });
  });

  // =========================================================================
  // 3. normalizeHR
  // =========================================================================

  group('PerformanceEngine.normalizeHR', () {
    test('currentHr equals baselineHr (deviation = 0) produces 100', () {
      expect(PerformanceEngine.normalizeHR(60.0, 60.0), 100.0);
    });

    test('currentHr below baselineHr (deviation < 0) produces 100', () {
      // Lower resting HR than baseline = better recovery
      expect(PerformanceEngine.normalizeHR(55.0, 60.0), 100.0);
    });

    test('deviation of +5 bpm produces score of 80', () {
      // 100 - (5 * 4) = 80
      expect(PerformanceEngine.normalizeHR(65.0, 60.0), 80.0);
    });

    test('deviation of +10 bpm produces score of 60', () {
      // 100 - (10 * 4) = 60
      expect(PerformanceEngine.normalizeHR(70.0, 60.0), 60.0);
    });

    test('deviation of +15 bpm produces score of 40', () {
      // 100 - (15 * 4) = 40
      expect(PerformanceEngine.normalizeHR(75.0, 60.0), 40.0);
    });

    test('deviation of +25 bpm produces score of 0', () {
      // 100 - (25 * 4) = 0
      expect(PerformanceEngine.normalizeHR(85.0, 60.0), 0.0);
    });

    test('large deviation (+30 bpm) is clamped to 0 (not negative)', () {
      // 100 - (30 * 4) = -20 → clamped to 0
      expect(PerformanceEngine.normalizeHR(90.0, 60.0), 0.0);
    });

    test('very large negative deviation is clamped to 100', () {
      expect(PerformanceEngine.normalizeHR(30.0, 80.0), 100.0);
    });

    test('score decreases linearly for increasing positive deviations', () {
      final score5 = PerformanceEngine.normalizeHR(65.0, 60.0);   // +5 → 80
      final score10 = PerformanceEngine.normalizeHR(70.0, 60.0);  // +10 → 60
      final score15 = PerformanceEngine.normalizeHR(75.0, 60.0);  // +15 → 40
      expect(score5, greaterThan(score10));
      expect(score10, greaterThan(score15));
    });
  });

  // =========================================================================
  // 4. normalizeLoad
  // =========================================================================

  group('PerformanceEngine.normalizeLoad', () {
    group('previousLoad == 0 edge cases', () {
      test('both loads zero returns 100 (no training = fully rested)', () {
        expect(PerformanceEngine.normalizeLoad(0.0, 0.0), 100.0);
      });

      test('previous=0 and current>0 returns 80 (new training, uncertain)', () {
        expect(PerformanceEngine.normalizeLoad(100.0, 0.0), 80.0);
      });
    });

    group('Ratio-based scoring bands', () {
      test('ratio < 0.7 (significant recovery week) returns 100', () {
        // ratio = 50/100 = 0.5
        expect(PerformanceEngine.normalizeLoad(50.0, 100.0), 100.0);
      });

      test('exact boundary ratio = 0.7 falls into the <1.0 band and returns 90', () {
        // ratio = 70/100 = 0.7; not <0.7, is <1.0 → 90
        expect(PerformanceEngine.normalizeLoad(70.0, 100.0), 90.0);
      });

      test('ratio = 0.9 (light recovery week) returns 90', () {
        // ratio = 90/100 = 0.9
        expect(PerformanceEngine.normalizeLoad(90.0, 100.0), 90.0);
      });

      test('exact boundary ratio = 1.0 falls into <=1.2 band and returns 75', () {
        // ratio = 100/100 = 1.0; not <1.0, is <=1.2 → 75
        expect(PerformanceEngine.normalizeLoad(100.0, 100.0), 75.0);
      });

      test('ratio = 1.1 (maintaining load) returns 75', () {
        // ratio = 110/100 = 1.1
        expect(PerformanceEngine.normalizeLoad(110.0, 100.0), 75.0);
      });

      test('exact boundary ratio = 1.2 falls into <=1.2 band and returns 75', () {
        // ratio = 120/100 = 1.2; <=1.2 → 75
        expect(PerformanceEngine.normalizeLoad(120.0, 100.0), 75.0);
      });

      test('ratio = 1.25 (slight overreach) returns 60', () {
        // ratio = 125/100 = 1.25
        expect(PerformanceEngine.normalizeLoad(125.0, 100.0), 60.0);
      });

      test('exact boundary ratio = 1.3 falls into <=1.3 band and returns 60', () {
        // ratio = 130/100 = 1.3; <=1.3 → 60
        expect(PerformanceEngine.normalizeLoad(130.0, 100.0), 60.0);
      });

      test('ratio = 1.4 (overreaching) returns 40', () {
        // ratio = 140/100 = 1.4
        expect(PerformanceEngine.normalizeLoad(140.0, 100.0), 40.0);
      });

      test('exact boundary ratio = 1.5 falls into <=1.5 band and returns 40', () {
        // ratio = 150/100 = 1.5; <=1.5 → 40
        expect(PerformanceEngine.normalizeLoad(150.0, 100.0), 40.0);
      });

      test('ratio = 2.0 (potential overtraining) returns 20', () {
        // ratio = 200/100 = 2.0; >1.5 → 20
        expect(PerformanceEngine.normalizeLoad(200.0, 100.0), 20.0);
      });
    });
  });

  // =========================================================================
  // 5. calculateRecoveryScore
  // =========================================================================

  group('PerformanceEngine.calculateRecoveryScore', () {
    /// Weights from the engine source:
    ///   stress=0.25, sleep=0.30, hr=0.20, load=0.25
    /// Weighted average = sum(value*weight) / sum(weights)

    group('All four components provided', () {
      test('returns correct weighted average when all components are present', () {
        // stress=50  → normalizeStress(50) = 50.0
        // sleep=480  → normalizeSleep(480) = 100.0
        // hr (60/60) → normalizeHR(60, 60)  = 100.0
        // load(100,100) → normalizeLoad(100,100) = 75.0
        // weighted = (50*0.25 + 100*0.30 + 100*0.20 + 75*0.25) / 1.0
        //          = (12.5 + 30 + 20 + 18.75) = 81.25
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 50.0,
          sleepDurationMin: 480.0,
          restingHr: 60.0,
          baselineHr: 60.0,
          currentWeekLoad: 100.0,
          previousWeekLoad: 100.0,
        );

        expect(result.recoveryScore, closeTo(81.25, 0.001));
        expect(result.componentsAvailable, 4);
        expect(result.stressComponent, closeTo(50.0, 0.001));
        expect(result.sleepComponent, closeTo(100.0, 0.001));
        expect(result.hrComponent, closeTo(100.0, 0.001));
        expect(result.loadComponent, closeTo(75.0, 0.001));
      });

      test('populates profileId and scoreDate on the returned entity', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 30.0,
          sleepDurationMin: 480.0,
          restingHr: 60.0,
          baselineHr: 60.0,
          currentWeekLoad: 80.0,
          previousWeekLoad: 100.0,
        );

        expect(result.profileId, _kProfileId);
        expect(result.scoreDate, _kDate);
      });
    });

    group('Missing components — weights are rebalanced', () {
      test('only stress and sleep provided — weighted average uses combined weight 0.55', () {
        // stress=50 → 50.0; sleep=480 → 100.0
        // sum   = 50*0.25 + 100*0.30 = 12.5 + 30 = 42.5
        // total weight = 0.25 + 0.30 = 0.55
        // score = 42.5 / 0.55 ≈ 77.27
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 50.0,
          sleepDurationMin: 480.0,
        );

        expect(result.recoveryScore, closeTo(77.27, 0.01));
        expect(result.componentsAvailable, 2);
        expect(result.hrComponent, isNull);
        expect(result.loadComponent, isNull);
      });

      test('HR component absent leaves hrComponent null and reduces component count', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 0.0,
          sleepDurationMin: 480.0,
          currentWeekLoad: 50.0,
          previousWeekLoad: 100.0,
        );

        expect(result.hrComponent, isNull);
        expect(result.componentsAvailable, 3);
      });

      test('load component absent (missing currentWeekLoad) leaves loadComponent null', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 20.0,
          sleepDurationMin: 480.0,
          restingHr: 60.0,
          baselineHr: 60.0,
        );

        expect(result.loadComponent, isNull);
        expect(result.componentsAvailable, 3);
      });

      test('load component absent (missing previousWeekLoad only) leaves loadComponent null', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          currentWeekLoad: 100.0,
          // previousWeekLoad intentionally omitted
        );

        expect(result.loadComponent, isNull);
      });
    });

    group('Only stress provided', () {
      test('single stress component — score equals the normalised stress value', () {
        // normalizeStress(50) = 50.0; weighted = 50*0.25 / 0.25 = 50.0
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 50.0,
        );

        expect(result.recoveryScore, closeTo(50.0, 0.001));
        expect(result.componentsAvailable, 1);
        expect(result.stressComponent, closeTo(50.0, 0.001));
        expect(result.sleepComponent, isNull);
        expect(result.hrComponent, isNull);
        expect(result.loadComponent, isNull);
      });

      test('zero stress produces score of 100 (perfect recovery from stress side)', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 0.0,
        );

        expect(result.recoveryScore, closeTo(100.0, 0.001));
      });
    });

    group('Only sleep provided', () {
      test('single sleep component — score equals the normalised sleep value', () {
        // normalizeSleep(480) = 100.0; weighted = 100*0.30 / 0.30 = 100.0
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          sleepDurationMin: 480.0,
        );

        expect(result.recoveryScore, closeTo(100.0, 0.001));
        expect(result.componentsAvailable, 1);
        expect(result.sleepComponent, closeTo(100.0, 0.001));
        expect(result.stressComponent, isNull);
        expect(result.hrComponent, isNull);
        expect(result.loadComponent, isNull);
      });

      test('short sleep of 210 minutes produces score of 50', () {
        // normalizeSleep(210) = 50; weighted = 50*0.30 / 0.30 = 50
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          sleepDurationMin: 210.0,
        );

        expect(result.recoveryScore, closeTo(50.0, 0.001));
      });
    });

    group('No components provided', () {
      test('score is 0 when no data is available', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
        );

        expect(result.recoveryScore, 0.0);
        expect(result.componentsAvailable, 0);
        expect(result.stressComponent, isNull);
        expect(result.sleepComponent, isNull);
        expect(result.hrComponent, isNull);
        expect(result.loadComponent, isNull);
      });
    });

    group('Entity structure', () {
      test('returns a RecoveryScoreEntity with the correct runtime type', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 25.0,
        );

        expect(result, isA<RecoveryScoreEntity>());
      });

      test('rawData map contains all input fields including null ones', () {
        final result = PerformanceEngine.calculateRecoveryScore(
          profileId: _kProfileId,
          date: _kDate,
          stressAvg: 30.0,
          sleepDurationMin: 420.0,
        );

        expect(result.rawData, isNotNull);
        expect(result.rawData!.containsKey('stress_avg'), isTrue);
        expect(result.rawData!.containsKey('sleep_duration_min'), isTrue);
        expect(result.rawData!.containsKey('resting_hr'), isTrue);
        expect(result.rawData!['stress_avg'], 30.0);
        expect(result.rawData!['sleep_duration_min'], 420.0);
        expect(result.rawData!['resting_hr'], isNull);
      });
    });
  });

  // =========================================================================
  // 6. calculateTrainingLoad
  // =========================================================================

  group('PerformanceEngine.calculateTrainingLoad', () {
    test('60 minutes at intensity factor 1.0 returns load of 60', () {
      expect(PerformanceEngine.calculateTrainingLoad(60.0, 1.0), 60.0);
    });

    test('90 minutes at intensity factor 1.5 returns load of 135', () {
      expect(PerformanceEngine.calculateTrainingLoad(90.0, 1.5), 135.0);
    });

    test('zero duration produces zero load regardless of intensity', () {
      expect(PerformanceEngine.calculateTrainingLoad(0.0, 2.0), 0.0);
    });

    test('45 minutes at light intensity 0.5 returns load of 22.5', () {
      expect(PerformanceEngine.calculateTrainingLoad(45.0, 0.5), 22.5);
    });

    test('120 minutes at very hard intensity 2.0 returns load of 240', () {
      expect(PerformanceEngine.calculateTrainingLoad(120.0, 2.0), 240.0);
    });

    test('result equals duration * intensityFactor (general multiplication)', () {
      expect(
        PerformanceEngine.calculateTrainingLoad(75.0, 1.25),
        closeTo(75.0 * 1.25, 0.0001),
      );
    });
  });

  // =========================================================================
  // 7. intensityFromHR
  // =========================================================================

  group('PerformanceEngine.intensityFromHR', () {
    // Fixture: resting=60, max=200, hrReserve=140
    // Karvonen intensity = (avgHr - resting) / hrReserve
    // Zone boundaries:
    //   <0.6  → 0.5  (avgHr < 60 + 0.6*140 = 144)
    //   <0.7  → 0.75 (avgHr < 60 + 0.7*140 = 158)
    //   <0.8  → 1.0  (avgHr < 60 + 0.8*140 = 172)
    //   <0.9  → 1.5  (avgHr < 60 + 0.9*140 = 186)
    //   >=0.9 → 2.0

    const resting = 60.0;
    const max = 200.0;

    group('hrReserve <= 0 guard', () {
      test('returns 1.0 when resting equals max (hrReserve = 0)', () {
        expect(PerformanceEngine.intensityFromHR(150.0, 200.0, 200.0), 1.0);
      });

      test('returns 1.0 when resting exceeds max (hrReserve < 0)', () {
        expect(PerformanceEngine.intensityFromHR(180.0, 200.0, 180.0), 1.0);
      });
    });

    group('Zone 1 — intensity < 0.6 → factor 0.5', () {
      test('avgHr of 120 yields intensity 0.43 (Zone 1) → factor 0.5', () {
        // (120-60)/140 ≈ 0.4286 < 0.6
        expect(PerformanceEngine.intensityFromHR(120.0, resting, max), 0.5);
      });

      test('avgHr just below Zone 2 boundary (143) → factor 0.5', () {
        // (143-60)/140 ≈ 0.5929 < 0.6
        expect(PerformanceEngine.intensityFromHR(143.0, resting, max), 0.5);
      });
    });

    group('Zone 2 — intensity 0.6–0.7 → factor 0.75', () {
      test('avgHr at exact Zone 2 lower boundary (144) → factor 0.75', () {
        // (144-60)/140 = 0.6 → NOT <0.6, IS <0.7
        expect(PerformanceEngine.intensityFromHR(144.0, resting, max), 0.75);
      });

      test('avgHr at Zone 2 midpoint (151) → factor 0.75', () {
        // (151-60)/140 ≈ 0.65 → Zone 2
        expect(PerformanceEngine.intensityFromHR(151.0, resting, max), 0.75);
      });

      test('avgHr just below Zone 3 boundary (157) → factor 0.75', () {
        // (157-60)/140 ≈ 0.6929 < 0.7
        expect(PerformanceEngine.intensityFromHR(157.0, resting, max), 0.75);
      });
    });

    group('Zone 3 — intensity 0.7–0.8 → factor 1.0', () {
      test('avgHr at exact Zone 3 lower boundary (158) → factor 1.0', () {
        // (158-60)/140 = 0.7 → NOT <0.7, IS <0.8
        expect(PerformanceEngine.intensityFromHR(158.0, resting, max), 1.0);
      });

      test('avgHr at Zone 3 midpoint (165) → factor 1.0', () {
        // (165-60)/140 = 0.75 → Zone 3
        expect(PerformanceEngine.intensityFromHR(165.0, resting, max), 1.0);
      });

      test('avgHr just below Zone 4 boundary (171) → factor 1.0', () {
        // (171-60)/140 ≈ 0.7929 < 0.8
        expect(PerformanceEngine.intensityFromHR(171.0, resting, max), 1.0);
      });
    });

    group('Zone 4 — intensity 0.8–0.9 → factor 1.5', () {
      test('avgHr at exact Zone 4 lower boundary (172) → factor 1.5', () {
        // (172-60)/140 = 0.8 → NOT <0.8, IS <0.9
        expect(PerformanceEngine.intensityFromHR(172.0, resting, max), 1.5);
      });

      test('avgHr at Zone 4 midpoint (179) → factor 1.5', () {
        // (179-60)/140 ≈ 0.85 → Zone 4
        expect(PerformanceEngine.intensityFromHR(179.0, resting, max), 1.5);
      });

      test('avgHr just below Zone 5 boundary (185) → factor 1.5', () {
        // (185-60)/140 ≈ 0.8929 < 0.9
        expect(PerformanceEngine.intensityFromHR(185.0, resting, max), 1.5);
      });
    });

    group('Zone 5 — intensity >= 0.9 → factor 2.0', () {
      test('avgHr at exact Zone 5 lower boundary (186) → factor 2.0', () {
        // (186-60)/140 = 0.9 → NOT <0.9 → 2.0
        expect(PerformanceEngine.intensityFromHR(186.0, resting, max), 2.0);
      });

      test('avgHr at max heart rate (200) → factor 2.0', () {
        // (200-60)/140 = 1.0 → Zone 5
        expect(PerformanceEngine.intensityFromHR(200.0, resting, max), 2.0);
      });

      test('avgHr above max HR → still factor 2.0', () {
        expect(PerformanceEngine.intensityFromHR(210.0, resting, max), 2.0);
      });
    });
  });

  // =========================================================================
  // 8. calculateForecast
  // =========================================================================

  group('PerformanceEngine.calculateForecast', () {
    final baseline = DateTime(2026, 1, 1);

    group('Guard — empty data points', () {
      test('throws ArgumentError when dataPoints list is empty', () {
        expect(
          () => PerformanceEngine.calculateForecast(
            profileId: _kProfileId,
            metricType: 'weight',
            targetValue: 80.0,
            dataPoints: [],
            baselineDate: baseline,
          ),
          throwsArgumentError,
        );
      });
    });

    group('Known perfectly linear data — weight loss scenario', () {
      // Data: day 0 → 90, day 7 → 83, day 14 → 76 (perfectly linear)
      // Linear regression yields:
      //   xMean = 7, yMean = 83
      //   numerator  = (-7*7) + (0*0) + (7*-7) = -98
      //   denominator = 49 + 0 + 49 = 98
      //   slope     = -98/98 = -1.0
      //   intercept = 83 - (-1)*7 = 90.0
      //   rSquared  = 1.0 (perfect fit, ssRes = 0)
      // Target = 55.0:
      //   daysToTarget = round((55 - 90) / -1.0) = 35
      //   projectedDate = baseline + 35 days

      late List<DataPoint> linearPoints;

      setUp(() {
        linearPoints = [
          makePoint(baseline, 0, 90.0),
          makePoint(baseline, 7, 83.0),
          makePoint(baseline, 14, 76.0),
        ];
      });

      test('slope is exactly -1.0 per day', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.slope, closeTo(-1.0, 0.0001));
      });

      test('intercept is exactly 90.0 (day-0 value)', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.intercept, closeTo(90.0, 0.0001));
      });

      test('rSquared is 1.0 for perfectly linear data', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.rSquared, closeTo(1.0, 0.0001));
      });

      test('projectedDate is 35 days from baseline for target=55', () {
        // (55 - 90) / -1 = 35 days → baseline + 35 days
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.projectedDate, isNotNull);
        expect(
          result.projectedDate,
          baseline.add(const Duration(days: 35)),
        );
      });

      test('currentValue equals the value of the most recent data point', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        // Most recent point is day 14 → value 76
        expect(result.currentValue, 76.0);
      });

      test('metricType and targetValue are stored on the entity', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.metricType, 'weight');
        expect(result.targetValue, 55.0);
        expect(result.dataPoints, linearPoints.length);
        expect(result.modelType, 'linear_regression');
      });

      test('goalForecastId is passed through when provided', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
          goalForecastId: 'goal-001',
        );

        expect(result.goalForecastId, 'goal-001');
      });

      test('goalForecastId is null when omitted', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );

        expect(result.goalForecastId, isNull);
      });

      test('data points are sorted before regression — unordered input produces same result', () {
        // Shuffle the perfectly linear points to verify sorting
        final shuffled = [
          makePoint(baseline, 14, 76.0),
          makePoint(baseline, 0, 90.0),
          makePoint(baseline, 7, 83.0),
        ];

        final orderedResult = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: linearPoints,
          baselineDate: baseline,
        );
        final shuffledResult = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: shuffled,
          baselineDate: baseline,
        );

        expect(shuffledResult.slope, closeTo(orderedResult.slope, 0.0001));
        expect(shuffledResult.intercept, closeTo(orderedResult.intercept, 0.0001));
        expect(shuffledResult.projectedDate, orderedResult.projectedDate);
      });
    });

    group('Single data point — slope is zero (n < 2)', () {
      test('returns slope of 0 for a single data point', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 80.0,
          dataPoints: [makePoint(baseline, 0, 90.0)],
          baselineDate: baseline,
        );

        expect(result.slope, 0.0);
      });

      test('projectedDate is null when slope is 0 and target is not met', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 80.0,
          dataPoints: [makePoint(baseline, 0, 90.0)],
          baselineDate: baseline,
        );

        expect(result.projectedDate, isNull);
      });

      test('currentValue matches the single point value', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 80.0,
          dataPoints: [makePoint(baseline, 0, 90.0)],
          baselineDate: baseline,
        );

        expect(result.currentValue, 90.0);
      });
    });

    group('Flat data — all values identical', () {
      // y = [80, 80, 80] at x = [0, 7, 14]
      // numerator = 0 for all terms → slope = 0

      test('slope is approximately 0 when all values are identical', () {
        final flatPoints = [
          makePoint(baseline, 0, 80.0),
          makePoint(baseline, 7, 80.0),
          makePoint(baseline, 14, 80.0),
        ];

        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 70.0,
          dataPoints: flatPoints,
          baselineDate: baseline,
        );

        expect(result.slope, closeTo(0.0, 0.0001));
      });

      test('projectedDate is null when trend is flat and target differs', () {
        final flatPoints = [
          makePoint(baseline, 0, 80.0),
          makePoint(baseline, 7, 80.0),
          makePoint(baseline, 14, 80.0),
        ];

        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 70.0,
          dataPoints: flatPoints,
          baselineDate: baseline,
        );

        expect(result.projectedDate, isNull);
      });
    });

    group('Data trending in the wrong direction', () {
      // Points: day 0 → 90, day 7 → 97, day 14 → 104 (slope = +1.0/day)
      // target = 55 (want to decrease but slope is positive)
      // daysToTarget = (55 - 90) / 1.0 = -35 (negative → no valid projection)

      test('projectedDate is null when trend is opposite to target direction', () {
        final wrongDirectionPoints = [
          makePoint(baseline, 0, 90.0),
          makePoint(baseline, 7, 97.0),
          makePoint(baseline, 14, 104.0),
        ];

        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: wrongDirectionPoints,
          baselineDate: baseline,
        );

        expect(result.projectedDate, isNull);
      });

      test('slope is positive for upward-trending data', () {
        final wrongDirectionPoints = [
          makePoint(baseline, 0, 90.0),
          makePoint(baseline, 7, 97.0),
          makePoint(baseline, 14, 104.0),
        ];

        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: wrongDirectionPoints,
          baselineDate: baseline,
        );

        expect(result.slope, closeTo(1.0, 0.0001));
      });
    });

    group('Projection guard — daysToTarget outside valid window', () {
      test('projectedDate is null when daysToTarget exceeds 3650 (10 years)', () {
        // With an extremely gentle slope, the target will be unreachably far
        // day0=100, day1=99.9999 → slope ~ -0.0001/day
        // target=0: daysToTarget = (0 - 100) / -0.0001 = 1_000_000 days → null
        final gentlePoints = [
          makePoint(baseline, 0, 100.0),
          makePoint(baseline, 1, 99.9999),
        ];

        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'vo2max',
          targetValue: 0.0,
          dataPoints: gentlePoints,
          baselineDate: baseline,
        );

        expect(result.projectedDate, isNull);
      });
    });

    group('Returned ForecastEntity structure', () {
      test('returns a ForecastEntity with the correct runtime type', () {
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: [
            makePoint(baseline, 0, 90.0),
            makePoint(baseline, 7, 83.0),
            makePoint(baseline, 14, 76.0),
          ],
          baselineDate: baseline,
        );

        expect(result, isA<ForecastEntity>());
      });

      test('calculatedAt is set to approximately now', () {
        final before = DateTime.now();
        final result = PerformanceEngine.calculateForecast(
          profileId: _kProfileId,
          metricType: 'weight',
          targetValue: 55.0,
          dataPoints: [
            makePoint(baseline, 0, 90.0),
            makePoint(baseline, 7, 83.0),
          ],
          baselineDate: baseline,
        );
        final after = DateTime.now();

        expect(
          result.calculatedAt.isAfter(before) ||
              result.calculatedAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          result.calculatedAt.isBefore(after) ||
              result.calculatedAt.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });
  });

  // =========================================================================
  // 9. checkOvertrainingRisk
  // =========================================================================

  group('PerformanceEngine.checkOvertrainingRisk', () {
    group('previousLoad == 0 guard', () {
      test('returns none when previousLoad is 0 regardless of currentLoad', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(200.0, 0.0),
          OvertrainingRisk.none,
        );
      });

      test('returns none when both loads are 0', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(0.0, 0.0),
          OvertrainingRisk.none,
        );
      });
    });

    group('none — ratio <= 1.3', () {
      test('ratio of 1.0 (same load) returns none', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(100.0, 100.0),
          OvertrainingRisk.none,
        );
      });

      test('ratio of 1.2 returns none', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(120.0, 100.0),
          OvertrainingRisk.none,
        );
      });

      test('exact boundary ratio of 1.3 returns none (> required for moderate)', () {
        // >1.3 required for moderate; 1.3 exactly is NOT >1.3
        expect(
          PerformanceEngine.checkOvertrainingRisk(130.0, 100.0),
          OvertrainingRisk.none,
        );
      });

      test('ratio below 1.0 (recovery week) returns none', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(80.0, 100.0),
          OvertrainingRisk.none,
        );
      });
    });

    group('moderate — ratio > 1.3 and <= 1.5', () {
      test('ratio of 1.35 returns moderate', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(135.0, 100.0),
          OvertrainingRisk.moderate,
        );
      });

      test('ratio just above 1.3 (1.31) returns moderate', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(131.0, 100.0),
          OvertrainingRisk.moderate,
        );
      });

      test('exact boundary ratio of 1.5 returns moderate (> 1.5 required for high)', () {
        // >1.5 required for high; 1.5 exactly is NOT >1.5 → moderate
        expect(
          PerformanceEngine.checkOvertrainingRisk(150.0, 100.0),
          OvertrainingRisk.moderate,
        );
      });
    });

    group('high — ratio > 1.5', () {
      test('ratio of 1.51 returns high', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(151.0, 100.0),
          OvertrainingRisk.high,
        );
      });

      test('ratio of 1.6 returns high', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(160.0, 100.0),
          OvertrainingRisk.high,
        );
      });

      test('ratio of 2.0 returns high', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(200.0, 100.0),
          OvertrainingRisk.high,
        );
      });

      test('extreme load spike (ratio = 5.0) returns high', () {
        expect(
          PerformanceEngine.checkOvertrainingRisk(500.0, 100.0),
          OvertrainingRisk.high,
        );
      });
    });

    group('OvertrainingRisk enum completeness', () {
      test('enum has exactly three values: none, moderate, high', () {
        expect(OvertrainingRisk.values.length, 3);
        expect(OvertrainingRisk.values, contains(OvertrainingRisk.none));
        expect(OvertrainingRisk.values, contains(OvertrainingRisk.moderate));
        expect(OvertrainingRisk.values, contains(OvertrainingRisk.high));
      });
    });
  });
}
