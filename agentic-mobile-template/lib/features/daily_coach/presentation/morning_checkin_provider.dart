import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/checkin_repository.dart';
import '../data/daily_prescription_repository.dart';
import '../data/fallback_narratives.dart';
import '../data/prescription_engine.dart';
import '../domain/checkin_entity.dart';
import '../domain/daily_prescription_entity.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_metric_entity.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MorningCheckInState {
  const MorningCheckInState({
    this.currentStep = 0,
    this.feelingLevel,
    this.sleepQuality,
    this.sleepQualityOverride = false,
    this.autoSleepMinutes,
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

  /// Manual override value (1–10). Null = use auto-detected.
  final double? sleepQuality;
  final bool sleepQualityOverride;

  /// Raw sleep duration from Health Connect (minutes). Shown as default.
  final int? autoSleepMinutes;

  final bool? morningErection;
  final String? injuriesNotes;
  final String? scheduleType;
  final int? erectionQualityWeekly;
  final bool isSubmitting;
  final bool isComplete;
  final CheckInEntity? todayCheckIn;
  final String? error;

  // ── Derived ──────────────────────────────────────────────────────────────

  bool get isSundayPrompt => DateTime.now().weekday == DateTime.sunday;

  /// 4 steps: feeling, sleep, schedule, injuries.
  int get totalSteps => 4;

  /// The sleep quality value to persist (override takes precedence).
  double? get effectiveSleepQuality {
    if (sleepQualityOverride && sleepQuality != null) return sleepQuality;
    if (autoSleepMinutes != null) {
      return (autoSleepMinutes! / 60.0).clamp(1.0, 10.0);
    }
    return sleepQuality;
  }

  MorningCheckInState copyWith({
    int? currentStep,
    String? feelingLevel,
    double? sleepQuality,
    bool? sleepQualityOverride,
    int? autoSleepMinutes,
    bool? morningErection,
    String? injuriesNotes,
    String? scheduleType,
    int? erectionQualityWeekly,
    bool? isSubmitting,
    bool? isComplete,
    CheckInEntity? todayCheckIn,
    String? error,
    bool clearError = false,
    bool clearMorningErection = false,
    bool clearInjuries = false,
    bool clearErectionQuality = false,
  }) {
    return MorningCheckInState(
      currentStep: currentStep ?? this.currentStep,
      feelingLevel: feelingLevel ?? this.feelingLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepQualityOverride: sleepQualityOverride ?? this.sleepQualityOverride,
      autoSleepMinutes: autoSleepMinutes ?? this.autoSleepMinutes,
      morningErection:
          clearMorningErection ? null : (morningErection ?? this.morningErection),
      injuriesNotes:
          clearInjuries ? null : (injuriesNotes ?? this.injuriesNotes),
      scheduleType: scheduleType ?? this.scheduleType,
      erectionQualityWeekly: clearErectionQuality
          ? null
          : (erectionQualityWeekly ?? this.erectionQualityWeekly),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      todayCheckIn: todayCheckIn ?? this.todayCheckIn,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class MorningCheckInNotifier
    extends StateNotifier<MorningCheckInState> {
  MorningCheckInNotifier(
    this._checkinRepo,
    this._prescriptionRepo,
    this._healthRepo,
    this._aiService,
    this._profileId,
  ) : super(const MorningCheckInState()) {
    _loadInitialData();
  }

  final CheckInRepository _checkinRepo;
  final DailyPrescriptionRepository _prescriptionRepo;
  final HealthRepository _healthRepo;
  final AiOrchestratorService _aiService;
  final String _profileId;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Load existing check-in for today (if re-opening the flow)
    CheckInEntity? existing;
    try {
      existing = await _checkinRepo.getTodayCheckIn(_profileId);
    } catch (_) {}

    // Auto-fill sleep from health data (last night's session)
    int? sleepMinutes;
    try {
      final sleepMetrics = await _healthRepo.getMetrics(
        _profileId,
        MetricType.sleep,
        startDate: yesterday,
        endDate: now,
      );
      if (sleepMetrics.isNotEmpty) {
        sleepMinutes = sleepMetrics.first.valueNum?.toInt();
      }
    } catch (_) {}

    if (!mounted) return;
    state = state.copyWith(
      todayCheckIn: existing,
      autoSleepMinutes: sleepMinutes,
      isComplete: existing != null,
    );
  }

  // ── Step setters ─────────────────────────────────────────────────────────

  void setFeeling(String feeling) {
    state = state.copyWith(feelingLevel: feeling, clearError: true);
  }

  void setSleepQuality(double quality) {
    state = state.copyWith(sleepQuality: quality);
  }

  void overrideSleep(double quality) {
    state = state.copyWith(
      sleepQuality: quality,
      sleepQualityOverride: true,
    );
  }

  void useAutoSleep() {
    state = state.copyWith(sleepQualityOverride: false, sleepQuality: null);
  }

  void setSchedule(String schedule) {
    state = state.copyWith(scheduleType: schedule, clearError: true);
  }

  void setMorningErection(bool? value) {
    if (value == null) {
      state = state.copyWith(clearMorningErection: true);
    } else {
      state = state.copyWith(morningErection: value);
    }
  }

  void setErectionQuality(int quality) {
    state = state.copyWith(erectionQualityWeekly: quality);
  }

  void setInjuries(String? notes) {
    final trimmed = notes?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearInjuries: true);
    } else {
      state = state.copyWith(injuriesNotes: trimmed);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void nextStep() {
    if (state.currentStep < state.totalSteps - 1) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        clearError: true,
      );
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearError: true,
      );
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final today = DateTime.now();
      final checkinDate = DateTime(today.year, today.month, today.day);

      // 1. Build and upsert CheckInEntity
      final checkIn = CheckInEntity(
        profileId: _profileId,
        checkinDate: checkinDate,
        feelingLevel: state.feelingLevel,
        sleepQuality: state.effectiveSleepQuality,
        sleepQualityOverride: state.sleepQualityOverride,
        morningErection: state.morningErection,
        injuriesNotes:
            (state.injuriesNotes?.isNotEmpty ?? false) ? state.injuriesNotes : null,
        scheduleType: state.scheduleType,
        isWeekly: state.isSundayPrompt,
        erectionQualityWeekly: state.erectionQualityWeekly,
        isSensitive: true,
      );

      final savedCheckIn = await _checkinRepo.upsertCheckIn(checkIn);

      // 2. Load health signals for PrescriptionInput
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      int? stepsToday;
      double? restingHR;
      bool hadHeavySession = false;

      try {
        final stepsMetrics = await _healthRepo.getMetrics(
          _profileId,
          MetricType.steps,
          startDate: startOfDay,
          endDate: endOfDay,
        );
        stepsToday =
            stepsMetrics.isNotEmpty ? stepsMetrics.first.valueNum?.toInt() : null;
      } catch (_) {}

      try {
        final hrMetrics = await _healthRepo.getMetrics(
          _profileId,
          MetricType.hr,
          startDate: startOfDay.subtract(const Duration(hours: 6)),
          endDate: startOfDay.add(const Duration(hours: 8)),
        );
        restingHR = hrMetrics.isNotEmpty ? hrMetrics.first.valueNum : null;
      } catch (_) {}

      try {
        // Approximate heavy session: active calories > 400 yesterday
        final yesterday = startOfDay.subtract(const Duration(days: 1));
        final calMetrics = await _healthRepo.getMetrics(
          _profileId,
          MetricType.calories,
          startDate: yesterday,
          endDate: startOfDay,
        );
        final cals = calMetrics.isNotEmpty ? (calMetrics.first.valueNum ?? 0) : 0;
        hadHeavySession = cals > 400;
      } catch (_) {}

      // 3. Build PrescriptionInput and run deterministic engine
      final prescriptionInput = PrescriptionInput(
        profileId: _profileId,
        date: checkinDate,
        checkIn: savedCheckIn,
        sleepMinutes: state.autoSleepMinutes,
        restingHR: restingHR,
        stepsToday: stepsToday,
        stepsGoal: 10000,
        hadHeavySessionYesterday: hadHeavySession,
        currentTime: today,
      );

      var prescription = PrescriptionEngine.evaluate(prescriptionInput);

      // Attach checkin reference
      prescription = DailyPrescriptionEntity(
        profileId: prescription.profileId,
        checkinId: savedCheckIn.id,
        prescriptionDate: prescription.prescriptionDate,
        scenario: prescription.scenario,
        workoutDirective: prescription.workoutDirective,
        workoutVolumeModifier: prescription.workoutVolumeModifier,
        workoutNote: prescription.workoutNote,
        mealDirective: prescription.mealDirective,
        calorieModifier: prescription.calorieModifier,
        stepsNudge: prescription.stepsNudge,
        bedtimeHour: prescription.bedtimeHour,
        bedtimeMinute: prescription.bedtimeMinute,
      );

      // 4. Persist prescription (without AI fields)
      var savedPrescription =
          await _prescriptionRepo.upsertPrescription(prescription);

      // 5. AI narration — non-fatal; prescription shows regardless
      try {
        final contextOverride = <String, dynamic>{
          'prescription_scenario': savedPrescription.scenario.name,
          'workout_directive': savedPrescription.workoutDirective.name,
          'workout_volume_modifier': savedPrescription.workoutVolumeModifier,
          'meal_directive': savedPrescription.mealDirective.name,
          'calorie_modifier': savedPrescription.calorieModifier,
          'check_in': savedCheckIn.toAiContextJson(includeVitality: false),
          'steps_today': stepsToday,
          'steps_goal': 10000,
        };

        final aiResponse = await _aiService.orchestrate(
          userId: userId,
          profileId: _profileId,
          workflowType: 'generate_daily_plan',
          contextOverride: contextOverride,
        );

        final parsed =
            jsonDecode(aiResponse.assistantMessage) as Map<String, dynamic>;

        final withAi = DailyPrescriptionEntity(
          id: savedPrescription.id,
          profileId: savedPrescription.profileId,
          checkinId: savedPrescription.checkinId,
          prescriptionDate: savedPrescription.prescriptionDate,
          scenario: savedPrescription.scenario,
          workoutDirective: savedPrescription.workoutDirective,
          workoutVolumeModifier: savedPrescription.workoutVolumeModifier,
          workoutNote: savedPrescription.workoutNote,
          mealDirective: savedPrescription.mealDirective,
          calorieModifier: savedPrescription.calorieModifier,
          stepsNudge: savedPrescription.stepsNudge,
          aiFocusTip: parsed['focus_tip'] as String?,
          aiNarrative: parsed['narrative'] as String?,
          aiModel: 'gpt-4o-mini',
          bedtimeHour: savedPrescription.bedtimeHour,
          bedtimeMinute: savedPrescription.bedtimeMinute,
          isFallback: false,
        );
        savedPrescription = await _prescriptionRepo.upsertPrescription(withAi);
      } on AiException {
        // Mark as fallback — plan still persisted with pre-written narrative
        final fallbackContent =
            FallbackNarrative.forScenario(savedPrescription.scenario);
        final fallback = DailyPrescriptionEntity(
          id: savedPrescription.id,
          profileId: savedPrescription.profileId,
          checkinId: savedPrescription.checkinId,
          prescriptionDate: savedPrescription.prescriptionDate,
          scenario: savedPrescription.scenario,
          workoutDirective: savedPrescription.workoutDirective,
          workoutVolumeModifier: savedPrescription.workoutVolumeModifier,
          workoutNote: savedPrescription.workoutNote,
          mealDirective: savedPrescription.mealDirective,
          calorieModifier: savedPrescription.calorieModifier,
          stepsNudge: savedPrescription.stepsNudge,
          aiFocusTip: fallbackContent.focusTip,
          aiNarrative: fallbackContent.narrative,
          bedtimeHour: savedPrescription.bedtimeHour,
          bedtimeMinute: savedPrescription.bedtimeMinute,
          isFallback: true,
        );
        await _prescriptionRepo.upsertPrescription(fallback);
      } catch (_) {
        // Any other error — still complete the check-in
      }

      // 6. Done
      state = state.copyWith(
        isSubmitting: false,
        isComplete: true,
        todayCheckIn: savedCheckIn,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Check-in failed: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final morningCheckInProvider = StateNotifierProvider.family<
    MorningCheckInNotifier, MorningCheckInState, String>(
  (ref, profileId) {
    return MorningCheckInNotifier(
      ref.watch(checkinRepositoryProvider),
      ref.watch(dailyPrescriptionRepositoryProvider),
      ref.watch(healthRepositoryProvider),
      ref.watch(aiOrchestratorServiceProvider),
      profileId,
    );
  },
);
