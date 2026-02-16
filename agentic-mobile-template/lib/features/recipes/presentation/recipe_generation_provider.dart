import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/pantry/domain/pantry_item_entity.dart';
import 'package:welltrack/features/recipes/data/recipe_repository.dart';
import 'package:welltrack/features/recipes/domain/recipe_entity.dart';
import 'package:welltrack/features/recipes/domain/recipe_ingredient.dart';
import 'package:welltrack/features/recipes/domain/recipe_step.dart';

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
      title: json['title'] as String,
      description: json['description'] as String,
      estimatedTimeMin: json['estimated_time_min'] as int,
      difficulty: json['difficulty'] as String,
      nutritionScore: json['nutrition_score'] as String,
      tags: List<String>.from(json['tags'] as List),
      servings: json['servings'] as int? ?? 2,
    );
  }
}

final recipeGenerationProvider =
    StateNotifierProvider<RecipeGenerationNotifier, RecipeGenerationData>((ref) {
  return RecipeGenerationNotifier(ref.watch(recipeRepositoryProvider));
});

class RecipeGenerationNotifier extends StateNotifier<RecipeGenerationData> {
  final RecipeRepository _repository;

  RecipeGenerationNotifier(this._repository)
      : super(const RecipeGenerationData(state: RecipeGenerationState.idle));

  Future<void> generateRecipeSuggestions(
    String profileId,
    List<PantryItemEntity> pantryItems,
  ) async {
    state = state.copyWith(state: RecipeGenerationState.generating);

    try {
      // TODO: Call AI orchestrator Edge Function
      // For now, return mock data
      await Future.delayed(const Duration(seconds: 2));

      final mockSuggestions = _generateMockSuggestions(pantryItems);

      state = state.copyWith(
        state: RecipeGenerationState.suggestions,
        suggestions: mockSuggestions,
      );
    } catch (e) {
      state = state.copyWith(
        state: RecipeGenerationState.error,
        errorMessage: 'Failed to generate recipes: $e',
      );
    }
  }

  Future<void> selectSuggestion(
    String profileId,
    RecipeSuggestion suggestion,
  ) async {
    state = state.copyWith(
      state: RecipeGenerationState.generatingSteps,
      selectedSuggestion: suggestion,
    );

    try {
      // TODO: Call AI orchestrator to generate detailed steps
      await Future.delayed(const Duration(seconds: 2));

      final mockSteps = _generateMockSteps(suggestion);
      final mockIngredients = _generateMockIngredients();

      state = state.copyWith(state: RecipeGenerationState.saving);

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
        steps: mockSteps,
        ingredients: mockIngredients,
      );

      state = state.copyWith(
        state: RecipeGenerationState.complete,
        generatedRecipe: recipe,
      );
    } catch (e) {
      state = state.copyWith(
        state: RecipeGenerationState.error,
        errorMessage: 'Failed to generate recipe details: $e',
      );
    }
  }

  void reset() {
    state = const RecipeGenerationData(state: RecipeGenerationState.idle);
  }

  // Mock data generators (to be replaced with actual AI calls)

  List<RecipeSuggestion> _generateMockSuggestions(List<PantryItemEntity> items) {
    final itemNames = items.map((e) => e.name).take(3).join(', ');

    return [
      RecipeSuggestion(
        title: 'Quick Stir-Fry with $itemNames',
        description: 'A fast and healthy stir-fry using your available ingredients',
        estimatedTimeMin: 20,
        difficulty: 'Easy',
        nutritionScore: 'A',
        tags: ['Quick', 'Healthy', 'Asian'],
        servings: 2,
      ),
      RecipeSuggestion(
        title: 'Hearty Soup',
        description: 'A comforting soup perfect for using up pantry items',
        estimatedTimeMin: 45,
        difficulty: 'Medium',
        nutritionScore: 'B',
        tags: ['Comfort Food', 'One-Pot'],
        servings: 4,
      ),
      RecipeSuggestion(
        title: 'Simple Pasta Dish',
        description: 'Easy pasta with what you have on hand',
        estimatedTimeMin: 25,
        difficulty: 'Easy',
        nutritionScore: 'B',
        tags: ['Quick', 'Italian', 'Family-Friendly'],
        servings: 3,
      ),
      RecipeSuggestion(
        title: 'Grilled Protein Bowl',
        description: 'Balanced bowl with grains and vegetables',
        estimatedTimeMin: 30,
        difficulty: 'Medium',
        nutritionScore: 'A',
        tags: ['Healthy', 'Protein-Rich', 'Meal Prep'],
        servings: 2,
      ),
      RecipeSuggestion(
        title: 'Veggie Stir-Fry Rice',
        description: 'Colorful fried rice with fresh vegetables',
        estimatedTimeMin: 15,
        difficulty: 'Easy',
        nutritionScore: 'A',
        tags: ['Quick', 'Vegetarian', 'Budget-Friendly'],
        servings: 2,
      ),
    ];
  }

  List<RecipeStep> _generateMockSteps(RecipeSuggestion suggestion) {
    return [
      const RecipeStep(
        id: '1',
        stepNumber: 1,
        instruction: 'Prepare all ingredients by washing and chopping vegetables',
        durationMinutes: 5,
      ),
      const RecipeStep(
        id: '2',
        stepNumber: 2,
        instruction: 'Heat oil in a large pan or wok over medium-high heat',
        durationMinutes: 2,
      ),
      const RecipeStep(
        id: '3',
        stepNumber: 3,
        instruction: 'Add protein and cook until browned on all sides',
        durationMinutes: 5,
      ),
      const RecipeStep(
        id: '4',
        stepNumber: 4,
        instruction: 'Add vegetables and stir-fry until tender-crisp',
        durationMinutes: 5,
      ),
      const RecipeStep(
        id: '5',
        stepNumber: 5,
        instruction: 'Season with sauce and toss everything together',
        durationMinutes: 2,
      ),
      const RecipeStep(
        id: '6',
        stepNumber: 6,
        instruction: 'Serve hot, garnished with fresh herbs',
      ),
    ];
  }

  List<RecipeIngredient> _generateMockIngredients() {
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
