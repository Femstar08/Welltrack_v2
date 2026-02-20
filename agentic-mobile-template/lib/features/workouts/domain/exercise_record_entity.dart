// lib/features/workouts/domain/exercise_record_entity.dart

class ExerciseRecordEntity {
  const ExerciseRecordEntity({
    required this.id,
    required this.profileId,
    required this.exerciseId,
    this.maxWeightKg,
    this.maxWeightDate,
    this.maxReps,
    this.maxRepsDate,
    this.maxVolume,
    this.maxVolumeDate,
    this.maxEstimated1rm,
    this.max1rmDate,
    required this.updatedAt,
  });

  /// Date-only fields (e.g. `max_weight_date`) are stored as plain date strings
  /// in the database. They are parsed with [DateTime.parse] which correctly
  /// handles `YYYY-MM-DD` strings and returns midnight UTC.
  factory ExerciseRecordEntity.fromJson(Map<String, dynamic> json) {
    return ExerciseRecordEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      exerciseId: json['exercise_id'] as String,
      maxWeightKg: json['max_weight_kg'] != null
          ? (json['max_weight_kg'] as num).toDouble()
          : null,
      maxWeightDate: json['max_weight_date'] != null
          ? DateTime.parse(json['max_weight_date'] as String)
          : null,
      maxReps: json['max_reps'] as int?,
      maxRepsDate: json['max_reps_date'] != null
          ? DateTime.parse(json['max_reps_date'] as String)
          : null,
      maxVolume: json['max_volume'] != null
          ? (json['max_volume'] as num).toDouble()
          : null,
      maxVolumeDate: json['max_volume_date'] != null
          ? DateTime.parse(json['max_volume_date'] as String)
          : null,
      maxEstimated1rm: json['max_estimated_1rm'] != null
          ? (json['max_estimated_1rm'] as num).toDouble()
          : null,
      max1rmDate: json['max_1rm_date'] != null
          ? DateTime.parse(json['max_1rm_date'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String profileId;
  final String exerciseId;

  final double? maxWeightKg;

  /// Date of the maximum weight set. Stored as a date-only value in the DB.
  final DateTime? maxWeightDate;

  final int? maxReps;

  /// Date of the maximum reps set. Stored as a date-only value in the DB.
  final DateTime? maxRepsDate;

  /// Maximum single-session volume (sets x reps x weight) for this exercise.
  final double? maxVolume;

  /// Date of the maximum volume session. Stored as a date-only value in the DB.
  final DateTime? maxVolumeDate;

  /// Maximum Epley-estimated 1RM recorded for this exercise.
  final double? maxEstimated1rm;

  /// Date of the maximum estimated 1RM. Stored as a date-only value in the DB.
  final DateTime? max1rmDate;

  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'exercise_id': exerciseId,
      'max_weight_kg': maxWeightKg,
      'max_weight_date': maxWeightDate?.toIso8601String(),
      'max_reps': maxReps,
      'max_reps_date': maxRepsDate?.toIso8601String(),
      'max_volume': maxVolume,
      'max_volume_date': maxVolumeDate?.toIso8601String(),
      'max_estimated_1rm': maxEstimated1rm,
      'max_1rm_date': max1rmDate?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ExerciseRecordEntity copyWith({
    String? id,
    String? profileId,
    String? exerciseId,
    double? maxWeightKg,
    DateTime? maxWeightDate,
    int? maxReps,
    DateTime? maxRepsDate,
    double? maxVolume,
    DateTime? maxVolumeDate,
    double? maxEstimated1rm,
    DateTime? max1rmDate,
    DateTime? updatedAt,
  }) {
    return ExerciseRecordEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      exerciseId: exerciseId ?? this.exerciseId,
      maxWeightKg: maxWeightKg ?? this.maxWeightKg,
      maxWeightDate: maxWeightDate ?? this.maxWeightDate,
      maxReps: maxReps ?? this.maxReps,
      maxRepsDate: maxRepsDate ?? this.maxRepsDate,
      maxVolume: maxVolume ?? this.maxVolume,
      maxVolumeDate: maxVolumeDate ?? this.maxVolumeDate,
      maxEstimated1rm: maxEstimated1rm ?? this.maxEstimated1rm,
      max1rmDate: max1rmDate ?? this.max1rmDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
