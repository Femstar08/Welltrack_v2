import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_entity.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import '../../shopping/data/shopping_list_repository.dart';
import '../../shopping/domain/shopping_list_item_entity.dart';

class GeneratedShoppingItem {
  const GeneratedShoppingItem({
    required this.ingredientName,
    this.quantity,
    this.unit,
    this.aisle = 'Other',
    this.notes,
    this.isIncluded = true,
  });

  final String ingredientName;
  final double? quantity;
  final String? unit;
  final String aisle;
  final String? notes;
  final bool isIncluded;

  GeneratedShoppingItem copyWith({bool? isIncluded}) {
    return GeneratedShoppingItem(
      ingredientName: ingredientName,
      quantity: quantity,
      unit: unit,
      aisle: aisle,
      notes: notes,
      isIncluded: isIncluded ?? this.isIncluded,
    );
  }
}

class DateWithPlan {
  const DateWithPlan({required this.date, required this.hasPlan, this.plan});
  final DateTime date;
  final bool hasPlan;
  final MealPlanEntity? plan;
}

class ShoppingListGeneratorState {
  const ShoppingListGeneratorState({
    this.availableDates = const [],
    this.selectedDates = const {},
    this.generatedItems = const [],
    this.listName = '',
    this.isLoadingDates = false,
    this.isGenerating = false,
    this.isCreating = false,
    this.error,
    this.createdListId,
  });

  final List<DateWithPlan> availableDates;
  final Set<DateTime> selectedDates;
  final List<GeneratedShoppingItem> generatedItems;
  final String listName;
  final bool isLoadingDates;
  final bool isGenerating;
  final bool isCreating;
  final String? error;
  final String? createdListId;

  int get selectedCount => selectedDates.length;
  int get includedItemCount => generatedItems.where((i) => i.isIncluded).length;

  ShoppingListGeneratorState copyWith({
    List<DateWithPlan>? availableDates,
    Set<DateTime>? selectedDates,
    List<GeneratedShoppingItem>? generatedItems,
    String? listName,
    bool? isLoadingDates,
    bool? isGenerating,
    bool? isCreating,
    String? error,
    String? createdListId,
    bool clearError = false,
    bool clearCreatedListId = false,
  }) {
    return ShoppingListGeneratorState(
      availableDates: availableDates ?? this.availableDates,
      selectedDates: selectedDates ?? this.selectedDates,
      generatedItems: generatedItems ?? this.generatedItems,
      listName: listName ?? this.listName,
      isLoadingDates: isLoadingDates ?? this.isLoadingDates,
      isGenerating: isGenerating ?? this.isGenerating,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      createdListId: clearCreatedListId
          ? null
          : (createdListId ?? this.createdListId),
    );
  }
}

