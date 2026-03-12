# Phase 9: AI Daily Coach — Implementation Plan

**Version:** 1.0
**Date:** 2026-02-21
**Architect:** Solutions Architect Agent
**Target:** WellTrack Flutter app — `agentic-mobile-template/`

---

## 1. Executive Summary

Phase 9 introduces the AI Daily Coach: a morning check-in flow that captures the user's current state, a deterministic prescription engine that maps that state to a daily plan, and a "Today's Plan" screen that presents that plan as actionable cards. The AI layer narrates the prescription — it does not generate it.

All decisions in this document are grounded in reading the actual codebase. File paths, provider names, and patterns referenced below are accurate as of the 2026-02-21 snapshot.

**Key finding — `wt_daily_checkins` already exists.** Migration `20260220000008_checkins_habits_bloodwork.sql` deployed the table with all required columns, RLS policies, and an `updated_at` trigger. No new migration is needed for this table.

**Key finding — `wt_daily_prescriptions` does NOT exist.** The CLAUDE.md spec lists it but no migration has been written. A new migration is required.

**Key finding — `ai_consent_vitality` and `ai_consent_bloodwork` columns** were added to `wt_profiles` in migration `20260220000009_ai_consent_toggles.sql`. The `ProfileEntity` class does NOT yet expose these fields. They must be added.

---

## 2. Database / Schema

### 2a. `wt_daily_checkins` — Already Deployed

Table exists. Schema confirmed from migration `20260220000008_checkins_habits_bloodwork.sql`:

```sql
-- No changes required.
-- Columns available:
--   id, profile_id, checkin_date (date, UNIQUE per profile per day)
--   feeling_level   text  CHECK IN ('great','good','tired','sore','unwell')
--   sleep_quality   numeric(3,1)  CHECK 1..10
--   sleep_quality_override  boolean  DEFAULT false
--   morning_erection  boolean
--   injuries_notes  text
--   schedule_type   text  CHECK IN ('busy','normal','flexible')
--   is_weekly       boolean  DEFAULT false
--   erection_quality_weekly  smallint  CHECK 1..10
--   is_sensitive    boolean  DEFAULT true
--   created_at, updated_at
```

The `is_sensitive` flag applies to the whole row. The prescription engine must strip `morning_erection` and `erection_quality_weekly` before passing context to AI unless `ai_consent_vitality = true` on the profile.

### 2b. `wt_daily_prescriptions` — NEW MIGRATION REQUIRED

Create migration file:
`supabase/migrations/20260222000001_daily_prescriptions.sql`

```sql
-- Migration: Daily Prescriptions for Phase 9 AI Daily Coach
CREATE TABLE IF NOT EXISTS public.wt_daily_prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  checkin_id uuid REFERENCES public.wt_daily_checkins(id) ON DELETE SET NULL,
  prescription_date date NOT NULL DEFAULT CURRENT_DATE,

  -- Prescription scenario resolved by the rule engine
  scenario text NOT NULL,
  -- Values: 'well_rested' | 'tired_not_sore' | 'very_sore' | 'behind_steps'
  --        | 'weight_stalling' | 'busy_day' | 'unwell' | 'default'

  -- Workout directive
  workout_directive text NOT NULL,
  -- Values: 'full_session' | 'reduced_volume' | 'active_recovery' | 'rest' | 'quick_session'
  workout_volume_modifier numeric(4,2) DEFAULT 1.0,
  -- 1.0 = full, 0.8 = reduce 20%, 0.0 = no workout
  workout_note text,

  -- Meal directive
  meal_directive text NOT NULL,
  -- Values: 'standard' | 'extra_carbs' | 'high_protein' | 'light' | 'grab_and_go' | 'hydration_focus'
  calorie_modifier numeric(5,0) DEFAULT 0,
  -- Signed integer offset from normal target (e.g. -150 for stalling weight)

  -- Steps / activity directive
  steps_nudge text,

  -- AI-generated narrative (narrates the rule-based output only)
  ai_focus_tip text,
  ai_narrative text,

  -- Bedtime recommendation
  bedtime_hour smallint,       -- 22 = 10 PM
  bedtime_minute smallint,     -- 45 = :45

  -- Generation metadata
  generated_at timestamptz NOT NULL DEFAULT now(),
  ai_model text,
  is_fallback boolean NOT NULL DEFAULT false,
  -- true when AI narration failed; deterministic plan still shown

  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT unique_prescription_per_day UNIQUE (profile_id, prescription_date)
);

CREATE INDEX idx_daily_prescriptions_profile_date
  ON public.wt_daily_prescriptions(profile_id, prescription_date DESC);

ALTER TABLE public.wt_daily_prescriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own prescriptions"
  ON public.wt_daily_prescriptions FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own prescriptions"
  ON public.wt_daily_prescriptions FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own prescriptions"
  ON public.wt_daily_prescriptions FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE TRIGGER handle_updated_at_daily_prescriptions
  BEFORE UPDATE ON public.wt_daily_prescriptions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

GRANT SELECT, INSERT, UPDATE ON public.wt_daily_prescriptions TO authenticated;
```

### 2c. `wt_profiles` — Consent Columns Already Deployed

Migration `20260220000009_ai_consent_toggles.sql` already added:
- `ai_consent_vitality boolean DEFAULT false`
- `ai_consent_bloodwork boolean DEFAULT false`

The `ProfileEntity` class at `lib/features/profile/domain/profile_entity.dart` does NOT yet include these fields. The Profile domain update is a dependency for Task B (see Section 10).

---

## 3. Domain Entities

### 3a. `CheckInEntity`

**File:** `lib/features/daily_coach/domain/checkin_entity.dart`

