import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe_entity.dart';

class SavedRecipesState {
  const SavedRecipesState({
    this.recipes = const [],
    this.filteredRecipes = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.activeFilter = 'All',
  });

  final List<RecipeEntity> recipes;
  final List<RecipeEntity> filteredRecipes;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String activeFilter;

  SavedRecipesState copyWith({
    List<RecipeEntity>? recipes,
    List<RecipeEntity>? filteredRecipes,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? activeFilter,
  }) {
    return SavedRecipesState(
      recipes: recipes ?? this.recipes,
      filteredRecipes: filteredRecipes ?? this.filteredRecipes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  Set<String> get allTags {
    final tags = <String>{};
    for (final recipe in recipes) {
      tags.addAll(recipe.tags);
    }
    return tags;
  }
}

class SavedRecipesNotifier extends StateNotifier<SavedRecipesState> {
  SavedRecipesNotifier(this._repository, this._profileId)
      : super(const SavedRecipesState());

  final RecipeRepository _repository;
  final String _profileId;

  Future<void> loadRecipes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final recipes = await _repository.getRecipes(_profileId);
      state = state.copyWith(
        recipes: recipes,
        filteredRecipes: recipes,
        isLoading: false,
        searchQuery: '',
        activeFilter: 'All',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void searchRecipes(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void filterByTag(String tag) {
    state = state.copyWith(activeFilter: tag);
    _applyFilters();
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      activeFilter: 'All',
      filteredRecipes: state.recipes,
    );
  }

  void _applyFilters() {
    var filtered = state.recipes;

    // Apply search query
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(query) ||
            (r.description?.toLowerCase().contains(query) ?? false) ||
            r.tags.any((t) => t.toLowerCase().contains(query));
      }).toList();
    }

    // Apply tag filter
    if (state.activeFilter != 'All') {
      if (state.activeFilter == 'Favorites') {
        filtered = filtered.where((r) => r.isFavorite).toList();
      } else {
        filtered = filtered
            .where((r) => r.tags.contains(state.activeFilter))
            .toList();
      }
    }

    state = state.copyWith(filteredRecipes: filtered);
  }
}

final savedRecipesProvider = StateNotifierProvider.family<
    SavedRecipesNotifier, SavedRecipesState, String>((ref, profileId) {
  return SavedRecipesNotifier(
    ref.watch(recipeRepositoryProvider),
    profileId,
  );
});
