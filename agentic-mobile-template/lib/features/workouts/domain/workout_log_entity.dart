// lib/features/workouts/domain/workout_log_entity.dart

class WorkoutLogEntity {
  final String id;
  final String profileId;
  final String workoutId;
  final String? exerciseId;
  final String exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceM;
  final String? notes;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutLogEntity({
    required this.id,
    required this.profileId,
    required this.workoutId,
    this.exerciseId,
    required this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
    this.notes,
    required this.loggedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutLogEntity.fromJson(Map<String, dynamic> json) {
    return WorkoutLogEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      workoutId: json['workout_id'] as String,
      exerciseId: json['exercise_id'] as String?,
      exerciseName: json['exercise_name'] as String,
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] as num).toDouble()
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      distanceM: json['distance_m'] != null
          ? (json['distance_m'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'logged_at': loggedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WorkoutLogEntity copyWith({
    String? id,
    String? profileId,
    String? workoutId,
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceM,
    String? notes,
    DateTime? loggedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutLogEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceM: distanceM ?? this.distanceM,
      notes: notes ?? this.notes,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displaySummary {
    final parts = <String>[];

    if (sets != null && reps != null) {
      parts.add('$sets × $reps');
    }

    if (weightKg != null) {
      parts.add('${weightKg!.toStringAsFixed(1)} kg');
    }

    if (durationSeconds != null) {
      final minutes = durationSeconds! ~/ 60;
      final seconds = durationSeconds! % 60;
      if (minutes > 0) {
        parts.add('${minutes}m ${seconds}s');
      } else {
        parts.add('${seconds}s');
      }
    }

    if (distanceM != null) {
      if (distanceM! >= 1000) {
        parts.add('${(distanceM! / 1000).toStringAsFixed(2)} km');
      } else {
        parts.add('${distanceM!.toStringAsFixed(0)} m');
      }
    }

    return parts.isEmpty ? 'Completed' : parts.join(' · ');
  }
}
