import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/core/ocr/ocr_service.dart';
import '../../../shared/core/ocr/ocr_text_parser.dart';
import '../data/pantry_repository.dart';

/// State for photo-based pantry import.
class PhotoPantryImportState {
  const PhotoPantryImportState({
    this.status = PhotoPantryImportStatus.idle,
    this.items = const [],
    this.category = 'fridge',
    this.error,
  });

  final PhotoPantryImportStatus status;
  final List<SelectablePantryItem> items;
  final String category;
  final String? error;

  PhotoPantryImportState copyWith({
    PhotoPantryImportStatus? status,
    List<SelectablePantryItem>? items,
    String? category,
    String? error,
  }) {
    return PhotoPantryImportState(
      status: status ?? this.status,
      items: items ?? this.items,
      category: category ?? this.category,
      error: error,
    );
  }

  int get selectedCount => items.where((i) => i.isSelected).length;
}

enum PhotoPantryImportStatus { idle, processing, review, saving }

/// An item parsed from OCR with a selection toggle.
class SelectablePantryItem {
  const SelectablePantryItem({
    required this.name,
    this.quantity,
    this.unit,
    this.isSelected = true,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final bool isSelected;

  SelectablePantryItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    bool? isSelected,
  }) {
    return SelectablePantryItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Notifier managing the photo pantry import flow.
class PhotoPantryImportNotifier extends StateNotifier<PhotoPantryImportState> {
  PhotoPantryImportNotifier(this._ocrService, this._repository)
      : super(const PhotoPantryImportState());

  final OcrService _ocrService;
  final PantryRepository _repository;

  /// Process an image from camera or gallery.
  Future<void> processImage(String imagePath) async {
    state = state.copyWith(status: PhotoPantryImportStatus.processing, error: null);

    try {
      final lines = await _ocrService.recognizeLines(imagePath);
      if (lines.isEmpty) {
        state = state.copyWith(
          status: PhotoPantryImportStatus.idle,
          error: 'No text detected. Please try a clearer photo.',
        );
        return;
      }

      final parsed = OcrTextParser.parseAsItemList(lines);
      if (parsed.isEmpty) {
        state = state.copyWith(
          status: PhotoPantryImportStatus.idle,
          error: 'No items could be identified. Please try again.',
        );
        return;
      }

      final selectableItems = parsed
          .map((p) => SelectablePantryItem(
                name: p.name,
                quantity: p.quantity,
                unit: p.unit,
              ))
          .toList();

      state = state.copyWith(
        status: PhotoPantryImportStatus.review,
        items: selectableItems,
      );
    } catch (e) {
      state = state.copyWith(
        status: PhotoPantryImportStatus.idle,
        error: 'OCR failed: ${e.toString()}',
      );
    }
  }

  /// Toggle selection of an item at [index].
  void toggleItem(int index) {
    final items = List<SelectablePantryItem>.from(state.items);
    items[index] = items[index].copyWith(isSelected: !items[index].isSelected);
    state = state.copyWith(items: items);
  }

  /// Update the name of an item at [index].
  void updateItemName(int index, String name) {
    final items = List<SelectablePantryItem>.from(state.items);
    items[index] = items[index].copyWith(name: name);
    state = state.copyWith(items: items);
  }

  /// Remove an item at [index].
  void removeItem(int index) {
    final items = List<SelectablePantryItem>.from(state.items);
    items.removeAt(index);
    state = state.copyWith(items: items);
  }

  /// Set the target pantry category.
  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  /// Save selected items to the pantry.
  Future<int> saveSelectedItems(String profileId) async {
    final selected = state.items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return 0;

    state = state.copyWith(status: PhotoPantryImportStatus.saving);

    try {
      for (final item in selected) {
        await _repository.addItem(
          profileId: profileId,
          name: item.name,
          category: state.category,
          quantity: item.quantity,
          unit: item.unit,
        );
      }
      state = const PhotoPantryImportState();
      return selected.length;
    } catch (e) {
      state = state.copyWith(
        status: PhotoPantryImportStatus.review,
        error: 'Failed to save items: ${e.toString()}',
      );
      return 0;
    }
  }
}

/// Provider for [PhotoPantryImportNotifier].
final photoPantryImportProvider =
    StateNotifierProvider.autoDispose<PhotoPantryImportNotifier, PhotoPantryImportState>((ref) {
  return PhotoPantryImportNotifier(
    ref.watch(ocrServiceProvider),
    ref.watch(pantryRepositoryProvider),
  );
});