```dart
class CheckInEntity {
  const CheckInEntity({
    this.id,
    required this.profileId,
    required this.checkinDate,
    this.feelingLevel,
    this.sleepQuality,
    this.sleepQualityOverride = false,
    this.morningErection,          // sensitive
    this.injuriesNotes,
    this.scheduleType,
    this.isWeekly = false,
    this.erectionQualityWeekly,    // sensitive
    this.isSensitive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String profileId;
  final DateTime checkinDate;
  final String? feelingLevel;       // 'great'|'good'|'tired'|'sore'|'unwell'
  final double? sleepQuality;       // 1.0–10.0 (auto-filled from health data)
  final bool sleepQualityOverride;
  final bool? morningErection;      // sensitive — encrypted in transit
  final String? injuriesNotes;
  final String? scheduleType;       // 'busy'|'normal'|'flexible'
  final bool isWeekly;
  final int? erectionQualityWeekly; // 1–10, sensitive
  final bool isSensitive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Serialization: sensitive fields are omitted from toAiContextJson()
  Map<String, dynamic> toJson(); // full — for DB writes
  Map<String, dynamic> toAiContextJson({required bool includeVitality});
  factory CheckInEntity.fromJson(Map<String, dynamic> json);
}

enum FeelingLevel { great, good, tired, sore, unwell }
enum ScheduleType { busy, normal, flexible }
```

**Sensitive field rule:** `toAiContextJson` omits `morning_erection` and `erection_quality_weekly` unless `includeVitality = true`. This is enforced client-side before building the AI context snapshot. It mirrors the server-side consent check in the edge function.

### 3b. `DailyPrescriptionEntity`

**File:** `lib/features/daily_coach/domain/daily_prescription_entity.dart`

```dart
class DailyPrescriptionEntity {
  const DailyPrescriptionEntity({
    this.id,
    required this.profileId,
    this.checkinId,
    required this.prescriptionDate,
    required this.scenario,
    required this.workoutDirective,
    this.workoutVolumeModifier = 1.0,
    this.workoutNote,
    required this.mealDirective,
    this.calorieModifier = 0,
    this.stepsNudge,
    this.aiFocusTip,
    this.aiNarrative,
    this.bedtimeHour,
    this.bedtimeMinute,
    this.generatedAt,
    this.aiModel,
    this.isFallback = false,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String profileId;
  final String? checkinId;
  final DateTime prescriptionDate;
  final PrescriptionScenario scenario;
  final WorkoutDirective workoutDirective;
  final double workoutVolumeModifier;
  final String? workoutNote;
  final MealDirective mealDirective;
  final int calorieModifier;
  final String? stepsNudge;
  final String? aiFocusTip;
  final String? aiNarrative;
  final int? bedtimeHour;
  final int? bedtimeMinute;
  final DateTime? generatedAt;
  final String? aiModel;
  final bool isFallback;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get bedtimeDisplay { ... } // e.g. "10:45 PM"
  bool get hasWorkout => workoutDirective != WorkoutDirective.rest;

  Map<String, dynamic> toJson();
  factory DailyPrescriptionEntity.fromJson(Map<String, dynamic> json);
}

enum PrescriptionScenario {
  wellRested,
  tiredNotSore,
  verySore,
  behindSteps,
  weightStalling,
  busyDay,
  unwell,
  defaultPlan,
}

enum WorkoutDirective {
  fullSession,
  reducedVolume,
  activeRecovery,
  quickSession,
  rest,
}

enum MealDirective {
  standard,
  extraCarbs,
  highProtein,
  light,
  grabAndGo,
  hydrationFocus,
}
```

---

## 4. Data Layer — Repositories

### 4a. `CheckInRepository`

**File:** `lib/features/daily_coach/data/checkin_repository.dart`

**Supabase table:** `wt_daily_checkins`

Methods:

```dart
class CheckInRepository {
  CheckInRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Returns today's check-in or null if not yet completed.
  Future<CheckInEntity?> getTodayCheckIn(String profileId);

  /// Returns check-in for a specific date.
  Future<CheckInEntity?> getCheckInForDate(String profileId, DateTime date);

  /// Returns last N check-ins ordered by date desc.
  Future<List<CheckInEntity>> getRecentCheckIns(String profileId, {int limit = 7});

  /// Upsert today's check-in (uses UNIQUE constraint on profile_id + checkin_date).
  Future<CheckInEntity> upsertCheckIn(CheckInEntity checkIn);

  /// Returns Sunday check-in streak data (weekly entries).
  Future<List<CheckInEntity>> getWeeklyCheckIns(String profileId, {int limit = 4});
}

final checkinRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(Supabase.instance.client);
});
```

**Implementation notes:**
- Use `.upsert()` with `onConflict: 'profile_id,checkin_date'` to handle re-submission gracefully.
- Never pass `morning_erection` or `erection_quality_weekly` through any non-encrypted channel. Supabase RLS ensures row-level isolation. No additional client-side field encryption is needed beyond what RLS + HTTPS provides (see Section 9).

### 4b. `DailyPrescriptionRepository`

**File:** `lib/features/daily_coach/data/daily_prescription_repository.dart`

**Supabase table:** `wt_daily_prescriptions`

Methods:

```dart
class DailyPrescriptionRepository {
  DailyPrescriptionRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Returns today's prescription or null if not yet generated.
  Future<DailyPrescriptionEntity?> getTodayPrescription(String profileId);

  /// Returns prescription for a specific date.
  Future<DailyPrescriptionEntity?> getPrescriptionForDate(
      String profileId, DateTime date);

  /// Upsert prescription (one per day per profile).
  Future<DailyPrescriptionEntity> upsertPrescription(
      DailyPrescriptionEntity prescription);

  /// Returns last N prescriptions for trend analysis.
  Future<List<DailyPrescriptionEntity>> getRecentPrescriptions(
      String profileId, {int limit = 14});
}

final dailyPrescriptionRepositoryProvider =
    Provider<DailyPrescriptionRepository>((ref) {
  return DailyPrescriptionRepository(Supabase.instance.client);
});
```

---

## 5. Prescription Logic Engine

**File:** `lib/features/daily_coach/data/prescription_engine.dart`

This is pure Dart — no AI, no async, no Supabase. It takes a `PrescriptionInput` value object and returns a `DailyPrescriptionEntity` with all fields except `aiFocusTip` and `aiNarrative` (those are populated by the AI narration step afterward).

