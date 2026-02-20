// lib/features/workouts/data/workout_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/exercise_entity.dart';
import '../domain/exercise_record_entity.dart';
import '../domain/workout_entity.dart';
import '../domain/workout_log_entity.dart';
import '../domain/workout_plan_entity.dart';
import '../domain/workout_plan_exercise_entity.dart';
import '../domain/workout_set_entity.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Supabase.instance.client);
});

class WorkoutRepository {
  WorkoutRepository(this._supabase);
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  // ─── Workouts (sessions) ──────────────────────────────────────────

  Future<List<WorkoutEntity>> getWorkouts(
    String profileId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('wt_workouts')
          .select()
          .eq('profile_id', profileId);

      if (startDate != null) {
        query = query.gte('scheduled_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('scheduled_date', endDate.toIso8601String());
      }

      final response = await query.order('scheduled_date', ascending: false);

      return (response as List)
          .map((json) => WorkoutEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch workouts: $e');
    }
  }

  Future<WorkoutEntity> getWorkout(String workoutId) async {
    try {
      final response = await _supabase
          .from('wt_workouts')
          .select()
          .eq('id', workoutId)
          .single();

      return WorkoutEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch workout: $e');
    }
  }

  Future<List<WorkoutEntity>> getTodayWorkouts(String profileId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getWorkouts(
      profileId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  Future<List<WorkoutEntity>> getCompletedWorkouts(
    String profileId, {
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('wt_workouts')
          .select()
          .eq('profile_id', profileId)
          .eq('completed', true)
          .order('completed_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => WorkoutEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch completed workouts: $e');
    }
  }

  Future<WorkoutEntity> createWorkout({
    required String profileId,
    required String name,
    required String workoutType,
    required DateTime scheduledDate,
    String? notes,
    String? planId,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'name': name,
        'workout_type': workoutType,
        'scheduled_date': scheduledDate.toIso8601String(),
        'completed': false,
        'notes': notes,
        'plan_id': planId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workouts')
          .insert(data)
          .select()
          .single();

      return WorkoutEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create workout: $e');
    }
  }

  Future<WorkoutEntity> startWorkoutSession({
    required String profileId,
    required String name,
    required String workoutType,
    String? planId,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'name': name,
        'workout_type': workoutType,
        'scheduled_date': now.toIso8601String(),
        'completed': false,
        'plan_id': planId,
        'start_time': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workouts')
          .insert(data)
          .select()
          .single();

      return WorkoutEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to start workout session: $e');
    }
  }

  Future<WorkoutEntity> updateWorkout(WorkoutEntity workout) async {
    try {
      final data = workout.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_workouts')
          .update(data)
          .eq('id', workout.id)
          .select()
          .single();

      return WorkoutEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update workout: $e');
    }
  }

  Future<WorkoutEntity> completeWorkout(
    String workoutId, {
    int? durationMinutes,
  }) async {
    try {
      final now = DateTime.now();
      final data = <String, dynamic>{
        'completed': true,
        'completed_at': now.toIso8601String(),
        'end_time': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (durationMinutes != null) {
        data['duration_minutes'] = durationMinutes;
      }

      final response = await _supabase
          .from('wt_workouts')
          .update(data)
          .eq('id', workoutId)
          .select()
          .single();

      return WorkoutEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to complete workout: $e');
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    try {
      await _supabase.from('wt_workouts').delete().eq('id', workoutId);
    } catch (e) {
      throw Exception('Failed to delete workout: $e');
    }
  }

  // ─── Exercise Library ─────────────────────────────────────────────

  Future<List<ExerciseEntity>> getExercises({
    String? muscleGroup,
    String? equipmentType,
    String? search,
    bool includeCustom = true,
    String? profileId,
  }) async {
    try {
      var query = _supabase.from('wt_exercises').select();

      if (muscleGroup != null) {
        query = query.contains('muscle_groups', [muscleGroup]);
      }

      if (equipmentType != null) {
        query = query.eq('equipment_type', equipmentType);
      }

      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }

      if (!includeCustom) {
        query = query.eq('is_custom', false);
      }

      final response = await query.order('name');

      return (response as List)
          .map((json) => ExerciseEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises: $e');
    }
  }

  Future<ExerciseEntity> getExerciseById(String id) async {
    try {
      final response = await _supabase
          .from('wt_exercises')
          .select()
          .eq('id', id)
          .single();

      return ExerciseEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch exercise: $e');
    }
  }

  Future<ExerciseEntity> createCustomExercise({
    required String profileId,
    required String name,
    required List<String> muscleGroups,
    List<String> secondaryMuscles = const [],
    String? equipmentType,
    String? category,
    String? instructions,
    String? difficulty,
  }) async {
    try {
      final data = {
        'id': _uuid.v4(),
        'name': name,
        'muscle_group': muscleGroups.isNotEmpty ? muscleGroups.first : null,
        'muscle_groups': muscleGroups,
        'secondary_muscles': secondaryMuscles,
        'equipment_type': equipmentType,
        'category': category ?? 'strength',
        'instructions': instructions,
        'difficulty': difficulty ?? 'intermediate',
        'is_custom': true,
        'profile_id': profileId,
      };

      final response = await _supabase
          .from('wt_exercises')
          .insert(data)
          .select()
          .single();

      return ExerciseEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create custom exercise: $e');
    }
  }

  // ─── Workout Plans ────────────────────────────────────────────────

  Future<List<WorkoutPlanEntity>> getPlans(String profileId) async {
    try {
      final response = await _supabase
          .from('wt_workout_plans')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WorkoutPlanEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch workout plans: $e');
    }
  }

  Future<WorkoutPlanEntity?> getActivePlan(String profileId) async {
    try {
      final response = await _supabase
          .from('wt_workout_plans')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .limit(1);

      if ((response as List).isEmpty) return null;
      return WorkoutPlanEntity.fromJson(response.first);
    } catch (e) {
      throw Exception('Failed to fetch active plan: $e');
    }
  }

  Future<WorkoutPlanEntity> createPlan({
    required String profileId,
    required String name,
    String? description,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'name': name,
        'description': description,
        'is_active': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workout_plans')
          .insert(data)
          .select()
          .single();

      return WorkoutPlanEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create workout plan: $e');
    }
  }

  Future<WorkoutPlanEntity> updatePlan(WorkoutPlanEntity plan) async {
    try {
      final data = plan.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_workout_plans')
          .update(data)
          .eq('id', plan.id)
          .select()
          .single();

      return WorkoutPlanEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update workout plan: $e');
    }
  }

  Future<void> setActivePlan(String profileId, String planId) async {
    try {
      // Deactivate all plans for this profile
      await _supabase
          .from('wt_workout_plans')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('profile_id', profileId);

      // Activate the selected plan
      await _supabase
          .from('wt_workout_plans')
          .update({'is_active': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', planId);
    } catch (e) {
      throw Exception('Failed to set active plan: $e');
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await _supabase.from('wt_workout_plans').delete().eq('id', planId);
    } catch (e) {
      throw Exception('Failed to delete workout plan: $e');
    }
  }

  // ─── Workout Plan Exercises ───────────────────────────────────────

  Future<List<WorkoutPlanExerciseEntity>> getPlanExercises(
    String planId, {
    int? dayOfWeek,
  }) async {
    try {
      var query = _supabase
          .from('wt_workout_plan_exercises')
          .select('*, wt_exercises(*)')
          .eq('plan_id', planId);

      if (dayOfWeek != null) {
        query = query.eq('day_of_week', dayOfWeek);
      }

      final response = await query.order('sort_order');

      return (response as List)
          .map((json) => WorkoutPlanExerciseEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch plan exercises: $e');
    }
  }

  Future<WorkoutPlanExerciseEntity> addPlanExercise({
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
    try {
      final data = {
        'id': _uuid.v4(),
        'plan_id': planId,
        'exercise_id': exerciseId,
        'day_of_week': dayOfWeek,
        'sort_order': sortOrder,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'target_weight_kg': targetWeightKg,
        'rest_seconds': restSeconds,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workout_plan_exercises')
          .insert(data)
          .select('*, wt_exercises(*)')
          .single();

      return WorkoutPlanExerciseEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add plan exercise: $e');
    }
  }

  Future<WorkoutPlanExerciseEntity> updatePlanExercise({
    required String id,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
    int? restSeconds,
    String? notes,
    int? sortOrder,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (targetSets != null) data['target_sets'] = targetSets;
      if (targetReps != null) data['target_reps'] = targetReps;
      if (targetWeightKg != null) data['target_weight_kg'] = targetWeightKg;
      if (restSeconds != null) data['rest_seconds'] = restSeconds;
      if (notes != null) data['notes'] = notes;
      if (sortOrder != null) data['sort_order'] = sortOrder;

      final response = await _supabase
          .from('wt_workout_plan_exercises')
          .update(data)
          .eq('id', id)
          .select('*, wt_exercises(*)')
          .single();

      return WorkoutPlanExerciseEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update plan exercise: $e');
    }
  }

  Future<void> removePlanExercise(String id) async {
    try {
      await _supabase
          .from('wt_workout_plan_exercises')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to remove plan exercise: $e');
    }
  }

  Future<void> reorderPlanExercises(
    String planId,
    int dayOfWeek,
    List<String> orderedIds,
  ) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _supabase
            .from('wt_workout_plan_exercises')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
    } catch (e) {
      throw Exception('Failed to reorder plan exercises: $e');
    }
  }

  // ─── Workout Sets (per-set logging) ───────────────────────────────

  Future<List<WorkoutSetEntity>> getWorkoutSets(
    String workoutId, {
    String? exerciseId,
  }) async {
    try {
      var query = _supabase
          .from('wt_workout_sets')
          .select()
          .eq('workout_id', workoutId);

      if (exerciseId != null) {
        query = query.eq('exercise_id', exerciseId);
      }

      final response = await query.order('set_number');

      return (response as List)
          .map((json) => WorkoutSetEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch workout sets: $e');
    }
  }

  Future<WorkoutSetEntity> addWorkoutSet({
    required String profileId,
    required String workoutId,
    required String exerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
    bool completed = true,
    double? rpe,
  }) async {
    try {
      // Calculate estimated 1RM using Epley formula
      double? estimated1rm;
      if (weightKg != null && weightKg > 0 && reps != null && reps > 0) {
        estimated1rm = weightKg * (1 + reps / 30.0);
      }

      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'completed': completed,
        'rpe': rpe,
        'estimated_1rm': estimated1rm,
        'logged_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workout_sets')
          .insert(data)
          .select()
          .single();

      return WorkoutSetEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add workout set: $e');
    }
  }

  Future<WorkoutSetEntity> updateWorkoutSet(WorkoutSetEntity set) async {
    try {
      // Recalculate estimated 1RM
      double? estimated1rm;
      if (set.weightKg != null &&
          set.weightKg! > 0 &&
          set.reps != null &&
          set.reps! > 0) {
        estimated1rm = set.weightKg! * (1 + set.reps! / 30.0);
      }

      final data = set.toJson();
      data['estimated_1rm'] = estimated1rm;

      final response = await _supabase
          .from('wt_workout_sets')
          .update(data)
          .eq('id', set.id)
          .select()
          .single();

      return WorkoutSetEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update workout set: $e');
    }
  }

  Future<void> deleteWorkoutSet(String id) async {
    try {
      await _supabase.from('wt_workout_sets').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete workout set: $e');
    }
  }

  /// Fetches sets from the most recent completed session containing this
  /// exercise. Used to auto-fill the live logging screen with previous values.
  Future<List<WorkoutSetEntity>> getPreviousSessionSets(
    String profileId,
    String exerciseId,
  ) async {
    try {
      // Find the most recent workout containing sets for this exercise
      final workoutResponse = await _supabase
          .from('wt_workout_sets')
          .select('workout_id')
          .eq('profile_id', profileId)
          .eq('exercise_id', exerciseId)
          .order('logged_at', ascending: false)
          .limit(1);

      if ((workoutResponse as List).isEmpty) return [];

      final lastWorkoutId = workoutResponse.first['workout_id'] as String;

      // Fetch all sets for that exercise in that workout
      final response = await _supabase
          .from('wt_workout_sets')
          .select()
          .eq('workout_id', lastWorkoutId)
          .eq('exercise_id', exerciseId)
          .order('set_number');

      return (response as List)
          .map((json) => WorkoutSetEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch previous session sets: $e');
    }
  }

  // ─── Exercise Records (PRs) ───────────────────────────────────────

  Future<ExerciseRecordEntity?> getExerciseRecord(
    String profileId,
    String exerciseId,
  ) async {
    try {
      final response = await _supabase
          .from('wt_exercise_records')
          .select()
          .eq('profile_id', profileId)
          .eq('exercise_id', exerciseId)
          .limit(1);

      if ((response as List).isEmpty) return null;
      return ExerciseRecordEntity.fromJson(response.first);
    } catch (e) {
      throw Exception('Failed to fetch exercise record: $e');
    }
  }

  Future<List<ExerciseRecordEntity>> getExerciseRecords(
    String profileId,
  ) async {
    try {
      final response = await _supabase
          .from('wt_exercise_records')
          .select()
          .eq('profile_id', profileId)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => ExerciseRecordEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch exercise records: $e');
    }
  }

  Future<ExerciseRecordEntity> upsertExerciseRecord(
    ExerciseRecordEntity record,
  ) async {
    try {
      final data = record.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_exercise_records')
          .upsert(data, onConflict: 'profile_id,exercise_id')
          .select()
          .single();

      return ExerciseRecordEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to upsert exercise record: $e');
    }
  }

  /// Checks if the given values beat the current records. Updates if so.
  /// Returns true if a new PR was set.
  Future<bool> checkAndUpdateRecord({
    required String profileId,
    required String exerciseId,
    double? weight,
    int? reps,
    double? volume,
    double? estimated1rm,
  }) async {
    try {
      final existing = await getExerciseRecord(profileId, exerciseId);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      bool isNewPR = false;

      double? maxWeight = existing?.maxWeightKg;
      DateTime? maxWeightDate = existing?.maxWeightDate;
      int? maxReps = existing?.maxReps;
      DateTime? maxRepsDate = existing?.maxRepsDate;
      double? maxVolume = existing?.maxVolume;
      DateTime? maxVolumeDate = existing?.maxVolumeDate;
      double? max1rm = existing?.maxEstimated1rm;
      DateTime? max1rmDate = existing?.max1rmDate;

      if (weight != null && (maxWeight == null || weight > maxWeight)) {
        maxWeight = weight;
        maxWeightDate = todayDate;
        isNewPR = true;
      }

      if (reps != null && (maxReps == null || reps > maxReps)) {
        maxReps = reps;
        maxRepsDate = todayDate;
        isNewPR = true;
      }

      if (volume != null && (maxVolume == null || volume > maxVolume)) {
        maxVolume = volume;
        maxVolumeDate = todayDate;
        isNewPR = true;
      }

      if (estimated1rm != null && (max1rm == null || estimated1rm > max1rm)) {
        max1rm = estimated1rm;
        max1rmDate = todayDate;
        isNewPR = true;
      }

      if (isNewPR) {
        final record = ExerciseRecordEntity(
          id: existing?.id ?? _uuid.v4(),
          profileId: profileId,
          exerciseId: exerciseId,
          maxWeightKg: maxWeight,
          maxWeightDate: maxWeightDate,
          maxReps: maxReps,
          maxRepsDate: maxRepsDate,
          maxVolume: maxVolume,
          maxVolumeDate: maxVolumeDate,
          maxEstimated1rm: max1rm,
          max1rmDate: max1rmDate,
          updatedAt: today,
        );
        await upsertExerciseRecord(record);
      }

      return isNewPR;
    } catch (e) {
      throw Exception('Failed to check/update exercise record: $e');
    }
  }

  // ─── Volume & Analytics Queries ───────────────────────────────────

  /// Weekly muscle volume: total (sets * reps * weight) per muscle group.
  Future<Map<String, double>> getWeeklyMuscleVolume(
    String profileId,
    DateTime weekStart,
  ) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));

      // Get all sets for this week
      final response = await _supabase
          .from('wt_workout_sets')
          .select('weight_kg, reps, exercise_id')
          .eq('profile_id', profileId)
          .eq('completed', true)
          .gte('logged_at', weekStart.toIso8601String())
          .lt('logged_at', weekEnd.toIso8601String());

      if ((response as List).isEmpty) return {};

      // Collect unique exercise IDs
      final exerciseIds = <String>{};
      for (final row in response) {
        final eid = row['exercise_id'] as String?;
        if (eid != null) exerciseIds.add(eid);
      }

      if (exerciseIds.isEmpty) return {};

      // Fetch exercise muscle groups
      final exercises = await _supabase
          .from('wt_exercises')
          .select('id, muscle_groups')
          .inFilter('id', exerciseIds.toList());

      final exerciseMuscles = <String, List<String>>{};
      for (final ex in exercises as List) {
        exerciseMuscles[ex['id'] as String] =
            (ex['muscle_groups'] as List?)?.cast<String>() ?? [];
      }

      // Calculate volume per muscle group
      final volumeMap = <String, double>{};
      for (final row in response) {
        final weightKg = row['weight_kg'] != null
            ? (row['weight_kg'] as num).toDouble()
            : 0.0;
        final reps = row['reps'] as int? ?? 0;
        final exerciseId = row['exercise_id'] as String?;
        final volume = weightKg * reps;

        if (exerciseId != null && volume > 0) {
          final muscles = exerciseMuscles[exerciseId] ?? [];
          for (final muscle in muscles) {
            volumeMap[muscle] = (volumeMap[muscle] ?? 0) + volume;
          }
        }
      }

      return volumeMap;
    } catch (e) {
      throw Exception('Failed to fetch weekly muscle volume: $e');
    }
  }

  /// Weekly muscle set count per muscle group.
  Future<Map<String, int>> getWeeklyMuscleSets(
    String profileId,
    DateTime weekStart,
  ) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));

      final response = await _supabase
          .from('wt_workout_sets')
          .select('exercise_id')
          .eq('profile_id', profileId)
          .eq('completed', true)
          .gte('logged_at', weekStart.toIso8601String())
          .lt('logged_at', weekEnd.toIso8601String());

      if ((response as List).isEmpty) return {};

      final exerciseIds = <String>{};
      for (final row in response) {
        final eid = row['exercise_id'] as String?;
        if (eid != null) exerciseIds.add(eid);
      }

      if (exerciseIds.isEmpty) return {};

      final exercises = await _supabase
          .from('wt_exercises')
          .select('id, muscle_groups')
          .inFilter('id', exerciseIds.toList());

      final exerciseMuscles = <String, List<String>>{};
      for (final ex in exercises as List) {
        exerciseMuscles[ex['id'] as String] =
            (ex['muscle_groups'] as List?)?.cast<String>() ?? [];
      }

      final setsMap = <String, int>{};
      for (final row in response) {
        final exerciseId = row['exercise_id'] as String?;
        if (exerciseId != null) {
          final muscles = exerciseMuscles[exerciseId] ?? [];
          for (final muscle in muscles) {
            setsMap[muscle] = (setsMap[muscle] ?? 0) + 1;
          }
        }
      }

      return setsMap;
    } catch (e) {
      throw Exception('Failed to fetch weekly muscle sets: $e');
    }
  }

  /// Estimated 1RM history for a specific exercise over N weeks.
  Future<List<({DateTime date, double estimated1rm})>> getExercise1rmHistory(
    String profileId,
    String exerciseId, {
    int weeks = 12,
  }) async {
    try {
      final startDate =
          DateTime.now().subtract(Duration(days: weeks * 7));

      final response = await _supabase
          .from('wt_workout_sets')
          .select('logged_at, estimated_1rm')
          .eq('profile_id', profileId)
          .eq('exercise_id', exerciseId)
          .not('estimated_1rm', 'is', null)
          .gte('logged_at', startDate.toIso8601String())
          .order('logged_at');

      final results = <({DateTime date, double estimated1rm})>[];

      // Group by date, take max 1RM per day
      final dailyMax = <String, double>{};
      final dailyDates = <String, DateTime>{};

      for (final row in response as List) {
        final loggedAt = DateTime.parse(row['logged_at'] as String);
        final dateKey =
            '${loggedAt.year}-${loggedAt.month}-${loggedAt.day}';
        final e1rm = (row['estimated_1rm'] as num).toDouble();

        if (!dailyMax.containsKey(dateKey) || e1rm > dailyMax[dateKey]!) {
          dailyMax[dateKey] = e1rm;
          dailyDates[dateKey] = DateTime(
            loggedAt.year,
            loggedAt.month,
            loggedAt.day,
          );
        }
      }

      for (final entry in dailyMax.entries) {
        results.add((
          date: dailyDates[entry.key]!,
          estimated1rm: entry.value,
        ));
      }

      results.sort((a, b) => a.date.compareTo(b.date));
      return results;
    } catch (e) {
      throw Exception('Failed to fetch 1RM history: $e');
    }
  }

  // ─── Legacy Workout Logs (kept for backward compat) ───────────────

  Future<List<WorkoutLogEntity>> getWorkoutLogs(String workoutId) async {
    try {
      final response = await _supabase
          .from('wt_workout_logs')
          .select()
          .eq('workout_id', workoutId)
          .order('logged_at');

      return (response as List)
          .map((json) => WorkoutLogEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch workout logs: $e');
    }
  }

  Future<WorkoutLogEntity> addExerciseLog({
    required String profileId,
    required String workoutId,
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
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets': sets,
        'reps': reps,
        'weight_kg': weightKg,
        'duration_seconds': durationSeconds,
        'distance_m': distanceM,
        'notes': notes,
        'logged_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_workout_logs')
          .insert(data)
          .select()
          .single();

      return WorkoutLogEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add exercise log: $e');
    }
  }

  Future<WorkoutLogEntity> updateWorkoutLog(WorkoutLogEntity log) async {
    try {
      final data = log.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_workout_logs')
          .update(data)
          .eq('id', log.id)
          .select()
          .single();

      return WorkoutLogEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update workout log: $e');
    }
  }

  Future<void> deleteWorkoutLog(String logId) async {
    try {
      await _supabase.from('wt_workout_logs').delete().eq('id', logId);
    } catch (e) {
      throw Exception('Failed to delete workout log: $e');
    }
  }
}
