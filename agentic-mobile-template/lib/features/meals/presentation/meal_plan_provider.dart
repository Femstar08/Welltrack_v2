import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/food_database_service.dart';
import '../data/macro_calculator.dart';
import '../data/meal_plan_repository.dart';
import '../data/custom_macro_target_repository.dart';
import '../domain/meal_plan_entity.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../daily_coach/data/daily_prescription_repository.dart';

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
    this.recoveryAdjustmentLabel,
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

  /// Human-readable label explaining the recovery-based calorie adjustment,
  /// e.g. "Reduced −10% — fair recovery". Null when no recovery data exists.
  final String? recoveryAdjustmentLabel;

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
    String? recoveryAdjustmentLabel,
    bool clearPlan = false,
    bool clearError = false,
    bool clearSwappingItemId = false,
    bool clearRecoveryLabel = false,
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
      recoveryAdjustmentLabel: clearRecoveryLabel
          ? null
          : (recoveryAdjustmentLabel ?? this.recoveryAdjustmentLabel),
    );
  }
}

class MealPlanNotifier extends StateNotifier<MealPlanState> {
  MealPlanNotifier(
    this._repository,
    this._aiService,
    this._profileId,
    this._customTargetRepo,
    this._profileRepository,
    this._prescriptionRepository,
  ) : super(MealPlanState(selectedDate: DateTime.now()));

  final MealPlanRepository _repository;
  final AiOrchestratorService _aiService;
  final String _profileId;
  final CustomMacroTargetRepository _customTargetRepo;
  final ProfileRepository _profileRepository;
  final DailyPrescriptionRepository _prescriptionRepository;

  Future<void> loadPlan(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      isGenerating: false,
      clearError: true,
    );

