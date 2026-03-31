import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Pantry & Recipes
import '../../../../features/pantry/presentation/pantry_screen.dart'
    as pantry_screen;
import '../../../../features/recipes/presentation/recipe_suggestions_screen.dart'
    as recipe_suggestions;
import '../../../../features/recipes/presentation/recipe_detail_screen.dart'
    as recipe_detail;
import '../../../../features/recipes/presentation/url_import_screen.dart'
    as url_import;
import '../../../../features/recipes/presentation/ocr_import_screen.dart'
    as ocr_import;
import '../../../../features/recipes/presentation/recipe_list_screen.dart'
    as recipe_list;
import '../../../../features/recipes/presentation/recipe_edit_screen.dart'
    as recipe_edit;
import '../../../../features/pantry/presentation/photo_pantry_import_screen.dart'
    as photo_pantry_import;

// Shopping
import '../../../../features/shopping/presentation/shopping_lists_screen.dart'
    as shopping_lists;
import '../../../../features/shopping/presentation/shopping_list_detail_screen.dart'
    as shopping_detail;
import '../../../../features/shopping/presentation/photo_shopping_import_screen.dart'
    as photo_shopping_import;
import '../../../../features/shopping/presentation/barcode_scanner_screen.dart'
    as barcode_scanner;
import '../../../../features/shopping/domain/shopping_list_item_entity.dart';

// Meals
import '../../../../features/meals/presentation/log_meal_screen.dart'
    as log_meal;
import '../../../../features/meals/presentation/meal_plan_screen.dart'
    as meal_plan;
import '../../../../features/meals/presentation/meal_prep_screen.dart'
    as meal_prep;
import '../../../../features/meals/presentation/shopping_list_generator_screen.dart'
    as shopping_generator;
import '../../../../features/meals/presentation/nutrition_targets_screen.dart'
    as nutrition_targets;
import '../../../../features/meals/presentation/nutrition_profiles_screen.dart'
    as nutrition_profiles;
import '../../../../features/meals/presentation/food_search_screen.dart'
    as food_search;
import '../../../../features/meals/presentation/weekly_nutrition_summary_screen.dart'
    as weekly_nutrition;
import '../../../../features/meals/presentation/nutrition_detail_screen.dart'
    as nutrition_detail;
import '../../../../features/meals/presentation/voice_log_screen.dart'
    as voice_log;
import '../../../../features/meals/presentation/meal_scan_screen.dart'
    as meal_scan;

// Health
import '../../../../features/health/presentation/health_connection_screen.dart'
    as health_connection;
import '../../../../features/health/presentation/screens/steps_screen.dart'
    as steps_screen;
import '../../../../features/health/presentation/screens/sleep_screen.dart'
    as sleep_screen;
import '../../../../features/health/presentation/screens/heart_cardio_screen.dart'
    as heart_cardio;
import '../../../../features/health/presentation/screens/weight_body_screen.dart'
    as weight_body;
import '../../../../features/health/presentation/screens/vo2max_entry_screen.dart'
    as vo2max_entry;
import '../../../../features/health/presentation/screens/weight_log_screen.dart'
    as weight_log;
import '../../../../features/health/presentation/screens/health_permissions_rationale_screen.dart'
    as health_rationale;

// Insights
import '../../../../features/insights/presentation/insights_dashboard_screen.dart'
    as insights_screen;
import '../../../../features/insights/presentation/recovery_detail_screen.dart'
    as recovery_detail;

// Goals
import '../../../../features/goals/domain/goal_entity.dart';
import '../../../../features/goals/presentation/goals_list_screen.dart'
    as goals_list;
import '../../../../features/goals/presentation/goal_setup_screen.dart'
    as goal_setup;
import '../../../../features/goals/presentation/goal_detail_screen.dart'
    as goal_detail;

// Supplements, Bloodwork, Habits, Daily Coach, Reminders, Settings
import '../../../../features/supplements/presentation/supplements_screen.dart'
    as supplements_screen;
import '../../../../features/bloodwork/presentation/bloodwork_screen.dart'
    as bloodwork_screen;
import '../../../../features/bloodwork/presentation/bloodwork_detail_screen.dart'
    as bloodwork_detail;
import '../../../../features/habits/presentation/habits_screen.dart'
    as habits_screen;
import '../../../../features/habits/presentation/kegel_timer_screen.dart'
    as kegel_timer;
import '../../../../features/daily_coach/presentation/morning_checkin_screen.dart'
    as morning_checkin;
import '../../../../features/daily_coach/presentation/todays_plan_screen.dart'
    as todays_plan;
import '../../../../features/reminders/presentation/reminders_screen.dart'
    as reminders_screen;
import '../../../../features/settings/presentation/settings_screen.dart'
    as settings_screen;
import '../../../../features/settings/presentation/health_settings_screen.dart'
    as health_settings;
