# Phase 5 PRP: Pantry → Recipes → Prep (First End-to-End Feature)

**Project**: WellTrack — Performance & Recovery Optimization Engine
**Phase**: 5 of 12 — Pantry Management + AI Recipe Generation + Step-by-Step Prep + Meal Logging
**Status**: READY FOR IMPLEMENTATION
**Confidence Score**: 7/10
**Date**: 2026-02-15

---

## 1. Overview & Why Phase 5

Phase 5 is the **first end-to-end user workflow** that proves the entire system works together:
- Flutter UI captures pantry items (fridge/cupboard/freezer)
- AI Orchestrator generates 5-10 recipe options with nutrition
- User selects a recipe → step-by-step prep with timers + checklist
- Prep completion logs a meal + nutrient breakdown
- Leftovers are captured for future pantry

### Why Build This First?
- **High user value**: "Cook with what I have" is a core wellness feature
- **Demonstrates AI integration**: End-to-end proof that AI orchestrator works
- **Tests offline-first**: Meal logs must sync when online
- **Validates data model**: Recipes, meals, ingredients, nutrients all exercised
- **Foundation for future features**: Recipe import, shopping lists, insights all build on this

### Scope (MVP)
- **Pantry management**: Add/remove items with fridge/cupboard/freezer categorization
- **AI recipe generation**: Call `generate_pantry_recipes` tool
- **Recipe selection & viewing**: Display recipes with tags, time, difficulty, nutrition score (A-D)
- **Step-by-step prep**: Call `generate_recipe_steps` tool; display with timers + checklist
- **Meal logging**: Save meal + extracted nutrients to `wt_meals` + `wt_meal_nutrient_breakdown`
- **Leftover capture**: Optional manual entry of unused ingredients
- **Offline support**: All logs queued if offline; sync on reconnection

### Out of Scope (Phase 6+)
- Recipe URL import
- Photo OCR recipe extraction
- Shopping list generation
- Recipe sharing / community recipes
- Multi-user meal planning

---

## 2. Deliverables (Must Have)

### 2.1 Database Tables (Already Designed in Phase 1)

**Tables to Use**:
- `wt_pantry_items` — User's pantry inventory
- `wt_recipes` — Recipe definitions (user-created + AI-generated)
- `wt_recipe_steps` — Step-by-step prep instructions
- `wt_recipe_ingredients` — Recipe's ingredient list + quantities
- `wt_meals` — Logged meals (from recipes or manual)
- `wt_meal_nutrient_breakdown` — Nutrient details per meal
- `wt_leftovers` — Unused ingredients after cooking

**Required Schema Columns** (verify in Phase 1 migration):

```sql
-- wt_pantry_items
id, user_id, profile_id, name, quantity, unit,
category (fridge/cupboard/freezer), added_at, expires_at, created_at, updated_at

-- wt_recipes
id, user_id, profile_id, title, source (user_created/ai_generated/imported),
servings, prep_time_mins, cook_time_mins, difficulty (easy/medium/hard),
nutrition_score (A/B/C/D), tags (json array), created_at, updated_at

-- wt_recipe_steps
id, recipe_id, step_number, instruction, timer_mins, created_at

-- wt_recipe_ingredients
id, recipe_id, ingredient_name, quantity, unit, notes, created_at

-- wt_meals
id, user_id, profile_id, recipe_id, servings, logged_at, created_at, updated_at

-- wt_meal_nutrient_breakdown
id, meal_id, nutrient_name (calories/protein/carbs/fat/fiber/etc.),
value, unit, created_at

-- wt_leftovers
id, meal_id, ingredient_name, quantity, unit, stored_location (fridge/cupboard/freezer),
created_at
```

All tables:
- PK: `id` (UUID)
- RLS: profile-scoped (user owns data via `user_id` + `profile_id`)
- Soft delete: Consider `deleted_at` column if needed

---

### 2.2 Flutter UI Screens & Widgets

#### 2.2.1 Pantry Management Screen
**Path**: `lib/features/pantry/presentation/screens/PantryScreen.dart`