    try {
      final plan = await _repository.getMealPlan(_profileId, date);

      // Derive the recovery-adjusted calorie label for the selected date.
      // Only today's prescription is relevant; for past/future dates we skip.
      String? recoveryLabel;
      final today = DateTime.now();
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      if (isToday) {
        try {
          final prescription =
              await _prescriptionRepository.getTodayPrescription(_profileId);
          if (prescription != null) {
            recoveryLabel = MacroCalculator.recoveryAdjustmentLabel(
              prescription.recoveryScore,
            );
          }
        } catch (_) {
          // Non-fatal — recovery label is purely informational
        }
      }

      state = state.copyWith(
        plan: plan,
        clearPlan: plan == null,
        recoveryAdjustmentLabel: recoveryLabel,
        clearRecoveryLabel: recoveryLabel == null,
      );
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
      final baseTargets = await MacroCalculator.resolveTargets(
        profileId: _profileId,
        dayType: dayType,
        customRepo: _customTargetRepo,
        weightKg: weightKg ?? 75.0,
        activityLevel: activityLevel,
        fitnessGoal: fitnessGoal,
        gender: gender,
        age: age,
      );

      // Apply recovery-score-based calorie adjustment from today's prescription.
      // Falls back to base targets when no prescription exists (e.g. baseline
      // period or first-time users with no health data yet).
      double? recoveryScore;
      int prescriptionCalorieModifier = 0;
      double prescriptionAdjustmentPct = 0.0;
      String? recoveryLabel;

      try {
        final prescription =
            await _prescriptionRepository.getTodayPrescription(_profileId);
        if (prescription != null) {
          recoveryScore = prescription.recoveryScore;
          prescriptionCalorieModifier = prescription.calorieModifier;
          prescriptionAdjustmentPct = prescription.calorieAdjustmentPercent;
          recoveryLabel =
              MacroCalculator.recoveryAdjustmentLabel(recoveryScore);
        }
      } catch (_) {
        // Non-fatal — proceed with unadjusted base targets
      }

      final targets = MacroCalculator.applyRecoveryAdjustment(
        base: baseTargets,
        recoveryScore: recoveryScore,
        calorieModifier: prescriptionCalorieModifier,
        calorieAdjustmentPct: prescriptionAdjustmentPct,
      );

      state = state.copyWith(
        macroTargets: targets,
        recoveryAdjustmentLabel: recoveryLabel,
        clearRecoveryLabel: recoveryLabel == null,
      );

      // Load profile for nutrition preferences and ingredient restrictions
      List<String> nutritionProfiles = const [];
      String cuisinePreference = 'balanced';
      List<String> excludedIngredients = const [];
      List<String> preferredIngredients = const [];
      try {
        final profile = await _profileRepository.getProfile(_profileId);
        nutritionProfiles = profile.nutritionProfiles;
        cuisinePreference = profile.cuisinePreference;
        excludedIngredients = profile.excludedIngredients;
        preferredIngredients = profile.preferredIngredients;
      } catch (_) {
        // Non-fatal — proceed with defaults
      }

      // Build ingredient restriction clauses for the prompt
      final excludedClause = excludedIngredients.isNotEmpty
          ? ' NEVER include these ingredients: ${excludedIngredients.join(', ')}.'
          : '';
      final preferredClause = preferredIngredients.isNotEmpty
          ? ' Prefer these ingredients when possible: ${preferredIngredients.join(', ')}.'
          : '';

      // Call AI orchestrator
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_daily_meal_plan',
        message: 'Generate a $dayType day meal plan targeting '
            '${targets.calories} calories, ${targets.proteinG}g protein, '
            '${targets.carbsG}g carbs, ${targets.fatG}g fat.'
            '$excludedClause$preferredClause',
        contextOverride: {
          'day_type': dayType,
          'macro_targets': targets.toJson(),
          'plan_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'nutrition_profiles': nutritionProfiles,
          'cuisine_preference': cuisinePreference,
          if (excludedIngredients.isNotEmpty)
            'excluded_ingredients': excludedIngredients,
          if (preferredIngredients.isNotEmpty)
            'preferred_ingredients': preferredIngredients,
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


  Future<void> markMealLogged(
    String itemId, {
    required bool isLogged,
    double portionMultiplier = 1.0,
  }) async {
    try {
      await _repository.updateItemLogged(
        itemId,
        isLogged: isLogged,
        portionMultiplier: portionMultiplier,
      );

      // Update local state immediately
      final plan = state.plan;
      if (plan != null) {
        final updatedItems = plan.items.map((item) {
          if (item.id == itemId) {
            return item.copyWith(
              isLogged: isLogged,
              portionMultiplier: portionMultiplier,
            );
          }
          return item;
        }).toList();
        state = state.copyWith(plan: plan.copyWith(items: updatedItems));
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update meal: $e');
    }
  }

  /// Fetches 3 macro-matched swap alternatives from the AI.
  /// The caller (screen) handles displaying and selection.
  Future<List<Map<String, dynamic>>> getSwapAlternatives({
    required String userId,
    required String itemId,
  }) async {
    final plan = state.plan;
    if (plan == null) return [];

    final item = plan.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return [];

    state = state.copyWith(isSwapping: true, swappingItemId: itemId, clearError: true);

    try {
      final macroTargetsJson = state.macroTargets?.toJson() ??
          (plan.totalCalories != null
              ? {
                  'calories': plan.totalCalories,
                  'protein_g': plan.totalProteinG,
                  'carbs_g': plan.totalCarbsG,
                  'fat_g': plan.totalFatG,
                }
              : null);

      // Load ingredient restrictions from profile
      List<String> excludedIngredients = const [];
      List<String> preferredIngredients = const [];
      try {
        final profile = await _profileRepository.getProfile(_profileId);
        excludedIngredients = profile.excludedIngredients;
        preferredIngredients = profile.preferredIngredients;
      } catch (_) {
        // Non-fatal — proceed without restrictions
      }

      final excludedClause = excludedIngredients.isNotEmpty
          ? ' NEVER include these ingredients: ${excludedIngredients.join(', ')}.'
          : '';
      final preferredClause = preferredIngredients.isNotEmpty
          ? ' Prefer these ingredients when possible: ${preferredIngredients.join(', ')}.'
          : '';

      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_meal_swap',
        message: 'Provide 3 alternative ${item.mealType} options to replace '
            '"${item.name}" (${item.calories} cal, ${item.proteinG}g P, '
            '${item.carbsG}g C, ${item.fatG}g F). Each must closely match '
            'the macro targets. Return as JSON with key "alternatives" containing '
            'an array of 3 objects each with: name, description, calories, '
            'protein_g, carbs_g, fat_g.'
            '$excludedClause$preferredClause',
        contextOverride: {
          'current_meal': item.toJson(),
          'macro_targets': macroTargetsJson,
          'day_type': state.dayType,
          if (excludedIngredients.isNotEmpty)
            'excluded_ingredients': excludedIngredients,
          if (preferredIngredients.isNotEmpty)
            'preferred_ingredients': preferredIngredients,
        },
      );

      final data = _extractJsonFromMessage(response.assistantMessage);
      final alternatives = (data?['alternatives'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      state = state.copyWith(isSwapping: false, clearSwappingItemId: true);
      return alternatives;
    } catch (e) {
      state = state.copyWith(
        isSwapping: false,
        clearSwappingItemId: true,
        error: 'Failed to load alternatives: $e',
      );
      return [];
    }
  }

  /// Applies a chosen swap alternative to the item in DB and refreshes state.
  Future<void> applySwapAlternative({
    required String itemId,
    required Map<String, dynamic> alternative,
  }) async {
    final plan = state.plan;
    if (plan == null) return;

    final item = plan.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;

    try {
      await _repository.updateItem(itemId, {
        'name': alternative['name'] as String? ?? item.name,
        'description': alternative['description'] as String?,
        'calories': alternative['calories'] as int?,
        'protein_g': alternative['protein_g'] as int?,
        'carbs_g': alternative['carbs_g'] as int?,
        'fat_g': alternative['fat_g'] as int?,
        'swap_count': item.swapCount + 1,
        'is_logged': false,
        'portion_multiplier': 1.0,
      });

      final refreshed = await _repository.getMealPlan(
        _profileId,
        state.selectedDate ?? DateTime.now(),
      );
      state = state.copyWith(plan: refreshed);
    } catch (e) {
      state = state.copyWith(error: 'Swap failed: $e');
    }
  }

  /// Regenerates a single meal item with a fresh AI suggestion.
  Future<void> regenerateMeal({
    required String userId,
    required String itemId,
    required String mealType,
  }) async {
    final plan = state.plan;
    if (plan == null) return;

    final item = plan.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;

    state = state.copyWith(isSwapping: true, swappingItemId: itemId, clearError: true);

    try {
      final macroTargetsJson = state.macroTargets?.toJson() ??
          (plan.totalCalories != null
              ? {
                  'calories': plan.totalCalories,
                  'protein_g': plan.totalProteinG,
                  'carbs_g': plan.totalCarbsG,
                  'fat_g': plan.totalFatG,
                }
              : null);

      // Load ingredient restrictions from profile
      List<String> excludedIngredients = const [];
      List<String> preferredIngredients = const [];
      try {
        final profile = await _profileRepository.getProfile(_profileId);
        excludedIngredients = profile.excludedIngredients;
        preferredIngredients = profile.preferredIngredients;
      } catch (_) {
        // Non-fatal — proceed without restrictions
      }

      final excludedClause = excludedIngredients.isNotEmpty
          ? ' NEVER include these ingredients: ${excludedIngredients.join(', ')}.'
          : '';
      final preferredClause = preferredIngredients.isNotEmpty
          ? ' Prefer these ingredients when possible: ${preferredIngredients.join(', ')}.'
          : '';

      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'generate_meal_swap',
        message: 'Regenerate a completely new $mealType meal to replace '
            '"${item.name}". It must match the macro targets. Return JSON with: '
            'name, description, calories, protein_g, carbs_g, fat_g.'
            '$excludedClause$preferredClause',
        contextOverride: {
          'current_meal': item.toJson(),
          'macro_targets': macroTargetsJson,
          'day_type': state.dayType,
          if (excludedIngredients.isNotEmpty)
            'excluded_ingredients': excludedIngredients,
          if (preferredIngredients.isNotEmpty)
            'preferred_ingredients': preferredIngredients,
        },
      );

      final data = _extractJsonFromMessage(response.assistantMessage);
      if (data == null) throw Exception('AI returned invalid data');

      await _repository.updateItem(itemId, {
        'name': data['name'] as String? ?? item.name,
        'description': data['description'] as String?,
        'calories': data['calories'] as int?,
        'protein_g': data['protein_g'] as int?,
        'carbs_g': data['carbs_g'] as int?,
        'fat_g': data['fat_g'] as int?,
        'is_logged': false,
        'portion_multiplier': 1.0,
      });

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
        error: 'Regenerate failed: $e',
      );
    }
  }

  /// Logs a food item from the food database into today's meal plan.
  /// Creates a minimal plan if none exists for the selected date.
  Future<void> addFoodToLog({
    required String userId,
    required FoodItem foodItem,
    required String mealType,
    required double portionG,
  }) async {
    var plan = state.plan;
    final date = state.selectedDate ?? DateTime.now();

    // Create a minimal plan if none exists
    if (plan == null) {
      try {
        final targets = await MacroCalculator.resolveTargets(
          profileId: _profileId,
          dayType: state.dayType,
          customRepo: _customTargetRepo,
          weightKg: 75.0,
        );
        final now = DateTime.now();
        plan = await _repository.saveMealPlan(MealPlanEntity(
          id: '',
          profileId: _profileId,
          planDate: date,
          dayType: state.dayType,
          totalCalories: targets.calories,
          totalProteinG: targets.proteinG,
          totalCarbsG: targets.carbsG,
          totalFatG: targets.fatG,
          status: 'active',
          items: const [],
          createdAt: now,
          updatedAt: now,
        ));
        state = state.copyWith(plan: plan);
      } catch (e) {
        state = state.copyWith(error: 'Could not create meal log: $e');
        return;
      }
    }

    // portionMultiplier relative to 100g base from Open Food Facts
    final multiplier = portionG / 100.0;

    final now = DateTime.now();
    final item = MealPlanItemEntity(
      id: '',
      mealPlanId: plan.id,
      mealType: mealType,
      name: foodItem.name,
      description: foodItem.brand,
      calories: foodItem.caloriesPer100g.round(),
      proteinG: foodItem.proteinPer100g.round(),
      carbsG: foodItem.carbsPer100g.round(),
      fatG: foodItem.fatPer100g.round(),
      sortOrder: plan.items.length,
      isLogged: true,
      portionMultiplier: multiplier,
      source: 'food_search',
      createdAt: now,
    );

    try {
      state = state.copyWith(isSaving: true, clearError: true);
      final savedItem = await _repository.insertItem(plan.id, item);
      final updatedItems = [...plan.items, savedItem];
      state = state.copyWith(
        plan: plan.copyWith(items: updatedItems),
        isSaving: false,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, error: 'Could not log food: $e');
    }
  }

  Future<void> deleteAndRegeneratePlan({
    required String userId,
    required String dayType,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoal,
    String? gender,
    int? age,
  }) async {
    final plan = state.plan;
    if (plan != null && plan.id.isNotEmpty) {
      try {
        await _repository.deleteMealPlan(plan.id);
      } catch (e) {
        state = state.copyWith(error: 'Failed to delete plan: $e');
        return;
      }
    }
    state = state.copyWith(clearPlan: true, clearError: true);
    await generatePlan(
      userId: userId,
      dayType: dayType,
      weightKg: weightKg,
      activityLevel: activityLevel,
      fitnessGoal: fitnessGoal,
      gender: gender,
      age: age,
    );
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
    final profileRepo = ref.watch(profileRepositoryProvider);
    final prescriptionRepo = ref.watch(dailyPrescriptionRepositoryProvider);
    return MealPlanNotifier(
      repository,
      aiService,
      profileId,
      customTargetRepo,
      profileRepo,
      prescriptionRepo,
    );
  },
);
