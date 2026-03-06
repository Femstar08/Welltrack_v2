import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/daily_coach/data/prescription_engine.dart';
import 'package:welltrack/features/daily_coach/domain/checkin_entity.dart';
import 'package:welltrack/features/daily_coach/domain/daily_prescription_entity.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const _kProfileId = 'test-profile-001';
final _kDate = DateTime(2026, 2, 22);

/// 3 PM — triggers steps-nudge checks.
final _k3PM = DateTime(2026, 2, 22, 15, 0);

/// 10 AM — before the 3 PM threshold.
final _k10AM = DateTime(2026, 2, 22, 10, 0);

CheckInEntity makeCheckIn({String? feeling, String? schedule}) {
  return CheckInEntity(
    profileId: _kProfileId,
    checkinDate: _kDate,
    feelingLevel: feeling,
    scheduleType: schedule,
  );
}

PrescriptionInput makeInput({
  CheckInEntity? checkIn,
  bool useNullCheckIn = false,
  int? sleepMinutes,
  double? restingHR,
  int? stepsToday,
  int? stepsGoal,
  double? weightTrend,
  bool hadHeavySession = false,
  int wakeHour = 7,
  DateTime? currentTime,
}) {
  return PrescriptionInput(
    profileId: _kProfileId,
    date: _kDate,
    checkIn: useNullCheckIn ? null : (checkIn ?? makeCheckIn()),
    sleepMinutes: sleepMinutes,
    restingHR: restingHR,
    stepsToday: stepsToday,
    stepsGoal: stepsGoal,
    weightTrend: weightTrend,
    hadHeavySessionYesterday: hadHeavySession,
    wakeHour: wakeHour,
    currentTime: currentTime ?? _k10AM,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Scenario 1: unwell
  // =========================================================================

  group('PrescriptionEngine — scenario: unwell', () {
    test('feeling=unwell produces rest + light + calorie deficit', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(checkIn: makeCheckIn(feeling: 'unwell')),
      );
      expect(result.scenario, PrescriptionScenario.unwell);
      expect(result.workoutDirective, WorkoutDirective.rest);
      expect(result.workoutVolumeModifier, 0.0);
      expect(result.mealDirective, MealDirective.light);
      expect(result.calorieModifier, -200);
      expect(result.hasWorkout, isFalse);
    });

    test('unwell overrides heavy-session-yesterday signal', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'unwell'),
          hadHeavySession: true,
        ),
      );
      expect(result.scenario, PrescriptionScenario.unwell);
    });

    test('unwell overrides busy schedule', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'unwell', schedule: 'busy'),
        ),
      );
      expect(result.scenario, PrescriptionScenario.unwell);
    });
  });

  // =========================================================================
  // Scenario 2: verySore
  // =========================================================================

  group('PrescriptionEngine — scenario: verySore', () {
    test('sore + heavy yesterday -> active_recovery + high_protein', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'sore'),
          hadHeavySession: true,
        ),
      );
      expect(result.scenario, PrescriptionScenario.verySore);
      expect(result.workoutDirective, WorkoutDirective.activeRecovery);
      expect(result.workoutVolumeModifier, 0.0);
      expect(result.mealDirective, MealDirective.highProtein);
      expect(result.calorieModifier, 0);
    });

    test('sore WITHOUT heavy yesterday does NOT trigger verySore', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'sore'),
          hadHeavySession: false,
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.verySore));
    });
  });

  // =========================================================================
  // Scenario 3: busyDay
  // =========================================================================

  group('PrescriptionEngine — scenario: busyDay', () {
    test('schedule=busy produces quick_session + grab_and_go', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(checkIn: makeCheckIn(feeling: 'good', schedule: 'busy')),
      );
      expect(result.scenario, PrescriptionScenario.busyDay);
      expect(result.workoutDirective, WorkoutDirective.quickSession);
      expect(result.workoutVolumeModifier, 0.6);
      expect(result.mealDirective, MealDirective.grabAndGo);
    });

    test('busyDay takes priority over wellRested signals', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'great', schedule: 'busy'),
          sleepMinutes: 480,
          restingHR: 55,
        ),
      );
      expect(result.scenario, PrescriptionScenario.busyDay);
    });
  });

  // =========================================================================
  // Scenario 4: wellRested
  // =========================================================================

  group('PrescriptionEngine — scenario: wellRested', () {
    test('7+ hours sleep + low RHR + great feeling -> full_session + standard',
        () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'great'),
          sleepMinutes: 420, // exactly 7 h
          restingHR: 60,
        ),
      );
      expect(result.scenario, PrescriptionScenario.wellRested);
      expect(result.workoutDirective, WorkoutDirective.fullSession);
      expect(result.workoutVolumeModifier, 1.0);
      expect(result.mealDirective, MealDirective.standard);
    });

    test('null restingHR still matches wellRested with 7+ h sleep + great', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'great'),
          sleepMinutes: 420,
          restingHR: null,
        ),
      );
      expect(result.scenario, PrescriptionScenario.wellRested);
    });

    test('RHR >= 65 blocks wellRested even with great feeling + 7+ h sleep',
        () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'great'),
          sleepMinutes: 420,
          restingHR: 65.0, // boundary — not < 65
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.wellRested));
    });

    test('sleep < 7 h blocks wellRested', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'great'),
          sleepMinutes: 419, // 6 h 59 min
          restingHR: 55,
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.wellRested));
    });
  });

  // =========================================================================
  // Scenario 5: tiredNotSore — sleep boundary tests
  // =========================================================================

  group('PrescriptionEngine — scenario: tiredNotSore', () {
    test('<6 h sleep + tired -> reduced_volume + extra_carbs', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'tired'),
          sleepMinutes: 359, // 5 h 59 min → < 6 h
        ),
      );
      expect(result.scenario, PrescriptionScenario.tiredNotSore);
      expect(result.workoutDirective, WorkoutDirective.reducedVolume);
      expect(result.workoutVolumeModifier, 0.8);
      expect(result.mealDirective, MealDirective.extraCarbs);
      expect(result.calorieModifier, 50);
    });

    test('exactly 360 min (6 h) does NOT trigger tiredNotSore', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'tired'),
          sleepMinutes: 360, // exactly 6 h — NOT < 6 h
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.tiredNotSore));
    });

    test('null feeling + <6 h sleep triggers tiredNotSore', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: null),
          sleepMinutes: 300,
        ),
      );
      expect(result.scenario, PrescriptionScenario.tiredNotSore);
    });

    test('stepsNudge is set for tiredNotSore', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'tired'),
          sleepMinutes: 300,
        ),
      );
      expect(result.stepsNudge, isNotNull);
    });
  });

  // =========================================================================
  // Scenario 6: behindSteps
  // =========================================================================

  group('PrescriptionEngine — scenario: behindSteps', () {
    test('after 3 PM with <40% of goal steps -> behindSteps', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          checkIn: makeCheckIn(feeling: 'good'),
          stepsToday: 3000,
          stepsGoal: 10000,
          currentTime: _k3PM,
        ),
      );
      // 40% of 10000 = 4000; 3000 < 4000 → behindSteps
      expect(result.scenario, PrescriptionScenario.behindSteps);
      expect(result.workoutDirective, WorkoutDirective.fullSession);
      expect(result.stepsNudge, isNotNull);
    });

    test('steps >= 40% goal does NOT trigger behindSteps', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          stepsToday: 4001,
          stepsGoal: 10000,
          currentTime: _k3PM,
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.behindSteps));
    });

    test('before 3 PM does NOT trigger behindSteps', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          stepsToday: 100,
          stepsGoal: 10000,
          currentTime: DateTime(2026, 2, 22, 14, 59),
        ),
      );
      expect(result.scenario, isNot(PrescriptionScenario.behindSteps));
    });

    test('stepsNudge message includes remaining steps count', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(
          stepsToday: 2000,
          stepsGoal: 10000,
          currentTime: _k3PM,
        ),
      );
      expect(result.stepsNudge, contains('8000'));
    });
  });

  // =========================================================================
  // Scenario 7: weightStalling
  // =========================================================================

  group('PrescriptionEngine — scenario: weightStalling', () {
    test('weight trend abs < 0.05 -> weightStalling + calorie -150', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(weightTrend: 0.02),
      );
      expect(result.scenario, PrescriptionScenario.weightStalling);
      expect(result.calorieModifier, -150);
      expect(result.workoutDirective, WorkoutDirective.fullSession);
    });

    test('exactly 0.05 does NOT trigger weightStalling (boundary)', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(weightTrend: 0.05),
      );
      expect(result.scenario, isNot(PrescriptionScenario.weightStalling));
    });

    test('losing fast (trend -0.1) does NOT trigger stalling', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(weightTrend: -0.1),
      );
      expect(result.scenario, isNot(PrescriptionScenario.weightStalling));
    });

    test('null weightTrend does NOT trigger weightStalling', () {
      final result = PrescriptionEngine.evaluate(makeInput());
      expect(result.scenario, isNot(PrescriptionScenario.weightStalling));
    });

    test('negative trend abs < 0.05 (nearly zero loss) triggers stalling', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(weightTrend: -0.02),
      );
      expect(result.scenario, PrescriptionScenario.weightStalling);
    });
  });

  // =========================================================================
  // Scenario 8: defaultPlan
  // =========================================================================

  group('PrescriptionEngine — scenario: defaultPlan', () {
    test('no special signals -> defaultPlan + full_session + standard', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(checkIn: makeCheckIn(feeling: 'good')),
      );
      expect(result.scenario, PrescriptionScenario.defaultPlan);
      expect(result.workoutDirective, WorkoutDirective.fullSession);
      expect(result.workoutVolumeModifier, 1.0);
      expect(result.mealDirective, MealDirective.standard);
      expect(result.calorieModifier, 0);
    });

    test('null check-in with no health data -> defaultPlan', () {
      final result = PrescriptionEngine.evaluate(
        makeInput(useNullCheckIn: true),
      );
      expect(result.scenario, PrescriptionScenario.defaultPlan);
    });
  });

  // =========================================================================
  // Bedtime calculation
  // =========================================================================

  group('PrescriptionEngine — bedtime calculation', () {
    test('wakeHour=7 -> bedtime clamped to 21 (floor, 7-1=6 < 21)', () {
      final result = PrescriptionEngine.evaluate(makeInput(wakeHour: 7));
      expect(result.bedtimeHour, 21);
    });

    test('wakeHour=22 -> bedtime=21', () {
      final result = PrescriptionEngine.evaluate(makeInput(wakeHour: 22));
      expect(result.bedtimeHour, 21);
    });

    test('wakeHour=23 -> bedtime=22', () {
      final result = PrescriptionEngine.evaluate(makeInput(wakeHour: 23));
      expect(result.bedtimeHour, 22);
    });

    test('wakeHour=24 -> bedtime clamped to 23 (ceiling)', () {
      final result = PrescriptionEngine.evaluate(makeInput(wakeHour: 24));
      expect(result.bedtimeHour, 23);
    });

    test('bedtimeMinute is always 0 from engine (AI may adjust after)', () {
      final result = PrescriptionEngine.evaluate(makeInput());
      expect(result.bedtimeMinute, 0);
    });
  });

  // =========================================================================
  // Output field invariants
  // =========================================================================

  group('PrescriptionEngine — output invariants', () {
    test('profileId and prescriptionDate are always set', () {
      final result = PrescriptionEngine.evaluate(makeInput());
      expect(result.profileId, _kProfileId);
      expect(result.prescriptionDate, _kDate);
    });

    test('aiFocusTip and aiNarrative are null (populated by AI layer)', () {
      final result = PrescriptionEngine.evaluate(makeInput());
      expect(result.aiFocusTip, isNull);
      expect(result.aiNarrative, isNull);
    });

    test('isFallback defaults to false', () {
      final result = PrescriptionEngine.evaluate(makeInput());
      expect(result.isFallback, isFalse);
    });
  });

  // =========================================================================
  // DailyPrescriptionEntity helpers
  // =========================================================================

  group('DailyPrescriptionEntity helpers', () {
    test('hasWorkout is false when directive is rest', () {
      final e = DailyPrescriptionEntity(
        profileId: _kProfileId,
        prescriptionDate: _kDate,
        scenario: PrescriptionScenario.unwell,
        workoutDirective: WorkoutDirective.rest,
        mealDirective: MealDirective.light,
      );
      expect(e.hasWorkout, isFalse);
    });

    test('hasWorkout is true for fullSession', () {
      final e = DailyPrescriptionEntity(
        profileId: _kProfileId,
        prescriptionDate: _kDate,
        scenario: PrescriptionScenario.defaultPlan,
        workoutDirective: WorkoutDirective.fullSession,
        mealDirective: MealDirective.standard,
      );
      expect(e.hasWorkout, isTrue);
    });

    test('bedtimeDisplay formats 22:00 as "10:00 PM"', () {
      final e = DailyPrescriptionEntity(
        profileId: _kProfileId,
        prescriptionDate: _kDate,
        scenario: PrescriptionScenario.defaultPlan,
        workoutDirective: WorkoutDirective.fullSession,
        mealDirective: MealDirective.standard,
        bedtimeHour: 22,
        bedtimeMinute: 0,
      );
      expect(e.bedtimeDisplay, '10:00 PM');
    });

    test('bedtimeDisplay formats 21:30 as "9:30 PM"', () {
      final e = DailyPrescriptionEntity(
        profileId: _kProfileId,
        prescriptionDate: _kDate,
        scenario: PrescriptionScenario.defaultPlan,
        workoutDirective: WorkoutDirective.fullSession,
        mealDirective: MealDirective.standard,
        bedtimeHour: 21,
        bedtimeMinute: 30,
      );
      expect(e.bedtimeDisplay, '9:30 PM');
    });

    test('bedtimeDisplay returns empty string when bedtimeHour is null', () {
      final e = DailyPrescriptionEntity(
        profileId: _kProfileId,
        prescriptionDate: _kDate,
        scenario: PrescriptionScenario.defaultPlan,
        workoutDirective: WorkoutDirective.fullSession,
        mealDirective: MealDirective.standard,
      );
      expect(e.bedtimeDisplay, '');
    });
  });

  // =========================================================================
  // CheckInEntity — toAiContextJson sensitive field stripping
  // =========================================================================

  group('CheckInEntity.toAiContextJson', () {
    final checkIn = CheckInEntity(
      profileId: _kProfileId,
      checkinDate: _kDate,
      feelingLevel: 'good',
      morningErection: true,
      erectionQualityWeekly: 8,
    );

    test(
        'includeVitality=false strips morningErection and erectionQualityWeekly',
        () {
      final json = checkIn.toAiContextJson(includeVitality: false);
      expect(json.containsKey('morning_erection'), isFalse);
      expect(json.containsKey('erection_quality_weekly'), isFalse);
    });

    test('includeVitality=true includes sensitive fields', () {
      final json = checkIn.toAiContextJson(includeVitality: true);
      expect(json['morning_erection'], true);
      expect(json['erection_quality_weekly'], 8);
    });

    test('non-sensitive fields always present regardless of consent', () {
      for (final include in [true, false]) {
        final json = checkIn.toAiContextJson(includeVitality: include);
        expect(json.containsKey('feeling_level'), isTrue);
        expect(json.containsKey('sleep_quality'), isTrue);
        expect(json.containsKey('schedule_type'), isTrue);
        expect(json.containsKey('checkin_date'), isTrue);
      }
    });
  });

  // =========================================================================
  // Enum DB serialization round-trips
  // =========================================================================

  group('Enum DB serialization', () {
    test('all PrescriptionScenarios round-trip', () {
      for (final s in PrescriptionScenario.values) {
        expect(PrescriptionScenarioExtension.fromDbValue(s.dbValue), s);
      }
    });

    test('all WorkoutDirectives round-trip', () {
      for (final d in WorkoutDirective.values) {
        expect(WorkoutDirectiveExtension.fromDbValue(d.dbValue), d);
      }
    });

    test('all MealDirectives round-trip', () {
      for (final d in MealDirective.values) {
        expect(MealDirectiveExtension.fromDbValue(d.dbValue), d);
      }
    });
  });
}
