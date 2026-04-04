import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_coach/data/daily_prescription_repository.dart';
import '../../daily_coach/domain/daily_prescription_entity.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_metric_entity.dart';
import '../../meals/data/meal_plan_repository.dart';
import '../../meals/domain/meal_plan_entity.dart';
import '../../goals/data/goal_repository.dart';
import '../../workouts/data/workout_repository.dart';
import '../../workouts/domain/workout_plan_entity.dart';

// ── State ──────────────────────────────────────────────────────────────────

class TodaysPlanState {
  const TodaysPlanState({
    this.prescription,
    this.mealPlan,
    this.todaysWorkoutName,
    this.todaysExerciseCount,
    this.estimatedDurationMinutes,
    this.muscleGroups = const [],
    this.activePlanId,
    this.stepsToday,
    this.stepsGoal = 10000,
    this.isLoading = false,
    this.error,
  });

  final DailyPrescriptionEntity? prescription;
  final MealPlanEntity? mealPlan;
  final String? todaysWorkoutName;
  final int? todaysExerciseCount;
  final int? estimatedDurationMinutes;
  final List<String> muscleGroups;

  /// Plan ID used for deep-linking to /workouts/plan/:planId
  final String? activePlanId;

  final int? stepsToday;
  final int stepsGoal;
  final bool isLoading;
  final String? error;

  TodaysPlanState copyWith({
    DailyPrescriptionEntity? prescription,
    MealPlanEntity? mealPlan,
    String? todaysWorkoutName,
    int? todaysExerciseCount,
    int? estimatedDurationMinutes,
    List<String>? muscleGroups,
    String? activePlanId,
    int? stepsToday,
    int? stepsGoal,
    bool? isLoading,
    String? error,
  }) {
    return TodaysPlanState(
      prescription: prescription ?? this.prescription,
      mealPlan: mealPlan ?? this.mealPlan,
      todaysWorkoutName: todaysWorkoutName ?? this.todaysWorkoutName,
      todaysExerciseCount: todaysExerciseCount ?? this.todaysExerciseCount,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      activePlanId: activePlanId ?? this.activePlanId,
      stepsToday: stepsToday ?? this.stepsToday,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class TodaysPlanNotifier extends StateNotifier<TodaysPlanState> {
  TodaysPlanNotifier(
    this._prescriptionRepo,
    this._mealPlanRepo,
    this._healthRepo,
    this._workoutRepo,
    this._goalsRepo,
    this._profileId,
  ) : super(const TodaysPlanState(isLoading: true));

  final DailyPrescriptionRepository _prescriptionRepo;
  final MealPlanRepository _mealPlanRepo;
  final HealthRepository _healthRepo;
  final WorkoutRepository _workoutRepo;
  final GoalsRepository _goalsRepo;
  final String _profileId;

  Future<void> loadPlan() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday

      // Load all data sources in parallel
      final results = await Future.wait([
        _prescriptionRepo.getTodayPrescription(_profileId),
        _mealPlanRepo.getMealPlan(_profileId, today),
        _healthRepo.getMetrics(
          _profileId,
          MetricType.steps,
          startDate: startOfDay,
          endDate: endOfDay,
        ),
        _workoutRepo.getActivePlan(_profileId),
        _goalsRepo.getGoals(_profileId),
      ]);

      final prescription = results[0] as DailyPrescriptionEntity?;
      final mealPlan = results[1] as MealPlanEntity?;
      final stepsMetrics = results[2] as List<HealthMetricEntity>;
      final activePlan = results[3] as WorkoutPlanEntity?;
      final goals = results[4] as List;

      // Extract steps count
      final stepsToday = stepsMetrics.isNotEmpty
          ? stepsMetrics.first.valueNum?.toInt()
          : null;

      // Extract steps goal
      int stepsGoal = 10000;
      for (final goal in goals) {
        if (goal.metricType == 'steps') {
          stepsGoal = goal.targetValue.toInt();
          break;
        }
      }

      // Load today's workout exercises if there's an active plan
      String? todaysWorkoutName;
      int? exerciseCount;
      int? estimatedDuration;
      List<String> muscleGroups = [];
      String? activePlanId;

      if (activePlan != null) {
        activePlanId = activePlan.id;
        final exercises = await _workoutRepo.getPlanExercises(
          activePlan.id,
          dayOfWeek: dayOfWeek,
        );
        todaysWorkoutName = activePlan.name;
        exerciseCount = exercises.length;

        // Estimate duration: ~45s per set + rest between sets
        int totalSeconds = 0;
        final groups = <String>{};
        for (final ex in exercises) {
          final sets = ex.targetSets;
          totalSeconds += (sets * 45) + ((sets - 1).clamp(0, 99) * ex.restSeconds);
          if (ex.exercise?.muscleGroup != null) {
            groups.add(ex.exercise!.muscleGroup!);
          }
        }
        estimatedDuration = (totalSeconds / 60).ceil();
        muscleGroups = groups.toList();
      }

      state = TodaysPlanState(
        prescription: prescription,
        mealPlan: mealPlan,
        todaysWorkoutName: todaysWorkoutName,
        todaysExerciseCount: exerciseCount,
        estimatedDurationMinutes: estimatedDuration,
        muscleGroups: muscleGroups,
        activePlanId: activePlanId,
        stepsToday: stepsToday,
        stepsGoal: stepsGoal,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadPlan();
}

// ── Provider ───────────────────────────────────────────────────────────────

final todaysPlanProvider = StateNotifierProvider.family<
    TodaysPlanNotifier, TodaysPlanState, String>(
  (ref, profileId) {
    final notifier = TodaysPlanNotifier(
      ref.watch(dailyPrescriptionRepositoryProvider),
      ref.watch(mealPlanRepositoryProvider),
      ref.watch(healthRepositoryProvider),
      ref.watch(workoutRepositoryProvider),
      ref.watch(goalsRepositoryProvider),
      profileId,
    );
    notifier.loadPlan();
    return notifier;
  },
);
