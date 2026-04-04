// lib/features/habits/domain/habit_log_entity.dart
//
// Maps to the wt_habit_logs table.
// One row per (profile_id, habit_type, log_date) — the daily completion record.

class HabitLogEntity {
  const HabitLogEntity({
    required this.id,
    required this.profileId,
    required this.habitType,
    required this.logDate,
    required this.completed,
    this.notes,
    required this.createdAt,
  });

  factory HabitLogEntity.fromJson(Map<String, dynamic> json) {
    return HabitLogEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      habitType: json['habit_type'] as String,
      logDate: DateTime.parse(json['log_date'] as String),
      completed: json['completed'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Supabase primary key.
  final String id;

  /// Foreign key to wt_profiles.id.
  final String profileId;

  /// Machine-readable type key matching wt_habit_streaks.habit_type.
  final String habitType;

  /// The calendar date this log entry applies to (time-of-day is ignored).
  final DateTime logDate;

  /// Whether the habit was completed on [logDate].
  final bool completed;

  /// Optional free-text notes for this entry.
  final String? notes;

  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'habit_type': habitType,
      'log_date': logDate.toIso8601String().substring(0, 10),
      'completed': completed,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  HabitLogEntity copyWith({
    String? id,
    String? profileId,
    String? habitType,
    DateTime? logDate,
    bool? completed,
    String? notes,
    DateTime? createdAt,
  }) {
    return HabitLogEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      habitType: habitType ?? this.habitType,
      logDate: logDate ?? this.logDate,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convenience: returns the log_date formatted as 'YYYY-MM-DD'.
  String get logDateString => logDate.toIso8601String().substring(0, 10);
}