### 5a. Input Data Object

```dart
class PrescriptionInput {
  const PrescriptionInput({
    required this.profileId,
    required this.date,
    required this.checkIn,         // today's CheckInEntity (nullable if no check-in)
    this.sleepMinutes,             // from wt_health_metrics (MetricType.sleep)
    this.restingHR,                // from wt_health_metrics (MetricType.hr)
    this.stepsToday,               // from wt_health_metrics (MetricType.steps)
    this.stepsGoal,                // from wt_goals (metricType = 'steps')
    this.weightTrend,              // slope over last 14 days (null = unknown)
    this.hadHeavySessionYesterday, // from wt_workout_sessions
    this.wakeHour,                 // from profile preferences or default 7
    this.currentTime,              // DateTime.now() — for "3 PM steps nudge" check
  });

  final String profileId;
  final DateTime date;
  final CheckInEntity? checkIn;
  final int? sleepMinutes;           // e.g. 420 = 7 hours
  final double? restingHR;
  final int? stepsToday;
  final int? stepsGoal;             // default 10000
  final double? weightTrend;        // kg/day (negative = losing)
  final bool hadHeavySessionYesterday;
  final int wakeHour;               // default 7
  final DateTime currentTime;
}
```

### 5b. Decision Tree

```dart
class PrescriptionEngine {
  static DailyPrescriptionEntity evaluate(PrescriptionInput input) {
    final scenario = _resolveScenario(input);
    return _buildPrescription(input, scenario);
  }

  static PrescriptionScenario _resolveScenario(PrescriptionInput input) {
    final feeling = input.checkIn?.feelingLevel;
    final schedule = input.checkIn?.scheduleType;
    final sleepHours = (input.sleepMinutes ?? 0) / 60.0;

    // Priority order — first match wins
    if (feeling == 'unwell') return PrescriptionScenario.unwell;

    if (feeling == 'sore' && input.hadHeavySessionYesterday) {
      return PrescriptionScenario.verySore;
    }

    if (schedule == 'busy') return PrescriptionScenario.busyDay;

    if (sleepHours >= 7.0 &&
        (input.restingHR == null || input.restingHR! < 65) &&
        feeling == 'great') {
      return PrescriptionScenario.wellRested;
    }

    if (sleepHours < 6.0 && (feeling == 'tired' || feeling == null)) {
      return PrescriptionScenario.tiredNotSore;
    }

    // Steps nudge: after 3 PM with < 40% of daily step goal reached
    if (input.currentTime.hour >= 15 &&
        input.stepsToday != null &&
        input.stepsGoal != null &&
        input.stepsToday! < (input.stepsGoal! * 0.4).round()) {
      return PrescriptionScenario.behindSteps;
    }

    // Weight stalling: trend < 0.05 kg/day toward goal over 14 days
    if (input.weightTrend != null &&
        input.weightTrend!.abs() < 0.05) {
      return PrescriptionScenario.weightStalling;
    }

    return PrescriptionScenario.defaultPlan;
  }

  static DailyPrescriptionEntity _buildPrescription(
    PrescriptionInput input,
    PrescriptionScenario scenario,
  ) {
    // Bedtime = wakeHour - 1 (to hit 7+ hours), capped at 23:00
    final bedtimeHour = _calcBedtime(input.wakeHour);

    switch (scenario) {
      case PrescriptionScenario.wellRested:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.fullSession,
          workoutVolumeModifier: 1.0,
          workoutNote: 'Push progressive overload today. You are well rested.',
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
          workoutNote: 'Reduce sets by 20%. Keep the session — consistency beats perfection.',
          mealDirective: MealDirective.extraCarbs,
          calorieModifier: 50, // small carb top-up
          stepsNudge: 'Add a short walk this evening to boost energy.',
          bedtimeHour: bedtimeHour - 1, // earlier tonight
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.verySore:
        return DailyPrescriptionEntity(
          profileId: input.profileId,
          prescriptionDate: input.date,
          scenario: scenario,
          workoutDirective: WorkoutDirective.activeRecovery,
          workoutVolumeModifier: 0.0,
          workoutNote: 'Active recovery: 20-min walk + stretching only. Heavy session tomorrow.',
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
          workoutNote: '30-minute express session. Hit the compound lifts only.',
          mealDirective: MealDirective.grabAndGo,
          calorieModifier: 0,
          bedtimeHour: bedtimeHour,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.behindSteps:
        final stepsRemaining = (input.stepsGoal ?? 10000) - (input.stepsToday ?? 0);
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
          workoutNote: 'Add one light cardio session this week to break the plateau.',
          mealDirective: MealDirective.standard,
          calorieModifier: -150, // reduce rest-day calories
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
          workoutNote: 'Rest day. No training. Prioritise hydration and sleep.',
          mealDirective: MealDirective.light,
          calorieModifier: -200,
          bedtimeHour: bedtimeHour - 1,
          bedtimeMinute: 0,
        );

      case PrescriptionScenario.defaultPlan:
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

  // Bedtime = 23:00 max. Target: wake_hour + 7 hours back from midnight
  static int _calcBedtime(int wakeHour) {
    final target = wakeHour - 1; // needs 7 hours before wake
    if (target < 21) return 22; // never earlier than 10 PM as a floor
    if (target > 23) return 23;
    return target;
  }
}
```

---

## 6. Presentation Layer

### 6a. Feature Directory Structure

```
lib/features/daily_coach/
  data/
    checkin_repository.dart
    daily_prescription_repository.dart
    prescription_engine.dart
  domain/
    checkin_entity.dart
    daily_prescription_entity.dart
  presentation/
    morning_checkin_provider.dart
    morning_checkin_screen.dart
    todays_plan_provider.dart
    todays_plan_screen.dart
    widgets/
      checkin_step_feeling.dart
      checkin_step_sleep.dart
      checkin_step_schedule.dart
      checkin_step_vitality.dart       (sensitive — shown behind consent check)
      checkin_step_injuries.dart
      todays_workout_card.dart
      todays_meals_card.dart
      todays_steps_ring.dart
      todays_focus_tip.dart
      bedtime_reminder_card.dart
```

