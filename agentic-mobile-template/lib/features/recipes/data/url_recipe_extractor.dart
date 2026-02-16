import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/recipes/domain/recipe_entity.dart';
import 'package:welltrack/features/recipes/domain/recipe_ingredient.dart';
import 'package:welltrack/features/recipes/domain/recipe_step.dart';
import 'package:welltrack/shared/core/network/dio_client.dart';

/// Service for extracting recipes from URLs via AI orchestrator
class UrlRecipeExtractor {
  final Dio _dio;

  UrlRecipeExtractor(this._dio);

  /// Extracts a recipe from a given URL
  ///
  /// Calls the AI orchestrator with workflow_type: 'extract_recipe_from_url'
  /// Returns a RecipeEntity with extracted data
  /// Throws exceptions on invalid URL or extraction failure
  Future<RecipeEntity> extractRecipe({
    required String url,
    required String userId,
    required String profileId,
  }) async {
    try {
      // Validate URL format
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw ArgumentError('Invalid URL format');
      }

      // Call AI orchestrator
      final response = await _dio.post(
        '/ai/orchestrate',
        data: {
          'user_id': userId,
          'profile_id': profileId,
          'workflow_type': 'extract_recipe_from_url',
          'context': {
            'url': url,
          },
          'user_message': 'Extract recipe from URL: $url',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Recipe extraction failed with status ${response.statusCode}');
      }

      final data = response.data;

      // Check for safety flags or errors
      if (data['safety_flags'] != null && (data['safety_flags'] as List).isNotEmpty) {
        throw Exception('Recipe extraction flagged as unsafe: ${data['safety_flags']}');
      }

      // Parse extracted recipe from response
      final recipeData = data['extracted_recipe'];
      if (recipeData == null) {
        throw Exception('No recipe data found in response');
      }

      // Parse ingredients
      final ingredientsList = (recipeData['ingredients'] as List?)
          ?.asMap()
          .entries
          .map((entry) => RecipeIngredient(
                id: '',
                ingredientName: entry.value.toString(),
                sortOrder: entry.key,
              ))
          .toList() ?? <RecipeIngredient>[];

      // Parse steps
      final stepsList = (recipeData['steps'] as List?)
          ?.asMap()
          .entries
          .map((entry) => RecipeStep(
                id: '',
                stepNumber: entry.key + 1,
                instruction: entry.value.toString(),
              ))
          .toList() ?? <RecipeStep>[];

      return RecipeEntity(
        id: '', // Will be generated on save
        profileId: profileId,
        title: recipeData['title'] ?? 'Untitled Recipe',
        description: recipeData['description'],
        servings: recipeData['servings'] ?? 1,
        prepTimeMin: recipeData['prep_time'] ?? 0,
        cookTimeMin: recipeData['cook_time'] ?? 0,
        sourceType: 'url_import',
        sourceUrl: url,
        nutritionScore: recipeData['nutrition_score'],
        tags: (recipeData['tags'] as List?)
            ?.map((t) => t.toString())
            .toList() ?? [],
        imageUrl: recipeData['image_url'],
        ingredients: ingredientsList,
        steps: stepsList,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Recipe could not be extracted from URL. The page may not contain a valid recipe.');
      } else if (e.response?.statusCode == 429) {
        throw Exception('AI usage limit reached. Please upgrade to Pro or try again later.');
      }
      throw Exception('Network error during recipe extraction: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider for URL recipe extractor
final urlRecipeExtractorProvider = Provider<UrlRecipeExtractor>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UrlRecipeExtractor(dioClient.instance);
});
