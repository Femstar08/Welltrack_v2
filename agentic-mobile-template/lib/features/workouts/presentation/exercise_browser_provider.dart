// lib/features/workouts/presentation/exercise_browser_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_entity.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ExerciseBrowserState {
  const ExerciseBrowserState({
    this.allExercises = const [],
    this.filteredExercises = const [],
    this.searchQuery = '',
    this.selectedMuscleGroup,
    this.selectedEquipment,
    this.isLoading = false,
    this.error,
  });

  final List<ExerciseEntity> allExercises;
  final List<ExerciseEntity> filteredExercises;
  final String searchQuery;
  final String? selectedMuscleGroup;
  final String? selectedEquipment;
  final bool isLoading;
  final String? error;

  ExerciseBrowserState copyWith({
    List<ExerciseEntity>? allExercises,
    List<ExerciseEntity>? filteredExercises,
    String? searchQuery,
    String? selectedMuscleGroup,
    bool clearMuscleGroup = false,
    String? selectedEquipment,
    bool clearEquipment = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ExerciseBrowserState(
      allExercises: allExercises ?? this.allExercises,
      filteredExercises: filteredExercises ?? this.filteredExercises,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMuscleGroup: clearMuscleGroup
          ? null
          : selectedMuscleGroup ?? this.selectedMuscleGroup,
      selectedEquipment: clearEquipment
          ? null
          : selectedEquipment ?? this.selectedEquipment,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  List<String> get availableMuscleGroups {
    final groups = <String>{};
    for (final ex in allExercises) {
      groups.addAll(ex.muscleGroups);
      if (ex.muscleGroup != null) groups.add(ex.muscleGroup!);
    }
    return groups.toList()..sort();
  }

  List<String> get availableEquipment {
    final types = <String>{};
    for (final ex in allExercises) {
      if (ex.equipmentType != null) types.add(ex.equipmentType!);
    }
    return types.toList()..sort();
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ExerciseBrowserNotifier
    extends StateNotifier<ExerciseBrowserState> {
  ExerciseBrowserNotifier(this._repository, this._profileId)
      : super(const ExerciseBrowserState());

  final WorkoutRepository _repository;
  final String _profileId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final exercises = await _repository.getExercises(
        includeCustom: true,
        profileId: _profileId,
      );
      state = state.copyWith(
        allExercises: exercises,
        filteredExercises: exercises,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void filterByMuscleGroup(String? group) {
    if (group == null) {
      state = state.copyWith(clearMuscleGroup: true);
    } else {
      state = state.copyWith(selectedMuscleGroup: group);
    }
    _applyFilters();
  }

  void filterByEquipment(String? equipment) {
    if (equipment == null) {
      state = state.copyWith(clearEquipment: true);
    } else {
      state = state.copyWith(selectedEquipment: equipment);
    }
    _applyFilters();
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      clearMuscleGroup: true,
      clearEquipment: true,
      filteredExercises: state.allExercises,
    );
  }

  void _applyFilters() {
    var results = state.allExercises;

    final query = state.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results
          .where((e) => e.name.toLowerCase().contains(query))
          .toList();
    }

    if (state.selectedMuscleGroup != null) {
      final mg = state.selectedMuscleGroup!;
      results = results
          .where((e) =>
              e.muscleGroups.contains(mg) || e.muscleGroup == mg)
          .toList();
    }

    if (state.selectedEquipment != null) {
      results = results
          .where((e) => e.equipmentType == state.selectedEquipment)
          .toList();
    }

    state = state.copyWith(filteredExercises: results);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final exerciseBrowserProvider = StateNotifierProvider.family<
    ExerciseBrowserNotifier, ExerciseBrowserState, String>(
  (ref, profileId) {
    final repo = ref.watch(workoutRepositoryProvider);
    return ExerciseBrowserNotifier(repo, profileId);
  },
);

// ---------------------------------------------------------------------------
// Lightweight atomic filter providers
//
// Prefer these over [exerciseBrowserProvider] when the UI only needs a simple
// filtered list (e.g. plan-exercise picker) without the full browser state.
// ---------------------------------------------------------------------------

/// Live search query; empty string means no search filter.
final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Active muscle-group chip; null means "all muscles".
final exerciseMuscleFilterProvider = StateProvider<String?>((ref) => null);

/// Active equipment chip; null means "all equipment".
final exerciseEquipmentFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered exercise list derived from the three providers above.
///
/// Re-evaluates automatically whenever any filter changes.
final filteredExercisesProvider = FutureProvider<List<ExerciseEntity>>(
  (ref) async {
    final repo = ref.watch(workoutRepositoryProvider);
    final search = ref.watch(exerciseSearchQueryProvider).trim();
    final muscleFilter = ref.watch(exerciseMuscleFilterProvider);
    final equipmentFilter = ref.watch(exerciseEquipmentFilterProvider);

    return repo.getExercises(
      search: search.isNotEmpty ? search : null,
      muscleGroup: muscleFilter,
      equipmentType: equipmentFilter,
    );
  },
);

// ---------------------------------------------------------------------------
// Static filter constants — used to populate chip rows in the UI
// ---------------------------------------------------------------------------

/// All recognised muscle groups stored in `wt_exercises.muscle_groups[]`.
const kMuscleGroups = <String>[
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quadriceps',
  'hamstrings',
  'glutes',
  'calves',
  'core',
  'full_body',
  'cardio',
];

/// All recognised equipment types stored in `wt_exercises.equipment_type`.
const kEquipmentTypes = <String>[
  'barbell',
  'dumbbell',
  'cable',
  'machine',
  'bodyweight',
  'kettlebell',
  'ez_bar',
  'smith_machine',
  'trap_bar',
];

// ---------------------------------------------------------------------------
// Custom exercise creation notifier
// ---------------------------------------------------------------------------

/// Tracks async state for the custom-exercise creation flow.
class CustomExerciseCreationState {
  const CustomExerciseCreationState({
    this.isLoading = false,
    this.created,
    this.error,
  });

  final bool isLoading;

  /// The most recently created exercise, available immediately after success
  /// so the caller can auto-select it (e.g. in a plan-exercise picker).
  final ExerciseEntity? created;

  final String? error;

  CustomExerciseCreationState copyWith({
    bool? isLoading,
    ExerciseEntity? created,
    String? error,
  }) {
    return CustomExerciseCreationState(
      isLoading: isLoading ?? this.isLoading,
      created: created ?? this.created,
      error: error,
    );
  }
}

class CustomExerciseNotifier
    extends StateNotifier<CustomExerciseCreationState> {
  CustomExerciseNotifier(this._repository)
      : super(const CustomExerciseCreationState());

  final WorkoutRepository _repository;

  /// Persists a new custom exercise and updates [state] with the result.
  ///
  /// Returns the created [ExerciseEntity] on success, or null on failure.
  Future<ExerciseEntity?> createCustomExercise({
    required String profileId,
    required String name,
    required List<String> muscleGroups,
    List<String> secondaryMuscles = const [],
    String? equipmentType,
    String? category,
    String? instructions,
    String? difficulty,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final exercise = await _repository.createCustomExercise(
        profileId: profileId,
        name: name,
        muscleGroups: muscleGroups,
        secondaryMuscles: secondaryMuscles,
        equipmentType: equipmentType,
        category: category,
        instructions: instructions,
        difficulty: difficulty,
      );

      state = CustomExerciseCreationState(isLoading: false, created: exercise);
      return exercise;
    } catch (e) {
      state = CustomExerciseCreationState(isLoading: false, error: e.toString());
      return null;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  /// Resets state — call after the created exercise has been handled.
  void reset() => state = const CustomExerciseCreationState();
}

final customExerciseNotifierProvider = StateNotifierProvider.family<
    CustomExerciseNotifier, CustomExerciseCreationState, String>(
  (ref, profileId) {
    final repo = ref.watch(workoutRepositoryProvider);
    return CustomExerciseNotifier(repo);
  },
);
