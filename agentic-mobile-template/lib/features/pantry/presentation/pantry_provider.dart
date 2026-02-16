import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/pantry/data/pantry_repository.dart';
import 'package:welltrack/features/pantry/domain/pantry_item_entity.dart';

final pantryItemsProvider = StateNotifierProvider.family<
    PantryNotifier,
    AsyncValue<List<PantryItemEntity>>,
    String>((ref, profileId) {
  return PantryNotifier(ref.watch(pantryRepositoryProvider), profileId);
});

final pantryItemsByCategoryProvider = StateNotifierProvider.family<
    PantryByCategoryNotifier,
    AsyncValue<List<PantryItemEntity>>,
    PantryCategoryParams>((ref, params) {
  return PantryByCategoryNotifier(
    ref.watch(pantryRepositoryProvider),
    params.profileId,
    params.category,
  );
});

class PantryCategoryParams {
  final String profileId;
  final String category;

  PantryCategoryParams({
    required this.profileId,
    required this.category,
  });
}

class PantryNotifier extends StateNotifier<AsyncValue<List<PantryItemEntity>>> {
  final PantryRepository _repository;
  final String _profileId;

  PantryNotifier(this._repository, this._profileId)
      : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems({String? category}) async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getItems(_profileId, category: category);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> searchItems(String query) async {
    if (query.isEmpty) {
      await loadItems();
      return;
    }

    state = const AsyncValue.loading();
    try {
      final items = await _repository.searchItems(_profileId, query);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addItem({
    required String name,
    required String category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? barcode,
    double? cost,
    String? notes,
  }) async {
    try {
      await _repository.addItem(
        profileId: _profileId,
        name: name,
        category: category,
        quantity: quantity,
        unit: unit,
        expiryDate: expiryDate,
        barcode: barcode,
        cost: cost,
        notes: notes,
      );
      await loadItems();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> fields) async {
    try {
      await _repository.updateItem(itemId, fields);
      await loadItems();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _repository.deleteItem(itemId);
      await loadItems();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAsUnavailable(String itemId) async {
    try {
      await _repository.markAsUnavailable(itemId);
      await loadItems();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void refresh() {
    loadItems();
  }
}

class PantryByCategoryNotifier extends StateNotifier<AsyncValue<List<PantryItemEntity>>> {
  final PantryRepository _repository;
  final String _profileId;
  final String _category;

  PantryByCategoryNotifier(this._repository, this._profileId, this._category)
      : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getItemsByCategory(_profileId, _category);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void refresh() {
    loadItems();
  }
}