**Components**:
1. **Pantry List View**
   - Tab or section for each category: Fridge, Cupboard, Freezer
   - Each item: name, quantity, unit, expiration badge (if < 3 days)
   - Swipe-to-delete or long-press menu (delete, edit, use)
   - Search / filter by category

2. **Add Item Dialog**
   - Text field: item name (autocomplete from common ingredients)
   - Quantity + Unit dropdown (pcs, grams, ml, cups, etc.)
   - Category selector: Fridge / Cupboard / Freezer
   - Optional: Expiration date picker
   - Save button → POST to `/api/pantry` (or local Isar + sync queue)

3. **Empty State**
   - Illustration + "Start by adding ingredients"
   - Suggest pantry action: "Tap + to add items"

**State Management** (Riverpod):
- Provider: `pantryItemsProvider` (List<PantryItem>)
- Provider: `addPantryItemProvider` (async mutation)
- Provider: `deletePantryItemProvider` (async mutation)
- Offline queue: sync mutations to `wt_pantry_items` when online

**Offline Handling**:
- All mutations queued in local Isar table: `offline_queue` (table, action, data, sync_status)
- On app reconnect, flush queue; show toast if sync fails

#### 2.2.2 AI Recipe Generation Screen
**Path**: `lib/features/recipes/presentation/screens/RecipeGenerationScreen.dart`

**Flow**:
1. User taps "Cook with what I have" → shows pantry items as pills
2. Each pill: name + quantity (editable, removable)
3. Optional text field: "Any preferences?" (vegan, quick, specific cuisine)
4. Button: "Generate recipes"
5. Loading state: spinner + "Getting recipe ideas..."
6. Success: List of 5-10 recipe cards
7. Error: Retry button + error message

**Recipe Card**:
- Recipe title + difficulty badge (easy/medium/hard)
- Prep time + cook time (mins)
- Nutrition score (A/B/C/D) with color coding:
  - A = green (excellent)
  - B = blue (good)
  - C = yellow (moderate)
  - D = orange (check nutrients)
- Tags: vegan, gluten-free, quick (< 30 mins), etc.
- Tap to view full recipe → RecipeDetailScreen

**API Call**:
```dart
// Call AI Orchestrator
final response = await _aiClient.orchestrate(
  tool: 'generate_pantry_recipes',
  context: {
    'pantry_items': selectedItems,
    'preferences': userPreferences,
  },
  userMessage: 'Generate recipes',
);
// Parse response.suggested_actions for recipes
// Save to wt_recipes via RLS (if action_type == 'add_recipe')
```

**Offline Handling**:
- If offline, show cached recipes from last successful generation (if any)
- Queue AI call for sync; warn user "This feature requires internet"

#### 2.2.3 Recipe Detail Screen
**Path**: `lib/features/recipes/presentation/screens/RecipeDetailScreen.dart`

**Content**:
- Recipe title + source badge (AI-generated, User-created, Imported)
- Difficulty, prep/cook times, servings selector
- Nutrition breakdown: calories, protein, carbs, fat, fiber
- Ingredients list (interactive; user can check off as they prep)
- Tags
- "Start Cooking" button → PrepWalkthroughScreen

**Ingredients List Widget**:
- Expandable for each ingredient: "1 cup rice" → nutritional info
- Checkbox per ingredient (for shopping list future feature)

---

### 2.2.4 Prep Walkthrough Screen
**Path**: `lib/features/recipes/presentation/screens/PrepWalkthroughScreen.dart`

**UI**:
1. **Recipe header** (collapsible): title, total time, nutrition
2. **Steps carousel or list**:
   - Step N of total
   - Instruction text (large, readable)
   - Timer button (if step has timer_mins)
   - Checkbox: "Done with this step"
   - Next/Previous buttons

3. **Timer Modal** (if timer_mins > 0):
   - Countdown display (MM:SS)
   - Start / Pause / Cancel buttons
   - Notification on completion (local push)

