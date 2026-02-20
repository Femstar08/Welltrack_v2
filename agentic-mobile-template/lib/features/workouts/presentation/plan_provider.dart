// lib/features/workouts/presentation/plan_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workout_repository.dart';
import '../domain/workout_plan_entity.dart';
import '../domain/workout_plan_exercise_entity.dart';

// ---------------------------------------------------------------------------
// FutureProvider — list all plans for a profile
// ---------------------------------------------------------------------------

final workoutPlansProvider =
    FutureProvider.family<List<WorkoutPlanEntity>, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getPlans(profileId);
  },
);

// ---------------------------------------------------------------------------
// FutureProvider — the currently active plan for a profile (may be null)
// ---------------------------------------------------------------------------

final activePlanProvider =
    FutureProvider.family<WorkoutPlanEntity?, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getActivePlan(profileId);
  },
);

// ---------------------------------------------------------------------------
// FutureProvider — exercises assigned to a specific plan day
// ---------------------------------------------------------------------------

final planExercisesProvider = FutureProvider.family<
    List<WorkoutPlanExerciseEntity>, ({String planId, int dayOfWeek})>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getPlanExercises(params.planId, dayOfWeek: params.dayOfWeek);
  },
);

// ---------------------------------------------------------------------------
// StateNotifier — full CRUD for plans + plan-exercise management
// ---------------------------------------------------------------------------

class WorkoutPlanNotifier
    extends StateNotifier<AsyncValue<List<WorkoutPlanEntity>>> {
  WorkoutPlanNotifier(this._repository, this._profileId)
      : super(const AsyncValue.loading()) {
    loadPlans();
  }

  final WorkoutRepository _repository;
  final String _profileId;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetches all plans for [_profileId] and refreshes state.
  Future<void> loadPlans() async {
    state = const AsyncValue.loading();
    try {
      final plans = await _repository.getPlans(_profileId);
      state = AsyncValue.data(plans);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Plan CRUD ─────────────────────────────────────────────────────────────

  /// Creates a new plan and prepends it to the current list.
  Future<WorkoutPlanEntity> createPlan({
    required String name,
    String? description,
  }) async {
    final plan = await _repository.createPlan(
      profileId: _profileId,
      name: name,
      description: description,
    );

    state.whenData((plans) {
      state = AsyncValue.data([plan, ...plans]);
    });

    return plan;
  }

  /// Persists changes to [plan] and updates the list in-place.
  Future<void> updatePlan(WorkoutPlanEntity plan) async {
    final updated = await _repository.updatePlan(plan);

    state.whenData((plans) {
      state = AsyncValue.data(
        plans.map((p) => p.id == updated.id ? updated : p).toList(),
      );
    });
  }

  /// Marks [planId] as the active plan and deactivates all others.
  ///
  /// The repository handles the two-step deactivate-then-activate in a single
  /// call. After the remote update we reload to ensure local state is
  /// consistent with the server's response.
  Future<void> setActivePlan(String planId) async {
    await _repository.setActivePlan(_profileId, planId);
    await loadPlans();
  }

  /// Deletes [planId] and removes it from the local list.
  Future<void> deletePlan(String planId) async {
    await _repository.deletePlan(planId);

    state.whenData((plans) {
      state = AsyncValue.data(plans.where((p) => p.id != planId).toList());
    });
  }

  // ── Plan exercise management ───────────────────────────────────────────────

  /// Adds an exercise to [planId] for [dayOfWeek] and returns the new entity.
  Future<WorkoutPlanExerciseEntity> addExercise({
    required String planId,
    required String exerciseId,
    required int dayOfWeek,
    required int sortOrder,
    int targetSets = 3,
    int targetReps = 10,
    double? targetWeightKg,
    int restSeconds = 90,
    String? notes,
  }) async {
    return _repository.addPlanExercise(
      planId: planId,
      exerciseId: exerciseId,
      dayOfWeek: dayOfWeek,
      sortOrder: sortOrder,
      targetSets: targetSets,
      targetReps: targetReps,
      targetWeightKg: targetWeightKg,
      restSeconds: restSeconds,
      notes: notes,
    );
  }

  /// Removes a plan-exercise row by its own [id].
  Future<void> removeExercise(String id) async {
    await _repository.removePlanExercise(id);
  }

  /// Persists a new sort order for [dayOfWeek] of [planId].
  ///
  /// [orderedIds] must contain the IDs of every plan-exercise for that day
  /// in the desired display order.
  Future<void> reorderExercises(
    String planId,
    int dayOfWeek,
    List<String> orderedIds,
  ) async {
    await _repository.reorderPlanExercises(planId, dayOfWeek, orderedIds);
  }
}

final workoutPlanNotifierProvider = StateNotifierProvider.family<
    WorkoutPlanNotifier, AsyncValue<List<WorkoutPlanEntity>>, String>(
  (ref, profileId) {
    final repo = ref.watch(workoutRepositoryProvider);
    return WorkoutPlanNotifier(repo, profileId);
  },
);
