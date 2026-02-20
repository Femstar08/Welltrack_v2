import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/core/ocr/ocr_service.dart';
import '../../../shared/core/ocr/ocr_text_parser.dart';
import '../data/aisle_mapper.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_item_entity.dart';

/// State for photo-based shopping list import.
class PhotoShoppingImportState {
  const PhotoShoppingImportState({
    this.status = PhotoShoppingImportStatus.idle,
    this.items = const [],
    this.error,
  });

  final PhotoShoppingImportStatus status;
  final List<SelectableShoppingItem> items;
  final String? error;

  PhotoShoppingImportState copyWith({
    PhotoShoppingImportStatus? status,
    List<SelectableShoppingItem>? items,
    String? error,
  }) {
    return PhotoShoppingImportState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
    );
  }

  int get selectedCount => items.where((i) => i.isSelected).length;
}

enum PhotoShoppingImportStatus { idle, processing, review, saving }

/// A shopping item parsed from OCR with selection toggle and auto-aisle.
class SelectableShoppingItem {
  const SelectableShoppingItem({
    required this.name,
    this.quantity,
    this.unit,
    required this.aisle,
    this.isSelected = true,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final String aisle;
  final bool isSelected;

  SelectableShoppingItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? aisle,
    bool? isSelected,
  }) {
    return SelectableShoppingItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      aisle: aisle ?? this.aisle,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Notifier managing the photo shopping list import flow.
class PhotoShoppingImportNotifier extends StateNotifier<PhotoShoppingImportState> {
  PhotoShoppingImportNotifier(this._ocrService, this._repository)
      : super(const PhotoShoppingImportState());

  final OcrService _ocrService;
  final ShoppingListRepository _repository;

  /// Process an image from camera or gallery.
  Future<void> processImage(String imagePath) async {
    state = state.copyWith(status: PhotoShoppingImportStatus.processing, error: null);

    try {
      final lines = await _ocrService.recognizeLines(imagePath);
      if (lines.isEmpty) {
        state = state.copyWith(
          status: PhotoShoppingImportStatus.idle,
          error: 'No text detected. Please try a clearer photo.',
        );
        return;
      }

      final parsed = OcrTextParser.parseAsItemList(lines);
      if (parsed.isEmpty) {
        state = state.copyWith(
          status: PhotoShoppingImportStatus.idle,
          error: 'No items could be identified. Please try again.',
        );
        return;
      }

      final selectableItems = parsed
          .map((p) => SelectableShoppingItem(
                name: p.name,
                quantity: p.quantity,
                unit: p.unit,
                aisle: AisleMapper.getAisle(p.name),
              ))
          .toList();

      state = state.copyWith(
        status: PhotoShoppingImportStatus.review,
        items: selectableItems,
      );
    } catch (e) {
      state = state.copyWith(
        status: PhotoShoppingImportStatus.idle,
        error: 'OCR failed: ${e.toString()}',
      );
    }
  }

  /// Toggle selection of an item at [index].
  void toggleItem(int index) {
    final items = List<SelectableShoppingItem>.from(state.items);
    items[index] = items[index].copyWith(isSelected: !items[index].isSelected);
    state = state.copyWith(items: items);
  }

  /// Update the name of an item at [index].
  void updateItemName(int index, String name) {
    final items = List<SelectableShoppingItem>.from(state.items);
    items[index] = items[index].copyWith(
      name: name,
      aisle: AisleMapper.getAisle(name),
    );
    state = state.copyWith(items: items);
  }

  /// Remove an item at [index].
  void removeItem(int index) {
    final items = List<SelectableShoppingItem>.from(state.items);
    items.removeAt(index);
    state = state.copyWith(items: items);
  }

  /// Save selected items to the shopping list.
  ///
  /// Returns the number of items saved.
  Future<int> saveSelectedItems(String listId) async {
    final selected = state.items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return 0;

    state = state.copyWith(status: PhotoShoppingImportStatus.saving);

    try {
      final now = DateTime.now();
      final entities = selected.asMap().entries.map((entry) {
        final item = entry.value;
        return ShoppingListItemEntity(
          id: '',
          shoppingListId: listId,
          ingredientName: item.name,
          quantity: item.quantity,
          unit: item.unit,
          aisle: item.aisle,
          isChecked: false,
          sortOrder: entry.key,
          createdAt: now,
        );
      }).toList();

      await _repository.addItems(listId, entities);
      state = const PhotoShoppingImportState();
      return entities.length;
    } catch (e) {
      state = state.copyWith(
        status: PhotoShoppingImportStatus.review,
        error: 'Failed to save items: ${e.toString()}',
      );
      return 0;
    }
  }
}

/// Provider for [PhotoShoppingImportNotifier].
final photoShoppingImportProvider =
    StateNotifierProvider.autoDispose<PhotoShoppingImportNotifier, PhotoShoppingImportState>((ref) {
  return PhotoShoppingImportNotifier(
    ref.watch(ocrServiceProvider),
    ref.watch(shoppingListRepositoryProvider),
  );
});