import '../../../../features/settings/presentation/ingredient_preferences_screen.dart'
    as ingredient_prefs;
import '../../../../features/settings/presentation/module_settings_screen.dart'
    as module_settings;

import '../app_router.dart' show activeProfileIdProvider;

/// All nested routes under the Dashboard (Branch 0, path '/').
/// Extracted from app_router.dart for maintainability.
List<GoRoute> dashboardChildRoutes(Ref ref) {
  return [
    // ── Pantry & Recipes ───────────────────────────────────────
    GoRoute(
      path: 'pantry',
      name: 'pantry',
      builder: (context, state) => const pantry_screen.PantryScreen(),
    ),
    GoRoute(
      path: 'pantry/photo-import',
      name: 'pantryPhotoImport',
      builder: (context, state) =>
          const photo_pantry_import.PhotoPantryImportScreen(),
    ),
    GoRoute(
      path: 'recipes/suggestions',
      name: 'recipeSuggestions',
      builder: (context, state) =>
          const recipe_suggestions.RecipeSuggestionsScreen(),
    ),
    GoRoute(
      path: 'recipes/import-url',
      name: 'recipeImportUrl',
      builder: (context, state) => const url_import.UrlImportScreen(),
    ),
    GoRoute(
      path: 'recipes/import-ocr',
      name: 'recipeImportOcr',
      builder: (context, state) => const ocr_import.OcrImportScreen(),
    ),
    GoRoute(
      path: 'recipes',
      name: 'recipeList',
      builder: (context, state) => const recipe_list.RecipeListScreen(),
    ),
    GoRoute(
      path: 'recipes/:id/edit',
      name: 'recipeEdit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return recipe_edit.RecipeEditScreen(recipeId: id);
      },
    ),
    GoRoute(
      path: 'recipes/:id',
      name: 'recipeDetail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return recipe_detail.RecipeDetailScreen(recipeId: id);
      },
    ),

    // ── Shopping ────────────────────────────────────────────────
    GoRoute(
      path: 'shopping',
      name: 'shoppingLists',
      builder: (context, state) =>
          const shopping_lists.ShoppingListsScreen(),
    ),
    GoRoute(
      path: 'shopping/:id',
      name: 'shoppingListDetail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return shopping_detail.ShoppingListDetailScreen(listId: id);
      },
    ),
    GoRoute(
      path: 'shopping/:id/photo-import',
      name: 'shoppingPhotoImport',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return photo_shopping_import.PhotoShoppingImportScreen(listId: id);
      },
    ),
    GoRoute(
      path: 'shopping/:id/barcode-scan',
      name: 'shoppingBarcodeScan',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final items =
            state.extra as List<ShoppingListItemEntity>? ?? const [];
        return barcode_scanner.BarcodeScannerScreen(
          listId: id,
          items: items,
        );
      },
    ),

    // ── Meals ──────────────────────────────────────────────────
    GoRoute(
      path: 'meals/log',
      name: 'logMeal',
      builder: (context, state) => const log_meal.LogMealScreen(),
    ),
    GoRoute(
      path: 'meals/plan',
      name: 'mealPlan',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return meal_plan.MealPlanScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'meals/shopping-generator',
      name: 'shoppingListGenerator',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return shopping_generator.ShoppingListGeneratorScreen(
          profileId: profileId,
        );
      },
    ),
    GoRoute(
      path: 'meals/prep',
      name: 'mealPrep',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return meal_prep.MealPrepScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'meals/food-search',
      name: 'foodSearch',
      builder: (context, state) => const food_search.FoodSearchScreen(),
    ),
    GoRoute(
      path: 'meals/food-barcode-scan',
      name: 'foodBarcodeScan',
      builder: (context, state) =>
          const food_search.FoodBarcodeScannerScreen(),
    ),
    GoRoute(
      path: 'meals/nutrition-profiles',
      name: 'nutritionProfiles',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return nutrition_profiles.NutritionProfilesScreen(
          profileId: profileId,
        );
      },
    ),
    GoRoute(
      path: 'meals/weekly-summary',
      name: 'weeklyNutritionSummary',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return weekly_nutrition.WeeklyNutritionSummaryScreen(
          profileId: profileId,
        );
      },
    ),
    GoRoute(
      path: 'nutrition',
      name: 'nutritionDetail',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return nutrition_detail.NutritionDetailScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: 'meals/voice-log',
      name: 'voiceLog',
      builder: (context, state) => const voice_log.VoiceLogScreen(),
    ),
    GoRoute(
      path: 'meals/meal-scan',
      name: 'mealScan',
      builder: (context, state) => const meal_scan.MealScanScreen(),
    ),

    // ── Weight ─────────────────────────────────────────────────
    GoRoute(
      path: 'weight/log',
      name: 'weightLog',
      builder: (context, state) => const weight_log.WeightLogScreen(),
    ),

    // ── Health ─────────────────────────────────────────────────
    GoRoute(
      path: 'health/permissions-rationale',
      name: 'healthPermissionsRationale',
      builder: (context, state) =>
          const health_rationale.HealthPermissionsRationaleScreen(),
    ),
    GoRoute(
      path: 'health/connections',
      name: 'healthConnections',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return health_connection.HealthConnectionScreen(
          profileId: profileId,
        );
      },
    ),
    GoRoute(
      path: 'health/steps',
      name: 'healthSteps',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return steps_screen.StepsScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'health/sleep',
      name: 'healthSleep',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return sleep_screen.SleepScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'health/heart',
      name: 'healthHeart',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return heart_cardio.HeartCardioScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'health/weight',
      name: 'healthWeight',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return weight_body.WeightBodyScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'health/vo2max-entry',
      name: 'vo2maxEntry',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return vo2max_entry.Vo2maxEntryScreen(profileId: profileId);
      },
    ),

    // ── Insights ───────────────────────────────────────────────
    GoRoute(
      path: 'insights',
      name: 'insights',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return insights_screen.InsightsDashboardScreen(
          profileId: profileId,
        );
      },
    ),
    GoRoute(
      path: 'recovery-detail',
      name: 'recoveryDetail',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return recovery_detail.RecoveryDetailScreen(
          profileId: profileId,
        );
      },
    ),

    // ── Goals ──────────────────────────────────────────────────
    GoRoute(
      path: 'goals',
      name: 'goals',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return goals_list.GoalsListScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'goals/create',
      name: 'goalCreate',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        final existingGoal = state.extra as GoalEntity?;
        return goal_setup.GoalSetupScreen(
          profileId: profileId,
          existingGoal: existingGoal,
        );
      },
    ),
    GoRoute(
      path: 'goals/:goalId',
      name: 'goalDetail',
      builder: (context, state) {
        final goalId = state.pathParameters['goalId']!;
        return goal_detail.GoalDetailScreen(goalId: goalId);
      },
    ),

    // ── Supplements ────────────────────────────────────────────
    GoRoute(
      path: 'supplements',
      name: 'supplements',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return supplements_screen.SupplementsScreen(
          profileId: profileId,
        );
      },
    ),

    // ── Bloodwork ──────────────────────────────────────────────
    GoRoute(
      path: 'bloodwork',
      name: 'bloodwork',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return bloodwork_screen.BloodworkScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'bloodwork/:testName',
      name: 'bloodworkDetail',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        final testName = Uri.decodeComponent(
          state.pathParameters['testName'] ?? '',
        );
        return bloodwork_detail.BloodworkDetailScreen(
          profileId: profileId,
          testName: testName,
        );
      },
    ),

    // ── Habits ─────────────────────────────────────────────────
    GoRoute(
      path: 'habits',
      name: 'habits',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return habits_screen.HabitsScreen(profileId: profileId);
      },
    ),
    GoRoute(
      path: 'habits/kegel-timer',
      name: 'kegelTimer',
      builder: (context, state) => const kegel_timer.KegelTimerScreen(),
    ),

    // ── Daily Coach ────────────────────────────────────────────
    GoRoute(
      path: 'daily-coach/checkin',
      name: 'morningCheckIn',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return morning_checkin.MorningCheckInScreen(
            profileId: profileId);
      },
    ),
    GoRoute(
      path: 'daily-coach/plan',
      name: 'todaysPlan',
      builder: (context, state) {
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        return todays_plan.TodaysPlanScreen(profileId: profileId);
      },
    ),

    // ── Reminders ──────────────────────────────────────────────
    GoRoute(
      path: 'reminders',
      name: 'reminders',
      builder: (context, state) =>
          const reminders_screen.RemindersScreen(),
    ),

    // ── Settings ───────────────────────────────────────────────
    GoRoute(
      path: 'settings',
      name: 'settings',
      builder: (context, state) =>
          const settings_screen.SettingsScreen(),
    ),
    GoRoute(
      path: 'settings/health',
      name: 'healthSettings',
      builder: (context, state) =>
          const health_settings.HealthSettingsScreen(),
    ),
    GoRoute(
      path: 'settings/nutrition-targets',
      name: 'nutritionTargets',
      builder: (context, state) =>
          const nutrition_targets.NutritionTargetsScreen(),
    ),
    GoRoute(
      path: 'settings/ingredient-preferences',
      name: 'ingredientPreferences',
      builder: (context, state) =>
          const ingredient_prefs.IngredientPreferencesScreen(),
    ),
    GoRoute(
      path: 'settings/modules',
      name: 'moduleSettings',
      builder: (context, state) =>
          const module_settings.ModuleSettingsScreen(),
    ),
  ];
}