### 6b. Morning Check-In Screen

**File:** `lib/features/daily_coach/presentation/morning_checkin_screen.dart`

This is a step-by-step wizard. Target: under 30 seconds to complete.

**UX flow:**
1. Step 1 — Feeling (5 tap chips: Great / Good / Tired / Sore / Unwell)
2. Step 2 — Sleep (auto-populated from health data; user can override via slider 1–10)
3. Step 3 — Injuries (optional free text; can be skipped with a "No injuries" button)
4. Step 4 — Schedule (3 tap chips: Busy / Normal / Flexible)
5. Step 5 (Sunday only) — Erection quality weekly slider (1–10); shown only if `DateTime.now().weekday == DateTime.sunday`; skippable
6. Final step — "Morning erection today?" (Yes / No chips); shown only if consent check passes

**Important:** Vitality questions (steps 5 and 6) are displayed ONLY if:
- `profile.aiConsentVitality == true` (consent toggle enabled), OR
- the questions are framed as private local-only entries with a clear note: "This is private. Not shared with AI unless you enable Vitality Data in Settings."

For MVP, always show vitality questions but display the privacy disclaimer inline. The consent toggle controls AI inclusion only, not collection.

**Provider:** `morning_checkin_provider.dart`

```dart
// State
class MorningCheckInState {
  const MorningCheckInState({
    this.currentStep = 0,
    this.feelingLevel,
    this.sleepQuality,
    this.sleepQualityOverride = false,
    this.morningErection,
    this.injuriesNotes,
    this.scheduleType,
    this.erectionQualityWeekly,
    this.isSubmitting = false,
    this.isComplete = false,
    this.todayCheckIn,
    this.error,
  });

  final int currentStep;
  final String? feelingLevel;
  final double? sleepQuality;
  final bool sleepQualityOverride;
  final bool? morningErection;
  final String? injuriesNotes;
  final String? scheduleType;
  final int? erectionQualityWeekly;
  final bool isSubmitting;
  final bool isComplete;
  final CheckInEntity? todayCheckIn;
  final String? error;

  bool get isSundayPrompt => DateTime.now().weekday == DateTime.sunday;
  int get totalSteps => isSundayPrompt ? 6 : 5;
}

// Notifier
class MorningCheckInNotifier extends StateNotifier<MorningCheckInState> {
  MorningCheckInNotifier(
    this._checkinRepo,
    this._prescriptionRepo,
    this._healthRepo,
    this._profileId,
  ) : super(const MorningCheckInState());

  // Methods: nextStep(), prevStep(), setFeeling(), setSleep(),
  //          setSchedule(), setInjuries(), setMorningErection(),
  //          setErectionQuality(), submit()

  Future<void> submit() async {
    // 1. Upsert CheckInEntity via CheckInRepository
    // 2. Load PrescriptionInput from health + workout repos
    // 3. Run PrescriptionEngine.evaluate(input)
    // 4. Upsert DailyPrescriptionEntity (without AI fields) via DailyPrescriptionRepository
    // 5. Call AiOrchestratorService.orchestrate(workflowType: 'generate_daily_plan')
    //    with contextOverride containing the prescription scenario and check-in summary
    // 6. Merge AI narrative into prescription via DailyPrescriptionRepository.upsertPrescription()
    // 7. Set isComplete = true — navigate to Today's Plan screen
    //
    // On AI failure: set isFallback = true, show prescription without narration
    // NEVER show blank screen
  }
}

// Provider
final morningCheckInProvider =
    StateNotifierProvider.family<MorningCheckInNotifier, MorningCheckInState, String>(
  (ref, profileId) {
    return MorningCheckInNotifier(
      ref.watch(checkinRepositoryProvider),
      ref.watch(dailyPrescriptionRepositoryProvider),
      ref.watch(healthRepositoryProvider),
      profileId,
    );
  },
);
```

**Screen structure:**
```dart
class MorningCheckInScreen extends ConsumerStatefulWidget {
  const MorningCheckInScreen({required this.profileId, super.key});
  final String profileId;
  // Uses PageView with physics: NeverScrollableScrollPhysics()
  // Back/forward controlled by provider notifier only
  // LinearProgressIndicator at top showing step N of totalSteps
  // Each step widget is a stateless widget receiving callbacks
}
```

**Post-submit navigation:**
```dart
// On isComplete, navigate to Today's Plan:
context.go('/daily-coach/plan');
```

### 6c. Today's Plan Screen

**File:** `lib/features/daily_coach/presentation/todays_plan_screen.dart`

Single-scroll screen with five card sections. Tapping cards deep-links into existing features.

```dart
class TodaysPlanScreen extends ConsumerWidget {
  const TodaysPlanScreen({required this.profileId, super.key});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todaysPlanProvider(profileId));

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.prescription == null) return _buildNoPrescriptionFallback(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Plan")),
      body: RefreshIndicator(
        onRefresh: () => ref.read(todaysPlanProvider(profileId).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            TodaysWorkoutCard(prescription: state.prescription!, profileId: profileId),
            TodaysMealsCard(mealPlan: state.mealPlan, directive: state.prescription!.mealDirective),
            TodaysStepsRing(stepsToday: state.stepsToday, stepsGoal: state.stepsGoal),
            TodaysFocusTip(tip: state.prescription!.aiFocusTip ?? _fallbackTip(state.prescription!.scenario)),
            BedtimeReminderCard(hour: state.prescription!.bedtimeHour, minute: state.prescription!.bedtimeMinute),
            const SizedBox(height: 100),
          ]),
        ),
      ),
    );
  }
}
```

**Provider:** `todays_plan_provider.dart`

