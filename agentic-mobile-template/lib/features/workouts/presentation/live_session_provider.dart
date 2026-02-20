// lib/features/workouts/presentation/live_session_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workout_repository.dart';
import '../domain/workout_entity.dart';
import '../domain/workout_plan_exercise_entity.dart';
import '../domain/workout_set_entity.dart';

// ---------------------------------------------------------------------------
// LiveExerciseData — per-exercise state within an active session
// ---------------------------------------------------------------------------

/// Holds the plan spec, the current session's sets, and the previous session's
/// sets (used for auto-filling weight/reps on the logging UI).
class LiveExerciseData {
  const LiveExerciseData({
    required this.planExercise,
    required this.sets,
    required this.previousSets,
  });

  final WorkoutPlanExerciseEntity planExercise;

  /// Sets logged so far in this session for this exercise.
  final List<WorkoutSetEntity> sets;

  /// Sets from the most recent previous session — used to auto-fill weights.
  final List<WorkoutSetEntity> previousSets;

  LiveExerciseData copyWith({
    WorkoutPlanExerciseEntity? planExercise,
    List<WorkoutSetEntity>? sets,
    List<WorkoutSetEntity>? previousSets,
  }) {
    return LiveExerciseData(
      planExercise: planExercise ?? this.planExercise,
      sets: sets ?? this.sets,
      previousSets: previousSets ?? this.previousSets,
    );
  }

  // Convenience getters used by the UI.

  /// Exercise name from the joined entity; falls back to the exercise ID.
  String get displayName =>
      planExercise.exercise?.name ?? planExercise.exerciseId;

  /// Total volume for this exercise in the current session (kg * reps).
  double get sessionVolume {
    return sets
        .where((s) => s.completed)
        .fold(0.0, (sum, s) => sum + ((s.weightKg ?? 0) * (s.reps ?? 0)));
  }

  /// Highest estimated 1RM seen across completed sets this session.
  double? get bestEstimated1rm {
    final completed = sets.where((s) => s.completed && s.estimated1rm != null);
    if (completed.isEmpty) return null;
    return completed
        .map((s) => s.estimated1rm!)
        .reduce((a, b) => a > b ? a : b);
  }
}

// ---------------------------------------------------------------------------
// LiveSessionState
// ---------------------------------------------------------------------------

class LiveSessionState {
  const LiveSessionState({
    this.workoutId,
    this.profileId,
    this.planId,
    this.exercises = const [],
    this.currentExerciseIndex = 0,
    this.startTime,
    this.isActive = false,
    this.newPRExerciseIds = const [],
    this.isLoading = false,
    this.error,
  });

  /// The ID of the wt_workouts row created by [startSession] or
  /// [startAdHocSession].
  final String? workoutId;

  /// Profile that owns this session.
  final String? profileId;

  /// Plan ID — null for ad-hoc sessions.
  final String? planId;

  /// Ordered list of exercises to be completed this session.
  final List<LiveExerciseData> exercises;

  /// Index into [exercises] pointing at the currently displayed exercise.
  final int currentExerciseIndex;

  /// Wall-clock time the session began; used to calculate elapsed duration.
  final DateTime? startTime;

  /// True once the session has been started and before [completeSession] is
  /// called.
  final bool isActive;

  /// Exercise IDs for which a new personal record was set this session.
  final List<String> newPRExerciseIds;

  final bool isLoading;
  final String? error;

