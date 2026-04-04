# Meal Generation UX Improvements

**Created**: 2026-03-29
**Source**: User feedback screenshots + review findings
**Status**: Ready for implementation

---

## Issues to Fix

### 1. Double FAB on Recipe Screen (Bug)

**Problem**: Recipe list screen has its own `FloatingActionButton` (recipe_list_screen.dart:135-138) AND the global FAB from `ScaffoldWithBottomNav` (scaffold_with_bottom_nav.dart) are both visible simultaneously, creating two overlapping green buttons.

**Fix**: Remove the local FAB from recipe_list_screen.dart. Move the "Add Recipe" options (AI Suggestions, Import URL, Import Photo) into the AppBar as an action button (popup menu or icon button that opens the existing bottom sheet).

**Files**: `lib/features/recipes/presentation/recipe_list_screen.dart`

---

### 2. Auto-Generate Meals Daily (PRO Feature)

**Problem**: User must manually tap "Generate Plan" every day. No auto-generation.

**Current state**: meal_plan_screen.dart:70-83 — `_generatePlan()` is manual only.

**Fix**:
- Add a toggle in settings: "Auto-generate daily meal plan" (PRO only)
- Store preference in wt_profiles or Hive: `auto_generate_meals: bool`
- On app launch (after morning check-in), check if today's meal plan exists. If not and toggle is on, auto-generate in background.
- Generation should use the day type from PrescriptionEngine (push/normal/easy/rest)
- Show a notification or banner: "Today's meal plan is ready"

**Files**:
- `lib/features/meals/presentation/meal_plan_screen.dart` (auto-trigger check)
- `lib/features/settings/presentation/settings_screen.dart` (toggle)
- New: `lib/features/meals/data/meal_auto_generator.dart`

---

### 3. Background Meal Generation (Don't Wait on Screen)

**Problem**: When generating recipes from pantry, user is stuck on recipe_suggestions_screen.dart watching a spinner. Takes 10-30 seconds. User cannot navigate away.

**Current state**: recipe_suggestions_screen.dart:101-117 shows blocking spinner.

**Fix**:
- Show a SnackBar "Generating meal suggestions..." and let user navigate away
- Use a background provider (StateNotifier) that continues generating even when screen is disposed
- When generation completes, show a notification or update a badge on the recipe tab
- If user returns to suggestions screen, show completed results

**Files**:
- `lib/features/recipes/presentation/recipe_suggestions_screen.dart`
- `lib/features/recipes/presentation/recipe_generation_provider.dart`

---

### 4. Pantry-Based Meal Generation (PRO Feature)

**Problem**: User should be able to enter ingredients they have in stock OR select from pantry to generate that day's meals.

**Current state**: pantry_screen.dart:203-236 has "Cook with these" button that passes available pantry items to recipe generation. This partially works but:
- Only generates recipes, not a full meal plan (breakfast/lunch/dinner/snack)
- No option to manually enter ingredients without adding to pantry first
- Not gated as PRO feature

**Fix**:
- Add "Generate from ingredients" option in the meal plan generation flow
- Show a text field + pantry selection UI before generation
- User can type ingredients freely OR tap pantry items to include
- Generated meal plan considers available ingredients
- Gate this feature as PRO (free users get standard generation without ingredient input)

**Files**:
- `lib/features/meals/presentation/meal_plan_screen.dart`
- New: `lib/features/meals/presentation/ingredient_selection_sheet.dart`

---

## Priority Order

| # | Issue | Effort | Priority |
|---|-------|--------|----------|
| 1 | Double FAB fix | 30 min | P0 — visible bug |
| 2 | Background generation | 2 hrs | P1 — UX blocker |
| 3 | Auto-generate daily | 3 hrs | P1 — PRO feature |
| 4 | Pantry-based generation | 4 hrs | P2 — PRO feature |
