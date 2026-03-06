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
    this.recoveryScore,
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

  /// Recovery score 0–100 from PerformanceEngine. Drives base plan type:
  /// 80–100 = push, 60–79 = normal, 40–59 = easy, 0–39 = rest.
  final double? recoveryScore;

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
/// recovery-score-based plan type with priority overrides.
/// The AI layer narrates the output afterward; it does NOT influence
/// the scenario selection here.
class PrescriptionEngine {
  // Prevent instantiation — all methods are static.
  const PrescriptionEngine._();

  /// Entry point: evaluate input and return a fully-populated prescription
  /// (without AI narrative fields — those are merged in the notifier).
  static DailyPrescriptionEntity evaluate(PrescriptionInput input) {
    final scenario = _resolveScenario(input);
    final planType = _resolvePlanType(input, scenario);
    return _buildPrescription(input, scenario, planType);
  }

  // ---------------------------------------------------------------------------
  // Plan type from recovery score
  // ---------------------------------------------------------------------------

  /// Determine base plan type from recovery score.
  /// When no score is available, falls back to normal.
  static PlanType _planTypeFromScore(double? recoveryScore) {
    if (recoveryScore == null) return PlanType.normal;
    if (recoveryScore >= 80) return PlanType.push;
    if (recoveryScore >= 60) return PlanType.normal;
    if (recoveryScore >= 40) return PlanType.easy;
    return PlanType.rest;
  }

  /// Resolve final plan type: score-based default with override rules.
  static PlanType _resolvePlanType(
    PrescriptionInput input,
    PrescriptionScenario scenario,
  ) {
    // Feeling = unwell always forces rest regardless of score
    if (scenario == PrescriptionScenario.unwell) return PlanType.rest;

    // Score-based plan type when available
    if (input.recoveryScore != null) {
      final scoreBased = _planTypeFromScore(input.recoveryScore);

      // Busy caps at normal (no push on busy days)
      if (scenario == PrescriptionScenario.busyDay &&
          scoreBased == PlanType.push) {
        return PlanType.normal;
      }

      return scoreBased;
    }

    // Heuristic fallback when no recovery score
    switch (scenario) {
      case PrescriptionScenario.wellRested:
        return PlanType.push;
      case PrescriptionScenario.tiredNotSore:
        return PlanType.easy;
      case PrescriptionScenario.verySore:
        return PlanType.rest;
      case PrescriptionScenario.sore:
        return PlanType.normal;
      default:
        return PlanType.normal;
    }
  }

  // ---------------------------------------------------------------------------
  // Scenario resolution — priority order, first match wins
  // ---------------------------------------------------------------------------

  static PrescriptionScenario _resolveScenario(PrescriptionInput input) {
    final feeling = input.checkIn?.feelingLevel;
    final schedule = input.checkIn?.scheduleType;
    final sleepHours = (input.sleepMinutes ?? 0) / 60.0;

    // 1. Unwell — always rest (overrides everything)
    if (feeling == 'unwell') return PrescriptionScenario.unwell;

    // 2. Sore — reduces workout volume by 20% from standard plan
    //    With heavy session yesterday, triggers full active recovery
    if (feeling == 'sore') {
      if (input.hadHeavySessionYesterday) {
        return PrescriptionScenario.verySore;
      }
      return PrescriptionScenario.sore;
    }

    // 3. Busy schedule — swaps to 30-minute workout variant
    if (schedule == 'busy') return PrescriptionScenario.busyDay;

    // 4. Well rested — push overload (heuristic when no recovery score)
    if (sleepHours >= 7.0 &&
        (input.restingHR == null || input.restingHR! < 65) &&
        feeling == 'great') {
      return PrescriptionScenario.wellRested;
    }

    // 5. Poor sleep or tired — reduce volume
    if (feeling == 'tired' ||
        (sleepHours > 0 && sleepHours < 6.0 && feeling == null)) {
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

    // 8. Recovery score tiers (when no other signal matched)
    if (input.recoveryScore != null) {
      final score = input.recoveryScore!;
      if (score >= 80) return PrescriptionScenario.wellRested;
      if (score >= 60) return PrescriptionScenario.defaultPlan;
      if (score >= 40) return PrescriptionScenario.tiredNotSore;
      return PrescriptionScenario.unwell; // 0–39 = rest day
    }

    return PrescriptionScenario.defaultPlan;
  }

  // ---------------------------------------------------------------------------
  // Prescription construction
  // ---------------------------------------------------------------------------

  static DailyPrescriptionEntity _buildPrescription(
    PrescriptionInput input,
    PrescriptionScenario scenario,
    PlanType planType,
  ) {
    final bedtimeHour = _calcBedtime(input.wakeHour);

    switch (scenario) {
      case PrescriptionScenario.wellRested:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          workoutNote:
              'Push progressive overload today. You are well rested.',
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.tiredNotSore:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.reducedVolume,
          workoutVolumeModifier: 0.8,
          workoutNote:
              'Reduce sets by 20%. Keep the session — consistency beats perfection.',
          mealDirective: MealDirective.extraCarbs,
          calorieModifier: 0,
          calorieAdjustmentPercent: -0.10,
          stepsNudge: 'Add a short walk this evening to boost energy.',
          bedtimeHour: (bedtimeHour - 1).clamp(21, 23),
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.sore:
        // Sore (without heavy session yesterday): reduces volume by 20%
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.reducedVolume,
          workoutVolumeModifier: 0.8,
          workoutNote:
              'Feeling sore — reduce sets by 20% and focus on form.',
          mealDirective: MealDirective.highProtein,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.verySore:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.activeRecovery,
          workoutVolumeModifier: 0.0,
          workoutNote:
              'Active recovery: 20-min walk + stretching only. Heavy session tomorrow.',
          mealDirective: MealDirective.highProtein,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.busyDay:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.quickSession,
          workoutVolumeModifier: 0.6,
          workoutNote:
              '30-minute express session. Hit the compound lifts only.',
          mealDirective: MealDirective.grabAndGo,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
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
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
          stepsNudge:
              'You need ~$stepsRemaining more steps. A 30-min walk after work gets you there.',
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.weightStalling:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          workoutNote:
              'Add one light cardio session this week to break the plateau.',
          mealDirective: MealDirective.standard,
          calorieModifier: -150,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.unwell:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: PlanType.rest,
          recoveryScore: input.recoveryScore,
          scenario: scenario,
          workoutDirective: WorkoutDirective.rest,
          workoutVolumeModifier: 0.0,
          workoutNote:
              'Rest day. No training. Prioritise hydration and sleep.',
          mealDirective: MealDirective.light,
          calorieModifier: -200,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: (bedtimeHour - 1).clamp(21, 23),
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.defaultPlan:
      // ignore: no_default_cases
      default:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          planType: planType,
          recoveryScore: input.recoveryScore,
          scenario: PrescriptionScenario.defaultPlan,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          mealDirective: MealDirective.standard,
          calorieModifier: 0,
          calorieAdjustmentPercent: 0.0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Bedtime calculation
  //
  // Target: 7 hours before wake time (e.g. wake 6 AM → bed 11 PM).
  // Clamped to [21, 23] — never earlier than 9 PM, never later than 11 PM.
  // ---------------------------------------------------------------------------

  static int _calcBedtime(int wakeHour) {
    final target = (wakeHour + 24 - 7) % 24;
    return target.clamp(21, 23);
  }
}