4. **Ingredients checklist** (sidebar or modal):
   - Show all ingredients; check off as mentioned in steps
   - Visual: strikethrough when checked

5. **Completion Flow**:
   - Final step completed → "Ready to eat!" screen
   - Button: "Log this meal" → MealLoggingSheet

**State Management** (Riverpod):
- Provider: `recipeStepsProvider(recipeId)` → List<RecipeStep>
- Provider: `currentStepIndexProvider` (state: 0..n-1)
- Provider: `timerProvider` (countdown state + trigger notifications)

**Offline Handling**:
- Steps pre-fetched and cached (from Phase 4: AI orchestrator call)
- Timer works offline (local state only)
- Meal log queued for sync

---

### 2.2.5 Meal Logging Sheet
**Path**: `lib/features/meals/presentation/widgets/MealLoggingSheet.dart`

**UI** (Bottom Sheet):
1. **Meal summary**: Recipe title + servings logged
2. **Nutrition display** (read-only):
   - Calories, protein, carbs, fat, fiber (for servings selected)
   - "Adjusted nutrients" if user modified recipe
3. **Optional fields**:
   - Servings input (pre-filled from prep)
   - Notes: "Added more salt" or "Substituted chicken with tofu"
4. **Leftover capture** (optional expansion):
   - List of pantry items used
   - For each: "How much did you use?"
   - Checkbox: "Remove from pantry" vs. "Update quantity"
5. **Action buttons**:
   - "Log Meal" (saves to wt_meals + wt_meal_nutrient_breakdown + updates pantry)
   - "Skip" (dismisses sheet)

**API Call**:
```dart
// Save meal + nutrients
final mealId = await _mealsRepository.logMeal(
  recipeId: recipeId,
  servings: servingsLogged,
  loggedAt: DateTime.now(),
);

// Save nutrient breakdown (AI extracted in Phase 4)
await _nutrientsRepository.saveMealNutrients(
  mealId: mealId,
  nutrients: extractedNutrients,
);

// Update pantry (consume items)
await _pantryRepository.consumeItems(selectedItems);
```

**Offline Handling**:
- All writes queued in offline queue; sync on reconnection
- Show "Meal logged (pending sync)" message

---

### 2.3 Riverpod Providers

**File**: `lib/features/recipes/domain/providers/recipe_providers.dart`

```dart
// Pantry
final pantryItemsProvider = StateNotifierProvider<PantryItemsNotifier, List<PantryItem>>((ref) {
  final repository = ref.watch(pantryRepositoryProvider);
  return PantryItemsNotifier(repository);
});

final addPantryItemProvider = FutureProvider.autoDispose.family<void, PantryItem>((ref, item) async {
  final repository = ref.watch(pantryRepositoryProvider);
  await repository.addItem(item);
});

// Recipes
final recipeGenerationProvider = FutureProvider.family<List<Recipe>, RecipeGenerationRequest>((ref, request) async {
  final aiClient = ref.watch(aiOrchestratorProvider);
  return aiClient.generateRecipes(request);
});

final recipeDetailProvider = FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final repository = ref.watch(recipeRepositoryProvider);
  return repository.getRecipe(recipeId);
});

final recipeStepsProvider = FutureProvider.family<List<RecipeStep>, String>((ref, recipeId) async {
  final repository = ref.watch(recipeRepositoryProvider);
  return repository.getSteps(recipeId);
});

// Prep & Meal Logging
final currentStepIndexProvider = StateProvider<int>((ref) => 0);

final mealLoggingProvider = FutureProvider.autoDispose.family<void, MealLog>((ref, mealLog) async {
  final repository = ref.watch(mealsRepositoryProvider);
  await repository.logMeal(mealLog);
});
```

---

### 2.4 Data Models (Dart)

**File**: `lib/features/recipes/domain/entities/recipe.dart`

