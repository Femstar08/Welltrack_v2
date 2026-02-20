import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/product_lookup_service.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_item_entity.dart';
import '../../pantry/data/pantry_repository.dart';

class BarcodeScanState {
  const BarcodeScanState({
    this.scannedBarcode,
    this.productInfo,
    this.matchedItemIndex,
    this.selectedCategory = 'cupboard',
    this.quantity = 1,
    this.manualName,
    this.isLookingUp = false,
    this.isConfirming = false,
    this.error,
    this.successMessage,
  });

  final String? scannedBarcode;
  final ProductInfo? productInfo;
  final int? matchedItemIndex;
  final String selectedCategory;
  final int quantity;
  final String? manualName;
  final bool isLookingUp;
  final bool isConfirming;
  final String? error;
  final String? successMessage;

  String get itemName =>
      manualName ?? productInfo?.displayName ?? scannedBarcode ?? '';

  BarcodeScanState copyWith({
    String? scannedBarcode,
    ProductInfo? productInfo,
    int? matchedItemIndex,
    String? selectedCategory,
    int? quantity,
    String? manualName,
    bool? isLookingUp,
    bool? isConfirming,
    String? error,
    String? successMessage,
    bool clearBarcode = false,
    bool clearProduct = false,
    bool clearMatch = false,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearManualName = false,
  }) {
    return BarcodeScanState(
      scannedBarcode:
          clearBarcode ? null : (scannedBarcode ?? this.scannedBarcode),
      productInfo: clearProduct ? null : (productInfo ?? this.productInfo),
      matchedItemIndex:
          clearMatch ? null : (matchedItemIndex ?? this.matchedItemIndex),
      selectedCategory: selectedCategory ?? this.selectedCategory,
      quantity: quantity ?? this.quantity,
      manualName:
          clearManualName ? null : (manualName ?? this.manualName),
      isLookingUp: isLookingUp ?? this.isLookingUp,
      isConfirming: isConfirming ?? this.isConfirming,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class BarcodeScanNotifier extends StateNotifier<BarcodeScanState> {
  BarcodeScanNotifier(
    this._lookupService,
    this._shoppingRepo,
    this._pantryRepo,
    this._shoppingListId,
    this._shoppingItems,
  ) : super(const BarcodeScanState());

  final ProductLookupService _lookupService;
  final ShoppingListRepository _shoppingRepo;
  final PantryRepository _pantryRepo;
  final String _shoppingListId;
  final List<ShoppingListItemEntity> _shoppingItems;

  Future<void> onBarcodeScanned(String barcode) async {
    if (state.isLookingUp || state.isConfirming) return;
    if (barcode == state.scannedBarcode) return;

    state = state.copyWith(
      scannedBarcode: barcode,
      isLookingUp: true,
      clearProduct: true,
      clearMatch: true,
      clearError: true,
      clearSuccess: true,
      clearManualName: true,
      quantity: 1,
      selectedCategory: 'cupboard',
    );

    try {
      final product = await _lookupService.lookupBarcode(barcode);
      int? matchIndex;

      if (product?.productName != null) {
        matchIndex = _fuzzyMatch(product!.productName!);
      }

      state = state.copyWith(
        productInfo: product,
        matchedItemIndex: matchIndex,
        isLookingUp: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLookingUp: false,
        error: 'Lookup failed: $e',
      );
    }
  }

  int? _fuzzyMatch(String productName) {
    final productWords = productName.toLowerCase().split(RegExp(r'\s+'));
    int bestScore = 0;
    int? bestIndex;

    for (var i = 0; i < _shoppingItems.length; i++) {
      final item = _shoppingItems[i];
      if (item.isChecked) continue;

      final itemWords =
          item.ingredientName.toLowerCase().split(RegExp(r'\s+'));
      int score = 0;

      for (final pw in productWords) {
        for (final iw in itemWords) {
          if (pw == iw || pw.contains(iw) || iw.contains(pw)) {
            score++;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestScore >= 1 ? bestIndex : null;
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setQuantity(int quantity) {
    state = state.copyWith(quantity: quantity.clamp(1, 99));
  }

  void setManualName(String name) {
    state = state.copyWith(manualName: name.isEmpty ? null : name);
  }

  Future<void> confirm({required String profileId}) async {
    state = state.copyWith(isConfirming: true, clearError: true);

    try {
      final name = state.itemName;
      if (name.isEmpty) {
        state = state.copyWith(
          isConfirming: false,
          error: 'Please enter a product name',
        );
        return;
      }

      // Check off matched shopping list item
      if (state.matchedItemIndex != null) {
        final item = _shoppingItems[state.matchedItemIndex!];
        await _shoppingRepo.toggleItem(item.id, true);
      }

      // Add to pantry
      await _pantryRepo.addItem(
        profileId: profileId,
        name: name,
        category: state.selectedCategory,
        quantity: state.quantity.toDouble(),
        barcode: state.scannedBarcode,
      );

      state = state.copyWith(
        isConfirming: false,
        successMessage: '$name added to pantry',
      );
    } catch (e) {
      state = state.copyWith(
        isConfirming: false,
        error: 'Failed: $e',
      );
    }
  }

  void reset() {
    state = const BarcodeScanState();
  }
}

final barcodeScanProvider = StateNotifierProvider.autoDispose
    .family<BarcodeScanNotifier, BarcodeScanState, String>(
  (ref, shoppingListId) {
    return BarcodeScanNotifier(
      ref.watch(productLookupServiceProvider),
      ref.watch(shoppingListRepositoryProvider),
      ref.watch(pantryRepositoryProvider),
      shoppingListId,
      [], // Items will be provided by screen
    );
  },
);

// Provider that accepts items parameter
final barcodeScanWithItemsProvider = StateNotifierProvider.autoDispose
    .family<BarcodeScanNotifier, BarcodeScanState,
        ({String listId, List<ShoppingListItemEntity> items})>(
  (ref, params) {
    return BarcodeScanNotifier(
      ref.watch(productLookupServiceProvider),
      ref.watch(shoppingListRepositoryProvider),
      ref.watch(pantryRepositoryProvider),
      params.listId,
      params.items,
    );
  },
);
