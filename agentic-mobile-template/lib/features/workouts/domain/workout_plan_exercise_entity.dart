// lib/features/workouts/domain/workout_plan_exercise_entity.dart

import 'exercise_entity.dart';

class WorkoutPlanExerciseEntity {
  const WorkoutPlanExerciseEntity({
    required this.id,
    required this.planId,
    required this.exerciseId,
    required this.dayOfWeek,
    required this.sortOrder,
    required this.targetSets,
    required this.targetReps,
    this.targetWeightKg,
    required this.restSeconds,
    this.notes,
    required this.createdAt,
    this.exercise,
  });

  /// Parses a row from `wt_workout_plan_exercises`.
  ///
  /// When Supabase returns a joined row (e.g. `.select('*, wt_exercises(*)')`),
  /// the nested exercise data is present under the 'wt_exercises' key and is
  /// parsed automatically into [exercise].
  factory WorkoutPlanExerciseEntity.fromJson(Map<String, dynamic> json) {
    final exerciseJson = json['wt_exercises'];
    return WorkoutPlanExerciseEntity(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      exerciseId: json['exercise_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      sortOrder: json['sort_order'] as int,
      targetSets: json['target_sets'] as int,
      targetReps: json['target_reps'] as int,
      targetWeightKg: json['target_weight_kg'] != null
          ? (json['target_weight_kg'] as num).toDouble()
          : null,
      restSeconds: json['rest_seconds'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      exercise: exerciseJson != null
          ? ExerciseEntity.fromJson(exerciseJson as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String planId;
  final String exerciseId;

  /// ISO day-of-week: 1 = Monday, 7 = Sunday.
  final int dayOfWeek;
  final int sortOrder;
  final int targetSets;
  final int targetReps;
  final double? targetWeightKg;
  final int restSeconds;
  final String? notes;
  final DateTime createdAt;

  /// Populated when the row is fetched with a Supabase join on `wt_exercises`.
  final ExerciseEntity? exercise;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'day_of_week': dayOfWeek,
      'sort_order': sortOrder,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight_kg': targetWeightKg,
      'rest_seconds': restSeconds,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  WorkoutPlanExerciseEntity copyWith({
    String? id,
    String? planId,
    String? exerciseId,
    int? dayOfWeek,
    int? sortOrder,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
    int? restSeconds,
    String? notes,
    DateTime? createdAt,
    ExerciseEntity? exercise,
  }) {
    return WorkoutPlanExerciseEntity(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      exerciseId: exerciseId ?? this.exerciseId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      sortOrder: sortOrder ?? this.sortOrder,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      exercise: exercise ?? this.exercise,
    );
  }
}