```dart
class Recipe {
  final String id;
  final String userId;
  final String profileId;
  final String title;
  final RecipeSource source; // user_created, ai_generated, imported
  final int servings;
  final int prepTimeMins;
  final int cookTimeMins;
  final Difficulty difficulty; // easy, medium, hard
  final NutritionScore nutritionScore; // A, B, C, D
  final List<String> tags; // vegan, gluten-free, quick, etc.
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class RecipeStep {
  final String id;
  final String recipeId;
  final int stepNumber;
  final String instruction;
  final int? timerMins;
  final DateTime createdAt;
}

class PantryItem {
  final String id;
  final String userId;
  final String profileId;
  final String name;
  final double quantity;
  final String unit; // pcs, grams, ml, cups, tbsp, tsp, etc.
  final PantryCategory category; // fridge, cupboard, freezer
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Meal {
  final String id;
  final String userId;
  final String profileId;
  final String? recipeId;
  final double servingsLogged;
  final DateTime loggedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MealNutrient {
  final String id;
  final String mealId;
  final String nutrientName; // calories, protein, carbs, fat, fiber, etc.
  final double value;
  final String unit; // kcal, grams, etc.
  final DateTime createdAt;
}

class Leftover {
  final String id;
  final String mealId;
  final String ingredientName;
  final double quantity;
  final String unit;
  final PantryCategory storedLocation;
  final DateTime createdAt;
}
```

---

### 2.5 Repository Interfaces & Implementations

**File**: `lib/features/recipes/domain/repositories/recipe_repository.dart`

```dart
abstract class RecipeRepository {
  Future<List<Recipe>> generateRecipesFromPantry(List<PantryItem> items, String? preferences);
  Future<Recipe?> getRecipe(String recipeId);
  Future<List<RecipeStep>> getRecipeSteps(String recipeId);
  Future<void> saveRecipe(Recipe recipe);
  Future<void> deleteRecipe(String recipeId);
}

abstract class PantryRepository {
  Future<List<PantryItem>> getPantryItems(String profileId);
  Future<void> addItem(PantryItem item);
  Future<void> updateItem(PantryItem item);
  Future<void> deleteItem(String itemId);
  Future<void> consumeItems(Map<String, double> itemQuantities);
}

abstract class MealRepository {
  Future<void> logMeal(Meal meal, List<MealNutrient> nutrients, List<Leftover> leftovers);
  Future<List<Meal>> getMealsForProfile(String profileId, {DateTime? from, DateTime? to});
  Future<Meal?> getMeal(String mealId);
}
```

**Implementation**: Use Supabase client (via RLS) for online; Isar for offline cache + queue.

---

### 2.6 AI Orchestrator Integration

**File**: `lib/shared/core/network/ai_orchestrator_client.dart`

```dart
class AIOrchestrationClient {
  Future<AIResponse> orchestrate({
    required String tool,
    required Map<String, dynamic> context,
    required String userMessage,
    bool dryRun = false,
  }) async {
    // 1. Get current user & profile from auth
    final user = _authService.currentUser;
    final profile = _profileService.currentProfile;

    // 2. Assemble request
    final request = {
      'user_id': user.id,
      'profile_id': profile.id,
      'tool': tool,
      'context_snapshot': context,
      'messages': [
        {'role': 'user', 'content': userMessage}
      ],
      'dry_run': dryRun,
    };

    // 3. Call Edge Function: POST /functions/v1/ai-orchestrate
    final response = await _supabaseClient.functions.invoke(
      'ai-orchestrate',
      body: request,
    );

    // 4. Parse response
    return AIResponse.fromJson(response);
  }

  // Helper: generate_pantry_recipes
  Future<List<Recipe>> generateRecipes(
    List<PantryItem> items,
    String? preferences,
  ) async {
    final response = await orchestrate(
      tool: 'generate_pantry_recipes',
      context: {
        'pantry_items': items.map((i) => i.toJson()).toList(),
        'preferences': preferences,
      },
      userMessage: 'Generate recipes from these pantry items',
    );

    // Parse db_writes[*] with action='insert' and table='wt_recipes'
    // Convert to Recipe objects
    return response.dbWrites
        .where((w) => w['table'] == 'wt_recipes')
        .map((w) => Recipe.fromJson(w['data']))
        .toList();
  }

  // Helper: generate_recipe_steps
  Future<List<RecipeStep>> generateSteps(String recipeId) async {
    final recipe = await _recipeRepository.getRecipe(recipeId);

    final response = await orchestrate(
      tool: 'generate_recipe_steps',
      context: {
        'recipe': recipe?.toJson(),
      },
      userMessage: 'Generate step-by-step instructions for this recipe',
    );

    return response.dbWrites
        .where((w) => w['table'] == 'wt_recipe_steps')
        .map((w) => RecipeStep.fromJson(w['data']))
        .toList();
  }
}
```

