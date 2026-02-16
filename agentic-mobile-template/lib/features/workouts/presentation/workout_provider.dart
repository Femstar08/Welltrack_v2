// lib/features/workouts/presentation/workout_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/workouts/data/workout_repository.dart';
import 'package:welltrack/features/workouts/domain/workout_entity.dart';
import 'package:welltrack/features/workouts/domain/workout_log_entity.dart';

// State classes
class WorkoutState {
  final List<WorkoutEntity> workouts;
  final List<WorkoutEntity> todayWorkouts;
  final List<Exercise> exercises;
  final bool isLoading;
  final String? error;

  const WorkoutState({
    this.workouts = const [],
    this.todayWorkouts = const [],
    this.exercises = const [],
    this.isLoading = false,
    this.error,
  });

  WorkoutState copyWith({
    List<WorkoutEntity>? workouts,
    List<WorkoutEntity>? todayWorkouts,
    List<Exercise>? exercises,
    bool? isLoading,
    String? error,
  }) {
    return WorkoutState(
      workouts: workouts ?? this.workouts,
      todayWorkouts: todayWorkouts ?? this.todayWorkouts,
      exercises: exercises ?? this.exercises,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get completedTodayCount =>
      todayWorkouts.where((w) => w.completed).length;

  int get totalTodayCount => todayWorkouts.length;

  double get todayCompletionPercentage {
    if (totalTodayCount == 0) return 0.0;
    return (completedTodayCount / totalTodayCount) * 100;
  }
}

class WorkoutDetailState {
  final WorkoutEntity? workout;
  final List<WorkoutLogEntity> logs;
  final bool isLoading;
  final String? error;

  const WorkoutDetailState({
    this.workout,
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  WorkoutDetailState copyWith({
    WorkoutEntity? workout,
    List<WorkoutLogEntity>? logs,
    bool? isLoading,
    String? error,
  }) {
    return WorkoutDetailState(
      workout: workout ?? this.workout,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalDurationSeconds {
    return logs.fold(0, (sum, log) => sum + (log.durationSeconds ?? 0));
  }

  int get totalExercises => logs.length;
}

// StateNotifier for workout list
class WorkoutNotifier extends StateNotifier<WorkoutState> {
  final WorkoutRepository _repository;
  final String _profileId;

  WorkoutNotifier(this._repository, this._profileId)
      : super(const WorkoutState());

  Future<void> loadWorkouts({DateTime? startDate, DateTime? endDate}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final workouts = await _repository.getWorkouts(
        _profileId,
        startDate: startDate,
        endDate: endDate,
      );

      final todayWorkouts = await _repository.getTodayWorkouts(_profileId);

      state = state.copyWith(
        workouts: workouts,
        todayWorkouts: todayWorkouts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadExercises({String? category, String? searchQuery}) async {
    try {
      final exercises = await _repository.getExercises(
        category: category,
        searchQuery: searchQuery,
      );

      state = state.copyWith(exercises: exercises);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createWorkout({
    required String name,
    required String workoutType,
    required DateTime scheduledDate,
    String? notes,
  }) async {
    try {
      final workout = await _repository.createWorkout(
        profileId: _profileId,
        name: name,
        workoutType: workoutType,
        scheduledDate: scheduledDate,
        notes: notes,
      );

      final isToday = workout.isScheduledToday;

      state = state.copyWith(
        workouts: [workout, ...state.workouts],
        todayWorkouts: isToday
            ? [workout, ...state.todayWorkouts]
            : state.todayWorkouts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateWorkout(WorkoutEntity workout) async {
    try {
      final updated = await _repository.updateWorkout(workout);

      final workouts = state.workouts
          .map((w) => w.id == updated.id ? updated : w)
          .toList();

      final todayWorkouts = state.todayWorkouts
          .map((w) => w.id == updated.id ? updated : w)
          .toList();

      state = state.copyWith(
        workouts: workouts,
        todayWorkouts: todayWorkouts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> completeWorkout(String workoutId, {int? durationMinutes}) async {
    try {
      final completed = await _repository.completeWorkout(
        workoutId,
        durationMinutes: durationMinutes,
      );

      final workouts = state.workouts
          .map((w) => w.id == completed.id ? completed : w)
          .toList();

      final todayWorkouts = state.todayWorkouts
          .map((w) => w.id == completed.id ? completed : w)
          .toList();

      state = state.copyWith(
        workouts: workouts,
        todayWorkouts: todayWorkouts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    try {
      await _repository.deleteWorkout(workoutId);

      final workouts = state.workouts.where((w) => w.id != workoutId).toList();
      final todayWorkouts =
          state.todayWorkouts.where((w) => w.id != workoutId).toList();

      state = state.copyWith(
        workouts: workouts,
        todayWorkouts: todayWorkouts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// StateNotifier for workout detail/logging
class WorkoutDetailNotifier extends StateNotifier<WorkoutDetailState> {
  final WorkoutRepository _repository;
  final String _profileId;
  final String _workoutId;

  WorkoutDetailNotifier(this._repository, this._profileId, this._workoutId)
      : super(const WorkoutDetailState());

  Future<void> loadWorkoutDetail() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final workout = await _repository.getWorkout(_workoutId);
      final logs = await _repository.getWorkoutLogs(_workoutId);

      state = state.copyWith(
        workout: workout,
        logs: logs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addExerciseLog({
    String? exerciseId,
    required String exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceM,
    String? notes,
  }) async {
    try {
      final log = await _repository.addExerciseLog(
        profileId: _profileId,
        workoutId: _workoutId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        sets: sets,
        reps: reps,
        weightKg: weightKg,
        durationSeconds: durationSeconds,
        distanceM: distanceM,
        notes: notes,
      );

      state = state.copyWith(logs: [...state.logs, log]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateLog(WorkoutLogEntity log) async {
    try {
      final updated = await _repository.updateWorkoutLog(log);
      final logs = state.logs.map((l) => l.id == updated.id ? updated : l).toList();

      state = state.copyWith(logs: logs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _repository.deleteWorkoutLog(logId);
      final logs = state.logs.where((l) => l.id != logId).toList();

      state = state.copyWith(logs: logs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final workoutProvider =
    StateNotifierProvider.family<WorkoutNotifier, WorkoutState, String>(
  (ref, profileId) {
    final repository = ref.watch(workoutRepositoryProvider);
    return WorkoutNotifier(repository, profileId);
  },
);

final workoutDetailProvider = StateNotifierProvider.family<WorkoutDetailNotifier,
    WorkoutDetailState, ({String profileId, String workoutId})>(
  (ref, params) {
    final repository = ref.watch(workoutRepositoryProvider);
    return WorkoutDetailNotifier(
      repository,
      params.profileId,
      params.workoutId,
    );
  },
);
