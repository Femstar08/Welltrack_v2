// lib/features/workouts/domain/workout_set_entity.dart

class WorkoutSetEntity {
  const WorkoutSetEntity({
    required this.id,
    required this.profileId,
    required this.workoutId,
    this.exerciseId,
    required this.setNumber,
    this.weightKg,
    this.reps,
    required this.completed,
    this.rpe,
    this.estimated1rm,
    required this.loggedAt,
    required this.createdAt,
  });

  factory WorkoutSetEntity.fromJson(Map<String, dynamic> json) {
    return WorkoutSetEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      workoutId: json['workout_id'] as String,
      exerciseId: json['exercise_id'] as String?,
      setNumber: json['set_number'] as int,
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] as num).toDouble()
          : null,
      reps: json['reps'] as int?,
      completed: json['completed'] as bool? ?? false,
      rpe: json['rpe'] != null ? (json['rpe'] as num).toDouble() : null,
      estimated1rm: json['estimated_1rm'] != null
          ? (json['estimated_1rm'] as num).toDouble()
          : null,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String profileId;
  final String workoutId;
  final String? exerciseId;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final bool completed;

  /// Rate of perceived exertion (0–10 scale).
  final double? rpe;

  /// Stored estimated 1RM (may be null if not yet persisted).
  /// Use [calcEstimated1rm] for a live calculation.
  final double? estimated1rm;

  final DateTime loggedAt;
  final DateTime createdAt;

  /// Live Epley-formula estimated 1RM: `weight * (1 + reps / 30)`.
  ///
  /// Returns null when either [weightKg] or [reps] is missing or zero.
  double? get calcEstimated1rm {
    if (weightKg != null && weightKg! > 0 && reps != null && reps! > 0) {
      return weightKg! * (1 + reps! / 30.0);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'completed': completed,
      'rpe': rpe,
      'estimated_1rm': estimated1rm,
      'logged_at': loggedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  WorkoutSetEntity copyWith({
    String? id,
    String? profileId,
    String? workoutId,
    String? exerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
    bool? completed,
    double? rpe,
    double? estimated1rm,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return WorkoutSetEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      rpe: rpe ?? this.rpe,
      estimated1rm: estimated1rm ?? this.estimated1rm,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