---

### 2.7 Offline Queue Management

**File**: `lib/shared/core/storage/offline_queue.dart`

**Isar Schema**:
```dart
@Collection()
class OfflineQueueItem {
  Id id = Isar.autoIncrement;

  late String table; // wt_pantry_items, wt_meals, etc.
  late String action; // insert, update, delete
  late Map<String, dynamic> data; // Serialized row data
  late String syncStatus; // pending, syncing, synced, error
  late String? errorMessage;

  late DateTime createdAt;
  late DateTime? syncedAt;
}
```

**Sync Logic** (on app startup + every 30 seconds if online):
1. Query all OfflineQueueItem with syncStatus='pending'
2. For each item:
   - Call Supabase client (RLS will validate)
   - If success: update syncStatus='synced', syncedAt=now()
   - If error: syncStatus='error', errorMessage=error.message
3. Show badge if any items with syncStatus='error'

---

### 2.8 Testing Requirements

**Unit Tests** (`test/unit/`):

```dart
// test/unit/features/recipes/domain/use_cases/generate_recipes_test.dart
void main() {
  group('GenerateRecipes UseCase', () {
    test('returns recipes when AI call succeeds', () async {
      // Arrange
      final mockAIClient = MockAIOrchestrationClient();
      final useCase = GenerateRecipesUseCase(mockAIClient);

      when(mockAIClient.generateRecipes(any, any))
          .thenAnswer((_) async => [mockRecipe1, mockRecipe2]);

      // Act
      final result = await useCase(
        pantryItems: [mockItem1, mockItem2],
        preferences: 'vegan',
      );

      // Assert
      expect(result, [mockRecipe1, mockRecipe2]);
    });

    test('returns empty list when offline', () async {
      // Mock offline condition
      // Verify fallback to cached recipes
    });
  });
}
```

**Widget Tests** (`test/widget/`):

```dart
// test/widget/features/pantry/screens/pantry_screen_test.dart
void main() {
  group('PantryScreen', () {
    testWidgets('displays pantry items grouped by category', (tester) async {
      // Build screen with mock data
      await tester.pumpWidget(createTestApp());

      // Verify items appear in correct categories
      expect(find.text('Fridge'), findsOneWidget);
      expect(find.text('Chicken'), findsOneWidget);
    });

    testWidgets('adds pantry item on button tap', (tester) async {
      await tester.pumpWidget(createTestApp());

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Enter item details
      await tester.enterText(find.byType(TextField), 'Tomatoes');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify item added to list
      expect(find.text('Tomatoes'), findsOneWidget);
    });
  });
}
```

**Integration Tests** (`test/integration/`):

```dart
// test/integration/pantry_to_meal_flow_test.dart
void main() {
  group('Pantry → Recipe → Prep → Meal Log Flow', () {
    test('end-to-end flow completes successfully', () async {
      // 1. Add pantry items
      // 2. Generate recipes via AI
      // 3. Select recipe
      // 4. View recipe steps
      // 5. Log meal with nutrients
      // 6. Verify meal + nutrients saved to DB
      // 7. Verify pantry items consumed
    });

    test('offline flow queues operations for sync', () async {
      // 1. Set network offline
      // 2. Perform entire flow
      // 3. Verify operations queued
      // 4. Set network online
      // 5. Verify queue flushed
    });
  });
}
```

