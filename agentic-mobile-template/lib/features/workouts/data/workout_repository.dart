// lib/features/workouts/data/workout_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:welltrack/features/workouts/domain/workout_entity.dart';
import 'package:welltrack/features/workouts/domain/workout_log_entity.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Supabase.instance.client);
});

class Exercise {
  final String id;
  final String name;
  final String category;
  final String? description;
  final List<String> muscleGroups;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.muscleGroups,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      muscleGroups: (json['muscle_groups'] as List?)?.cast<String>() ?? [],
    );
  }
}

class WorkoutRepository {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  WorkoutRepository(this._supabase);

  // CRUD for workouts
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

  Future<WorkoutEntity> createWorkout({
    required String profileId,
    required String name,
    required String workoutType,
    required DateTime scheduledDate,
    String? notes,
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
      final data = {
        'completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
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

  // Exercise library
  Future<List<Exercise>> getExercises({
    String? category,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from('wt_exercises').select();

      if (category != null) {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      final response = await query.order('name');

      return (response as List).map((json) => Exercise.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises: $e');
    }
  }

  // Workout logs
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
