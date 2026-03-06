// lib/features/daily_coach/data/prescription_engine.dart
//
// Pure Dart — no async, no Supabase, no side effects.
// Fully unit-testable.

import '../domain/checkin_entity.dart';
import '../domain/daily_prescription_entity.dart';

/// All inputs required by the deterministic prescription engine.
class PrescriptionInput {
  const PrescriptionInput({
    required this.profileId,
    required this.date,
    this.checkIn,
    this.sleepMinutes,
    this.restingHR,
    this.stepsToday,
    this.stepsGoal,
    this.weightTrend,
    this.hadHeavySessionYesterday = false,
    this.wakeHour = 7,
    required this.currentTime,
  });

  final String profileId;
  final DateTime date;

  /// Today's check-in. May be null if user skipped check-in.
  final CheckInEntity? checkIn;

  /// Sleep duration from health data (e.g. 420 = 7 h).
  final int? sleepMinutes;

  /// Resting heart rate in bpm.
  final double? restingHR;

  /// Steps walked so far today.
  final int? stepsToday;

  /// Daily step goal (defaults to 10 000 if not set).
  final int? stepsGoal;

  /// Weight change rate in kg/day over last 14 days (negative = losing).
  /// Null when data is insufficient.
  final double? weightTrend;

  /// True when the most recent completed session was classified as heavy.
  final bool hadHeavySessionYesterday;

  /// Hour user typically wakes (24-hour format). Drives bedtime calculation.
  final int wakeHour;

  /// Injection point for "now" — enables deterministic testing.
  final DateTime currentTime;
}

/// Deterministic prescription engine.
///
/// Maps a [PrescriptionInput] to a [DailyPrescriptionEntity] using a
/// priority-ordered decision tree. The AI layer narrates the output
/// afterward; it does NOT influence the scenario selection here.
class PrescriptionEngine {
  // Prevent instantiation — all methods are static.
  const PrescriptionEngine._();

  /// Entry point: evaluate input and return a fully-populated prescription
  /// (without AI narrative fields — those are merged in the notifier).
  static DailyPrescriptionEntity evaluate(PrescriptionInput input) {
    final scenario = _resolveScenario(input);
    return _buildPrescription(input, scenario);
  }

  // ---------------------------------------------------------------------------
  // Scenario resolution — priority order, first match wins
  // ---------------------------------------------------------------------------

  static PrescriptionScenario _resolveScenario(PrescriptionInput input) {
    final feeling = input.checkIn?.feelingLevel;
    final schedule = input.checkIn?.scheduleType;
    final sleepHours = (input.sleepMinutes ?? 0) / 60.0;

    // 1. Unwell — always rest
    if (feeling == 'unwell') return PrescriptionScenario.unwell;

    // 2. Very sore after a heavy session — active recovery
    if (feeling == 'sore' && input.hadHeavySessionYesterday) {
      return PrescriptionScenario.verySore;
    }

    // 3. Busy schedule — quick session
    if (schedule == 'busy') return PrescriptionScenario.busyDay;

    // 4. Well rested — push overload
    if (sleepHours >= 7.0 &&
        (input.restingHR == null || input.restingHR! < 65) &&
        feeling == 'great') {
      return PrescriptionScenario.wellRested;
    }

    // 5. Poor sleep — reduce volume
    if (sleepHours < 6.0 && (feeling == 'tired' || feeling == null)) {
      return PrescriptionScenario.tiredNotSore;
    }

    // 6. Behind on steps after 3 PM
    if (input.currentTime.hour >= 15 &&
        input.stepsToday != null &&
        input.stepsGoal != null &&
        input.stepsToday! < (input.stepsGoal! * 0.4).round()) {
      return PrescriptionScenario.behindSteps;
    }

    // 7. Weight stalling — trend near zero
    if (input.weightTrend != null && input.weightTrend!.abs() < 0.05) {
      return PrescriptionScenario.weightStalling;
    }

    return PrescriptionScenario.defaultPlan;
  }

  // ---------------------------------------------------------------------------
  // Prescription construction
  // ---------------------------------------------------------------------------

  static DailyPrescriptionEntity _buildPrescription(
    PrescriptionInput input,
    PrescriptionScenario scenario,
  ) {
    final bedtimeHour = _calcBedtime(input.wakeHour);

    switch (scenario) {
      case PrescriptionScenario.wellRested:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          workoutNote:
              'Push progressive overload today. You are well rested.',
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.tiredNotSore:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.reducedVolume,
          workoutVolumeModifier: 0.8,
          workoutNote:
              'Reduce sets by 20%. Keep the session — consistency beats perfection.',
          mealDirective: MealDirective.extraCarbs,
          calorieModifier: 50,
          stepsNudge: 'Add a short walk this evening to boost energy.',
          bedtimeHour: (bedtimeHour - 1).clamp(21, 23),
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.verySore:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.activeRecovery,
          workoutVolumeModifier: 0.0,
          workoutNote:
              'Active recovery: 20-min walk + stretching only. Heavy session tomorrow.',
          mealDirective: MealDirective.highProtein,
          calorieModifier: 0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.busyDay:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.quickSession,
          workoutVolumeModifier: 0.6,
          workoutNote:
              '30-minute express session. Hit the compound lifts only.',
          mealDirective: MealDirective.grabAndGo,
          calorieModifier: 0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.behindSteps:
        final goal = input.stepsGoal ?? 10000;
        final today = input.stepsToday ?? 0;
        final stepsRemaining = goal - today;
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          stepsNudge:
              'You need ~$stepsRemaining more steps. A 30-min walk after work gets you there.',
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.weightStalling:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          workoutNote:
              'Add one light cardio session this week to break the plateau.',
          mealDirective: MealDirective.standard,
          calorieModifier: -150,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.unwell:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.rest,
          workoutVolumeModifier: 0.0,
          workoutNote:
              'Rest day. No training. Prioritise hydration and sleep.',
          mealDirective: MealDirective.light,
          calorieModifier: -200,
          bedtimeHour: (bedtimeHour - 1).clamp(21, 23),
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.defaultPlan:
      // ignore: no_default_cases
      default:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: PrescriptionScenario.defaultPlan,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Bedtime calculation
  //
  // Target: wake_hour - 1 (gives ~7 h sleep window before alarm).
  // Clamped to [21, 23] — never earlier than 9 PM, never later than 11 PM.
  // ---------------------------------------------------------------------------

  static int _calcBedtime(int wakeHour) {
    final target = wakeHour - 1;
    return target.clamp(21, 23);
  }
}
