import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';

class RecipeEditState {
  const RecipeEditState({
    this.recipe,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.hasChanges = false,
  });

  final RecipeEntity? recipe;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool hasChanges;

  RecipeEditState copyWith({
    RecipeEntity? recipe,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool? hasChanges,
  }) {
    return RecipeEditState(
      recipe: recipe ?? this.recipe,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }
}

class RecipeEditNotifier extends StateNotifier<RecipeEditState> {
  RecipeEditNotifier(this._repository) : super(const RecipeEditState());

  final RecipeRepository _repository;

  void loadRecipe(RecipeEntity recipe) {
    state = state.copyWith(recipe: recipe, hasChanges: false);
  }

  void updateTitle(String title) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(title: title),
      hasChanges: true,
    );
  }

  void updateDescription(String? desc) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(description: desc),
      hasChanges: true,
    );
  }

  void updateServings(int servings) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(servings: servings),
      hasChanges: true,
    );
  }

  void updatePrepTime(int? time) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(prepTimeMin: time),
      hasChanges: true,
    );
  }

  void updateCookTime(int? time) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(cookTimeMin: time),
      hasChanges: true,
    );
  }

  void updateTags(List<String> tags) {
    final recipe = state.recipe;
    if (recipe == null) return;
    state = state.copyWith(
      recipe: recipe.copyWith(tags: tags),
      hasChanges: true,
    );
  }

  void reorderSteps(int oldIndex, int newIndex) {
    final recipe = state.recipe;
    if (recipe == null) return;
    final steps = List<RecipeStep>.from(recipe.steps);
    final item = steps.removeAt(oldIndex);
    steps.insert(newIndex, item);
    // Renumber
    final renumbered = steps.asMap().entries.map((e) {
      return RecipeStep(
        id: e.value.id,
        stepNumber: e.key + 1,
        instruction: e.value.instruction,
        durationMinutes: e.value.durationMinutes,
      );
    }).toList();
    state = state.copyWith(
      recipe: recipe.copyWith(steps: renumbered),
      hasChanges: true,
    );
  }

  void updateStep(int index, String instruction) {
    final recipe = state.recipe;
    if (recipe == null || index >= recipe.steps.length) return;
    final steps = List<RecipeStep>.from(recipe.steps);
    steps[index] = steps[index].copyWith(instruction: instruction);
    state = state.copyWith(
      recipe: recipe.copyWith(steps: steps),
      hasChanges: true,
    );
  }

  void addStep(String instruction) {
    final recipe = state.recipe;
    if (recipe == null) return;
    final steps = List<RecipeStep>.from(recipe.steps);
    steps.add(RecipeStep(
      id: '',
      stepNumber: steps.length + 1,
      instruction: instruction,
    ));
    state = state.copyWith(
      recipe: recipe.copyWith(steps: steps),
      hasChanges: true,
    );
  }

  void removeStep(int index) {
    final recipe = state.recipe;
    if (recipe == null || index >= recipe.steps.length) return;
    final steps = List<RecipeStep>.from(recipe.steps);
    steps.removeAt(index);
    // Renumber
    final renumbered = steps.asMap().entries.map((e) {
      return RecipeStep(
        id: e.value.id,
        stepNumber: e.key + 1,
        instruction: e.value.instruction,
        durationMinutes: e.value.durationMinutes,
      );
    }).toList();
    state = state.copyWith(
      recipe: recipe.copyWith(steps: renumbered),
      hasChanges: true,
    );
  }

  void updateStepDuration(int index, int? duration) {
    final recipe = state.recipe;
    if (recipe == null || index >= recipe.steps.length) return;
    final steps = List<RecipeStep>.from(recipe.steps);
    steps[index] = steps[index].copyWith(durationMinutes: duration);
    state = state.copyWith(
      recipe: recipe.copyWith(steps: steps),
      hasChanges: true,
    );
  }

  void reorderIngredients(int oldIndex, int newIndex) {
    final recipe = state.recipe;
    if (recipe == null) return;
    final ingredients = List<RecipeIngredient>.from(recipe.ingredients);
    final item = ingredients.removeAt(oldIndex);
    ingredients.insert(newIndex, item);
    // Renumber sort_order
    final renumbered = ingredients.asMap().entries.map((e) {
      return RecipeIngredient(
        id: e.value.id,
        ingredientName: e.value.ingredientName,
        quantity: e.value.quantity,
        unit: e.value.unit,
        notes: e.value.notes,
        sortOrder: e.key,
      );
    }).toList();
    state = state.copyWith(
      recipe: recipe.copyWith(ingredients: renumbered),
      hasChanges: true,
    );
  }

  void updateIngredient(int index, RecipeIngredient updated) {
    final recipe = state.recipe;
    if (recipe == null || index >= recipe.ingredients.length) return;
    final ingredients = List<RecipeIngredient>.from(recipe.ingredients);
    ingredients[index] = updated;
    state = state.copyWith(
      recipe: recipe.copyWith(ingredients: ingredients),
      hasChanges: true,
    );
  }

  void addIngredient(RecipeIngredient ingredient) {
    final recipe = state.recipe;
    if (recipe == null) return;
    final ingredients = List<RecipeIngredient>.from(recipe.ingredients);
    ingredients.add(ingredient);
    state = state.copyWith(
      recipe: recipe.copyWith(ingredients: ingredients),
      hasChanges: true,
    );
  }

  void removeIngredient(int index) {
    final recipe = state.recipe;
    if (recipe == null || index >= recipe.ingredients.length) return;
    final ingredients = List<RecipeIngredient>.from(recipe.ingredients);
    ingredients.removeAt(index);
    // Renumber sort_order
    final renumbered = ingredients.asMap().entries.map((e) {
      return RecipeIngredient(
        id: e.value.id,
        ingredientName: e.value.ingredientName,
        quantity: e.value.quantity,
        unit: e.value.unit,
        notes: e.value.notes,
        sortOrder: e.key,
      );
    }).toList();
    state = state.copyWith(
      recipe: recipe.copyWith(ingredients: renumbered),
      hasChanges: true,
    );
  }

  Future<bool> saveChanges() async {
    final recipe = state.recipe;
    if (recipe == null) return false;

    state = state.copyWith(isSaving: true, error: null);

    try {
      // Update recipe fields
      await _repository.updateRecipe(recipe.id, {
        'title': recipe.title,
        'description': recipe.description,
        'servings': recipe.servings,
        'prep_time_min': recipe.prepTimeMin,
        'cook_time_min': recipe.cookTimeMin,
        'tags': recipe.tags,
      });

      // Update steps
      await _repository.updateRecipeSteps(recipe.id, recipe.steps);

      // Update ingredients
      await _repository.updateRecipeIngredients(recipe.id, recipe.ingredients);

      state = state.copyWith(isSaving: false, hasChanges: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

final recipeEditProvider =
    StateNotifierProvider.autoDispose<RecipeEditNotifier, RecipeEditState>(
        (ref) {
  return RecipeEditNotifier(ref.watch(recipeRepositoryProvider));
});
