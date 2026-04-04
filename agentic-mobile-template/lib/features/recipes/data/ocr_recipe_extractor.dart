import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import '../../../shared/core/ocr/ocr_service.dart';

/// Extracts a structured recipe from a photo using on-device OCR + AI.
///
/// Step 1: Run on-device OCR via [OcrService] to get raw text.
/// Step 2: Send OCR text to the AI orchestrator (workflow: extract_recipe_from_image).
/// Step 3: Parse the AI JSON response into a [RecipeEntity].
class OcrRecipeExtractor {
  OcrRecipeExtractor(this._ocrService, this._aiService);

  final OcrService _ocrService;
  final AiOrchestratorService _aiService;

  /// Extracts a recipe from the photo at [imagePath].
  ///
  /// Throws if OCR finds no text or AI fails to parse a recipe.
  Future<RecipeEntity> extractRecipe({
    required String imagePath,
    required String userId,
    required String profileId,
  }) async {
    // Step 1: On-device OCR
    final ocrText = await _ocrService.recognizeText(imagePath);
    if (ocrText.trim().isEmpty) {
      throw Exception(
        'No text detected in the image. Please try a clearer photo.',
      );
    }

    // Step 2: Send OCR text to AI for structured parsing
    final response = await _aiService.orchestrate(
      userId: userId,
      profileId: profileId,
      workflowType: 'extract_recipe_from_image',
      message: 'Extract a structured recipe from the following OCR text:\n\n$ocrText',
      contextOverride: {'ocr_text': ocrText},
    );

    // Step 3: Parse AI response
    var recipeData = _extractJsonFromMessage(response.assistantMessage);
    if (recipeData == null) {
      throw Exception(
        'Could not parse recipe from the image. Try a clearer photo.',
      );
    }

    // Support new schema (recipe wrapper) and legacy (flat)
    if (recipeData.containsKey('recipe') && recipeData['recipe'] is Map) {
      recipeData = recipeData['recipe'] as Map<String, dynamic>;
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
                      ? _parseDouble((entry.value as Map)['quantity'])
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
      servings: _parseInt(recipeData['servings']) ?? 1,
      prepTimeMin: _parseInt(recipeData['prep_time']) ?? 0,
      cookTimeMin: _parseInt(recipeData['cook_time']) ?? 0,
      sourceType: 'ocr',
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

  /// Extracts JSON from an AI assistant message.
  /// Tries bare JSON first, then falls back to ```json code blocks.
  Map<String, dynamic>? _extractJsonFromMessage(String message) {
    // Try parsing the entire message as bare JSON first
    try {
      final decoded = jsonDecode(message.trim());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return decoded.first as Map<String, dynamic>;
      }
    } catch (_) {}

    // Fall back to code-fenced JSON block
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

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Riverpod provider for [OcrRecipeExtractor].
final ocrRecipeExtractorProvider = Provider<OcrRecipeExtractor>((ref) {
  final ocrService = ref.watch(ocrServiceProvider);
  final aiService = ref.watch(aiOrchestratorServiceProvider);
  return OcrRecipeExtractor(ocrService, aiService);
});