```dart
class TodaysPlanState {
  const TodaysPlanState({
    this.prescription,
    this.mealPlan,
    this.stepsToday,
    this.stepsGoal,
    this.isLoading = false,
    this.error,
  });

  final DailyPrescriptionEntity? prescription;
  final MealPlanEntity? mealPlan;       // from MealPlanRepository.getMealPlan()
  final int? stepsToday;                // from HealthRepository.getMetrics()
  final int? stepsGoal;
  final bool isLoading;
  final String? error;
}

class TodaysPlanNotifier extends StateNotifier<TodaysPlanState> {
  TodaysPlanNotifier(
    this._prescriptionRepo,
    this._mealPlanRepo,
    this._healthRepo,
    this._profileId,
  ) : super(const TodaysPlanState(isLoading: true));

  Future<void> loadPlan() async {
    // Load in parallel:
    // - DailyPrescriptionRepository.getTodayPrescription()
    // - MealPlanRepository.getMealPlan() for today
    // - HealthRepository.getMetrics() for MetricType.steps (today)
    // - Steps goal from wt_goals (metricType = 'steps')
  }
}

final todaysPlanProvider =
    StateNotifierProvider.family<TodaysPlanNotifier, TodaysPlanState, String>(
  (ref, profileId) {
    return TodaysPlanNotifier(
      ref.watch(dailyPrescriptionRepositoryProvider),
      ref.watch(mealPlanRepositoryProvider),   // already exists at lib/features/meals/data/meal_plan_repository.dart
      ref.watch(healthRepositoryProvider),      // already exists at lib/features/health/data/health_repository.dart
      profileId,
    );
  },
);
```

### 6d. Card Widgets

**`TodaysWorkoutCard`**
- Reads `prescription.workoutDirective`
- If `fullSession` or `reducedVolume` or `quickSession`: shows active plan name, today's exercise count, a "Start Workout" button that calls `context.push('/workouts/log/$workoutId')` — the active plan's today session
- If `activeRecovery`: shows walking/stretching icon with note
- If `rest`: shows rest icon with note
- Tap on card header: `context.push('/workouts')`

**`TodaysMealsCard`**
- Takes `MealPlanEntity?` and `MealDirective`
- If meal plan exists: shows breakfast/lunch/dinner/snack names with macro chips
- If `extraCarbs`: adds a "+ carbs" badge on breakfast
- If `highProtein`: adds "+ protein" badge on each meal
- If `calorieModifier != 0`: shows adjusted calorie total inline
- Tap on a meal: `context.push('/meals/plan')` (existing screen)
- If no meal plan: shows "Generate today's meals" button linking to `/meals/plan`

**`TodaysStepsRing`**
- Circular progress indicator (fl_chart `PieChart` or custom `CustomPainter`)
- Shows current steps / goal with percentage
- If `prescription.stepsNudge != null`: shows nudge text below ring

**`TodaysFocusTip`**
- Single `Card` with `Icons.lightbulb_outline`
- Shows `aiFocusTip` if available; falls back to scenario-specific static strings if AI failed

**`BedtimeReminderCard`**
- Shows `Icons.bedtime` with calculated bedtime display
- Tap: navigates to `/reminders` (existing screen)

---

## 7. AI Orchestrator Integration

### 7a. Tool: `generate_daily_plan`

This tool is registered on the edge function side (Supabase Edge Function at `/functions/v1/ai-orchestrate`). The Flutter client calls it via `AiOrchestratorService.orchestrate()`.

**Workflow type string:** `'generate_daily_plan'`

**Context passed in `contextOverride`:**

```dart
final contextOverride = {
  'prescription_scenario': prescription.scenario.name,
  'workout_directive': prescription.workoutDirective.name,
  'workout_volume_modifier': prescription.workoutVolumeModifier,
  'meal_directive': prescription.mealDirective.name,
  'calorie_modifier': prescription.calorieModifier,
  'check_in': checkIn.toAiContextJson(includeVitality: profile.aiConsentVitality),
  'sleep_hours': (sleepMinutes / 60.0).toStringAsFixed(1),
  'steps_today': stepsToday,
  'steps_goal': stepsGoal,
  'active_plan_name': activePlanName,
};
```

**What AI receives:** The deterministic scenario and directive have already been computed. The AI's job is only to write `ai_focus_tip` (one sentence) and `ai_narrative` (2–3 sentences explaining the prescription in plain language).

**Expected AI response fields** (mapped from `AiOrchestrateResponse.assistantMessage`):
The `assistantMessage` will be parsed as JSON with structure:
```json
{
  "focus_tip": "...",
  "narrative": "..."
}
```

Parse this in the notifier's `submit()` method. On JSON parse failure, `isFallback = true`.

**Call site in `MorningCheckInNotifier.submit()`:**
```dart
try {
  final aiResponse = await _aiService.orchestrate(
    userId: userId,
    profileId: _profileId,
    workflowType: 'generate_daily_plan',
    contextOverride: contextOverride,
  );
  final parsed = jsonDecode(aiResponse.assistantMessage) as Map<String, dynamic>;
  finalPrescription = prescription.copyWith(
    aiFocusTip: parsed['focus_tip'] as String?,
    aiNarrative: parsed['narrative'] as String?,
    aiModel: 'gpt-4o-mini',
  );
} on AiException {
  finalPrescription = prescription.copyWith(isFallback: true);
}
```

The notifier requires `AiOrchestratorService` injected via `ref.watch(aiOrchestratorServiceProvider)` and the active user ID via Supabase auth. Pattern: `Supabase.instance.client.auth.currentUser?.id`.

### 7b. Edge Function Changes Needed

The edge function at `supabase/functions/ai-orchestrate/` must register the `generate_daily_plan` tool and define its system prompt. This is server-side TypeScript work.

**System prompt fragment for `generate_daily_plan`:**
```
You are a performance coach. You will receive a deterministic daily plan (scenario, workout directive, meal directive) already calculated by WellTrack's rule engine.

Your job is to:
1. Write one focus_tip: a single actionable sentence the user can act on immediately.
2. Write a narrative: 2-3 sentences that explain WHY this plan makes sense given today's signals.

Rules:
- Do NOT change or override the workout or meal directives.
- Do NOT make medical claims.
- Use encouraging but realistic language.
- Return ONLY valid JSON: { "focus_tip": "...", "narrative": "..." }
```

