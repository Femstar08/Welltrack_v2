import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import 'html_recipe_extractor.dart';

/// Service for extracting recipes from URLs.
///
/// Primary strategy: call the AI orchestrator edge function
/// (workflow_type: 'extract_recipe_from_url').
///
/// Fallback: if the AI call fails for any reason (network error, 404,
/// undeployed edge function, etc.) the service falls back to
/// [HtmlRecipeExtractor], which parses schema.org JSON-LD directly from the
/// page HTML — no backend required.
class UrlRecipeExtractor {
  UrlRecipeExtractor(this._aiService, this._htmlExtractor);

  final AiOrchestratorService _aiService;
  final HtmlRecipeExtractor _htmlExtractor;

  /// Extracts a recipe from [url].
  ///
  /// Tries the AI orchestrator first; on any exception falls back to
  /// client-side HTML extraction.
  ///
  /// Throws [ArgumentError] for a malformed URL.
  /// Throws [Exception] with a descriptive message if both strategies fail.
  Future<RecipeEntity> extractRecipe({
    required String url,
    required String userId,
    required String profileId,
  }) async {
    // Validate URL format before attempting anything
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Invalid URL format');
    }

    // --- Primary: AI orchestrator ---
    try {
      return await _extractViaAi(
        url: url,
        userId: userId,
        profileId: profileId,
      );
    } catch (_) {
      // AI path failed (edge function not deployed, offline, rate-limited,
      // parse error, etc.) — fall through to HTML extraction.
    }

    // --- Fallback: client-side HTML / JSON-LD ---
    return _htmlExtractor.extractRecipe(url: url, profileId: profileId);
  }

  // ---------------------------------------------------------------------------
  // AI extraction
  // ---------------------------------------------------------------------------

  Future<RecipeEntity> _extractViaAi({
    required String url,
    required String userId,
    required String profileId,
  }) async {
    final response = await _aiService.orchestrate(
      userId: userId,
      profileId: profileId,
      workflowType: 'extract_recipe_from_url',
      message: 'Extract recipe from URL: $url',
      contextOverride: {'url': url},
    );

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
      id: '',
      profileId: profileId,
      title: recipeData['title']?.toString() ?? 'Untitled Recipe',
      description: recipeData['description']?.toString(),
      servings: recipeData['servings'] as int? ?? 1,
      prepTimeMin: recipeData['prep_time'] as int? ?? 0,
      cookTimeMin: recipeData['cook_time'] as int? ?? 0,
      sourceType: 'url',
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
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extracts the first ```json ... ``` block from an AI assistant message.
  Map<String, dynamic>? _extractJsonFromMessage(String message) {
    final regex = RegExp(r'```json\n([\s\S]*?)\n```');
    final match = regex.firstMatch(message);
    if (match == null) return null;

    try {
      final decoded = jsonDecode(match.group(1)!);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return decoded.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Riverpod provider for [UrlRecipeExtractor].
///
/// Composes [AiOrchestratorService] (primary) with [HtmlRecipeExtractor]
/// (fallback) so callers never need to handle the fallback logic themselves.
final urlRecipeExtractorProvider = Provider<UrlRecipeExtractor>((ref) {
  final aiService = ref.watch(aiOrchestratorServiceProvider);
  final htmlExtractor = ref.watch(htmlRecipeExtractorProvider);
  return UrlRecipeExtractor(aiService, htmlExtractor);
});
