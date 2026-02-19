import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/pantry/domain/pantry_item_entity.dart';
import 'package:welltrack/features/recipes/data/recipe_repository.dart';
import 'package:welltrack/features/recipes/domain/recipe_entity.dart';
import 'package:welltrack/features/recipes/domain/recipe_ingredient.dart';
import 'package:welltrack/features/recipes/domain/recipe_step.dart';
import 'package:welltrack/shared/core/ai/ai_orchestrator_service.dart';
import 'package:welltrack/shared/core/ai/ai_providers.dart';

enum RecipeGenerationState {
  idle,
  generating,
  suggestions,
  generatingSteps,
  saving,
  complete,
  error,
}

class RecipeGenerationData {
  final RecipeGenerationState state;
  final List<RecipeSuggestion> suggestions;
  final RecipeSuggestion? selectedSuggestion;
  final RecipeEntity? generatedRecipe;
  final String? errorMessage;

  const RecipeGenerationData({
    required this.state,
    this.suggestions = const [],
    this.selectedSuggestion,
    this.generatedRecipe,
    this.errorMessage,
  });

  RecipeGenerationData copyWith({
    RecipeGenerationState? state,
    List<RecipeSuggestion>? suggestions,
    RecipeSuggestion? selectedSuggestion,
    RecipeEntity? generatedRecipe,
    String? errorMessage,
  }) {
    return RecipeGenerationData(
      state: state ?? this.state,
      suggestions: suggestions ?? this.suggestions,
      selectedSuggestion: selectedSuggestion ?? this.selectedSuggestion,
      generatedRecipe: generatedRecipe ?? this.generatedRecipe,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RecipeSuggestion {
  final String title;
  final String description;
  final int estimatedTimeMin;
  final String difficulty;
  final String nutritionScore;
  final List<String> tags;
  final int servings;

  const RecipeSuggestion({
    required this.title,
    required this.description,
    required this.estimatedTimeMin,
    required this.difficulty,
    required this.nutritionScore,
    required this.tags,
    this.servings = 2,
  });

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      title: json['title'] as String? ?? json['name'] as String? ?? 'Recipe',
      description: json['description'] as String? ?? '',
      estimatedTimeMin: json['estimated_time_min'] as int? ??
          json['prep_time'] as int? ??
          30,
      difficulty: json['difficulty'] as String? ?? 'Medium',
      nutritionScore: json['nutrition_score'] as String? ?? 'B',
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
      servings: json['servings'] as int? ?? 2,
    );
  }
}

final recipeGenerationProvider =
    StateNotifierProvider<RecipeGenerationNotifier, RecipeGenerationData>((ref) {
  return RecipeGenerationNotifier(
    ref.watch(recipeRepositoryProvider),
    ref.watch(aiOrchestratorServiceProvider),
    ref,
  );
});

class RecipeGenerationNotifier extends StateNotifier<RecipeGenerationData> {
  final RecipeRepository _repository;
  final AiOrchestratorService _aiService;
  final Ref _ref;

  RecipeGenerationNotifier(this._repository, this._aiService, this._ref)
      : super(const RecipeGenerationData(state: RecipeGenerationState.idle));

