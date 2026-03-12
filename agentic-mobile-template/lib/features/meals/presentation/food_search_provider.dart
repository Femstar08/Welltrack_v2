import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/food_database_service.dart';

class FoodSearchState {
  const FoodSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<FoodItem> results;
  final bool isLoading;
  final String? error;

  FoodSearchState copyWith({
    String? query,
    List<FoodItem>? results,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FoodSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FoodSearchNotifier extends StateNotifier<FoodSearchState> {
  FoodSearchNotifier(this._service) : super(const FoodSearchState());

  final FoodDatabaseService _service;
  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      state = const FoodSearchState();
      return;
    }

    state = state.copyWith(query: query, isLoading: true, clearError: true);

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    try {
      final results = await _service.searchByKeyword(query);
      if (!mounted) return;
      state = state.copyWith(results: results, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed. Please try again.',
      );
    }
  }

  Future<FoodItem?> lookupBarcode(String barcode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final item = await _service.searchByBarcode(barcode);
      if (!mounted) return null;
      state = state.copyWith(isLoading: false);
      return item;
    } catch (_) {
      if (!mounted) return null;
      state = state.copyWith(
        isLoading: false,
        error: 'Barcode lookup failed.',
      );
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final foodSearchProvider =
    StateNotifierProvider.autoDispose<FoodSearchNotifier, FoodSearchState>(
  (ref) => FoodSearchNotifier(ref.watch(foodDatabaseServiceProvider)),
);
