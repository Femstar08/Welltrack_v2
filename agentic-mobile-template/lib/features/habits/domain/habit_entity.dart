// lib/features/habits/domain/habit_entity.dart
//
// Maps to the wt_habit_streaks table.
// One row per (profile_id, habit_type) — the canonical record for a habit,
// carrying the running streak counters and the last-logged date.

class HabitEntity {
  const HabitEntity({
    required this.id,
    required this.profileId,
    required this.habitType,
    this.habitLabel,
    required this.currentStreakDays,
    required this.longestStreakDays,
    this.lastLoggedDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HabitEntity.fromJson(Map<String, dynamic> json) {
    return HabitEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      habitType: json['habit_type'] as String,
      habitLabel: json['habit_label'] as String?,
      currentStreakDays: (json['current_streak_days'] as num).toInt(),
      longestStreakDays: (json['longest_streak_days'] as num).toInt(),
      lastLoggedDate: json['last_logged_date'] != null
          ? DateTime.parse(json['last_logged_date'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Supabase primary key.
  final String id;

  /// Foreign key to wt_profiles.id.
  final String profileId;

  /// Machine-readable type key (e.g. 'porn_free', 'kegels').
  /// Use [HabitType] constants to avoid magic strings.
  final String habitType;

  /// Human-readable display name shown in the UI.
  final String? habitLabel;

  /// Number of consecutive days completed up to and including [lastLoggedDate].
  final int currentStreakDays;

  /// All-time best streak for this habit.
  final int longestStreakDays;

  /// The most recent date a completion was logged (completed=true).
  /// Null when the habit has never been logged.
  final DateTime? lastLoggedDate;

  /// Soft-delete flag — false means archived, not shown in active list.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'habit_type': habitType,
      'habit_label': habitLabel,
      'current_streak_days': currentStreakDays,
      'longest_streak_days': longestStreakDays,
      'last_logged_date':
          lastLoggedDate?.toIso8601String().substring(0, 10),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HabitEntity copyWith({
    String? id,
    String? profileId,
    String? habitType,
    String? habitLabel,
    int? currentStreakDays,
    int? longestStreakDays,
    DateTime? lastLoggedDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      habitType: habitType ?? this.habitType,
      habitLabel: habitLabel ?? this.habitLabel,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns true when the streak was completed yesterday or today (still alive).
  bool get isStreakAlive {
    if (lastLoggedDate == null) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(
      lastLoggedDate!.year,
      lastLoggedDate!.month,
      lastLoggedDate!.day,
    );
    final diff = todayDate.difference(lastDate).inDays;
    return diff <= 1;
  }
}