**Target Coverage**: > 80% (unit + integration)

---

## 3. Implementation Plan

### Phase 5a: Schema Validation (0.5 days)

1. **Verify Phase 1 migrations created all required tables**
   - `wt_pantry_items`, `wt_recipes`, `wt_recipe_steps`, `wt_recipe_ingredients`
   - `wt_meals`, `wt_meal_nutrient_breakdown`, `wt_leftovers`
   - Check RLS policies (profile-scoped)

2. **Add missing indexes** (for performance):
   ```sql
   CREATE INDEX idx_pantry_items_profile_id ON wt_pantry_items(profile_id);
   CREATE INDEX idx_recipes_user_id ON wt_recipes(user_id);
   CREATE INDEX idx_meals_profile_id_logged_at ON wt_meals(profile_id, logged_at DESC);
   ```

3. **Validate data types & constraints** (nullable fields, defaults, etc.)

**Validation**: Run `supabase db push` locally; verify schema matches CLAUDE.md

---

### Phase 5b: Data Models & Repositories (1 day)

1. **Create Dart entities**
   - `lib/features/recipes/domain/entities/recipe.dart`
   - `lib/features/meals/domain/entities/meal.dart`
   - `lib/features/pantry/domain/entities/pantry_item.dart`
   - Model enum types: RecipeSource, Difficulty, NutritionScore, PantryCategory

2. **Create repository interfaces**
   - `lib/features/recipes/domain/repositories/recipe_repository.dart`
   - `lib/features/pantry/domain/repositories/pantry_repository.dart`
   - `lib/features/meals/domain/repositories/meal_repository.dart`

3. **Implement repositories (Supabase + Isar)**
   - `lib/features/recipes/data/repositories/recipe_repository_impl.dart`
   - Use Supabase for online queries; Isar for cache + offline queue

4. **Add JSON serialization** (json_serializable)
   - `@JsonSerializable()` on entities
   - Run `dart run build_runner build`

**Validation**: Unit tests for each repository method

---

### Phase 5c: Offline Queue & Sync (1 day)

1. **Define OfflineQueueItem Isar schema**
   - `lib/shared/core/storage/models/offline_queue_item.dart`

2. **Implement OfflineQueueManager**
   - Methods: enqueue(), sync(), getSyncStatus()
   - Test: verify queue persists across app restarts

3. **Wire into App initialization**
   - On app startup: flush queue if online
   - Every 30 seconds (while app running): check if online, flush queue

4. **Add visual indicators**
   - Badge on Pantry/Meals screens if items pending sync
   - Toast on successful sync

**Validation**: Integration test for offline → online sync flow

---

### Phase 5d: Riverpod Providers (1 day)

1. **Create provider file**: `lib/features/recipes/domain/providers/recipe_providers.dart`

2. **Implement providers**:
   - `pantryItemsProvider`
   - `addPantryItemProvider`
   - `generateRecipesProvider`
   - `recipeStepsProvider`
   - `mealLoggingProvider`

3. **Test providers** with mock repositories

**Validation**: Unit tests for provider logic; E2E test with real Supabase (dev instance)

---

### Phase 5e: UI Screens (2–3 days)

1. **PantryScreen**
   - List view with category tabs
   - Add/delete/edit items
   - Empty state + loading state

2. **RecipeGenerationScreen**
   - Pantry items as pills
   - Preferences input
   - Recipe card list + loading/error states

3. **RecipeDetailScreen**
   - Full recipe view
   - Nutrition breakdown
   - Ingredients list

4. **PrepWalkthroughScreen**
   - Step carousel/list
   - Timer modal
   - Ingredients checklist

5. **MealLoggingSheet**
   - Meal summary + nutrition
   - Leftover capture
   - Save meal action

6. **Shared widgets**:
   - RecipeCard, IngredientTile, NutritionBadge, TimerWidget

**Validation**: Widget tests for each screen; manual testing on iOS + Android

---

### Phase 5f: AI Orchestrator Integration (1–2 days)

