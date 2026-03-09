// lib/features/habits/presentation/habit_provider.dart
//
// Riverpod state management for the Habits feature (Phase 12).
// Keyed by profileId so each profile has isolated state.
//
// State shape:
//   - habits           : active HabitEntity records from wt_habit_streaks
//   - todayLogs        : map of habitType -> completed bool for today
//   - last30DaysLogs   : map of habitType -> list of HabitLogEntity for last 30 days
//   - isLoading        : data-load in progress
//   - error            : last error message, null when healthy
//   - milestoneReached : milestone day count just achieved (7/30/90/180), null
//                        when no milestone is pending display

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/habit_repository.dart';
import '../domain/habit_entity.dart';
import '../domain/habit_log_entity.dart';

// ---------------------------------------------------------------------------
// Milestone thresholds
// ---------------------------------------------------------------------------

/// Day counts that trigger a celebration dialog.
const List<int> habitMilestones = [7, 30, 90, 180];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class HabitState {
  const HabitState({
    this.habits = const [],
    this.todayLogs = const {},
    this.last30DaysLogs = const {},
    this.isLoading = false,
    this.error,
    this.milestoneReached,
  });

  /// All active habits for this profile.
  final List<HabitEntity> habits;

  /// habitType -> whether it was completed today.
  final Map<String, bool> todayLogs;

  /// habitType -> ordered list of log entities covering the last 30 days.
  final Map<String, List<HabitLogEntity>> last30DaysLogs;

  final bool isLoading;
  final String? error;

  /// Non-null immediately after a toggle that crosses a milestone boundary.
  /// The screen reads this, shows the dialog, then calls clearMilestone().
  final int? milestoneReached;

  HabitState copyWith({
    List<HabitEntity>? habits,
    Map<String, bool>? todayLogs,
    Map<String, List<HabitLogEntity>>? last30DaysLogs,
    bool? isLoading,
    String? error,
    int? milestoneReached,
    bool clearMilestone = false,
    bool clearError = false,
  }) {
    return HabitState(
      habits: habits ?? this.habits,
      todayLogs: todayLogs ?? this.todayLogs,
      last30DaysLogs: last30DaysLogs ?? this.last30DaysLogs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      milestoneReached:
          clearMilestone ? null : (milestoneReached ?? this.milestoneReached),
    );
  }
}

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class HabitNotifier extends StateNotifier<HabitState> {
  HabitNotifier(this._repository, this._profileId)
      : super(const HabitState());

  final HabitRepository _repository;
  final String _profileId;

  // -------------------------------------------------------------------------
  // Load
  // -------------------------------------------------------------------------

  /// Fetches active habits and this-week logs for each, then the last-30-day
  /// grid data.  Called once from initState via Future.microtask.
  Future<void> loadHabits() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final habits = await _repository.getActiveHabits(_profileId);

      final today = _todayDate();
      final thirtyDaysAgo = today.subtract(const Duration(days: 29));

      // Build today-logs map and 30-day grid in parallel per habit.
      final Map<String, bool> todayLogs = {};
      final Map<String, List<HabitLogEntity>> last30 = {};

      await Future.wait(habits.map((habit) async {
        final logs = await _repository.getHabitLogsForRange(
          _profileId,
          habit.habitType,
          thirtyDaysAgo,
          today,
        );
        last30[habit.habitType] = logs;

        // Today's completion flag.
        final todayStr = _formatDate(today);
        final todayLog = logs.where((l) => l.logDateString == todayStr);
        todayLogs[habit.habitType] =
            todayLog.isNotEmpty && todayLog.first.completed;
      }));

      state = state.copyWith(
        habits: habits,
        todayLogs: todayLogs,
        last30DaysLogs: last30,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Toggle today
  // -------------------------------------------------------------------------

  /// Flips the completion state for [habitType] on today's date.
  /// After the DB write the local streak counter is read back from the
  /// refreshed habit list, and a milestone check is run.
  Future<void> toggleHabitToday(String habitType) async {
    final currentlyDone = state.todayLogs[habitType] ?? false;
    final newDone = !currentlyDone;

    // Optimistic update for immediate UI feedback.
    final optimisticLogs = Map<String, bool>.from(state.todayLogs)
      ..[habitType] = newDone;
    state = state.copyWith(todayLogs: optimisticLogs);

    try {
      final today = _todayDate();
      await _repository.logHabitDay(_profileId, habitType, today, newDone);

      // Refresh habit list to pick up recalculated streak counters.
      final updatedHabits = await _repository.getActiveHabits(_profileId);

      // Also refresh 30-day logs for this habit so the dot grid stays current.
      final thirtyDaysAgo = today.subtract(const Duration(days: 29));
      final updatedLogs = await _repository.getHabitLogsForRange(
        _profileId,
        habitType,
        thirtyDaysAgo,
        today,
      );

      final updated30 = Map<String, List<HabitLogEntity>>.from(
        state.last30DaysLogs,
      )..[habitType] = updatedLogs;

      // Re-read today flag from freshly fetched logs.
      final todayStr = _formatDate(today);
      final confirmedLog =
          updatedLogs.where((l) => l.logDateString == todayStr);
      final confirmedDone =
          confirmedLog.isNotEmpty && confirmedLog.first.completed;

      final confirmedTodayLogs = Map<String, bool>.from(state.todayLogs)
        ..[habitType] = confirmedDone;

      // Milestone check — only fire when marking DONE (not undone).
      int? milestone;
      if (newDone) {
        final habit = updatedHabits.firstWhere(
          (h) => h.habitType == habitType,
          orElse: () => updatedHabits.first,
        );
        milestone = _checkMilestone(habit.currentStreakDays);
      }

      state = state.copyWith(
        habits: updatedHabits,
        todayLogs: confirmedTodayLogs,
        last30DaysLogs: updated30,
        milestoneReached: milestone,
      );
    } catch (e) {
      // Revert optimistic update on failure.
      final revertedLogs = Map<String, bool>.from(state.todayLogs)
        ..[habitType] = currentlyDone;
      state = state.copyWith(todayLogs: revertedLogs, error: e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Add custom habit
  // -------------------------------------------------------------------------

  /// Creates a new custom habit with a user-supplied label.
  /// The habitType is derived from the label (lower-snake-cased + timestamp
  /// suffix to ensure uniqueness).
  Future<void> addCustomHabit(String label) async {
    if (label.trim().isEmpty) return;

    try {
      // Build a unique type key from the label so it does not collide with
      // existing pre-defined types.
      final typeKey =
          'custom_${label.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';

      final habit = await _repository.createHabit(
        _profileId,
        typeKey,
        label.trim(),
      );

      // Seed an empty 30-day log list for the new habit.
      final updated30 = Map<String, List<HabitLogEntity>>.from(
        state.last30DaysLogs,
      )..[habit.habitType] = [];

      final updatedTodayLogs = Map<String, bool>.from(state.todayLogs)
        ..[habit.habitType] = false;

      state = state.copyWith(
        habits: [...state.habits, habit],
        todayLogs: updatedTodayLogs,
        last30DaysLogs: updated30,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Delete (soft)
  // -------------------------------------------------------------------------

  /// Soft-deletes the habit — sets is_active=false, removes from local list.
  Future<void> deleteHabit(String habitId) async {
    try {
      await _repository.deleteHabit(habitId);

      final removed =
          state.habits.where((h) => h.id != habitId).toList();
      state = state.copyWith(habits: removed);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Milestone acknowledgement
  // -------------------------------------------------------------------------

  /// Called by the screen once the milestone dialog has been shown.
  void clearMilestone() {
    state = state.copyWith(clearMilestone: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Returns the milestone value if [streak] is exactly one of the thresholds,
  /// otherwise null.
  int? _checkMilestone(int streak) {
    if (habitMilestones.contains(streak)) return streak;
    return null;
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final habitProvider =
    StateNotifierProvider.family<HabitNotifier, HabitState, String>(
  (ref, profileId) {
    final repository = ref.watch(habitRepositoryProvider);
    return HabitNotifier(repository, profileId);
  },
);