---

## 8. Routes to Add in `app_router.dart`

**File:** `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/shared/core/router/app_router.dart`

Add the following imports:
```dart
import '../../../features/daily_coach/presentation/morning_checkin_screen.dart'
    as morning_checkin;
import '../../../features/daily_coach/presentation/todays_plan_screen.dart'
    as todays_plan;
```

Add routes inside the `routes:` list, after the `/daily-view` route:
```dart
GoRoute(
  path: '/daily-coach/checkin',
  name: 'morningCheckIn',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return morning_checkin.MorningCheckInScreen(profileId: profileId);
  },
),
GoRoute(
  path: '/daily-coach/plan',
  name: 'todaysPlan',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return todays_plan.TodaysPlanScreen(profileId: profileId);
  },
),
```

Add these paths to the `needsProfile` guard condition:
```dart
// In the redirect block's needsProfile variable:
requestedPath.startsWith('/daily-coach/');
```

---

## 9. Dashboard Integration

### 9a. Daily Coach Banner Card

Add a new widget: `lib/features/dashboard/presentation/widgets/daily_coach_card.dart`

```dart
class DailyCoachCard extends ConsumerWidget {
  const DailyCoachCard({required this.profileId, super.key});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if today's check-in is complete (read from CheckInRepository)
    // If NOT complete: show "Start your morning check-in" banner with a "Begin" button
    //   -> context.push('/daily-coach/checkin')
    // If complete AND prescription exists: show summary card
    //   -> shows scenario badge, workout directive, tap opens /daily-coach/plan
    // If complete but no prescription: show "Generating your plan..." spinner
  }
}
```

The `DailyCoachCard` uses a `FutureProvider.family` for its data:
```dart
final _dailyCoachStatusProvider =
    FutureProvider.family<_DailyCoachStatus, String>((ref, profileId) async {
  final checkinRepo = ref.watch(checkinRepositoryProvider);
  final prescriptionRepo = ref.watch(dailyPrescriptionRepositoryProvider);
  final checkIn = await checkinRepo.getTodayCheckIn(profileId);
  final prescription = await prescriptionRepo.getTodayPrescription(profileId);
  return _DailyCoachStatus(checkIn: checkIn, prescription: prescription);
});
```

### 9b. Dashboard Screen Changes

**File:** `lib/features/dashboard/presentation/dashboard_screen.dart`

Insert `DailyCoachCard` as the FIRST content section after `TodaySummaryCard`. This positions it prominently without cluttering the existing hierarchy.

```dart
// In the CustomScrollView slivers list, after TodaySummaryCard:
SliverToBoxAdapter(
  child: DailyCoachCard(profileId: widget.profileId),
),
const SliverToBoxAdapter(child: SizedBox(height: 24)),
```

### 9c. Bottom Nav — "Log" Tab Enhancement

The dashboard bottom nav currently has "Log" (index 1) going to `/daily-view`. Consider whether the morning check-in should be the first thing on this tab. For Phase 9, leave the routing as is but the DailyCoachCard on the home screen provides the primary entry point.

---

## 10. Sensitive Data Handling

### 10a. Architecture Decision

**Decision: Do NOT implement additional client-side field encryption.**

Rationale:
- Data is transmitted only over HTTPS (TLS 1.2+).
- Supabase RLS policies on `wt_daily_checkins` ensure profile-scoped read/write.
- The `is_sensitive = true` flag marks the row for export exclusion.
- `flutter_secure_storage` (already in `pubspec.yaml`) is used for auth tokens only, not table row data.
- Adding custom field encryption (e.g., AES-256 with `pointycastle`) to Supabase upserts would make server-side queries against these fields impossible — breaking future trend analysis in SQL.

**What IS required:**
1. The fields `morning_erection` and `erection_quality_weekly` are NEVER included in push notification payloads.
2. The fields are stripped from AI context unless `profile.aiConsentVitality = true`.
3. The UI for these questions never shows the values in any notification preview, widget preview, or system-level recent app screenshot.
4. The check-in screen uses `FLAG_SECURE` (Android) / `ignoresScreenshots` to prevent screenshot capture of vitality steps. Implement via `SystemChrome.setEnabledSystemUIMode()` or a package like `flutter_windowmanager` if available, or simply avoid rendering these values outside the locked screen.

For MVP simplicity: the sensitive fields are stored in Supabase under RLS with HTTPS. Full column-level encryption at the database layer is a Phase 12 enhancement, not Phase 9.

### 10b. `ProfileEntity` Update Required

**File:** `lib/features/profile/domain/profile_entity.dart`

Add two fields to `ProfileEntity` (matching the columns deployed in `20260220000009_ai_consent_toggles.sql`):

```dart
// Add to constructor:
this.aiConsentVitality = false,
this.aiConsentBloodwork = false,

// Add fields:
final bool aiConsentVitality;
final bool aiConsentBloodwork;
```

The `fromJson` / `toJson` and `copyWith` methods must also be updated. This is required before the `MorningCheckInNotifier` can check `profile.aiConsentVitality`.

---

## 11. Task Breakdown (4 Parallelizable Work Units)

The following tasks can be developed by four agents in parallel. Tasks B and D have a dependency on Task A (the migration file) being deployed first, but the Dart code can be written before deployment.

---

### Task A — Backend + Entities (Day 1)

**Assigned to:** Backend Agent

**Deliverables:**

1. Write migration file:
   `supabase/migrations/20260222000001_daily_prescriptions.sql`
   (full SQL from Section 2b)

2. Update `ProfileEntity`:
   `lib/features/profile/domain/profile_entity.dart`
   Add `aiConsentVitality` and `aiConsentBloodwork` fields with defaults. Update `fromJson`, `toJson`, `copyWith`.

3. Write `CheckInEntity`:
   `lib/features/daily_coach/domain/checkin_entity.dart`
   Full implementation per Section 3a.

4. Write `DailyPrescriptionEntity`:
   `lib/features/daily_coach/domain/daily_prescription_entity.dart`
   Full implementation per Section 3b.