1. **Implement AIOrchestrationClient** (wrapper around Supabase Edge Functions)
   - Method: `orchestrate(tool, context, userMessage)`
   - Error handling: network errors, rate limits, validation errors

2. **Implement helper methods**:
   - `generateRecipes(items, preferences)`
   - `generateSteps(recipeId)`

3. **Integrate into repositories**:
   - RecipeRepository calls AI client for `generateRecipesFromPantry()`

4. **Test with AI Orchestrator** (Phase 4 must be complete)
   - Verify request/response contracts match
   - Test dry-run mode

**Validation**: Integration test with Phase 4 Edge Function; mock tests

---

### Phase 5g: Integration & E2E Testing (1–2 days)

1. **Write integration tests**:
   - Pantry add → recipe generation → meal log flow
   - Offline scenario: all operations queued, then synced
   - Error handling: AI call fails, DB write fails, network offline

2. **E2E tests on both platforms**:
   - iOS simulator: test UI, notifications, persistence
   - Android emulator: same

3. **Smoke tests**:
   - App launches
   - Auth works
   - Pantry/recipes/meals screens load
   - No crashes

**Validation**: All tests pass; no console errors; app builds for release

---

## 4. Success Criteria

- [ ] All Phase 1 schema tables exist with correct columns & RLS policies
- [ ] Data models (Recipe, Meal, PantryItem, etc.) defined and serializable
- [ ] Repositories implemented for all three domains (recipes, meals, pantry)
- [ ] Offline queue persists & syncs correctly on reconnection
- [ ] PantryScreen: add/remove items; group by category
- [ ] RecipeGenerationScreen: call AI; display 5-10 recipes with tags & nutrition score
- [ ] RecipeDetailScreen: view recipe details; tap "Start Cooking"
- [ ] PrepWalkthroughScreen: step-by-step with timers + checklist
- [ ] MealLoggingSheet: log meal + auto-extracted nutrients
- [ ] Leftovers captured and pantry updated accordingly
- [ ] AI Orchestrator integration works (calls generate_pantry_recipes + generate_recipe_steps)
- [ ] All UI states tested: loading, error, empty, success
- [ ] Offline-first verified: operations queue and sync on reconnection
- [ ] Unit tests: > 80% coverage (models, repositories, providers)
- [ ] Integration tests: end-to-end flow passes
- [ ] E2E tests: both iOS + Android; no crashes
- [ ] All code follows GLOBAL_RULES.md & CLAUDE.md conventions

---

## 5. Failure Prevention & Known Risks

| Risk | Mitigation |
|------|-----------|
| AI response doesn't conform to expected schema | Mock AI responses in tests; validate response structure before parsing |
| Offline queue loses data on app crash | Isar provides ACID guarantees; test with forced kill |
| Nutrient extraction inaccurate | AI returns structured JSON; validate numeric ranges in safety checks |
| Pantry items not consumed correctly | Unit test consumption logic; verify DB state after meal log |
| Meal nutrition doesn't match recipe | Use AI-extracted values from generate_recipe_steps; allow user edit |
| RLS prevents data access | Test with different user accounts; verify profile_id scoping |
| Sync fails silently | Retry logic with exponential backoff; show error badge + user notification |
| Timer doesn't fire offline | Timer is local state; test offline behavior |
| Network call timeout | Implement 30-second timeout; show error + retry option |
| Duplicate recipes created | De-duplicate by title + source; check for existing recipe before saving |

---

## 6. Dependencies & Prerequisites

**Must Be Complete Before Starting Phase 5**:
- [x] Phase 1: Supabase schema + RLS (all tables created)
- [x] Phase 2: Flutter scaffold + auth + offline engine (Isar + Supabase client set up)
- [x] Phase 4: AI Orchestrator Edge Function (`/ai/orchestrate` endpoint + 2 tools: generate_pantry_recipes, generate_recipe_steps)

**Phase 3 (Health Metrics)** can proceed in parallel; not blocking for MVP.

