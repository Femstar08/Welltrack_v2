import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_entity.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(Supabase.instance.client);
});

class MealRepository {

  MealRepository(this._client);
  final SupabaseClient _client;

  Future<List<MealEntity>> getMeals(String profileId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('wt_meals')
          .select()
          .eq('profile_id', profileId)
          .gte('meal_date', startOfDay.toIso8601String())
          .lt('meal_date', endOfDay.toIso8601String())
          .order('meal_date', ascending: true);

      return (response as List)
          .map((json) => MealEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch meals: $e');
    }
  }

  Future<List<MealEntity>> getMealsByDateRange(
    String profileId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _client
          .from('wt_meals')
          .select()
          .eq('profile_id', profileId)
          .gte('meal_date', startDate.toIso8601String())
          .lte('meal_date', endDate.toIso8601String())
          .order('meal_date', ascending: false);

      return (response as List)
          .map((json) => MealEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch meals by date range: $e');
    }
  }

  Future<MealEntity> logMeal({
    required String profileId,
    String? recipeId,
    required DateTime mealDate,
    required String mealType,
    required String name,
    double servingsConsumed = 1.0,
    Map<String, dynamic>? nutritionInfo,
    String? score,
    double? rating,
    String? notes,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      final mealData = {
        'profile_id': profileId,
        'recipe_id': recipeId,
        'meal_date': mealDate.toIso8601String(),
        'meal_type': mealType,
        'name': name,
        'servings_consumed': servingsConsumed,
        'nutrition_info': nutritionInfo,
        'score': score,
        'rating': rating,
        'notes': notes,
        'photo_url': photoUrl,
        'is_favorite': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client
          .from('wt_meals')
          .insert(mealData)
          .select()
          .single();

      return MealEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to log meal: $e');
    }
  }

  Future<MealEntity> updateMeal(
    String mealId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final updateData = {
        ...fields,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('wt_meals')
          .update(updateData)
          .eq('id', mealId)
          .select()
          .single();

      return MealEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update meal: $e');
    }
  }

  Future<void> deleteMeal(String mealId) async {
    try {
      await _client
          .from('wt_meals')
          .delete()
          .eq('id', mealId);
    } catch (e) {
      throw Exception('Failed to delete meal: $e');
    }
  }

  Future<MealEntity> toggleFavorite(String mealId, bool isFavorite) async {
    try {
      final response = await _client
          .from('wt_meals')
          .update({
            'is_favorite': isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', mealId)
          .select()
          .single();

      return MealEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  Future<List<MealEntity>> getFavoriteMeals(String profileId) async {
    try {
      final response = await _client
          .from('wt_meals')
          .select()
          .eq('profile_id', profileId)
          .eq('is_favorite', true)
          .order('meal_date', ascending: false);

      return (response as List)
          .map((json) => MealEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorite meals: $e');
    }
  }
}
