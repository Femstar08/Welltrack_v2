import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_plan_entity.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(Supabase.instance.client);
});

class MealPlanRepository {
  MealPlanRepository(this._client);
  final SupabaseClient _client;

  Future<MealPlanEntity?> getMealPlan(String profileId, DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from('wt_meal_plans')
          .select('*, wt_meal_plan_items(*)')
          .eq('profile_id', profileId)
          .eq('plan_date', dateStr)
          .limit(1);

      final list = response as List;
      if (list.isEmpty) return null;

      return MealPlanEntity.fromJson(list.first as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch meal plan: $e');
    }
  }

  Future<List<MealPlanEntity>> getMealPlans(
    String profileId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from('wt_meal_plans')
          .select('*, wt_meal_plan_items(*)')
          .eq('profile_id', profileId)
          .gte('plan_date', startStr)
          .lte('plan_date', endStr)
          .order('plan_date', ascending: true);

      return (response as List)
          .map((json) =>
              MealPlanEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch meal plans: $e');
    }
  }

  Future<MealPlanEntity> saveMealPlan(MealPlanEntity entity) async {
    try {
      // Upsert the plan (unique on profile_id + plan_date)
      final planData = entity.toJson();
      planData.remove('id'); // let DB generate if new

      final planResponse = await _client
          .from('wt_meal_plans')
          .upsert(
            planData,
            onConflict: 'profile_id,plan_date',
          )
          .select()
          .single();

      final planId = planResponse['id'] as String;

      // Delete existing items for this plan, then insert new ones
      await _client
          .from('wt_meal_plan_items')
          .delete()
          .eq('meal_plan_id', planId);

      if (entity.items.isNotEmpty) {
        final itemsData = entity.items.map((item) {
          final json = item.toJson();
          json.remove('id');
          json['meal_plan_id'] = planId;
          return json;
        }).toList();

        await _client.from('wt_meal_plan_items').insert(itemsData);
      }

      // Fetch the saved plan with items
      final result = await _client
          .from('wt_meal_plans')
          .select('*, wt_meal_plan_items(*)')
          .eq('id', planId)
          .single();

      return MealPlanEntity.fromJson(result);
    } catch (e) {
      throw Exception('Failed to save meal plan: $e');
    }
  }

  Future<void> updateItemLogged(String itemId, {required bool isLogged}) async {
    try {
      await _client
          .from('wt_meal_plan_items')
          .update({'is_logged': isLogged})
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to update meal item: $e');
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> fields) async {
    try {
      await _client
          .from('wt_meal_plan_items')
          .update(fields)
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to update meal plan item: $e');
    }
  }

  Future<void> deleteMealPlan(String planId) async {
    try {
      await _client.from('wt_meal_plans').delete().eq('id', planId);
    } catch (e) {
      throw Exception('Failed to delete meal plan: $e');
    }
  }
}
