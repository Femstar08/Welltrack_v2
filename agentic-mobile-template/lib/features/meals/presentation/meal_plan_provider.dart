import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/macro_calculator.dart';
import '../data/meal_plan_repository.dart';
import '../data/custom_macro_target_repository.dart';
import '../domain/meal_plan_entity.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';

class MealPlanState {
  const MealPlanState({
    this.plan,
    this.macroTargets,
    this.isGenerating = false,
    this.isSwapping = false,
    this.swappingItemId,
    this.isSaving = false,
    this.error,
    this.selectedDate,
    this.dayType = 'rest',
  });

  final MealPlanEntity? plan;
  final MacroTargets? macroTargets;
  final bool isGenerating;
  final bool isSwapping;
  final String? swappingItemId;
  final bool isSaving;
  final String? error;
  final DateTime? selectedDate;
  final String dayType;

  MealPlanState copyWith({
    MealPlanEntity? plan,
    MacroTargets? macroTargets,
    bool? isGenerating,
    bool? isSwapping,
    String? swappingItemId,
    bool? isSaving,
    String? error,
    DateTime? selectedDate,
    String? dayType,
    bool clearPlan = false,
    bool clearError = false,
    bool clearSwappingItemId = false,
  }) {
    return MealPlanState(
      plan: clearPlan ? null : (plan ?? this.plan),
      macroTargets: macroTargets ?? this.macroTargets,
      isGenerating: isGenerating ?? this.isGenerating,
      isSwapping: isSwapping ?? this.isSwapping,
      swappingItemId:
          clearSwappingItemId ? null : (swappingItemId ?? this.swappingItemId),
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      dayType: dayType ?? this.dayType,
    );
  }
}

class MealPlanNotifier extends StateNotifier<MealPlanState> {
  MealPlanNotifier(
    this._repository,
    this._aiService,
    this._profileId,
    this._customTargetRepo,
  ) : super(MealPlanState(selectedDate: DateTime.now()));

  final MealPlanRepository _repository;
  final AiOrchestratorService _aiService;
  final String _profileId;
  final CustomMacroTargetRepository _customTargetRepo;

  Future<void> loadPlan(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      isGenerating: false,
      clearError: true,
    );

