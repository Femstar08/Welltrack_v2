// lib/features/daily_view/presentation/daily_view_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/data/habit_repository.dart';
import '../../meals/data/meal_plan_repository.dart';
import '../../supplements/data/supplement_repository.dart';
import '../../workouts/domain/workout_entity.dart';
import '../../workouts/data/workout_repository.dart';

// Module data aggregator classes
class MealsSummary {

  const MealsSummary({
    required this.plannedCount,
    required this.loggedCount,
    required this.plannedMeals,
  });
  final int plannedCount;
  final int loggedCount;
  final List<String> plannedMeals;

  double get completionPercentage {
    if (plannedCount == 0) return 0.0;
    return (loggedCount / plannedCount) * 100;
  }
}

class SupplementsSummary {

  const SupplementsSummary({
    required this.totalDue,
    required this.taken,
    required this.skipped,
    required this.pendingSupplements,
  });
  final int totalDue;
  final int taken;
  final int skipped;
  final List<String> pendingSupplements;

  int get pending => totalDue - taken - skipped;

  double get completionPercentage {
    if (totalDue == 0) return 0.0;
    return (taken / totalDue) * 100;
  }
}

class WorkoutsSummary {

  const WorkoutsSummary({
    required this.scheduledCount,
    required this.completedCount,
    required this.scheduledWorkouts,
  });
  final int scheduledCount;
  final int completedCount;
  final List<WorkoutEntity> scheduledWorkouts;

  double get completionPercentage {
    if (scheduledCount == 0) return 0.0;
    return (completedCount / scheduledCount) * 100;
  }
}

class HealthMetricsSummary {

  const HealthMetricsSummary({
    this.sleepMinutes,
    this.steps,
    this.heartRate,
    this.stressScore,
  });
  final int? sleepMinutes;
  final int? steps;
  final double? heartRate;
  final double? stressScore;

  String get sleepDisplay {
    if (sleepMinutes == null) return 'No data';
    final hours = sleepMinutes! ~/ 60;
    final minutes = sleepMinutes! % 60;
    return '${hours}h ${minutes}m';
  }

  String get stepsDisplay {
    if (steps == null) return 'No data';
    return '${steps!.toString()} steps';
  }
}

/// Lightweight record representing one habit row in the daily checklist.
class HabitChecklistItem {

  const HabitChecklistItem({
    required this.habitId,
    required this.habitType,
    required this.habitLabel,
    required this.completedToday,
    required this.currentStreakDays,
  });
  final String habitId;
  final String habitType;
  final String habitLabel;
  final bool completedToday;
  final int currentStreakDays;
}

class HabitsSummary {

  const HabitsSummary({
    required this.totalHabits,
    required this.completedToday,
    required this.items,
  });
  final int totalHabits;
  final int completedToday;

  /// Ordered list of habits with today's completion state.
  final List<HabitChecklistItem> items;

  double get completionPercentage {
    if (totalHabits == 0) return 0.0;
    return (completedToday / totalHabits) * 100;
  }
}

class RecoveryScoreSummary {

  const RecoveryScoreSummary({
    this.score,
    this.isCalibrating = false,
    this.message,
  });
  final double? score;
  final bool isCalibrating;
  final String? message;

  String get displayMessage {
    if (isCalibrating) {
      return message ?? 'Calibrating recovery score...';
    }
    if (score == null) {
      return 'Not enough data';
    }
    return 'Recovery Score: ${score!.toStringAsFixed(0)}%';
  }

  String get statusText {
    if (score == null) return 'Unknown';
    if (score! >= 80) return 'Excellent';
    if (score! >= 60) return 'Good';
    if (score! >= 40) return 'Fair';
    return 'Poor';
  }
}

// Aggregate state
class DailyViewState {

  const DailyViewState({
    required this.selectedDate,
    this.mealsSummary,
    this.supplementsSummary,
    this.workoutsSummary,
    this.healthMetrics,
    this.recoveryScore,
    this.habitsSummary,
    this.reminders = const [],
    this.isLoading = false,
    this.error,
  });
  final DateTime selectedDate;
  final MealsSummary? mealsSummary;
  final SupplementsSummary? supplementsSummary;
  final WorkoutsSummary? workoutsSummary;
  final HealthMetricsSummary? healthMetrics;
  final RecoveryScoreSummary? recoveryScore;
  final HabitsSummary? habitsSummary;
  final List<String> reminders;
  final bool isLoading;
  final String? error;