  Future<void> generateRecipeSuggestions(
    String userId,
    String profileId,
    List<PantryItemEntity> pantryItems,
  ) async {
    state = state.copyWith(state: RecipeGenerationState.generating);

    try {
      final itemNames = pantryItems.map((e) => e.name).toList();

      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: profileId,
        workflowType: 'generate_pantry_recipes',
        message:
            'Generate recipe suggestions using these pantry items: ${itemNames.join(", ")}',
        contextOverride: {'pantry_items': itemNames},
      );

      // Update global usage state
      _ref.read(aiUsageProvider.notifier).state = response.usage;

      // Parse suggestions from suggested_actions (action_type == 'view_recipe')
      final suggestions = response.suggestedActions
          .where((a) => a.actionType == 'view_recipe')
          .map((a) => RecipeSuggestion.fromJson(a.payload))
          .toList();

      if (suggestions.isEmpty) {
        // Try parsing from assistant_message JSON blocks as fallback
        final parsed = _parseJsonFromMessage(response.assistantMessage);
        if (parsed != null && parsed is List) {
          suggestions.addAll(
            parsed.map((r) =>
                RecipeSuggestion.fromJson(r as Map<String, dynamic>)),
          );
        }
      }

      if (suggestions.isEmpty) {
        // AI returned nothing useful — use fallback
        state = state.copyWith(
          state: RecipeGenerationState.suggestions,
          suggestions: _fallbackSuggestions(pantryItems),
        );
      } else {
        state = state.copyWith(
          state: RecipeGenerationState.suggestions,
          suggestions: suggestions,
        );
      }
    } on AiOfflineException {
      state = state.copyWith(
        state: RecipeGenerationState.suggestions,
        suggestions: _fallbackSuggestions(pantryItems),
        errorMessage:
            'You\'re offline. Showing sample suggestions — connect to get AI recipes.',
      );
    } on AiRateLimitException catch (e) {
      if (e.usage != null) {
        _ref.read(aiUsageProvider.notifier).state = e.usage;
      }
      state = state.copyWith(
        state: RecipeGenerationState.suggestions,
        suggestions: _fallbackSuggestions(pantryItems),
        errorMessage:
            'AI limit reached (${e.usage?.callsUsed ?? "?"}/${e.usage?.callsLimit ?? "?"} calls). Showing sample suggestions.',
      );
    } on AiTimeoutException {
      state = state.copyWith(
        state: RecipeGenerationState.suggestions,
        suggestions: _fallbackSuggestions(pantryItems),
        errorMessage: 'AI timed out. Showing sample suggestions.',
      );
    } catch (e) {
      state = state.copyWith(
        state: RecipeGenerationState.suggestions,
        suggestions: _fallbackSuggestions(pantryItems),
        errorMessage: 'AI unavailable. Showing sample suggestions.',
      );
    }
  }

  Future<void> selectSuggestion(
    String userId,
    String profileId,
    RecipeSuggestion suggestion,
  ) async {
    state = state.copyWith(
      state: RecipeGenerationState.generatingSteps,
      selectedSuggestion: suggestion,
    );

    List<RecipeStep> steps;
    List<RecipeIngredient> ingredients;

    try {
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: profileId,
        workflowType: 'generate_recipe_steps',
        message:
            'Generate detailed steps and ingredients for: ${suggestion.title}',
        contextOverride: {
          'recipe_name': suggestion.title,
          'description': suggestion.description,
          'servings': suggestion.servings,
        },
      );

      // Update global usage state
      _ref.read(aiUsageProvider.notifier).state = response.usage;

      // Parse steps and ingredients from assistant_message JSON blocks
      final parsed = _parseJsonFromMessage(response.assistantMessage);
      if (parsed != null && parsed is Map<String, dynamic>) {
        steps = _parseSteps(parsed);
        ingredients = _parseIngredients(parsed);
      } else {
        steps = _fallbackSteps(suggestion);
        ingredients = _fallbackIngredients();
      }
    } on AiException {
      // Any AI failure: fall back to mock data (never a blank screen)
      steps = _fallbackSteps(suggestion);
      ingredients = _fallbackIngredients();
    }

    state = state.copyWith(state: RecipeGenerationState.saving);

