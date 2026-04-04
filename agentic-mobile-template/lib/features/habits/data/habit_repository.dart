// lib/features/habits/data/habit_repository.dart
//
// Data layer for Phase 12 Habits feature.
// Handles wt_habit_streaks (the habit definition + running counters) and
// wt_habit_logs (the per-day completion records).
//
// Streak recalculation is done client-side after every logHabitDay() call:
//   1. Fetch all completed logs for this habit ordered by date DESC.
//   2. Walk backwards from today counting consecutive completed days.
//   3. Write current_streak_days and (if higher) longest_streak_days back
//      to wt_habit_streaks.
//
// This keeps the DB schema simple (no triggers / stored procedures) and lets
// the same logic run offline once Hive sync is wired in Phase 13.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/habit_entity.dart';
import '../domain/habit_log_entity.dart';
import '../../../shared/core/sync/offline_write_mixin.dart';

// ---------------------------------------------------------------------------
// Pre-defined habit type constants — use these everywhere to avoid typos.
// ---------------------------------------------------------------------------

abstract class HabitType {
  /// No pornography viewed on this day.
  static const String pornFree = 'porn_free';

  /// Kegel exercises completed on this day.
  static const String kegels = 'kegels';

  /// Sleep target (hours) met on this day.
  static const String sleepTarget = 'sleep_target';