  DailyViewState copyWith({
    DateTime? selectedDate,
    MealsSummary? mealsSummary,
    SupplementsSummary? supplementsSummary,
    WorkoutsSummary? workoutsSummary,
    HealthMetricsSummary? healthMetrics,
    RecoveryScoreSummary? recoveryScore,
    HabitsSummary? habitsSummary,
    List<String>? reminders,
    bool? isLoading,
    String? error,
  }) {
    return DailyViewState(
      selectedDate: selectedDate ?? this.selectedDate,
      mealsSummary: mealsSummary ?? this.mealsSummary,
      supplementsSummary: supplementsSummary ?? this.supplementsSummary,
      workoutsSummary: workoutsSummary ?? this.workoutsSummary,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      habitsSummary: habitsSummary ?? this.habitsSummary,
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Overall completion percentage across all modules
  double get overallCompletionPercentage {
    final percentages = <double>[];

    if (mealsSummary != null) {
      percentages.add(mealsSummary!.completionPercentage);
    }

    if (supplementsSummary != null) {
      percentages.add(supplementsSummary!.completionPercentage);
    }

    if (workoutsSummary != null) {
      percentages.add(workoutsSummary!.completionPercentage);
    }

    if (habitsSummary != null && habitsSummary!.totalHabits > 0) {
      percentages.add(habitsSummary!.completionPercentage);
    }

    if (percentages.isEmpty) return 0.0;

    return percentages.reduce((a, b) => a + b) / percentages.length;
  }

  int get totalTasks {
    return (mealsSummary?.plannedCount ?? 0) +
        (supplementsSummary?.totalDue ?? 0) +
        (workoutsSummary?.scheduledCount ?? 0) +
        (habitsSummary?.totalHabits ?? 0);
  }

  int get completedTasks {
    return (mealsSummary?.loggedCount ?? 0) +
        (supplementsSummary?.taken ?? 0) +
        (workoutsSummary?.completedCount ?? 0) +
        (habitsSummary?.completedToday ?? 0);
  }
}

// StateNotifier
class DailyViewNotifier extends StateNotifier<DailyViewState> {

  DailyViewNotifier(
    this._supplementRepository,
    this._workoutRepository,
    this._mealPlanRepository,
    this._habitRepository,
    this._profileId,
  ) : super(DailyViewState(selectedDate: DateTime.now()));
  final SupplementRepository _supplementRepository;
  final WorkoutRepository _workoutRepository;
  final MealPlanRepository _mealPlanRepository;
  final HabitRepository _habitRepository;
  final String _profileId;

  Future<void> loadDailyData({DateTime? date}) async {
    final selectedDate = date ?? state.selectedDate;
    state = state.copyWith(
      selectedDate: selectedDate,
      isLoading: true,
      error: null,
    );

    try {
      // Load data from all modules in parallel
      final results = await Future.wait([
        _loadSupplementsData(selectedDate),
        _loadWorkoutsData(selectedDate),
        _loadMealsData(selectedDate),
        _loadHealthMetrics(selectedDate),
        _loadRecoveryScore(selectedDate),
        _loadHabitsData(selectedDate),
      ]);

      state = state.copyWith(
        supplementsSummary: results[0] as SupplementsSummary?,
        workoutsSummary: results[1] as WorkoutsSummary?,
        mealsSummary: results[2] as MealsSummary?,
        healthMetrics: results[3] as HealthMetricsSummary?,
        recoveryScore: results[4] as RecoveryScoreSummary?,
        habitsSummary: results[5] as HabitsSummary?,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<SupplementsSummary?> _loadSupplementsData(DateTime date) async {
    try {
      final protocols = await _supplementRepository.getActiveProtocols(_profileId);
      final logs = await _supplementRepository.getLogsForDate(_profileId, date);

      final taken = logs.where((l) => l.isTaken).length;
      final skipped = logs.where((l) => l.isSkipped).length;
      final pending = protocols
          .where((p) => !logs.any((l) =>
              l.supplementId == p.supplementId &&
              l.protocolTime == p.timeOfDay))
          .map((p) => p.supplementName)
          .toList();

      return SupplementsSummary(
        totalDue: protocols.length,
        taken: taken,
        skipped: skipped,
        pendingSupplements: pending,
      );
    } catch (e) {
      return null;
    }
  }

  Future<WorkoutsSummary?> _loadWorkoutsData(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final workouts = await _workoutRepository.getWorkouts(
        _profileId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final completed = workouts.where((w) => w.completed).length;

      return WorkoutsSummary(
        scheduledCount: workouts.length,
        completedCount: completed,
        scheduledWorkouts: workouts,
      );
    } catch (e) {
      return null;
    }
  }

  Future<MealsSummary?> _loadMealsData(DateTime date) async {
    try {
      final plan = await _mealPlanRepository.getMealPlan(_profileId, date);
      if (plan == null) return null;

      final loggedCount = plan.items.where((i) => i.isLogged).length;
      final plannedMeals = plan.items.map((i) => i.name).toList();

      return MealsSummary(
        plannedCount: plan.items.length,
        loggedCount: loggedCount,
        plannedMeals: plannedMeals,
      );
    } catch (e) {
      return null;
    }
  }

  /// Loads all active habits for [date] and resolves today's completion state.
  ///
  /// Auto-complete rules (applied only when date == today):
  ///   - HabitType.stepsTarget  → auto-complete when health data shows steps >= 10000
  ///   - HabitType.sleepTarget  → auto-complete when health data shows sleep >= 7h (420 min)
  ///
  /// When an auto-complete threshold is met and the habit is not yet marked done,
  /// the log is written to the DB so the streak counter advances correctly.
  Future<HabitsSummary?> _loadHabitsData(DateTime date) async {
    try {
      final habits = await _habitRepository.getActiveHabits(_profileId);
      if (habits.isEmpty) return null;

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Fetch logs for each habit in parallel, covering only the requested date.
      final logResults = await Future.wait(
        habits.map(
          (h) => _habitRepository.getHabitLogsForRange(
            _profileId,
            h.habitType,
            date,
            date,
          ),
        ),
      );

      // Build a quick lookup: habitType -> completed?
      final Map<String, bool> completionMap = {};
      for (int i = 0; i < habits.length; i++) {
        final logs = logResults[i];
        final todayLog = logs.where((l) => l.logDateString == dateStr);
        completionMap[habits[i].habitType] =
            todayLog.isNotEmpty && todayLog.first.completed;
      }

      // Auto-complete health-based habits when today's health data is available.
      final isToday = _isSameDay(date, DateTime.now());
      if (isToday) {
        final health = state.healthMetrics;
        if (health != null) {
          // Steps target: 10,000 steps
          if (completionMap.containsKey(HabitType.stepsTarget) &&
              !(completionMap[HabitType.stepsTarget]!) &&
              (health.steps ?? 0) >= 10000) {
            await _habitRepository.logHabitDay(
              _profileId,
              HabitType.stepsTarget,
              date,
              true,
              notes: 'Auto-completed: ${health.steps} steps recorded',
            );
            completionMap[HabitType.stepsTarget] = true;
          }

          // Sleep target: 7 hours (420 minutes)
          if (completionMap.containsKey(HabitType.sleepTarget) &&
              !(completionMap[HabitType.sleepTarget]!) &&
              (health.sleepMinutes ?? 0) >= 420) {
            await _habitRepository.logHabitDay(
              _profileId,
              HabitType.sleepTarget,
              date,
              true,
              notes:
                  'Auto-completed: ${(health.sleepMinutes! ~/ 60)}h ${health.sleepMinutes! % 60}m sleep recorded',
            );
            completionMap[HabitType.sleepTarget] = true;
          }
        }
      }

      final items = habits.map((h) {
        return HabitChecklistItem(
          habitId: h.id,
          habitType: h.habitType,
          habitLabel: h.habitLabel ?? _defaultLabelForType(h.habitType),
          completedToday: completionMap[h.habitType] ?? false,
          currentStreakDays: h.currentStreakDays,
        );
      }).toList();

      final completedCount = items.where((i) => i.completedToday).length;

      return HabitsSummary(
        totalHabits: habits.length,
        completedToday: completedCount,
        items: items,
      );
    } catch (e) {
      return null;
    }
  }

  /// Toggles a single habit's completion for today, then rebuilds
  /// [habitsSummary] in-place so the UI refreshes without a full reload.
  Future<void> toggleHabitToday(String habitType) async {
    final current = state.habitsSummary;
    if (current == null) return;

    final existingItem =
        current.items.where((i) => i.habitType == habitType).firstOrNull;
    if (existingItem == null) return;

    final newDone = !existingItem.completedToday;

    // Optimistic update.
    final optimisticItems = current.items.map((item) {
      if (item.habitType != habitType) return item;
      return HabitChecklistItem(
        habitId: item.habitId,
        habitType: item.habitType,
        habitLabel: item.habitLabel,
        completedToday: newDone,
        currentStreakDays: item.currentStreakDays,
      );
    }).toList();
    final optimisticCompleted =
        optimisticItems.where((i) => i.completedToday).length;
    state = state.copyWith(
      habitsSummary: HabitsSummary(
        totalHabits: current.totalHabits,
        completedToday: optimisticCompleted,
        items: optimisticItems,
      ),
    );

    try {
      final today = DateTime.now();
      await _habitRepository.logHabitDay(
        _profileId,
        habitType,
        today,
        newDone,
      );

      // Refresh streak counter from DB.
      final refreshedHabits =
          await _habitRepository.getActiveHabits(_profileId);
      final refreshedItem =
          refreshedHabits.where((h) => h.habitType == habitType).firstOrNull;

      if (refreshedItem != null) {
        final confirmedItems = optimisticItems.map((item) {
          if (item.habitType != habitType) return item;
          return HabitChecklistItem(
            habitId: item.habitId,
            habitType: item.habitType,
            habitLabel: item.habitLabel,
            completedToday: newDone,
            currentStreakDays: refreshedItem.currentStreakDays,
          );
        }).toList();
        final confirmedCompleted =
            confirmedItems.where((i) => i.completedToday).length;
        state = state.copyWith(
          habitsSummary: HabitsSummary(
            totalHabits: current.totalHabits,
            completedToday: confirmedCompleted,
            items: confirmedItems,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error.
      final revertedItems = optimisticItems.map((item) {
        if (item.habitType != habitType) return item;
        return HabitChecklistItem(
          habitId: item.habitId,
          habitType: item.habitType,
          habitLabel: item.habitLabel,
          completedToday: existingItem.completedToday,
          currentStreakDays: existingItem.currentStreakDays,
        );
      }).toList();
      final revertedCompleted =
          revertedItems.where((i) => i.completedToday).length;
      state = state.copyWith(
        habitsSummary: HabitsSummary(
          totalHabits: current.totalHabits,
          completedToday: revertedCompleted,
          items: revertedItems,
        ),
        error: e.toString(),
      );
    }
  }

  /// Returns a human-readable label for well-known habit types so the UI
  /// never shows a raw type key when [habitLabel] is null.
  String _defaultLabelForType(String habitType) {
    switch (habitType) {
      case HabitType.pornFree:
        return 'Porn-Free Day';
      case HabitType.kegels:
        return 'Kegel Exercises';
      case HabitType.sleepTarget:
        return 'Sleep Target (7h+)';
      case HabitType.stepsTarget:
        return 'Steps Target (10k+)';
      default:
        return habitType.replaceAll('_', ' ');
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<HealthMetricsSummary?> _loadHealthMetrics(DateTime date) async {
    // TODO: Implement once health metrics repository is available
    // For now, return mock data or null
    return const HealthMetricsSummary(
      sleepMinutes: 420, // 7 hours
      steps: 8500,
      heartRate: 72.0,
      stressScore: 35.0,
    );
  }

  Future<RecoveryScoreSummary?> _loadRecoveryScore(DateTime date) async {
    // TODO: Implement recovery score calculation
    // This should aggregate sleep, stress, and workout intensity
    return const RecoveryScoreSummary(
      score: 75.0,
      isCalibrating: false,
    );
  }

  void changeDate(DateTime newDate) {
    loadDailyData(date: newDate);
  }

  void goToPreviousDay() {
    final previousDay = state.selectedDate.subtract(const Duration(days: 1));
    changeDate(previousDay);
  }

  void goToNextDay() {
    final nextDay = state.selectedDate.add(const Duration(days: 1));
    changeDate(nextDay);
  }

  void goToToday() {
    changeDate(DateTime.now());
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final dailyViewProvider =
    StateNotifierProvider.family<DailyViewNotifier, DailyViewState, String>(
  (ref, profileId) {
    final supplementRepository = ref.watch(supplementRepositoryProvider);
    final workoutRepository = ref.watch(workoutRepositoryProvider);
    final mealPlanRepository = ref.watch(mealPlanRepositoryProvider);
    final habitRepository = ref.watch(habitRepositoryProvider);
    return DailyViewNotifier(
      supplementRepository,
      workoutRepository,
      mealPlanRepository,
      habitRepository,
      profileId,
    );
  },
);
