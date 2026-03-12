import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/goal_repository.dart';
import '../domain/goal_entity.dart';
import '../../insights/data/insights_repository.dart';
import '../../insights/domain/forecast_entity.dart';

/// Maps goal metric type to health metric type stored in wt_health_metrics.
/// Goal types can differ from DB column values (e.g. 'hr' → 'resting_hr').
String _healthMetricTypeFor(String goalMetricType) {
  switch (goalMetricType) {
    case 'hr':
      return 'resting_hr';
    default:
      return goalMetricType;
  }
}

/// Fetches real metric history for the goal projection chart.
/// Queries last 90 days of wt_health_metrics for the given metric type.
final goalMetricTrendProvider = FutureProvider.family<
    List<DataPoint>,
    ({String profileId, String metricType})>((ref, params) async {
  final insightsRepo = ref.watch(insightsRepositoryProvider);
  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 90));
  return insightsRepo.getMetricTrend(
    profileId: params.profileId,
    metricType: _healthMetricTypeFor(params.metricType),
    startDate: startDate,
    endDate: endDate,
  );
});

final goalsProvider = StateNotifierProvider.family<
    GoalsNotifier,
    AsyncValue<List<GoalEntity>>,
    String>((ref, profileId) {
  return GoalsNotifier(
    ref.watch(goalsRepositoryProvider),
    ref.watch(insightsRepositoryProvider),
    profileId,
  );
});

final goalDetailProvider =
    FutureProvider.family<GoalEntity?, String>((ref, goalId) async {
  final repository = ref.watch(goalsRepositoryProvider);
  return repository.getGoal(goalId);
});

class GoalsNotifier extends StateNotifier<AsyncValue<List<GoalEntity>>> {

  GoalsNotifier(this._repository, this._insightsRepository, this._profileId)
      : super(const AsyncValue.loading()) {
    loadGoals();
  }
  final GoalsRepository _repository;
  final InsightsRepository _insightsRepository;
  final String _profileId;

  Future<void> loadGoals() async {
    state = const AsyncValue.loading();
    try {
      final goals = await _repository.getGoals(_profileId);
      state = AsyncValue.data(goals);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createGoal({
    required String metricType,
    String? description,
    required double targetValue,
    required double currentValue,
    required String unit,
    DateTime? deadline,
    int priority = 0,
  }) async {
    try {
      await _repository.createGoal(
        profileId: _profileId,
        metricType: metricType,
        description: description,
        targetValue: targetValue,
        currentValue: currentValue,
        unit: unit,
        deadline: deadline,
        priority: priority,
      );
      await loadGoals();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateGoal(String goalId, Map<String, dynamic> fields) async {
    try {
      await _repository.updateGoal(goalId, fields);
      await loadGoals();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      await _repository.deleteGoal(goalId);
      await loadGoals();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refreshForecast(String goalId) async {
    try {
      await _repository.recalculateForecast(goalId, _insightsRepository);
      await loadGoals();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void refresh() {
    loadGoals();
  }
}