    try {
      final plan = await _repository.getMealPlan(_profileId, date);
      state = state.copyWith(plan: plan, clearPlan: plan == null);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load meal plan: $e');
    }
  }

  void setDayType(String dayType) {
    state = state.copyWith(dayType: dayType);
  }

  Future<void> generatePlan({
    required String userId,
    required String dayType,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoal,
    String? gender,
    int? age,
  }) async {
    final date = state.selectedDate ?? DateTime.now();
    state = state.copyWith(isGenerating: true, clearError: true, dayType: dayType);

    try {
      // Calculate macro targets (custom targets take precedence)
      final targets = await MacroCalculator.resolveTargets(
        profileId: _profileId,
        dayType: dayType,
        customRepo: _customTargetRepo,
        weightKg: weightKg ?? 75.0,
        activityLevel: activityLevel,
        fitnessGoal: fitnessGoal,
        gender: gender,
        age: age,
      );

      state = state.copyWith(macroTargets: targets);

      // Call AI orchestrator
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_daily_meal_plan',
        message: 'Generate a $dayType day meal plan targeting '
            '${targets.calories} calories, ${targets.proteinG}g protein, '
            '${targets.carbsG}g carbs, ${targets.fatG}g fat.',
        contextOverride: {
          'day_type': dayType,
          'macro_targets': targets.toJson(),
          'plan_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        },
      );

      // Parse AI response
      final mealData = _extractJsonFromMessage(response.assistantMessage);
      if (mealData == null) {
        throw Exception('AI returned invalid meal plan data');
      }

      final meals = (mealData['meals'] as List?) ?? [];
      final rationale = mealData['rationale'] as String?;

      final now = DateTime.now();
      final items = meals.asMap().entries.map((entry) {
        final m = entry.value as Map<String, dynamic>;
        return MealPlanItemEntity(
          id: '',
          mealPlanId: '',
          mealType: m['meal_type'] as String? ?? 'snack',
          name: m['name'] as String? ?? 'Meal',
          description: m['description'] as String?,
          calories: m['calories'] as int?,
          proteinG: m['protein_g'] as int?,
          carbsG: m['carbs_g'] as int?,
          fatG: m['fat_g'] as int?,
          sortOrder: entry.key,
          createdAt: now,
        );
      }).toList();

      // Build entity and save
      final entity = MealPlanEntity(
        id: '',
        profileId: _profileId,
        planDate: date,
        dayType: dayType,
        totalCalories: targets.calories,
        totalProteinG: targets.proteinG,
        totalCarbsG: targets.carbsG,
        totalFatG: targets.fatG,
        status: 'active',
        aiRationale: rationale,
        items: items,
        createdAt: now,
        updatedAt: now,
      );

      final saved = await _repository.saveMealPlan(entity);
      state = state.copyWith(plan: saved, isGenerating: false);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  Future<void> swapMeal({
    required String userId,
    required String itemId,
  }) async {
    final plan = state.plan;
    if (plan == null) return;

    final item = plan.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;

    state = state.copyWith(isSwapping: true, swappingItemId: itemId, clearError: true);

    try {
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_meal_swap',
        message: 'Swap this ${item.mealType}: "${item.name}" '
            '(${item.calories} cal, ${item.proteinG}g P, '
            '${item.carbsG}g C, ${item.fatG}g F) for something different.',
        contextOverride: {
          'current_meal': item.toJson(),
          'macro_targets': state.macroTargets?.toJson(),
          'day_type': state.dayType,
        },
      );

      final swapData = _extractJsonFromMessage(response.assistantMessage);
      if (swapData == null) {
        throw Exception('AI returned invalid swap data');
      }

      // Update the item in DB
      await _repository.updateItem(itemId, {
        'name': swapData['name'] as String? ?? item.name,
        'description': swapData['description'] as String?,
        'calories': swapData['calories'] as int?,
        'protein_g': swapData['protein_g'] as int?,
        'carbs_g': swapData['carbs_g'] as int?,
        'fat_g': swapData['fat_g'] as int?,
        'swap_count': item.swapCount + 1,
      });

      // Reload the plan
      final refreshed = await _repository.getMealPlan(
        _profileId,
        state.selectedDate ?? DateTime.now(),
      );
      state = state.copyWith(
        plan: refreshed,
        isSwapping: false,
        clearSwappingItemId: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSwapping: false,
        clearSwappingItemId: true,
        error: 'Swap failed: $e',
      );
    }
  }

  Future<void> markMealLogged(String itemId, {required bool isLogged}) async {
    try {
      await _repository.updateItemLogged(itemId, isLogged: isLogged);

      // Update local state immediately
      final plan = state.plan;
      if (plan != null) {
        final updatedItems = plan.items.map((item) {
          if (item.id == itemId) {
            return item.copyWith(isLogged: isLogged);
          }
          return item;
        }).toList();
        state = state.copyWith(plan: plan.copyWith(items: updatedItems));
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update meal: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Extracts the first ```json ... ``` block from an AI assistant message.
  Map<String, dynamic>? _extractJsonFromMessage(String message) {
    // Try fenced json block first
    final fencedRegex = RegExp(r'```json\n([\s\S]*?)\n```');
    final fencedMatch = fencedRegex.firstMatch(message);
    if (fencedMatch != null) {
      try {
        final decoded = jsonDecode(fencedMatch.group(1)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Fallback: try to find raw JSON object
    final jsonStart = message.indexOf('{');
    final jsonEnd = message.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd > jsonStart) {
      try {
        final decoded = jsonDecode(message.substring(jsonStart, jsonEnd + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }
}

final mealPlanProvider =
    StateNotifierProvider.family<MealPlanNotifier, MealPlanState, String>(
  (ref, profileId) {
    final repository = ref.watch(mealPlanRepositoryProvider);
    final aiService = ref.watch(aiOrchestratorServiceProvider);
    final customTargetRepo = ref.watch(customMacroTargetRepositoryProvider);
    return MealPlanNotifier(repository, aiService, profileId, customTargetRepo);
  },
);