class ShoppingListGeneratorNotifier
    extends StateNotifier<ShoppingListGeneratorState> {
  ShoppingListGeneratorNotifier(
    this._mealPlanRepo,
    this._shoppingRepo,
    this._aiService,
    this._profileId,
  ) : super(const ShoppingListGeneratorState());

  final MealPlanRepository _mealPlanRepo;
  final ShoppingListRepository _shoppingRepo;
  final AiOrchestratorService _aiService;
  final String _profileId;

  Future<void> loadAvailableDates() async {
    state = state.copyWith(isLoadingDates: true, clearError: true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = today.add(const Duration(days: 13));

      final plans = await _mealPlanRepo.getMealPlans(
        _profileId,
        today.subtract(const Duration(days: 7)),
        endDate,
      );

      final planMap = <String, MealPlanEntity>{};
      for (final plan in plans) {
        final key =
            '${plan.planDate.year}-${plan.planDate.month}-${plan.planDate.day}';
        planMap[key] = plan;
      }

      final dates = <DateWithPlan>[];
      for (var i = -7; i < 14; i++) {
        final date = today.add(Duration(days: i));
        final key = '${date.year}-${date.month}-${date.day}';
        final plan = planMap[key];
        dates.add(DateWithPlan(
          date: date,
          hasPlan: plan != null,
          plan: plan,
        ));
      }

      state = state.copyWith(
        availableDates: dates,
        isLoadingDates: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDates: false,
        error: 'Failed to load dates: $e',
      );
    }
  }

  void toggleDate(DateTime date) {
    final selected = Set<DateTime>.from(state.selectedDates);
    final normalized = DateTime(date.year, date.month, date.day);
    if (selected.contains(normalized)) {
      selected.remove(normalized);
    } else {
      selected.add(normalized);
    }
    state = state.copyWith(selectedDates: selected);
  }

  void setListName(String name) {
    state = state.copyWith(listName: name);
  }

  void toggleItem(int index) {
    final items = List<GeneratedShoppingItem>.from(state.generatedItems);
    items[index] = items[index].copyWith(isIncluded: !items[index].isIncluded);
    state = state.copyWith(generatedItems: items);
  }

  void removeItem(int index) {
    final items = List<GeneratedShoppingItem>.from(state.generatedItems);
    items.removeAt(index);
    state = state.copyWith(generatedItems: items);
  }

  Future<void> generateShoppingList({required String userId}) async {
    if (state.selectedDates.isEmpty) return;

    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      // Gather meal plans for selected dates
      final selectedPlans = <MealPlanEntity>[];
      for (final dateInfo in state.availableDates) {
        final normalized = DateTime(
          dateInfo.date.year,
          dateInfo.date.month,
          dateInfo.date.day,
        );
        if (state.selectedDates.contains(normalized) && dateInfo.plan != null) {
          selectedPlans.add(dateInfo.plan!);
        }
      }

      if (selectedPlans.isEmpty) {
        state = state.copyWith(
          isGenerating: false,
          error: 'No meal plans found for selected dates',
        );
        return;
      }

      // Build context for AI
      final mealSummaries = selectedPlans.map((plan) {
        final dateStr =
            '${plan.planDate.year}-${plan.planDate.month.toString().padLeft(2, '0')}-${plan.planDate.day.toString().padLeft(2, '0')}';
        final meals = plan.items.map((item) =>
            '${item.mealType}: ${item.name}${item.description != null ? ' - ${item.description}' : ''}');
        return '$dateStr (${plan.dayType}):\n${meals.join('\n')}';
      }).join('\n\n');

      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_shopping_list',
        message:
            'Generate a consolidated shopping list from these meal plans:\n\n$mealSummaries',
        contextOverride: {
          'meal_plan_count': selectedPlans.length,
          'date_range':
              '${selectedPlans.first.planDate.toIso8601String()} to ${selectedPlans.last.planDate.toIso8601String()}',
        },
      );

      // Parse response
      final items = _parseShoppingItems(response.assistantMessage);

      // Generate default name
      final dateRange = state.selectedDates.toList()..sort();
      final startStr = _formatShortDate(dateRange.first);
      final endStr = _formatShortDate(dateRange.last);
      final defaultName = dateRange.length == 1
          ? 'Groceries $startStr'
          : 'Groceries $startStr - $endStr';

      state = state.copyWith(
        generatedItems: items,
        listName: defaultName,
        isGenerating: false,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to generate: $e',
      );
    }
  }

  Future<void> createShoppingList() async {
    if (state.generatedItems.isEmpty || state.listName.isEmpty) return;

    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final now = DateTime.now();
      final includedItems = state.generatedItems
          .where((i) => i.isIncluded)
          .toList();

      final itemEntities = includedItems.asMap().entries.map((entry) {
        final item = entry.value;
        return ShoppingListItemEntity(
          id: '',
          shoppingListId: '',
          ingredientName: item.ingredientName,
          quantity: item.quantity,
          unit: item.unit,
          aisle: item.aisle,
          notes: item.notes,
          sortOrder: entry.key,
          createdAt: now,
        );
      }).toList();

      final list = await _shoppingRepo.createList(
        profileId: _profileId,
        name: state.listName,
        items: itemEntities,
      );

      state = state.copyWith(
        isCreating: false,
        createdListId: list.id,
      );
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create list: $e',
      );
    }
  }

  List<GeneratedShoppingItem> _parseShoppingItems(String message) {
    // Try fenced json block
    final fencedRegex = RegExp(r'```json\n([\s\S]*?)\n```');
    final fencedMatch = fencedRegex.firstMatch(message);
    String? jsonStr;

    if (fencedMatch != null) {
      jsonStr = fencedMatch.group(1);
    } else {
      // Try raw JSON
      final jsonStart = message.indexOf('{');
      final jsonEnd = message.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        jsonStr = message.substring(jsonStart, jsonEnd + 1);
      }
    }

    if (jsonStr == null) return [];

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      return items.map((item) {
        final m = item as Map<String, dynamic>;
        return GeneratedShoppingItem(
          ingredientName: m['ingredient_name'] as String? ?? 'Unknown',
          quantity: m['quantity'] != null
              ? (m['quantity'] as num).toDouble()
              : null,
          unit: m['unit'] as String?,
          aisle: m['aisle'] as String? ?? 'Other',
          notes: m['notes'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

final shoppingListGeneratorProvider = StateNotifierProvider.family<
    ShoppingListGeneratorNotifier, ShoppingListGeneratorState, String>(
  (ref, profileId) {
    return ShoppingListGeneratorNotifier(
      ref.watch(mealPlanRepositoryProvider),
      ref.watch(shoppingListRepositoryProvider),
      ref.watch(aiOrchestratorServiceProvider),
      profileId,
    );
  },
);