  LiveSessionState copyWith({
    String? workoutId,
    String? profileId,
    String? planId,
    List<LiveExerciseData>? exercises,
    int? currentExerciseIndex,
    DateTime? startTime,
    bool? isActive,
    List<String>? newPRExerciseIds,
    bool? isLoading,
    String? error,
  }) {
    return LiveSessionState(
      workoutId: workoutId ?? this.workoutId,
      profileId: profileId ?? this.profileId,
      planId: planId ?? this.planId,
      exercises: exercises ?? this.exercises,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      startTime: startTime ?? this.startTime,
      isActive: isActive ?? this.isActive,
      newPRExerciseIds: newPRExerciseIds ?? this.newPRExerciseIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // ── Derived getters ───────────────────────────────────────────────────────

  /// The [LiveExerciseData] currently focused in the UI.
  LiveExerciseData? get currentExercise {
    if (exercises.isEmpty) return null;
    if (currentExerciseIndex < 0 ||
        currentExerciseIndex >= exercises.length) {
      return null;
    }
    return exercises[currentExerciseIndex];
  }

  /// Total number of completed sets across all exercises.
  int get totalSetsCompleted {
    return exercises.fold(
      0,
      (sum, e) => sum + e.sets.where((s) => s.completed).length,
    );
  }

  /// Total number of exercises planned for this session.
  int get totalExercises => exercises.length;

  /// Aggregate volume (kg * reps) for all completed sets in the session.
  double get totalVolume {
    return exercises.fold(
      0.0,
      (sum, e) =>
          sum +
          e.sets
              .where((s) => s.completed)
              .fold(0.0, (s2, set) => s2 + ((set.weightKg ?? 0) * (set.reps ?? 0))),
    );
  }

  /// Time elapsed since the session started.
  Duration get elapsed =>
      startTime != null ? DateTime.now().difference(startTime!) : Duration.zero;

  /// Number of exercises that have at least one completed set.
  int get exercisesStarted {
    return exercises.where((e) => e.sets.any((s) => s.completed)).length;
  }

  /// True when at least one set has been completed in this session.
  bool get hasAnyLogged => totalSetsCompleted > 0;

  /// True when every exercise has all target sets completed.
  bool get allExercisesComplete {
    if (exercises.isEmpty) return false;
    return exercises.every(
      (e) =>
          e.sets.where((s) => s.completed).length >=
          e.planExercise.targetSets,
    );
  }
}

// ---------------------------------------------------------------------------
// LiveSessionNotifier
// ---------------------------------------------------------------------------

class LiveSessionNotifier extends StateNotifier<LiveSessionState> {
  LiveSessionNotifier(this._repository) : super(const LiveSessionState());

  final WorkoutRepository _repository;

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Starts a session driven by a specific [planId] and [dayOfWeek].
  ///
  /// Steps:
  /// 1. Creates the wt_workouts row via [startWorkoutSession].
  /// 2. Loads all plan exercises for this day (joined with exercise data).
  /// 3. For each exercise, loads the previous session's sets for auto-fill.
  /// 4. Builds [LiveExerciseData] with empty current sets pre-seeded from
  ///    target values (so the UI shows the expected weight/reps immediately).
  Future<void> startSession({
    required String profileId,
    required String planId,
    required int dayOfWeek,
    required String planName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Create the workout row.
      final workout = await _repository.startWorkoutSession(
        profileId: profileId,
        name: planName,
        workoutType: 'strength',
        planId: planId,
      );

      // 2. Load plan exercises for this day.
      final planExercises = await _repository.getPlanExercises(
        planId,
        dayOfWeek: dayOfWeek,
      );

      // 3 & 4. Build LiveExerciseData for each exercise.
      final liveExercises = await Future.wait(
        planExercises.map((pe) async {
          final previousSets = await _repository.getPreviousSessionSets(
            profileId,
            pe.exerciseId,
          );

          // Pre-seed empty sets from the plan targets.
          final seedSets = _buildSeedSets(
            workoutId: workout.id,
            profileId: profileId,
            planExercise: pe,
            previousSets: previousSets,
          );

          return LiveExerciseData(
            planExercise: pe,
            sets: seedSets,
            previousSets: previousSets,
          );
        }),
      );

      state = LiveSessionState(
        workoutId: workout.id,
        profileId: profileId,
        planId: planId,
        exercises: liveExercises,
        currentExerciseIndex: 0,
        startTime: workout.startTime ?? DateTime.now(),
        isActive: true,
        newPRExerciseIds: const [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Starts an ad-hoc session with no backing plan.
  Future<void> startAdHocSession({
    required String profileId,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final workout = await _repository.startWorkoutSession(
        profileId: profileId,
        name: name,
        workoutType: 'strength',
      );

      state = LiveSessionState(
        workoutId: workout.id,
        profileId: profileId,
        exercises: const [],
        currentExerciseIndex: 0,
        startTime: workout.startTime ?? DateTime.now(),
        isActive: true,
        newPRExerciseIds: const [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Set logging ───────────────────────────────────────────────────────────

  /// Logs a completed set for [exerciseIndex] / [setNumber].
  ///
  /// Returns true when this set established a new personal record.
  Future<bool> logSet({
    required int exerciseIndex,
    required int setNumber,
    required double weightKg,
    required int reps,
    double? rpe,
  }) async {
    final workoutId = state.workoutId;
    final profileId = state.profileId;
    if (workoutId == null || profileId == null) return false;
    if (exerciseIndex < 0 || exerciseIndex >= state.exercises.length) {
      return false;
    }

    try {
      final exercise = state.exercises[exerciseIndex];
      final exerciseId = exercise.planExercise.exerciseId;

      // 1. Persist the set.
      final savedSet = await _repository.addWorkoutSet(
        profileId: profileId,
        workoutId: workoutId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        weightKg: weightKg,
        reps: reps,
        completed: true,
        rpe: rpe,
      );

      // 2. Check for a new PR.
      final volume = weightKg * reps;
      final isNewPR = await _repository.checkAndUpdateRecord(
        profileId: profileId,
        exerciseId: exerciseId,
        weight: weightKg,
        reps: reps,
        volume: volume,
        estimated1rm: savedSet.estimated1rm,
      );

      // 3. Update state.
      final updatedSets = List<WorkoutSetEntity>.from(exercise.sets);
      final existingIndex =
          updatedSets.indexWhere((s) => s.setNumber == setNumber);
      if (existingIndex >= 0) {
        updatedSets[existingIndex] = savedSet;
      } else {
        updatedSets.add(savedSet);
      }

      final updatedExercise = exercise.copyWith(sets: updatedSets);
      final updatedExercises = List<LiveExerciseData>.from(state.exercises);
      updatedExercises[exerciseIndex] = updatedExercise;

      final updatedPRIds = isNewPR &&
              !state.newPRExerciseIds.contains(exerciseId)
          ? [...state.newPRExerciseIds, exerciseId]
          : state.newPRExerciseIds;

      state = state.copyWith(
        exercises: updatedExercises,
        newPRExerciseIds: updatedPRIds,
        error: null,
      );

      return isNewPR;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Toggles the [completed] flag on an already-persisted set.
  ///
  /// Returns true if the toggled set is now complete and a new PR was set.
  Future<bool> toggleSetComplete(int exerciseIndex, int setNumber) async {
    if (exerciseIndex < 0 || exerciseIndex >= state.exercises.length) {
      return false;
    }

    try {
      final exercise = state.exercises[exerciseIndex];
      final setIndex = exercise.sets.indexWhere((s) => s.setNumber == setNumber);
      if (setIndex < 0) return false;

      final set = exercise.sets[setIndex];
      final toggled = set.copyWith(completed: !set.completed);

      // Persist the change.
      final saved = await _repository.updateWorkoutSet(toggled);

      bool isNewPR = false;
      if (saved.completed &&
          saved.weightKg != null &&
          saved.reps != null &&
          state.profileId != null &&
          saved.exerciseId != null) {
        final volume = (saved.weightKg ?? 0) * (saved.reps ?? 0);
        isNewPR = await _repository.checkAndUpdateRecord(
          profileId: state.profileId!,
          exerciseId: saved.exerciseId!,
          weight: saved.weightKg,
          reps: saved.reps,
          volume: volume,
          estimated1rm: saved.estimated1rm,
        );
      }

      final updatedSets = List<WorkoutSetEntity>.from(exercise.sets);
      updatedSets[setIndex] = saved;

      final updatedExercise = exercise.copyWith(sets: updatedSets);
      final updatedExercises = List<LiveExerciseData>.from(state.exercises);
      updatedExercises[exerciseIndex] = updatedExercise;

      final prIds = isNewPR &&
              saved.exerciseId != null &&
              !state.newPRExerciseIds.contains(saved.exerciseId)
          ? [...state.newPRExerciseIds, saved.exerciseId!]
          : state.newPRExerciseIds;

      state = state.copyWith(
        exercises: updatedExercises,
        newPRExerciseIds: prIds,
        error: null,
      );

      return isNewPR;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Appends an extra (blank) set beyond the plan's target for [exerciseIndex].
  void addExtraSet(int exerciseIndex) {
    if (exerciseIndex < 0 || exerciseIndex >= state.exercises.length) return;

    final exercise = state.exercises[exerciseIndex];
    final nextSetNumber = exercise.sets.length + 1;

    // We create a local placeholder — it will be persisted when the user logs
    // actual weight/reps via [logSet].
    final workoutId = state.workoutId ?? '';
    final profileId = state.profileId ?? '';
    final now = DateTime.now();

    // Use previous set values as defaults when available.
    final prevSet = exercise.previousSets.isNotEmpty
        ? exercise.previousSets.last
        : null;

    final placeholder = WorkoutSetEntity(
      id: 'pending_$nextSetNumber',
      profileId: profileId,
      workoutId: workoutId,
      exerciseId: exercise.planExercise.exerciseId,
      setNumber: nextSetNumber,
      weightKg: prevSet?.weightKg,
      reps: prevSet?.reps,
      completed: false,
      loggedAt: now,
      createdAt: now,
    );

    final updatedSets = [...exercise.sets, placeholder];
    final updatedExercise = exercise.copyWith(sets: updatedSets);
    final updatedExercises = List<LiveExerciseData>.from(state.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    state = state.copyWith(exercises: updatedExercises);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  /// Advances to the next exercise (no-op if already at the last one).
  void nextExercise() {
    if (state.currentExerciseIndex < state.exercises.length - 1) {
      state = state.copyWith(
        currentExerciseIndex: state.currentExerciseIndex + 1,
      );
    }
  }

  /// Goes back to the previous exercise (no-op if already at the first one).
  void previousExercise() {
    if (state.currentExerciseIndex > 0) {
      state = state.copyWith(
        currentExerciseIndex: state.currentExerciseIndex - 1,
      );
    }
  }

  /// Jumps directly to [index] (clamped to valid range).
  void goToExercise(int index) {
    if (index < 0 || index >= state.exercises.length) return;
    state = state.copyWith(currentExerciseIndex: index);
  }

  // ── Session completion ────────────────────────────────────────────────────

  /// Marks the session as complete, persists the duration, and returns the
  /// final [WorkoutEntity].
  Future<WorkoutEntity> completeSession() async {
    final workoutId = state.workoutId;
    if (workoutId == null) {
      throw StateError('Cannot complete a session that was never started.');
    }

    final durationMinutes = state.elapsed.inMinutes;
    final completed = await _repository.completeWorkout(
      workoutId,
      durationMinutes: durationMinutes,
    );

    // Reset local state so the notifier is ready for the next session.
    state = const LiveSessionState();

    return completed;
  }

  // ── Error handling ────────────────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Builds a list of pre-seeded [WorkoutSetEntity] placeholders for the live
  /// logging UI. Values are taken from [previousSets] when available, otherwise
  /// they fall back to the plan's [targetWeightKg] / [targetReps].
  List<WorkoutSetEntity> _buildSeedSets({
    required String workoutId,
    required String profileId,
    required WorkoutPlanExerciseEntity planExercise,
    required List<WorkoutSetEntity> previousSets,
  }) {
    final now = DateTime.now();
    return List.generate(planExercise.targetSets, (i) {
      final setNumber = i + 1;
      final prev =
          previousSets.length > i ? previousSets[i] : null;

      return WorkoutSetEntity(
        id: 'seed_${planExercise.exerciseId}_$setNumber',
        profileId: profileId,
        workoutId: workoutId,
        exerciseId: planExercise.exerciseId,
        setNumber: setNumber,
        weightKg: prev?.weightKg ?? planExercise.targetWeightKg,
        reps: prev?.reps ?? planExercise.targetReps,
        completed: false,
        loggedAt: now,
        createdAt: now,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global (non-family) provider because there can only ever be one live
/// session active at a time. The notifier resets itself after [completeSession].
final liveSessionProvider =
    StateNotifierProvider<LiveSessionNotifier, LiveSessionState>(
  (ref) {
    final repo = ref.watch(workoutRepositoryProvider);
    return LiveSessionNotifier(repo);
  },
);