5. Write `CheckInRepository`:
   `lib/features/daily_coach/data/checkin_repository.dart`

6. Write `DailyPrescriptionRepository`:
   `lib/features/daily_coach/data/daily_prescription_repository.dart`

7. Write `PrescriptionEngine`:
   `lib/features/daily_coach/data/prescription_engine.dart`
   Pure Dart, fully unit-testable. All scenarios from Section 5b.

8. Write unit tests:
   `test/unit/daily_coach/prescription_engine_test.dart`
   Test all 8 scenarios with boundary conditions (e.g., sleepMinutes = 359 vs 360 for the < 6 hour check).

**No UI work in this task.**

---

### Task B — Morning Check-In Screen (Day 1-2)

**Assigned to:** Frontend Agent 1

**Depends on:** Task A entities and repositories must be written (not necessarily deployed).

**Deliverables:**

1. `lib/features/daily_coach/presentation/morning_checkin_provider.dart`
   Full `MorningCheckInState` + `MorningCheckInNotifier` + `morningCheckInProvider`.
   The `submit()` method orchestrates: checkin upsert → engine evaluate → prescription upsert → AI narrate → navigate.

2. `lib/features/daily_coach/presentation/morning_checkin_screen.dart`
   PageView wizard with `LinearProgressIndicator` header.

3. Step widgets (all in `widgets/` subdirectory):
   - `checkin_step_feeling.dart` — 5 `ChoiceChip` widgets
   - `checkin_step_sleep.dart` — shows auto-filled value; `Slider` for override with a "Use my value" toggle
   - `checkin_step_schedule.dart` — 3 `ChoiceChip` widgets
   - `checkin_step_vitality.dart` — Yes/No chips for morning erection + privacy disclaimer text; shown conditional on `DateTime.now().weekday == DateTime.sunday` for weekly slider
   - `checkin_step_injuries.dart` — `TextField` + "No injuries" skip button

4. Add routes to `app_router.dart` (Section 8).

**UX rules:**
- Back button on step 1 navigates to `/` (dismiss check-in, not back to auth).
- "Skip" on optional steps (injuries, vitality) advances to next step.
- Final step submit button shows `CircularProgressIndicator` while `isSubmitting = true`.
- On `isComplete`, call `context.go('/daily-coach/plan')`.

---

### Task C — Today's Plan Screen (Day 1-2)

**Assigned to:** Frontend Agent 2

**Depends on:** Task A entities and repositories.

**Deliverables:**

1. `lib/features/daily_coach/presentation/todays_plan_provider.dart`
   Full `TodaysPlanState` + `TodaysPlanNotifier` + `todaysPlanProvider`.

2. `lib/features/daily_coach/presentation/todays_plan_screen.dart`

3. Card widgets:
   - `widgets/todays_workout_card.dart`
   - `widgets/todays_meals_card.dart`
   - `widgets/todays_steps_ring.dart`
   - `widgets/todays_focus_tip.dart`
   - `widgets/bedtime_reminder_card.dart`

4. Fallback handling:
   - If `prescription == null`: show "No plan for today. Complete your morning check-in." with a button to `/daily-coach/checkin`.
   - If `isFallback == true`: show prescription without AI tip. Add subtle "Generated without AI" label.

**Data access pattern for steps today:**
```dart
// In TodaysPlanNotifier.loadPlan():
final today = DateTime.now();
final startOfDay = DateTime(today.year, today.month, today.day);
final endOfDay = startOfDay.add(const Duration(days: 1));
final stepsMetrics = await _healthRepo.getMetrics(
  _profileId,
  MetricType.steps,
  startDate: startOfDay,
  endDate: endOfDay,
);
final stepsToday = stepsMetrics.isNotEmpty
    ? stepsMetrics.first.valueNum?.toInt()
    : null;
```

**Steps goal access pattern:**
```dart
// Query wt_goals for metricType = 'steps' via the existing goals repository
// (lib/features/goals/data/goals_repository.dart)
// Fallback to 10000 if no goal set.
```

---

### Task D — Dashboard Integration + AI Context (Day 2)

**Assigned to:** Full-Stack Agent

**Depends on:** Tasks A and B complete.

**Deliverables:**

1. `lib/features/dashboard/presentation/widgets/daily_coach_card.dart`
   Three display states:
   - **Pending check-in:** "Good morning. How are you feeling today?" with "Start Check-In" button.
   - **Check-in complete, plan loading:** small `CircularProgressIndicator` with "Building your plan...".
   - **Plan ready:** shows scenario badge (icon + label), workout directive, and "View Today's Plan" button.

2. Update `lib/features/dashboard/presentation/dashboard_screen.dart`
   Insert `DailyCoachCard` below `TodaySummaryCard` and above `KeySignalsGrid` (first substantive card, highest visibility).

3. Edge function context update (TypeScript, file: `supabase/functions/ai-orchestrate/`):
   Register `generate_daily_plan` tool in the tool registry.
   System prompt: see Section 7b.
   Expected output schema: `{ "focus_tip": string, "narrative": string }`.
   Validate output against schema before returning to client.

4. Scenario badge labels (static strings) for `DailyCoachCard`:
   ```dart
   static String scenarioLabel(PrescriptionScenario s) {
     switch (s) {
       case PrescriptionScenario.wellRested:    return 'Well Rested';
       case PrescriptionScenario.tiredNotSore:  return 'Take It Easy';
       case PrescriptionScenario.verySore:      return 'Recovery Day';
       case PrescriptionScenario.busyDay:       return 'Express Mode';
       case PrescriptionScenario.behindSteps:   return 'Move More';
       case PrescriptionScenario.weightStalling: return 'Plateau Alert';
       case PrescriptionScenario.unwell:        return 'Rest & Recover';
       default:                                 return 'Standard Day';
     }
   }
   ```

---

## 12. Inter-Task Dependencies