**Environment Setup**:
- Local Supabase running: `supabase start`
- Flutter dev environment: `flutter --version`
- AI Orchestrator deployed or running locally: `supabase functions serve`

---

## 7. Test Plan

### Unit Tests (40% of time)
- **Models**: JSON serialization/deserialization
- **Repositories**: CRUD operations, queries
- **Providers**: state updates, async handling
- **Offline Queue**: enqueue, sync, error handling
- **AI Client**: request/response formatting, error handling

**Coverage Target**: > 80%

### Widget Tests (30% of time)
- **PantryScreen**: add item, delete item, filter by category
- **RecipeGenerationScreen**: generate, display, error state
- **RecipeDetailScreen**: load recipe, view nutrition
- **PrepWalkthroughScreen**: step navigation, timer, checklist
- **MealLoggingSheet**: logging, nutrient display

**Coverage Target**: All screens tested; > 70% coverage

### Integration Tests (20% of time)
- **Full flow**: pantry add → recipe generation → meal log
- **Offline scenario**: operations queue and sync
- **Error scenarios**: AI fails, DB fails, network offline
- **RLS enforcement**: user A can't access user B's data

**Coverage Target**: All critical paths tested

### E2E Tests (10% of time)
- **iOS**: run on simulator; verify no crashes
- **Android**: run on emulator; verify no crashes
- **Manual smoke test**: launch → auth → pantry → recipes → prep → log meal

---

## 8. Rollout Plan

### Week 1: Schema & Data Layer
- Validate Phase 1 schema; add indexes
- Create models + repositories
- Unit test repositories

### Week 2: Offline & Providers
- Implement offline queue
- Create Riverpod providers
- Integration test offline sync

### Week 3: UI (Part 1)
- PantryScreen + AddItemDialog
- RecipeGenerationScreen + RecipeCard
- Widget tests

### Week 4: UI (Part 2)
- RecipeDetailScreen
- PrepWalkthroughScreen + Timer
- MealLoggingSheet
- Widget tests

### Week 5: Integration & Testing
- AI Orchestrator integration (assuming Phase 4 done)
- Full integration tests
- E2E tests on both platforms
- Bug fixes

### Week 6: Polish & Deploy
- Performance optimization
- Accessibility audit
- Final E2E testing
- Merge to main

---

## 9. Open Questions & Decisions

1. **Nutrition extraction accuracy**: AI generates nutrition breakdown. Should app validate against USDA database? (MVP: trust AI; Phase 6+: add validation)
2. **Recipe sharing**: MVP is user-only recipes. Phase 6+: add community recipes?
3. **Serving size adjustments**: Should changing servings auto-adjust nutrition? (MVP: yes, multiply)
4. **Leftover storage**: Should app auto-suggest leftover recipes? (MVP: no; Phase 6+: yes)
5. **Multi-language support**: MVP: English only. Phase 6+: localization?
6. **Allergen tracking**: Should pantry items have allergen tags? (MVP: no; Phase 6+: yes)

---

## 10. Sign-Off

**Prepared by**: WellTrack Development Team
**Date**: 2026-02-15
**Status**: APPROVED FOR IMPLEMENTATION
**Confidence**: 7/10

**Rationale for 7/10 Confidence**:
- ✅ Clear requirements (Pantry → Recipes → Prep workflow well-defined)
- ✅ All tables designed in Phase 1
- ✅ AI Orchestrator interface defined (Phase 4)
- ⚠️ AI integration adds complexity; response parsing must be robust
- ⚠️ Offline sync is non-trivial; requires careful error handling
- ⚠️ Timer & UI state management (PrepWalkthroughScreen) can be tricky

**Risk Mitigation**: Heavy integration testing; mock AI responses early; validate offline queue thoroughly.

**Next Steps**:
1. Verify Phase 1 schema exists (run `supabase db push` locally)
2. Verify Phase 4 AI Orchestrator is ready
3. Begin Phase 5a: Schema validation
4. Create feature branch: `feature/phase5-pantry-recipes`
5. Implement in order: schema → data models → offline → UI → integration
