import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_entity.dart';
import '../domain/shopping_list_item_entity.dart';

class ShoppingListsState {
  const ShoppingListsState({
    this.lists = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ShoppingListEntity> lists;
  final bool isLoading;
  final String? error;

  ShoppingListsState copyWith({
    List<ShoppingListEntity>? lists,
    bool? isLoading,
    String? error,
  }) {
    return ShoppingListsState(
      lists: lists ?? this.lists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ShoppingListsNotifier extends StateNotifier<ShoppingListsState> {
  ShoppingListsNotifier(this._repository, this._profileId)
      : super(const ShoppingListsState());

  final ShoppingListRepository _repository;
  final String _profileId;

  Future<void> loadLists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lists = await _repository.getLists(_profileId);
      state = state.copyWith(lists: lists, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<ShoppingListEntity?> createList({
    required String name,
    required List<ShoppingListItemEntity> items,
  }) async {
    try {
      final list = await _repository.createList(
        profileId: _profileId,
        name: name,
        items: items,
      );
      await loadLists();
      return list;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<ShoppingListEntity?> createFromRecipes({
    required String name,
    required List<String> recipeIds,
  }) async {
    try {
      final list = await _repository.createListFromRecipes(
        profileId: _profileId,
        name: name,
        recipeIds: recipeIds,
      );
      await loadLists();
      return list;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      await _repository.deleteList(listId);
      state = state.copyWith(
        lists: state.lists.where((l) => l.id != listId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> archiveList(String listId) async {
    try {
      await _repository.updateListStatus(listId, 'archived');
      state = state.copyWith(
        lists: state.lists.where((l) => l.id != listId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadLists();
  }
}

final shoppingListsProvider = StateNotifierProvider.family<
    ShoppingListsNotifier, ShoppingListsState, String>((ref, profileId) {
  return ShoppingListsNotifier(
    ref.watch(shoppingListRepositoryProvider),
    profileId,
  );
});

final shoppingListDetailProvider =
    FutureProvider.family<ShoppingListEntity, String>((ref, listId) {
  return ref.watch(shoppingListRepositoryProvider).getList(listId);
});