```
Task A ──── completes entities/repos ──────────────┬──── Task B (check-in screen)
                                                   └──── Task C (plan screen)
Task B ──── routes registered ─────────────────────┬──── Task D (dashboard card)
Task A ──── migration deployed ────────────────────┘
Task D ──── edge function updated (independent of B and C)
```

Critical path: Task A must be substantially complete before B and C can build providers. B must be complete for Task D to wire the card's navigation. Task D's edge function work is independent and can proceed anytime.

---

## 13. File Summary

### New Files to Create

| File | Task |
|------|------|
| `supabase/migrations/20260222000001_daily_prescriptions.sql` | A |
| `lib/features/daily_coach/domain/checkin_entity.dart` | A |
| `lib/features/daily_coach/domain/daily_prescription_entity.dart` | A |
| `lib/features/daily_coach/data/checkin_repository.dart` | A |
| `lib/features/daily_coach/data/daily_prescription_repository.dart` | A |
| `lib/features/daily_coach/data/prescription_engine.dart` | A |
| `test/unit/daily_coach/prescription_engine_test.dart` | A |
| `lib/features/daily_coach/presentation/morning_checkin_provider.dart` | B |
| `lib/features/daily_coach/presentation/morning_checkin_screen.dart` | B |
| `lib/features/daily_coach/presentation/widgets/checkin_step_feeling.dart` | B |
| `lib/features/daily_coach/presentation/widgets/checkin_step_sleep.dart` | B |
| `lib/features/daily_coach/presentation/widgets/checkin_step_schedule.dart` | B |
| `lib/features/daily_coach/presentation/widgets/checkin_step_vitality.dart` | B |
| `lib/features/daily_coach/presentation/widgets/checkin_step_injuries.dart` | B |
| `lib/features/daily_coach/presentation/todays_plan_provider.dart` | C |
| `lib/features/daily_coach/presentation/todays_plan_screen.dart` | C |
| `lib/features/daily_coach/presentation/widgets/todays_workout_card.dart` | C |
| `lib/features/daily_coach/presentation/widgets/todays_meals_card.dart` | C |
| `lib/features/daily_coach/presentation/widgets/todays_steps_ring.dart` | C |
| `lib/features/daily_coach/presentation/widgets/todays_focus_tip.dart` | C |
| `lib/features/daily_coach/presentation/widgets/bedtime_reminder_card.dart` | C |
| `lib/features/dashboard/presentation/widgets/daily_coach_card.dart` | D |

### Modified Files

| File | Change | Task |
|------|--------|------|
| `lib/features/profile/domain/profile_entity.dart` | Add `aiConsentVitality`, `aiConsentBloodwork` fields | A |
| `lib/shared/core/router/app_router.dart` | Add `/daily-coach/checkin` and `/daily-coach/plan` routes; update `needsProfile` guard | B |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Insert `DailyCoachCard` | D |
| `supabase/functions/ai-orchestrate/` (TypeScript) | Register `generate_daily_plan` tool | D |

---

## 14. Known Constraints and Risks

**Risk 1: Sleep quality auto-fill**
`HealthRepository.getMetrics(profileId, MetricType.sleep)` returns `HealthMetricEntity.valueNum` in minutes. The check-in `sleep_quality` column is a 1–10 scale, not minutes. The mapping: `sleepQuality = (sleepMinutes / 60.0).clamp(1.0, 10.0)` (8 hours = 8.0). This is a reasonable approximation and overridable by the user.

**Risk 2: `_loadHealthMetrics` is mocked in DailyViewProvider**
The `_loadHealthMetrics` method in `lib/features/daily_view/presentation/daily_view_provider.dart` (line 317–325) returns hardcoded mock data. Task A's `PrescriptionInput` construction must use `HealthRepository.getMetrics()` directly, not this mock. Do not reuse the DailyViewProvider's data loading path.

**Risk 3: No `wt_goals` repository for steps goal**
There is a goals provider at `lib/features/goals/presentation/goals_provider.dart` but accessing step goal data from within the daily_coach feature requires calling through the goals repository. Do not couple domains directly — use a service layer call. For Phase 9, fallback to `stepsGoal = 10000` if not set.

**Risk 4: Active workout plan for "today"**
`WorkoutRepository.getActivePlan(profileId)` returns the active `WorkoutPlanEntity`. `getPlanExercises(planId, dayOfWeek: dow)` returns today's exercises. The workout card needs the number of exercises and a plan-day ID to construct the deep link. If no active plan exists, show "No plan set" in the workout card with a link to `/workouts`.

**Risk 5: Edge function not yet updated**
If the edge function does not yet have `generate_daily_plan` registered when the app calls it, it will return an error. The `MorningCheckInNotifier.submit()` method must handle `AiException` gracefully and set `isFallback = true`. The prescription must persist to the DB and the screen must load regardless.

**Risk 6: USB drops on Samsung SM S906B**
Per project memory, the test device drops USB frequently. Run the check-in flow on a physical device early in Task B to catch any `WillPopScope` or `PageController` disposal issues. Use `flutter run --release` on device for final validation.

---

## 15. Acceptance Criteria

Phase 9 is complete when:

1. A user can open the app and complete a morning check-in in under 30 seconds (5 taps for feeling/schedule, sleep auto-fills, injuries skipped).
2. After submission, `wt_daily_checkins` contains a row for today with correct values.
3. `wt_daily_prescriptions` contains a row for today with the correct scenario, directives, and bedtime.
4. The Today's Plan screen loads and shows: workout card, meals card (or "no plan" state), steps ring, focus tip, bedtime card.
5. The Dashboard home screen shows the `DailyCoachCard` with either a "Start check-in" prompt or the plan summary.
6. When AI narration fails (offline or 429), the plan still shows with `isFallback = true` — no blank screens.
7. `morning_erection` and `erection_quality_weekly` values are stored in Supabase but do NOT appear in AI context when `profile.aiConsentVitality = false`.
8. `PrescriptionEngine` unit tests cover all 8 scenarios and pass.
9. All navigation uses `context.go()` / `context.push()` — no `Navigator.pushNamed()`.
10. No file exceeds 500 lines (split if needed per CLAUDE.md conventions).
