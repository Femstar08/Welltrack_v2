import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/goals/data/goal_repository.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';
import 'package:welltrack/features/insights/data/insights_repository.dart';

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
  final GoalsRepository _repository;
  final InsightsRepository _insightsRepository;
  final String _profileId;

  GoalsNotifier(this._repository, this._insightsRepository, this._profileId)
      : super(const AsyncValue.loading()) {
    loadGoals();
  }

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