  /// Step-count target met on this day.
  static const String stepsTarget = 'steps_target';
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class HabitRepository {
  HabitRepository(this._client);

  final SupabaseClient _client;

  // -------------------------------------------------------------------------
  // Habits (wt_habit_streaks)
  // -------------------------------------------------------------------------

  /// Returns all active habits for [profileId], ordered by creation date.
  Future<List<HabitEntity>> getActiveHabits(String profileId) async {
    try {
      final response = await _client
          .from('wt_habit_streaks')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HabitEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active habits: $e');
    }
  }

  /// Creates a new habit row in wt_habit_streaks.
  /// The DB UNIQUE constraint (profile_id, habit_type) prevents duplicates.
  Future<HabitEntity> createHabit(
    String profileId,
    String habitType,
    String habitLabel,
  ) async {
    final data = {
      'profile_id': profileId,
      'habit_type': habitType,
      'habit_label': habitLabel,
      'current_streak_days': 0,
      'longest_streak_days': 0,
      'is_active': true,
    };

    HabitEntity? onlineResult;
    await offlineWrite(
      table: 'wt_habit_streaks',
      operation: 'insert',
      data: data,
      execute: () async {
        final response = await _client
            .from('wt_habit_streaks')
            .insert(data)
            .select()
            .single();
        onlineResult = HabitEntity.fromJson(response);
      },
    );

    if (onlineResult != null) return onlineResult!;

    final now = DateTime.now();
    return HabitEntity(
      id: 'offline_${now.microsecondsSinceEpoch}',
      profileId: profileId,
      habitType: habitType,
      habitLabel: habitLabel,
      currentStreakDays: 0,
      longestStreakDays: 0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Soft-deletes a habit by setting is_active = false.
  /// Historical logs are retained for analytics.
  Future<void> deleteHabit(String habitId) async {
    try {
      await _client
          .from('wt_habit_streaks')
          .update({'is_active': false})
          .eq('id', habitId);
    } catch (e) {
      throw Exception('Failed to delete habit: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Habit logs (wt_habit_logs)
  // -------------------------------------------------------------------------

  /// Upserts a daily completion record and recalculates the streak counters.
  ///
  /// Steps:
  ///   1. Upsert the log row (ON CONFLICT profile_id, habit_type, log_date).
  ///   2. Fetch all completed log dates for this habit (most recent first).
  ///   3. Walk backwards from today to count consecutive completed days.
  ///   4. Update current_streak_days / longest_streak_days on wt_habit_streaks.
  Future<HabitLogEntity> logHabitDay(
    String profileId,
    String habitType,
    DateTime date,
    bool completed, {
    String? notes,
  }) async {
    try {
      final dateStr = _formatDate(date);

      // 1. Upsert the log entry.
      final logResponse = await _client
          .from('wt_habit_logs')
          .upsert(
            {
              'profile_id': profileId,
              'habit_type': habitType,
              'log_date': dateStr,
              'completed': completed,
              'notes': notes,
            },
            onConflict: 'profile_id,habit_type,log_date',
          )
          .select()
          .single();

      final logEntity = HabitLogEntity.fromJson(logResponse);

      // 2. Recalculate streak — fetch all completed dates (no upper bound limit
      //    so we can correctly compute longest_streak_days as well).
      await _recalculateStreak(profileId, habitType);

      return logEntity;
    } catch (e) {
      throw Exception('Failed to log habit day: $e');
    }
  }

  /// Returns logs for [habitType] within the inclusive [startDate]..[endDate]
  /// range, ordered by log_date ascending (suitable for calendar views).
  Future<List<HabitLogEntity>> getHabitLogsForRange(
    String profileId,
    String habitType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      final response = await _client
          .from('wt_habit_logs')
          .select()
          .eq('profile_id', profileId)
          .eq('habit_type', habitType)
          .gte('log_date', startStr)
          .lte('log_date', endStr)
          .order('log_date', ascending: true);

      return (response as List)
          .map(
            (json) => HabitLogEntity.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch habit logs: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Streak recalculation (private)
  // -------------------------------------------------------------------------

  /// Pulls all completed log dates for [habitType] and recomputes both
  /// [currentStreakDays] and [longestStreakDays], then persists them.
  ///
  /// Algorithm:
  ///   - Build a set of dates where completed = true.
  ///   - Walk backwards from today: while the previous day is in the set,
  ///     increment current streak.
  ///   - Scan the full set for the longest unbroken consecutive run.
  Future<void> _recalculateStreak(
    String profileId,
    String habitType,
  ) async {
    // Fetch all completed log dates for this habit, newest first.
    final logsResponse = await _client
        .from('wt_habit_logs')
        .select('log_date')
        .eq('profile_id', profileId)
        .eq('habit_type', habitType)
        .eq('completed', true)
        .order('log_date', ascending: false);

    final completedDates = (logsResponse as List)
        .map((row) => DateTime.parse(row['log_date'] as String))
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet();

    if (completedDates.isEmpty) {
      // No completed logs — reset both counters.
      await _updateStreakCounters(
        profileId,
        habitType,
        currentStreak: 0,
        longestStreak: 0,
        lastLoggedDate: null,
      );
      return;
    }

    final today = _todayDate();

    // --- Current streak: walk backwards from today ---
    int current = 0;
    DateTime cursor = today;
    while (completedDates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // --- Longest streak: scan all completed dates ---
    final sortedDates = completedDates.toList()..sort();
    int longest = 0;
    int run = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff == 1) {
        run++;
      } else {
        if (run > longest) longest = run;
        run = 1;
      }
    }
    if (run > longest) longest = run;

    // The last-logged date is the maximum completed date.
    final lastLogged = sortedDates.last;

    await _updateStreakCounters(
      profileId,
      habitType,
      currentStreak: current,
      longestStreak: longest,
      lastLoggedDate: lastLogged,
    );
  }

  Future<void> _updateStreakCounters(
    String profileId,
    String habitType, {
    required int currentStreak,
    required int longestStreak,
    required DateTime? lastLoggedDate,
  }) async {
    await _client.from('wt_habit_streaks').update({
      'current_streak_days': currentStreak,
      'longest_streak_days': longestStreak,
      'last_logged_date':
          lastLoggedDate != null ? _formatDate(lastLoggedDate) : null,
    })
        .eq('profile_id', profileId)
        .eq('habit_type', habitType);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Returns today as a date-only [DateTime] (time stripped to midnight).
  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Formats a [DateTime] as 'YYYY-MM-DD' for Supabase date columns.
  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
