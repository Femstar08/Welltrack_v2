// lib/features/workouts/domain/workout_entity.dart

class WorkoutEntity {
  final String id;
  final String profileId;
  final String name;
  final String workoutType;
  final DateTime scheduledDate;
  final bool completed;
  final DateTime? completedAt;
  final int? durationMinutes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutEntity({
    required this.id,
    required this.profileId,
    required this.name,
    required this.workoutType,
    required this.scheduledDate,
    required this.completed,
    this.completedAt,
    this.durationMinutes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutEntity.fromJson(Map<String, dynamic> json) {
    return WorkoutEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      workoutType: json['workout_type'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'workout_type': workoutType,
      'scheduled_date': scheduledDate.toIso8601String(),
      'completed': completed,
      'completed_at': completedAt?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WorkoutEntity copyWith({
    String? id,
    String? profileId,
    String? name,
    String? workoutType,
    DateTime? scheduledDate,
    bool? completed,
    DateTime? completedAt,
    int? durationMinutes,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      workoutType: workoutType ?? this.workoutType,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isScheduledToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    return scheduled.isAtSameMomentAs(today);
  }

  bool get isPastDue {
    final now = DateTime.now();
    return scheduledDate.isBefore(now) && !completed;
  }
}
