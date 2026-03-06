import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_entity.dart';

class BatchCookGroup {
  const BatchCookGroup({
    required this.name,
    required this.meals,
    required this.estimatedPrepMinutes,
    required this.estimatedCookMinutes,
    required this.storageInstructions,
    required this.servings,
    this.isCompleted = false,
  });

  final String name;
  final List<MealPlanItemEntity> meals;
  final int estimatedPrepMinutes;
  final int estimatedCookMinutes;
  final String storageInstructions;
  final int servings;
  final bool isCompleted;

  BatchCookGroup copyWith({bool? isCompleted}) {
    return BatchCookGroup(
      name: name,
      meals: meals,
      estimatedPrepMinutes: estimatedPrepMinutes,
      estimatedCookMinutes: estimatedCookMinutes,
      storageInstructions: storageInstructions,
      servings: servings,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class PrepShoppingItem {
  const PrepShoppingItem({
    required this.name,
    required this.category,
    required this.count,
    this.isCrossedOff = false,
  });

  final String name;
  final String category;
  final int count;
  final bool isCrossedOff;

  PrepShoppingItem copyWith({bool? isCrossedOff}) {
    return PrepShoppingItem(
      name: name,
      category: category,
      count: count,
      isCrossedOff: isCrossedOff ?? this.isCrossedOff,
    );
  }
}

class MealPrepState {
  const MealPrepState({
    required this.weekStart,
    this.weekPlans = const [],
    this.batchGroups = const [],
    this.shoppingItems = const [],
    this.isLoading = false,
    this.error,
  });

  final DateTime weekStart;
  final List<MealPlanEntity> weekPlans;
  final List<BatchCookGroup> batchGroups;
  final List<PrepShoppingItem> shoppingItems;
  final bool isLoading;
  final String? error;

  MealPrepState copyWith({
    DateTime? weekStart,
    List<MealPlanEntity>? weekPlans,
    List<BatchCookGroup>? batchGroups,
    List<PrepShoppingItem>? shoppingItems,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MealPrepState(
      weekStart: weekStart ?? this.weekStart,
      weekPlans: weekPlans ?? this.weekPlans,
      batchGroups: batchGroups ?? this.batchGroups,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get totalMealsPlanned =>
      weekPlans.fold(0, (sum, plan) => sum + plan.items.length);

  int get batchCookableMeals =>
      batchGroups.fold(0, (sum, g) => sum + g.meals.length);

  int get daysWithPlans => weekPlans.length;
}

class MealPrepNotifier extends StateNotifier<MealPrepState> {
  MealPrepNotifier(this._repository, this._profileId)
      : super(MealPrepState(weekStart: _mondayOf(DateTime.now())));

  final MealPlanRepository _repository;
  final String _profileId;

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  Future<void> loadWeek(DateTime weekStart) async {
    state = state.copyWith(
      weekStart: weekStart,
      isLoading: true,
      clearError: true,
    );

    try {
      final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final sunday = monday.add(const Duration(days: 6));
      final plans = await _repository.getMealPlans(_profileId, monday, sunday);
      final groups = _groupForBatchCooking(plans);
      final shopping = _buildShoppingItems(plans);

      state = state.copyWith(
        weekPlans: plans,
        batchGroups: groups,
        shoppingItems: shopping,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load week: $e',
      );
    }
  }

  List<BatchCookGroup> _groupForBatchCooking(List<MealPlanEntity> plans) {
    final allItems = <MealPlanItemEntity>[];
    for (final plan in plans) {
      allItems.addAll(plan.items);
    }

    // Group by normalized (lowercase, trimmed) name
    final grouped = <String, List<MealPlanItemEntity>>{};
    for (final item in allItems) {
      final key = item.name.trim().toLowerCase();
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Only groups with 2+ occurrences are batch-cookable
    final groups = <BatchCookGroup>[];
    for (final entry in grouped.entries) {
      if (entry.value.length >= 2) {
        final first = entry.value.first;
        final isProteinHeavy = (first.proteinG ?? 0) >= 20;
        groups.add(BatchCookGroup(
          name: _capitalize(first.name),
          meals: entry.value,
          estimatedPrepMinutes: isProteinHeavy ? 30 : 15,
          estimatedCookMinutes: isProteinHeavy ? 45 : 20,
          storageInstructions:
              'Refrigerate in airtight containers for up to 4 days',
          servings: entry.value.length,
        ));
      }
    }

    return groups;
  }

  List<PrepShoppingItem> _buildShoppingItems(List<MealPlanEntity> plans) {
    final counters = <String, int>{};
    final categoryMap = <String, String>{};

    for (final plan in plans) {
      for (final item in plan.items) {
        final key = item.name.trim().toLowerCase();
        counters[key] = (counters[key] ?? 0) + 1;
        categoryMap[key] = _categorize(item);
      }
    }

    final items = counters.entries
        .map((e) => PrepShoppingItem(
              name: _capitalize(e.key),
              category: categoryMap[e.key] ?? 'Other',
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));

    return items;
  }

  String _capitalize(String text) {
    return text
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _categorize(MealPlanItemEntity item) {
    final protein = item.proteinG ?? 0;
    final name = item.name.toLowerCase();
    if (protein >= 20 ||
        name.contains('chicken') ||
        name.contains('beef') ||
        name.contains('fish') ||
        name.contains('salmon') ||
        name.contains('tuna') ||
        name.contains('egg') ||
        name.contains('turkey') ||
        name.contains('steak')) {
      return 'Proteins';
    }
    if (item.mealType == 'snack' ||
        name.contains('yogurt') ||
        name.contains('shake') ||
        name.contains('bar') ||
        name.contains('fruit')) {
      return 'Snacks';
    }
    return 'Sides & Grains';
  }

  void toggleGroupCompleted(int index) {
    final groups = List<BatchCookGroup>.from(state.batchGroups);
    if (index < 0 || index >= groups.length) return;
    groups[index] = groups[index].copyWith(isCompleted: !groups[index].isCompleted);
    state = state.copyWith(batchGroups: groups);
  }

  void toggleShoppingItem(int index) {
    final items = List<PrepShoppingItem>.from(state.shoppingItems);
    if (index < 0 || index >= items.length) return;
    items[index] = items[index].copyWith(isCrossedOff: !items[index].isCrossedOff);
    state = state.copyWith(shoppingItems: items);
  }

  Future<void> changeWeek(int delta) async {
    final newStart = state.weekStart.add(Duration(days: delta * 7));
    await loadWeek(newStart);
  }
}

final mealPrepProvider =
    StateNotifierProvider.family<MealPrepNotifier, MealPrepState, String>(
  (ref, profileId) {
    final repository = ref.watch(mealPlanRepositoryProvider);
    return MealPrepNotifier(repository, profileId);
  },
);
