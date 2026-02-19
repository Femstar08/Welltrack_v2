import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/features/insights/data/insights_repository.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(Supabase.instance.client);
});

class GoalsRepository {
  final SupabaseClient _client;

  GoalsRepository(this._client);

  Future<List<GoalEntity>> getGoals(String profileId) async {
    try {
      final response = await _client
          .from('wt_goal_forecasts')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('priority', ascending: false)
          .order('created_at', ascending: true);

      final goals = <GoalEntity>[];
      for (final json in response as List) {
        final goalId = json['id'] as String;
        final forecast = await _getLatestForecast(goalId);
        goals.add(GoalEntity.fromJson(json, forecast: forecast));
      }
      return goals;
    } catch (e) {
      throw Exception('Failed to fetch goals: $e');
    }
  }

  Future<GoalEntity?> getGoal(String goalId) async {
    try {
      final response = await _client
          .from('wt_goal_forecasts')
          .select()
          .eq('id', goalId)
          .single();

      final forecast = await _getLatestForecast(goalId);
      return GoalEntity.fromJson(response, forecast: forecast);
    } catch (e) {
      throw Exception('Failed to fetch goal: $e');
    }
  }

  Future<GoalEntity> createGoal({
    required String profileId,
    required String metricType,
    String? description,
    required double targetValue,
    required String unit,
    DateTime? deadline,
    int priority = 0,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'profile_id': profileId,
        'metric_type': metricType,
        'goal_description': description,
        'target_value': targetValue,
        'current_value': 0,
        'unit': unit,
        'deadline': deadline?.toIso8601String().split('T').first,
        'priority': priority,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client
          .from('wt_goal_forecasts')
          .insert(data)
          .select()
          .single();

      return GoalEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create goal: $e');
    }
  }

  Future<GoalEntity> updateGoal(
    String goalId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final updateData = {
        ...fields,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('wt_goal_forecasts')
          .update(updateData)
          .eq('id', goalId)
          .select()
          .single();

      final forecast = await _getLatestForecast(goalId);
      return GoalEntity.fromJson(response, forecast: forecast);
    } catch (e) {
      throw Exception('Failed to update goal: $e');
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      await _client
          .from('wt_goal_forecasts')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goalId);
    } catch (e) {
      throw Exception('Failed to delete goal: $e');
    }
  }

  Future<GoalEntity> recalculateForecast(
    String goalId,
    InsightsRepository insightsRepo,
  ) async {
    try {
      // Load the goal
      final goal = await getGoal(goalId);
      if (goal == null) {
        throw Exception('Goal not found: $goalId');
      }

      // Calculate and save forecast
      final forecast = await insightsRepo.calculateAndSaveForecast(
        profileId: goal.profileId,
        metricType: goal.metricType,
        targetValue: goal.targetValue,
        goalForecastId: goalId,
      );

      // Update goal with latest values from forecast
      final updateData = <String, dynamic>{
        'current_value': forecast.currentValue,
        'confidence_score': forecast.rSquared,
      };
      if (forecast.projectedDate != null) {
        updateData['expected_date'] =
            forecast.projectedDate!.toIso8601String().split('T').first;
      }

      return await updateGoal(goalId, updateData);
    } catch (e) {
      throw Exception('Failed to recalculate forecast: $e');
    }
  }

  Future<ForecastEntity?> _getLatestForecast(String goalId) async {
    try {
      final response = await _client
          .from('wt_forecasts')
          .select()
          .eq('goal_forecast_id', goalId)
          .order('calculated_at', ascending: false)
          .limit(1);

      if ((response as List).isEmpty) return null;
      return ForecastEntity.fromJson(response.first);
    } catch (e) {
      // Forecast may not exist yet — that's fine
      return null;
    }
  }
}
