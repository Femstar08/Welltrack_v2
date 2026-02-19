// lib/features/daily_view/presentation/daily_view_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    if (percentages.isEmpty) return 0.0;

    return percentages.reduce((a, b) => a + b) / percentages.length;
  }

  int get totalTasks {
    return (mealsSummary?.plannedCount ?? 0) +
        (supplementsSummary?.totalDue ?? 0) +
        (workoutsSummary?.scheduledCount ?? 0);
  }

  int get completedTasks {
    return (mealsSummary?.loggedCount ?? 0) +
        (supplementsSummary?.taken ?? 0) +
        (workoutsSummary?.completedCount ?? 0);
  }
}

// StateNotifier
class DailyViewNotifier extends StateNotifier<DailyViewState> {

  DailyViewNotifier(
    this._supplementRepository,
    this._workoutRepository,
    this._profileId,
  ) : super(DailyViewState(selectedDate: DateTime.now()));
  final SupplementRepository _supplementRepository;
  final WorkoutRepository _workoutRepository;
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
      ]);

      state = state.copyWith(
        supplementsSummary: results[0] as SupplementsSummary?,
        workoutsSummary: results[1] as WorkoutsSummary?,
        mealsSummary: results[2] as MealsSummary?,
        healthMetrics: results[3] as HealthMetricsSummary?,
        recoveryScore: results[4] as RecoveryScoreSummary?,
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
    // TODO: Implement once meals repository is available
    // For now, return mock data or null
    return const MealsSummary(
      plannedCount: 3,
      loggedCount: 1,
      plannedMeals: ['Breakfast', 'Lunch', 'Dinner'],
    );
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
    return DailyViewNotifier(
      supplementRepository,
      workoutRepository,
      profileId,
    );
  },
);
