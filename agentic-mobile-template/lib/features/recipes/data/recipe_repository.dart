import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(Supabase.instance.client);
});

class RecipeRepository {

  RecipeRepository(this._client);
  final SupabaseClient _client;

  Future<List<RecipeEntity>> getRecipes(String profileId) async {
    try {
      final response = await _client
          .from('wt_recipes')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RecipeEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recipes: $e');
    }
  }

  Future<RecipeEntity> getRecipe(String recipeId) async {
    try {
      // Fetch recipe
      final recipeResponse = await _client
          .from('wt_recipes')
          .select()
          .eq('id', recipeId)
          .single();

      final recipe = RecipeEntity.fromJson(recipeResponse);

      // Fetch steps
      final stepsResponse = await _client
          .from('wt_recipe_steps')
          .select()
          .eq('recipe_id', recipeId)
          .order('step_number', ascending: true);

      final steps = (stepsResponse as List)
          .map((json) => RecipeStep.fromJson(json))
          .toList();

      // Fetch ingredients
      final ingredientsResponse = await _client
          .from('wt_recipe_ingredients')
          .select()
          .eq('recipe_id', recipeId)
          .order('sort_order', ascending: true);

      final ingredients = (ingredientsResponse as List)
          .map((json) => RecipeIngredient.fromJson(json))
          .toList();

      return recipe.copyWith(steps: steps, ingredients: ingredients);
    } catch (e) {
      throw Exception('Failed to fetch recipe: $e');
    }
  }

  Future<RecipeEntity> saveRecipe({
    required String profileId,
    required String title,
    String? description,
    required int servings,
    int? prepTimeMin,
    int? cookTimeMin,
    required String sourceType,
    String? sourceUrl,
    String? nutritionScore,
    List<String>? tags,
    String? imageUrl,
    required List<RecipeStep> steps,
    required List<RecipeIngredient> ingredients,
  }) async {
    try {
      final now = DateTime.now();

      // Insert recipe
      final recipeData = {
        'profile_id': profileId,
        'title': title,
        'description': description,
        'servings': servings,
        'prep_time_min': prepTimeMin,
        'cook_time_min': cookTimeMin,
        'source_type': sourceType,
        'source_url': sourceUrl,
        'nutrition_score': nutritionScore,
        'tags': tags ?? [],
        'image_url': imageUrl,
        'is_favorite': false,
        'is_public': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final recipeResponse = await _client
          .from('wt_recipes')
          .insert(recipeData)
          .select()
          .single();

      final recipeId = recipeResponse['id'] as String;

      // Insert steps
      if (steps.isNotEmpty) {
        final stepsData = steps.map((step) {
          return {
            'recipe_id': recipeId,
            'step_number': step.stepNumber,
            'instruction': step.instruction,
            'duration_minutes': step.durationMinutes,
          };
        }).toList();

        await _client.from('wt_recipe_steps').insert(stepsData);
      }

      // Insert ingredients
      if (ingredients.isNotEmpty) {
        final ingredientsData = ingredients.map((ingredient) {
          return {
            'recipe_id': recipeId,
            'ingredient_name': ingredient.ingredientName,
            'quantity': ingredient.quantity,
            'unit': ingredient.unit,
            'notes': ingredient.notes,
            'sort_order': ingredient.sortOrder,
          };
        }).toList();

        await _client.from('wt_recipe_ingredients').insert(ingredientsData);
      }

      return await getRecipe(recipeId);
    } catch (e) {
      throw Exception('Failed to save recipe: $e');
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    try {
      // Delete steps
      await _client
          .from('wt_recipe_steps')
          .delete()
          .eq('recipe_id', recipeId);

      // Delete ingredients
      await _client
          .from('wt_recipe_ingredients')
          .delete()
          .eq('recipe_id', recipeId);

      // Delete recipe
      await _client
          .from('wt_recipes')
          .delete()
          .eq('id', recipeId);
    } catch (e) {
      throw Exception('Failed to delete recipe: $e');
    }
  }

  Future<RecipeEntity> toggleFavorite(String recipeId, bool isFavorite) async {
    try {
      final response = await _client
          .from('wt_recipes')
          .update({
            'is_favorite': isFavorite,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', recipeId)
          .select()
          .single();

      return RecipeEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  Future<RecipeEntity> updateRating(String recipeId, double rating) async {
    try {
      final response = await _client
          .from('wt_recipes')
          .update({
            'rating': rating,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', recipeId)
          .select()
          .single();

      return RecipeEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update rating: $e');
    }
  }

  Future<List<RecipeEntity>> searchRecipes(String profileId, String query) async {
    try {
      final response = await _client
          .from('wt_recipes')
          .select()
          .eq('profile_id', profileId)
          .ilike('title', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RecipeEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search recipes: $e');
    }
  }

  Future<List<RecipeEntity>> getRecipesByTags(String profileId, List<String> tags) async {
    try {
      // Fetch all recipes and filter client-side for multi-tag matching
      final response = await _client
          .from('wt_recipes')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      final allRecipes = (response as List)
          .map((json) => RecipeEntity.fromJson(json))
          .toList();

      return allRecipes.where((recipe) {
        return tags.any((tag) => recipe.tags.contains(tag));
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch recipes by tags: $e');
    }
  }

  Future<RecipeEntity> updateRecipe(String recipeId, Map<String, dynamic> fields) async {
    try {
      fields['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('wt_recipes')
          .update(fields)
          .eq('id', recipeId);

      return await getRecipe(recipeId);
    } catch (e) {
      throw Exception('Failed to update recipe: $e');
    }
  }

  Future<void> updateRecipeSteps(String recipeId, List<RecipeStep> steps) async {
    try {
      // Delete existing steps
      await _client
          .from('wt_recipe_steps')
          .delete()
          .eq('recipe_id', recipeId);

      // Insert new steps
      if (steps.isNotEmpty) {
        final stepsData = steps.map((step) {
          return {
            'recipe_id': recipeId,
            'step_number': step.stepNumber,
            'instruction': step.instruction,
            'duration_minutes': step.durationMinutes,
          };
        }).toList();

        await _client.from('wt_recipe_steps').insert(stepsData);
      }
    } catch (e) {
      throw Exception('Failed to update recipe steps: $e');
    }
  }

  Future<void> updateRecipeIngredients(String recipeId, List<RecipeIngredient> ingredients) async {
    try {
      // Delete existing ingredients
      await _client
          .from('wt_recipe_ingredients')
          .delete()
          .eq('recipe_id', recipeId);

      // Insert new ingredients
      if (ingredients.isNotEmpty) {
        final ingredientsData = ingredients.map((ingredient) {
          return {
            'recipe_id': recipeId,
            'ingredient_name': ingredient.ingredientName,
            'quantity': ingredient.quantity,
            'unit': ingredient.unit,
            'notes': ingredient.notes,
            'sort_order': ingredient.sortOrder,
          };
        }).toList();

        await _client.from('wt_recipe_ingredients').insert(ingredientsData);
      }
    } catch (e) {
      throw Exception('Failed to update recipe ingredients: $e');
    }
  }

  Future<List<RecipeEntity>> getFavoriteRecipes(String profileId) async {
    try {
      final response = await _client
          .from('wt_recipes')
          .select()
          .eq('profile_id', profileId)
          .eq('is_favorite', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RecipeEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorite recipes: $e');
    }
  }
}
