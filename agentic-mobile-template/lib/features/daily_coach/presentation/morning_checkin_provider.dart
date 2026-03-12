import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/checkin_repository.dart';
import '../data/daily_prescription_repository.dart';
import '../data/fallback_narratives.dart';
import '../data/prescription_engine.dart';
import '../domain/checkin_entity.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_metric_entity.dart';
import '../../insights/data/insights_repository.dart';
import '../../insights/presentation/insights_provider.dart';
import '../../dashboard/presentation/dashboard_home_provider.dart';
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

  /// 5 steps: feeling, sleep, schedule, vitality, injuries.
  int get totalSteps => 5;

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
    this._insightsRepo,
    this._aiService,
    this._ref,
    this._profileId,
  ) : super(const MorningCheckInState()) {
    _loadInitialData();
  }

  final CheckInRepository _checkinRepo;
  final DailyPrescriptionRepository _prescriptionRepo;
  final HealthRepository _healthRepo;
  final InsightsRepository _insightsRepo;
  final AiOrchestratorService _aiService;
  final Ref _ref;
  final String _profileId;

  DateTime? _lastAiCall;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Load existing check-in for today (if re-opening the flow)
    CheckInEntity? existing;
    try {
      existing = await _checkinRepo.getTodayCheckIn(_profileId);
    } catch (_) {}

    // Auto-fill sleep from Health Connect data (last night's session)
    int? sleepMinutes;
    try {
      // Prefer Health Connect source
      var sleepMetrics = await _healthRepo.getMetrics(
        _profileId,
        MetricType.sleep,
        startDate: yesterday,
        endDate: now,
        source: HealthSource.healthconnect,
      );
      // Fall back to any source if no Health Connect data
      if (sleepMetrics.isEmpty) {
        sleepMetrics = await _healthRepo.getMetrics(
          _profileId,
          MetricType.sleep,
          startDate: yesterday,
          endDate: now,
        );
      }
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
      final userId = _ref.read(currentUserProvider)?.id;
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

      // 2. Load health signals for PrescriptionInput (all fetches run concurrently)
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Each closure is independent — one failure does not block the others.
      final healthResults = await Future.wait([
        // [0] Recovery score (calculated by PerformanceEngine)
        () async {
          try {
            final scores = await _insightsRepo.getRecoveryScores(
              profileId: _profileId,
              startDate: startOfDay,
              endDate: endOfDay,
            );
            return scores.isNotEmpty ? scores.last.recoveryScore : null;
          } catch (_) {
            return null;
          }
        }(),

        // [1] Steps today
        () async {
          try {
            final stepsMetrics = await _healthRepo.getMetrics(
              _profileId,
              MetricType.steps,
              startDate: startOfDay,
              endDate: endOfDay,
            );
            return stepsMetrics.isNotEmpty
                ? stepsMetrics.first.valueNum?.toInt().toDouble()
                : null;
          } catch (_) {
            return null;
          }
        }(),

        // [2] Resting HR (morning window: 6 h before → 8 h after midnight)
        () async {
          try {
            final hrMetrics = await _healthRepo.getMetrics(
              _profileId,
              MetricType.hr,
              startDate: startOfDay.subtract(const Duration(hours: 6)),
              endDate: startOfDay.add(const Duration(hours: 8)),
            );
            return hrMetrics.isNotEmpty ? hrMetrics.first.valueNum : null;
          } catch (_) {
            return null;
          }
        }(),

        // [3] Active calories yesterday — used to flag heavy session (>400 kcal)
        () async {
          try {
            final yesterday = startOfDay.subtract(const Duration(days: 1));
            final calMetrics = await _healthRepo.getMetrics(
              _profileId,
              MetricType.calories,
              startDate: yesterday,
              endDate: startOfDay,
            );
            final cals =
                calMetrics.isNotEmpty ? (calMetrics.first.valueNum ?? 0) : 0;
            // Encode bool as 1.0 / 0.0 so it fits the Future<double?> list type.
            return cals > 400 ? 1.0 : 0.0;
          } catch (_) {
            return null;
          }
        }(),

        // [4] Weight trend over last 14 days (kg/day rate of change)
        () async {
          try {
            final fourteenDaysAgo = startOfDay.subtract(const Duration(days: 14));
            final weightMetrics = await _healthRepo.getMetrics(
              _profileId,
              MetricType.weight,
              startDate: fourteenDaysAgo,
              endDate: endOfDay,
            );
            if (weightMetrics.length >= 2) {
              final oldest = weightMetrics.last.valueNum;
              final newest = weightMetrics.first.valueNum;
              if (oldest != null && newest != null) {
                final days = weightMetrics.first.recordedAt
                    .difference(weightMetrics.last.recordedAt)
                    .inDays
                    .abs();
                if (days > 0) return (newest - oldest) / days;
              }
            }
            return null;
          } catch (_) {
            return null;
          }
        }(),
      ]);

      final double? recoveryScore = healthResults[0];
      // Steps were cast to double? above to satisfy the list type; convert back.
      final int? stepsToday = healthResults[1]?.toInt();
      final double? restingHR = healthResults[2];
      final bool hadHeavySession = (healthResults[3] ?? 0.0) == 1.0;
      final double? weightTrend = healthResults[4];

      // 3. Build PrescriptionInput and run deterministic engine
      final prescriptionInput = PrescriptionInput(
        profileId: _profileId,
        date: checkinDate,
        checkIn: savedCheckIn,
        sleepMinutes: state.autoSleepMinutes,
        restingHR: restingHR,
        stepsToday: stepsToday,
        stepsGoal: 10000,
        weightTrend: weightTrend,
        hadHeavySessionYesterday: hadHeavySession,
        currentTime: today,
        recoveryScore: recoveryScore,
      );

      var prescription = PrescriptionEngine.evaluate(prescriptionInput);

      // Attach checkin reference
      prescription = prescription.copyWith(checkinId: savedCheckIn.id);

      // 4. Persist prescription (without AI fields)
      var savedPrescription =
          await _prescriptionRepo.upsertPrescription(prescription);

      // 5. AI narration — non-fatal; prescription shows regardless
      try {
        final aiNow = DateTime.now();
        if (_lastAiCall != null && aiNow.difference(_lastAiCall!).inSeconds < 3) {
          // Debounce: skip if called within 3 seconds
        } else {
          _lastAiCall = aiNow;
        final contextOverride = <String, dynamic>{
          'plan_type': savedPrescription.planType.name,
          'recovery_score': savedPrescription.recoveryScore,
          'prescription_scenario': savedPrescription.scenario.name,
          'workout_directive': savedPrescription.workoutDirective.name,
          'workout_volume_modifier': savedPrescription.workoutVolumeModifier,
          'meal_directive': savedPrescription.mealDirective.name,
          'calorie_modifier': savedPrescription.calorieModifier,
          'calorie_adjustment_percent': savedPrescription.calorieAdjustmentPercent,
          'check_in': savedCheckIn.toAiContextJson(includeVitality: false),
          'steps_today': stepsToday,
          'steps_goal': 10000,
        };

        final aiResponse = await _aiService.orchestrate(
          userId: userId,
          profileId: _profileId,
          workflowType: 'generate_daily_plan',
          message:
              'Translate today\'s plan data into a motivating daily narrative.',
          contextOverride: contextOverride,
        );

        final parsed =
            jsonDecode(aiResponse.assistantMessage) as Map<String, dynamic>;

        // Support both new schema (today_plan) and legacy (focus_tip/narrative)
        String? focusTip;
        String? narrative;
        if (parsed.containsKey('today_plan')) {
          final tp = parsed['today_plan'] as Map<String, dynamic>;
          focusTip = tp['focus'] as String?;
          narrative = tp['motivation'] as String?;
        } else {
          focusTip = parsed['focus_tip'] as String?;
          narrative = parsed['narrative'] as String?;
        }

        final withAi = savedPrescription.copyWith(
          aiFocusTip: focusTip,
          aiNarrative: narrative,
          aiModel: 'gpt-4o-mini',
          isFallback: false,
        );
        savedPrescription = await _prescriptionRepo.upsertPrescription(withAi);
        } // end else (debounce guard)
      } on AiException {
        // Mark as fallback — plan still persisted with pre-written narrative
        final fallbackContent =
            FallbackNarrative.forScenario(savedPrescription.scenario);
        final fallback = savedPrescription.copyWith(
          aiFocusTip: fallbackContent.focusTip,
          aiNarrative: fallbackContent.narrative,
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

      // Invalidate downstream providers so recovery and dashboard re-fetch
      // with the newly submitted check-in data.
      _ref.invalidate(insightsProvider);
      _ref.invalidate(dashboardHomeProvider);
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
      ref.watch(insightsRepositoryProvider),
      ref.watch(aiOrchestratorServiceProvider),
      ref,
      profileId,
    );
  },
);
