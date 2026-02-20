// lib/features/workouts/presentation/progress_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_entity.dart';
import '../domain/exercise_record_entity.dart';
import '../domain/workout_entity.dart';

// ---------------------------------------------------------------------------
// Params types
// ---------------------------------------------------------------------------

typedef _WeekVolumeParams = ({String profileId, DateTime weekStart});
typedef _WeekSetsParams = ({String profileId, DateTime weekStart});
typedef _1rmHistoryParams = ({
  String profileId,
  String exerciseId,
  int weeks,
});

// ---------------------------------------------------------------------------
// Weekly muscle volume — Map<muscleGroup, totalVolumeKg>
// Keyed by (profileId, weekStart) so callers can request arbitrary weeks.
// ---------------------------------------------------------------------------

final weeklyMuscleVolumeProvider =
    FutureProvider.family<Map<String, double>, _WeekVolumeParams>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getWeeklyMuscleVolume(params.profileId, params.weekStart);
  },
);

// ---------------------------------------------------------------------------
// Weekly muscle set count — Map<muscleGroup, setCount>
// ---------------------------------------------------------------------------

final weeklyMuscleSetsProvider =
    FutureProvider.family<Map<String, int>, _WeekSetsParams>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getWeeklyMuscleSets(params.profileId, params.weekStart);
  },
);

// ---------------------------------------------------------------------------
// Exercise 1RM history — list of (date, estimated1rm) sorted ascending.
// ---------------------------------------------------------------------------

final exercise1rmHistoryProvider = FutureProvider.family<
    List<({DateTime date, double estimated1rm})>, _1rmHistoryParams>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getExercise1rmHistory(
      params.profileId,
      params.exerciseId,
      weeks: params.weeks,
    );
  },
);

// ---------------------------------------------------------------------------
// All exercise records (personal records) for a profile.
// ---------------------------------------------------------------------------

final exerciseRecordsProvider =
    FutureProvider.family<List<ExerciseRecordEntity>, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getExerciseRecords(profileId);
  },
);

// ---------------------------------------------------------------------------
// All exercises from the library (for dropdowns, search, etc.)
// Shared with exercise_browser_provider but defined here for progress screens.
// ---------------------------------------------------------------------------

final allExercisesProvider =
    FutureProvider.family<List<ExerciseEntity>, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getExercises(
      includeCustom: true,
      profileId: profileId,
    );
  },
);

// ---------------------------------------------------------------------------
// Completed workouts history — for the session-history screen.
// ---------------------------------------------------------------------------

final workoutHistoryProvider =
    FutureProvider.family<List<WorkoutEntity>, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getCompletedWorkouts(profileId);
  },
);

// ---------------------------------------------------------------------------
// Helper: returns the Monday of the week that contains [date].
// ---------------------------------------------------------------------------

DateTime mondayOf(DateTime date) {
  final weekday = date.weekday; // 1 = Mon … 7 = Sun
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

// ---------------------------------------------------------------------------
// Convenience: list of the last N week-start Mondays, newest first.
// ---------------------------------------------------------------------------

List<DateTime> lastNWeekStarts(int n) {
  final thisMonday = mondayOf(DateTime.now());
  return List.generate(n, (i) => thisMonday.subtract(Duration(days: i * 7)));
}
