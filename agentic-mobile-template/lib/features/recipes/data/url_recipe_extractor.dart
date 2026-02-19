import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/recipes/domain/recipe_entity.dart';
import 'package:welltrack/features/recipes/domain/recipe_ingredient.dart';
import 'package:welltrack/features/recipes/domain/recipe_step.dart';
import 'package:welltrack/shared/core/ai/ai_orchestrator_service.dart';

/// Service for extracting recipes from URLs via AI orchestrator
class UrlRecipeExtractor {
  final AiOrchestratorService _aiService;

  UrlRecipeExtractor(this._aiService);

  /// Extracts a recipe from a given URL
  ///
  /// Calls the AI orchestrator with workflow_type: 'extract_recipe_from_url'
  /// Returns a RecipeEntity with extracted data
  /// Throws [AiOfflineException], [AiRateLimitException], or generic exceptions
  Future<RecipeEntity> extractRecipe({
    required String url,
    required String userId,
    required String profileId,
  }) async {
    // Validate URL format
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Invalid URL format');
    }

    try {
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: profileId,
        workflowType: 'extract_recipe_from_url',
        message: 'Extract recipe from URL: $url',
        contextOverride: {'url': url},
      );

      // Parse recipe data from assistant_message JSON blocks
      final recipeData = _extractJsonFromMessage(response.assistantMessage);
      if (recipeData == null) {
        throw Exception('No recipe data found in AI response');
      }

      // Parse ingredients
      final ingredientsList = (recipeData['ingredients'] as List?)
              ?.asMap()
              .entries
              .map((entry) => RecipeIngredient(
                    id: '',
                    ingredientName: entry.value is Map
                        ? (entry.value as Map)['name']?.toString() ??
                            entry.value.toString()
                        : entry.value.toString(),
                    quantity: entry.value is Map
                        ? (entry.value as Map)['quantity'] as double?
                        : null,
                    unit: entry.value is Map
                        ? (entry.value as Map)['unit']?.toString()
                        : null,
                    sortOrder: entry.key,
                  ))
              .toList() ??
          <RecipeIngredient>[];

      // Parse steps
      final stepsList = (recipeData['steps'] as List?)
              ?.asMap()
              .entries
              .map((entry) => RecipeStep(
                    id: '',
                    stepNumber: entry.key + 1,
                    instruction: entry.value is Map
                        ? (entry.value as Map)['instruction']?.toString() ??
                            entry.value.toString()
                        : entry.value.toString(),
                  ))
              .toList() ??
          <RecipeStep>[];

      return RecipeEntity(
        id: '', // Will be generated on save
        profileId: profileId,
        title: recipeData['title']?.toString() ?? 'Untitled Recipe',
        description: recipeData['description']?.toString(),
        servings: recipeData['servings'] as int? ?? 1,
        prepTimeMin: recipeData['prep_time'] as int? ?? 0,
        cookTimeMin: recipeData['cook_time'] as int? ?? 0,
        sourceType: 'url_import',
        sourceUrl: url,
        nutritionScore: recipeData['nutrition_score']?.toString(),
        tags: (recipeData['tags'] as List?)
                ?.map((t) => t.toString())
                .toList() ??
            [],
        imageUrl: recipeData['image_url']?.toString(),
        ingredients: ingredientsList,
        steps: stepsList,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on AiOfflineException {
      rethrow;
    } on AiRateLimitException {
      rethrow;
    } on AiTimeoutException {
      throw Exception(
          'Recipe extraction timed out. The page may be too complex.');
    } catch (e) {
      rethrow;
    }
  }

  /// Extract the first JSON block from an AI assistant message.
  /// The server wraps structured data in ```json ... ``` fences.
  Map<String, dynamic>? _extractJsonFromMessage(String message) {
    final regex = RegExp(r'```json\n([\s\S]*?)\n```');
    final match = regex.firstMatch(message);
    if (match == null) return null;

    try {
      final decoded = jsonDecode(match.group(1)!);
      if (decoded is Map<String, dynamic>) return decoded;
      // If the server returned an array, take the first element
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return decoded.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

/// Provider for URL recipe extractor
final urlRecipeExtractorProvider = Provider<UrlRecipeExtractor>((ref) {
  final aiService = ref.watch(aiOrchestratorServiceProvider);
  return UrlRecipeExtractor(aiService);
});