    try {
      // Save to database
      final recipe = await _repository.saveRecipe(
        profileId: profileId,
        title: suggestion.title,
        description: suggestion.description,
        servings: suggestion.servings,
        prepTimeMin: (suggestion.estimatedTimeMin * 0.3).round(),
        cookTimeMin: (suggestion.estimatedTimeMin * 0.7).round(),
        sourceType: 'ai',
        nutritionScore: suggestion.nutritionScore,
        tags: suggestion.tags,
        steps: steps,
        ingredients: ingredients,
      );

      state = state.copyWith(
        state: RecipeGenerationState.complete,
        generatedRecipe: recipe,
      );
    } catch (e) {
      state = state.copyWith(
        state: RecipeGenerationState.error,
        errorMessage: 'Failed to save recipe: $e',
      );
    }
  }

  void reset() {
    state = const RecipeGenerationData(state: RecipeGenerationState.idle);
  }

  // --- JSON parsing helpers ---

  dynamic _parseJsonFromMessage(String message) {
    final regex = RegExp(r'```json\n([\s\S]*?)\n```');
    final match = regex.firstMatch(message);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!);
    } catch (_) {
      return null;
    }
  }

  List<RecipeStep> _parseSteps(Map<String, dynamic> data) {
    final raw = data['steps'] as List?;
    if (raw == null || raw.isEmpty) return _fallbackSteps(null);

    return raw.asMap().entries.map((entry) {
      final item = entry.value;
      return RecipeStep(
        id: '',
        stepNumber: entry.key + 1,
        instruction: item is Map
            ? (item['instruction'] ?? item['step'] ?? item.toString())
                .toString()
            : item.toString(),
        durationMinutes:
            item is Map ? item['duration_minutes'] as int? : null,
      );
    }).toList();
  }

  List<RecipeIngredient> _parseIngredients(Map<String, dynamic> data) {
    final raw = data['ingredients'] as List?;
    if (raw == null || raw.isEmpty) return _fallbackIngredients();

    return raw.asMap().entries.map((entry) {
      final item = entry.value;
      if (item is Map) {
        return RecipeIngredient(
          id: '',
          ingredientName:
              (item['name'] ?? item['ingredient_name'] ?? '').toString(),
          quantity: (item['quantity'] as num?)?.toDouble(),
          unit: item['unit']?.toString(),
          notes: item['notes']?.toString(),
          sortOrder: entry.key,
        );
      }
      return RecipeIngredient(
        id: '',
        ingredientName: item.toString(),
        sortOrder: entry.key,
      );
    }).toList();
  }

  // --- Fallback data (offline / AI failure — "never a blank screen") ---

  List<RecipeSuggestion> _fallbackSuggestions(List<PantryItemEntity> items) {
    final itemNames = items.map((e) => e.name).take(3).join(', ');

    return [
      RecipeSuggestion(
        title: 'Quick Stir-Fry with $itemNames',
        description:
            'A fast and healthy stir-fry using your available ingredients',
        estimatedTimeMin: 20,
        difficulty: 'Easy',
        nutritionScore: 'A',
        tags: const ['Quick', 'Healthy', 'Asian'],
        servings: 2,
      ),
      const RecipeSuggestion(
        title: 'Hearty Soup',
        description: 'A comforting soup perfect for using up pantry items',
        estimatedTimeMin: 45,
        difficulty: 'Medium',
        nutritionScore: 'B',
        tags: ['Comfort Food', 'One-Pot'],
        servings: 4,
      ),
      const RecipeSuggestion(
        title: 'Simple Pasta Dish',
        description: 'Easy pasta with what you have on hand',
        estimatedTimeMin: 25,
        difficulty: 'Easy',
        nutritionScore: 'B',
        tags: ['Quick', 'Italian', 'Family-Friendly'],
        servings: 3,
      ),
    ];
  }

  List<RecipeStep> _fallbackSteps(RecipeSuggestion? suggestion) {
    return const [
      RecipeStep(
        id: '1',
        stepNumber: 1,
        instruction:
            'Prepare all ingredients by washing and chopping vegetables',
        durationMinutes: 5,
      ),
      RecipeStep(
        id: '2',
        stepNumber: 2,
        instruction:
            'Heat oil in a large pan or wok over medium-high heat',
        durationMinutes: 2,
      ),
      RecipeStep(
        id: '3',
        stepNumber: 3,
        instruction: 'Add protein and cook until browned on all sides',
        durationMinutes: 5,
      ),
      RecipeStep(
        id: '4',
        stepNumber: 4,
        instruction: 'Add vegetables and stir-fry until tender-crisp',
        durationMinutes: 5,
      ),
      RecipeStep(
        id: '5',
        stepNumber: 5,
        instruction: 'Season with sauce and toss everything together',
        durationMinutes: 2,
      ),
      RecipeStep(
        id: '6',
        stepNumber: 6,
        instruction: 'Serve hot, garnished with fresh herbs',
      ),
    ];
  }

  List<RecipeIngredient> _fallbackIngredients() {
    return const [
      RecipeIngredient(
        id: '1',
        ingredientName: 'Chicken breast',
        quantity: 300,
        unit: 'g',
        sortOrder: 1,
      ),
      RecipeIngredient(
        id: '2',
        ingredientName: 'Mixed vegetables',
        quantity: 2,
        unit: 'cups',
        sortOrder: 2,
      ),
      RecipeIngredient(
        id: '3',
        ingredientName: 'Soy sauce',
        quantity: 2,
        unit: 'tbsp',
        sortOrder: 3,
      ),
      RecipeIngredient(
        id: '4',
        ingredientName: 'Garlic',
        quantity: 3,
        unit: 'cloves',
        notes: 'minced',
        sortOrder: 4,
      ),
      RecipeIngredient(
        id: '5',
        ingredientName: 'Cooking oil',
        quantity: 2,
        unit: 'tbsp',
        sortOrder: 5,
      ),
    ];
  }
}
