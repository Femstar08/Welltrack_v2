# PRD: Meals v4 — Enhanced FAB Bottom Sheet

**Document ID**: PRD-MEALS-V4-002
**Status**: Draft
**Created**: 2026-03-16
**Author**: Business Analysis
**Branch**: ralph/phase-13-ux-refinement
**Related PRDs**: PRD-MEALS-V4-001 (Dashboard Widgets), PRD-MEALS-V4-003 (Navigation Architecture)

---

## 1. Overview

This PRD defines the replacement of the current FAB (Floating Action Button) bottom sheet with a structured two-section layout: a 2x2 grid of primary logging actions and a vertical list of secondary actions. The design is inspired by MyFitnessPal's logging entry patterns but is tailored to WellTrack's performance identity — recovery data drives AI suggestions, and advanced logging modes (Voice, Meal Scan) are gated as PRO features.

### 1.1 Product Context

The FAB is the highest-frequency entry point in the app. Every meal, water log, weight entry, and exercise record starts here. The current implementation is a flat list that buries important actions. The v4 redesign promotes the four most common actions to a visual 2x2 grid and keeps secondary actions accessible below without overwhelming the user.

The WellTrack-specific additions from v4 (AI Suggestions, From Recipes, Quick Add) are preserved and integrated into the list section. This bottom sheet is the gateway to all logging flows, and it must be fast to open, visually clear, and respectful of the freemium boundary.

### 1.2 Non-Negotiables

- The FAB opens a modal bottom sheet — it does not push a full route
- Voice Log and Meal Scan are always visible but always locked for free users — never hidden entirely
- PRO gates use `FreemiumGateInline` or a locked tile overlay, not route-level guards, so free users understand what they are missing
- AI Suggestions must not call the AI directly — the suggestions are pre-computed by the prescription engine and fetched via a provider
- All navigation from the sheet uses `context.go()` (GoRouter) — never `Navigator.pushNamed()`

---

## 2. Bottom Sheet Layout

### 2.1 Visual Structure

```
┌─────────────────────────────────────┐
│  ── (drag handle) ──                │
│                                     │
│  Log Food          Barcode Scan     │
│  [search icon]     [barcode icon]   │
│  (blue)            (pink)           │
│                                     │
│  Voice Log         Meal Scan        │
│  [mic icon]        [camera icon]    │
│  (purple) PRO      (teal) PRO       │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  > Water                            │
│  > Weight                           │
│  > Exercise                         │
│  > AI Suggestions (PRO)             │
│  > From Recipes                     │
│  > Quick Add                        │
└─────────────────────────────────────┘
```

The divider between grid and list is a 1px `Divider` with 16dp vertical padding. The sheet has a drag handle at the top and uses `DraggableScrollableSheet` to allow expansion if the list grows.

---

## 3. Primary Grid Actions (2x2)

### 3.1 Log Food

**ID**: US-MEALS-V4-007
**Epic**: Enhanced FAB — Primary Actions
**Priority**: High

**As a** WellTrack user
**I want** to tap a clearly labelled "Log Food" button in the FAB sheet
**So that** I can quickly search for and add food items to my diary

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Log Food", then the sheet dismisses and navigation goes to `/meals/food-search`
- [ ] Given the food search screen opens, when a food item is selected, then the meal is logged to `wt_meals` and the user is returned to the previous screen
- [ ] Given the FAB sheet is open, when it renders, then "Log Food" tile shows a search icon on a blue background with the label "Log Food" centred beneath it
- [ ] Given any tier user opens the sheet, then "Log Food" is always accessible with no gate

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Grid tile widget: `FabActionTile` — a `Material` widget with `InkWell`, `Column` (icon container + label text)
- Background color passed as parameter: `Color(0xFF2196F3)` (blue) for this tile
- On tap: `context.go('/meals/food-search')`; sheet closed first via `Navigator.pop(context)` then `context.go`
- Icon: `Icons.search`

---

### 3.2 Barcode Scan

**ID**: US-MEALS-V4-008
**Epic**: Enhanced FAB — Primary Actions
**Priority**: High

**As a** WellTrack user
**I want** to open a barcode scanner directly from the FAB sheet
**So that** I can log packaged food items by scanning their barcode rather than typing

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Barcode Scan", then the sheet dismisses and navigation goes to `/meals/barcode-scan`
- [ ] Given the barcode scanner opens, when a valid barcode is scanned, then the app queries Open Food Facts (`https://world.openfoodfacts.org/api/v0/product/{barcode}.json`) and presents the food item for confirmation
- [ ] Given a barcode returns no result from Open Food Facts, when the lookup fails, then the user sees "Product not found — add manually?" with a CTA to manual entry on the food search screen
- [ ] Given the barcode scan screen is open and the user taps the back button, when navigation occurs, then the user returns to the previous screen (diary or dashboard) — not the FAB sheet
- [ ] Given the FAB sheet is open, when it renders, then "Barcode Scan" tile shows a barcode icon on a pink/rose background with the label "Barcode Scan" beneath it
- [ ] Given any tier user opens the sheet, then "Barcode Scan" is always accessible with no gate

#### Acceptance Criteria — Edge Cases

- [ ] Given the device camera permission has not been granted, when the user taps "Barcode Scan", then the app requests the `CAMERA` permission before opening the scanner
- [ ] Given the permission is denied, when the app handles the denial, then a snackbar informs the user "Camera permission required for barcode scanning"

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Background color: `Color(0xFFE91E8C)` (pink/rose)
- Icon: `Icons.barcode_reader` or `Icons.qr_code_scanner`
- Route: `/meals/barcode-scan` — a new route wrapping `FoodBarcodeScannerScreen` which already exists at `lib/features/meals/presentation/food_search_screen.dart` (the `FoodBarcodeScannerScreen` class). The route is currently registered as `/meals/food-barcode-scan` — the FAB should navigate to this existing route
- On tap: `Navigator.pop(context)` to dismiss sheet, then `context.go('/meals/food-barcode-scan')`

---

### 3.3 Voice Log (PRO — Future Feature)

**ID**: US-MEALS-V4-009
**Epic**: Enhanced FAB — Primary Actions
**Priority**: Low (PRO, future release)

**As a** WellTrack PRO user
**I want** to log food by speaking naturally into my phone
**So that** I can record meals hands-free without searching or scanning

#### Acceptance Criteria

- [ ] Given any user opens the FAB sheet, when the sheet renders, then the "Voice Log" tile is always visible with a mic icon on a purple background
- [ ] Given a free user taps "Voice Log", when the tap occurs, then the sheet dismisses and navigation goes to `/paywall` with the feature name "Voice Food Logging"
- [ ] Given a PRO user taps "Voice Log", when the tap occurs, then the sheet dismisses and navigation goes to `/meals/voice-log`
- [ ] Given the `/meals/voice-log` route is not yet implemented, when a PRO user taps the tile, then a `SnackBar` displays "Voice logging coming soon — stay tuned" and the sheet closes
- [ ] Given the "Voice Log" tile renders for any user, then a "PRO" badge is visible in the top-right corner of the tile

#### Voice Log Behaviour (When Implemented — Future Sprint)

The `/meals/voice-log` screen will:
- Open the device microphone using `speech_to_text` package
- Transcribe the user's speech (e.g., "two scrambled eggs and a slice of toast")
- Pass the transcription to `ai_orchestrator_service.dart` for food identification
- Return a list of matched food items for the user to confirm
- Log confirmed items to `wt_meals`

This behaviour is documented here for planning but is **not in scope for the current implementation sprint**. The tile must show the locked/coming-soon state.

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See Voice Log tile | Yes — with PRO badge | Yes — with PRO badge |
| Access Voice Log screen | No — redirects to paywall | Yes — screen (future) |

#### Flutter Implementation Notes

- Background color: `Color(0xFF9C27B0)` (purple)
- Icon: `Icons.mic_outlined`
- PRO badge: `Container(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)), child: Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))`
- Gate check: `ref.read(planTierProvider) == PlanTier.pro`
- Current implementation: always show snackbar "coming soon" for PRO users too, until feature is built

---

### 3.4 Meal Scan (PRO — Future Feature)

**ID**: US-MEALS-V4-010
**Epic**: Enhanced FAB — Primary Actions
**Priority**: Low (PRO, future release)

**As a** WellTrack PRO user
**I want** to photograph my meal and have WellTrack identify the foods automatically
**So that** I can log restaurant meals and home-cooked food without searching for each ingredient

#### Acceptance Criteria

- [ ] Given any user opens the FAB sheet, when the sheet renders, then the "Meal Scan" tile is always visible with a camera icon on a teal background
- [ ] Given a free user taps "Meal Scan", when the tap occurs, then the sheet dismisses and navigation goes to `/paywall` with the feature name "AI Meal Scanner"
- [ ] Given a PRO user taps "Meal Scan", when the tap occurs, then the sheet dismisses and navigation goes to `/meals/meal-scan`
- [ ] Given the `/meals/meal-scan` route is not yet implemented, when a PRO user taps the tile, then a `SnackBar` displays "Meal scanning coming soon — stay tuned" and the sheet closes
- [ ] Given the "Meal Scan" tile renders for any user, then a "PRO" badge is visible in the top-right corner of the tile

#### Meal Scan Behaviour (When Implemented — Future Sprint)

The `/meals/meal-scan` screen will:
- Open the device camera using `image_picker`
- Send the captured image to `ai_orchestrator_service.dart` with the `identify_meal_photo` tool
- Return a list of identified food items with confidence scores
- Allow the user to confirm, adjust portions, or remove items
- Log confirmed items to `wt_meals`

This behaviour is documented here for planning but is **not in scope for the current implementation sprint**.

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See Meal Scan tile | Yes — with PRO badge | Yes — with PRO badge |
| Access Meal Scan screen | No — redirects to paywall | Yes — screen (future) |

#### Flutter Implementation Notes

- Background color: `Color(0xFF009688)` (teal)
- Icon: `Icons.camera_alt_outlined`
- Same PRO badge implementation as Voice Log tile

---

## 4. Secondary List Actions

The list section sits below the grid, separated by a `Divider`. Each item is a `ListTile` with a leading icon, title, and trailing `Icon(Icons.chevron_right)`. Tapping an item dismisses the sheet and navigates or performs an action.

---

### 4.1 Water

**ID**: US-MEALS-V4-011
**Epic**: Enhanced FAB — Secondary Actions
**Priority**: Medium

**As a** WellTrack user
**I want** to quickly log a cup of water from the FAB sheet
**So that** I can track my daily hydration without navigating to a separate screen

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Water", then a bottom sub-sheet or inline stepper opens allowing the user to increment water cups (default increment: 1 cup / 250ml)
- [ ] Given the user confirms the water log, when the confirmation occurs, then the record is saved to `wt_water_logs` (or `wt_health_metrics` with `metric_type: 'water'`) and a success snackbar appears
- [ ] Given the sheet is open, when the Water tile renders, then it shows a water drop icon, the label "Water", and today's cup count as a trailing hint (e.g., "3 cups today")
- [ ] Given any tier user taps Water, then it is always accessible with no gate

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Leading icon: `Icons.water_drop_outlined` in blue
- Trailing: today's cup count from `waterLogProvider(profileId)`
- On tap: show `showModalBottomSheet` (nested) with a cup stepper (+/- buttons) and a "Log" button
- On confirm: call `waterLogRepository.addLog(profileId, cups: n)` and `Navigator.pop` twice (stepper + main sheet)
- New provider: `waterLogProvider(profileId)` → `FutureProvider.family` returning today's total cups

---

### 4.2 Weight

**ID**: US-MEALS-V4-012
**Epic**: Enhanced FAB — Secondary Actions
**Priority**: Medium

**As a** WellTrack user
**I want** to log my current weight from the FAB sheet
**So that** I can record my weight quickly and see it reflected in the dashboard weight trend chart

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Weight", then the sheet dismisses and navigation goes to `/weight/log`
- [ ] Given the weight log screen opens, when the user enters a weight value and taps Save, then the weight is saved to `wt_health_metrics` with `metric_type: 'weight'` and the user is returned to the previous screen
- [ ] Given the FAB sheet renders, when it shows the Weight item, then it displays a scale icon and the label "Weight"
- [ ] Given any tier user taps Weight, then it is always accessible with no gate

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Leading icon: `Icons.monitor_weight_outlined` in grey
- On tap: `Navigator.pop(context)` then `context.go('/weight/log')`
- The `/weight/log` route is new — see PRD-MEALS-V4-003

---

### 4.3 Exercise

**ID**: US-MEALS-V4-013
**Epic**: Enhanced FAB — Secondary Actions
**Priority**: Medium

**As a** WellTrack user
**I want** to log a manual exercise entry from the FAB sheet
**So that** I can add exercise that was not tracked by a wearable and have it count toward my calorie budget

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Exercise", then the sheet dismisses and navigation goes to `/workouts` (the workouts hub)
- [ ] Given the user navigates to workouts, when they start or log a session, then the exercise calories feed back to the calories remaining calculation on the dashboard carousel
- [ ] Given the FAB sheet renders, when it shows the Exercise item, then it displays a fitness icon and the label "Exercise"
- [ ] Given any tier user taps Exercise, then it is always accessible with no gate

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Leading icon: `Icons.fitness_center_outlined` in orange
- On tap: `Navigator.pop(context)` then `context.go('/workouts')`

---

### 4.4 AI Suggestions (PRO)

**ID**: US-MEALS-V4-014
**Epic**: Enhanced FAB — WellTrack Additions
**Priority**: High

**As a** WellTrack PRO user
**I want** to see AI-generated meal suggestions based on my remaining macros and recovery data
**So that** I can eat foods that support my recovery and hit my nutrition targets without manual searching

#### Acceptance Criteria

- [ ] Given a PRO user with today's prescription data available opens the FAB sheet, when the sheet renders, then the "AI Suggestions" list item shows a sparkle icon and the label "AI Suggestions"
- [ ] Given a PRO user taps "AI Suggestions", when the tap occurs, then the sheet dismisses and navigation goes to a meal suggestions view (reuse `RecipeSuggestionsScreen` or create `MealSuggestionsSheet`) filtered by remaining macros
- [ ] Given a free user taps "AI Suggestions", when the tap occurs, then the sheet dismisses and navigation goes to `/paywall` with feature name "AI Meal Suggestions"
- [ ] Given a PRO user taps "AI Suggestions", when suggestions are displayed, then each suggestion shows: food name, calories, macro split, and a one-tap "Add to diary" action
- [ ] Given the FAB sheet renders, when the AI Suggestions item renders for any user, then a "PRO" text label appears in the trailing position for free users; for PRO users a chevron appears

#### Suggestions Data Source

AI Suggestions are NOT generated in real time from within the FAB sheet. They are:
1. Pre-fetched on dashboard load by `mealSuggestionsProvider(profileId)` — a `FutureProvider.family`
2. `mealSuggestionsProvider` reads today's remaining macros from `todayMacroSummaryProvider`
3. It queries `ai_orchestrator_service.dart` with `workflow_type: 'meal_suggestions'` and the remaining macro context
4. Suggestions are cached for the session and reused when the FAB sheet opens

This ensures no AI latency when the sheet opens, and no direct AI calls from presentation layer widgets.

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See AI Suggestions item | Yes — with PRO badge | Yes |
| Access suggestions | No — redirects to paywall | Yes — shows pre-fetched suggestions |
| Remaining macro context | N/A | Yes — from `todayMacroSummaryProvider` |

#### Flutter Implementation Notes

- Leading icon: `Icons.auto_awesome_outlined` in amber/gold
- Gate check: `ref.read(planTierProvider) == PlanTier.pro`
- Pre-fetch: `ref.read(mealSuggestionsProvider(profileId))` — initiated on dashboard mount, not on FAB open
- New provider: `mealSuggestionsProvider(profileId)` → `FutureProvider.family` returning `List<MealSuggestionItem>`
- `MealSuggestionItem`: value class `{name, calories, carbsG, fatG, proteinG, reasoning}`

---

### 4.5 From Recipes

**ID**: US-MEALS-V4-015
**Epic**: Enhanced FAB — WellTrack Additions
**Priority**: Medium

**As a** WellTrack user
**I want** to log a meal directly from my saved recipes
**So that** I can quickly record home-cooked meals I prepare regularly

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "From Recipes", then the sheet dismisses and navigation goes to `/recipes` with a `selectMode: true` query parameter
- [ ] Given the recipe list screen opens in select mode, when the user taps a recipe, then the recipe's nutrition info is pre-filled in the meal log screen ready for confirmation
- [ ] Given the FAB sheet renders, when it shows the "From Recipes" item, then it displays a book icon and the label "From Recipes"
- [ ] Given any tier user taps From Recipes, then it is always accessible with no gate (recipe browsing is free)

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Leading icon: `Icons.menu_book_outlined` in green
- On tap: `Navigator.pop(context)` then `context.go('/recipes?selectMode=true')`
- The `RecipeListScreen` must handle the `selectMode` query parameter and show a "Use this recipe" button per item instead of the usual "View" action

---

### 4.6 Quick Add

**ID**: US-MEALS-V4-016
**Epic**: Enhanced FAB — WellTrack Additions
**Priority**: Medium

**As a** WellTrack user
**I want** to manually enter calories and macros without searching a food database
**So that** I can log meals where I know the nutrition values but the item is not in the food database

#### Acceptance Criteria

- [ ] Given the FAB sheet is open, when the user taps "Quick Add", then a bottom sub-sheet opens with a form containing: Meal Type dropdown (Breakfast/Lunch/Dinner/Snack), Calories (required), Protein g (optional), Carbs g (optional), Fat g (optional), and a "Log" button
- [ ] Given the user fills in at least the Calories field and taps "Log", when the save occurs, then a `MealEntity` is created with `name: 'Quick Add'`, the entered nutrition values in `nutritionInfo`, and the selected meal type
- [ ] Given the user taps "Log" with an empty Calories field, when validation runs, then an inline error "Calories are required" appears and the save is blocked
- [ ] Given the save succeeds, when the confirmation occurs, then a success snackbar appears and both the sub-sheet and the FAB sheet close
- [ ] Given any tier user taps Quick Add, then it is always accessible with no gate

#### Freemium Gating

Fully free. No gate.

#### Flutter Implementation Notes

- Leading icon: `Icons.add_circle_outline` in grey
- Sub-sheet: a `StatefulWidget` (local state for form fields) shown via `showModalBottomSheet`
- On save: call `mealRepository.logMeal(...)` with `name: 'Quick Add'`, `nutritionInfo: {calories: n, ...}`
- Validation: `formKey.currentState!.validate()`

---

## 5. Bottom Sheet Container

### 5.1 Container Behaviour

**ID**: US-MEALS-V4-017
**Epic**: Enhanced FAB — Container
**Priority**: High

**As a** WellTrack user
**I want** the FAB bottom sheet to open smoothly, be easy to dismiss, and clearly communicate which actions are available
**So that** logging is a friction-free experience I use habitually

#### Acceptance Criteria

- [ ] Given the user taps the central FAB "+" button, when the tap occurs, then the FAB bottom sheet opens using `showModalBottomSheet` with `isScrollControlled: true` and a drag handle visible at the top
- [ ] Given the sheet is open, when the user swipes down or taps the scrim, then the sheet dismisses and the user returns to where they were
- [ ] Given the sheet is open, when it renders on a device with a small screen height (< 700dp), then the sheet is scrollable to reveal all list items without clipping
- [ ] Given the sheet is open, when it renders, then a section header "Log" appears above the 2x2 grid and a section header "Track" appears above the list
- [ ] Given the sheet is open on a device with bottom system navigation (gesture nav bar), then the sheet content respects `MediaQuery.of(context).padding.bottom` with appropriate padding
- [ ] Given the FAB is the existing app FAB (central "+" in bottom nav), when the sheet is triggered, then the existing FAB tap handler is replaced — the sheet is the new handler

#### Flutter Implementation Notes

- Trigger: modify `ScaffoldWithBottomNav` (or the existing FAB handler) to call `_openLogSheet(context)` instead of the current action
- Sheet builder: `EnhancedLogBottomSheet` — a `ConsumerWidget` passed to `showModalBottomSheet`
- `DraggableScrollableSheet` with `initialChildSize: 0.55`, `minChildSize: 0.4`, `maxChildSize: 0.9`
- Internal structure: `Column` with drag handle → section header "Log" → `GridView` (2x2, shrinkWrap) → `Divider` → section header "Track" → `ListView` (shrinkWrap) → bottom safe area padding
- The sheet does not use `go_router` itself — it is a modal overlay; all navigation from within uses `Navigator.pop` + `context.go`

---

## 6. Provider Summary

New Riverpod providers introduced by this PRD:

| Provider | Type | Returns | Depends On |
|----------|------|---------|------------|
| `waterLogProvider(profileId)` | `FutureProvider.family` | `int` — today's total cups | `waterLogRepository` |
| `mealSuggestionsProvider(profileId)` | `FutureProvider.family` | `List<MealSuggestionItem>` | `todayMacroSummaryProvider`, `aiOrchestratorService` |

---

## 7. New Data Model

### 7.1 MealSuggestionItem

A value object (not persisted) used only for displaying AI-generated suggestions in the FAB sheet:

```
MealSuggestionItem {
  String name          // e.g., "Greek yogurt with berries"
  int calories         // e.g., 180
  int carbsG           // e.g., 22
  int fatG             // e.g., 3
  int proteinG         // e.g., 18
  String reasoning     // e.g., "High protein supports your recovery score target"
}
```

This is never stored in the database. When the user taps "Add to diary" on a suggestion, a `MealEntity` is created via `mealRepository.logMeal()` using the suggestion values.

---

## 8. Tile Color Palette

The 2x2 grid tiles use distinct background colors to provide visual differentiation:

| Tile | Color | Hex | Semantic Role |
|------|-------|-----|---------------|
| Log Food | Blue | `#2196F3` | Primary action — search |
| Barcode Scan | Pink | `#E91E8C` | Primary action — scan |
| Voice Log | Purple | `#9C27B0` | PRO — audio input |
| Meal Scan | Teal | `#009688` | PRO — AI vision |

These colors should be defined as constants in `lib/shared/core/constants/` to keep them consistent across the app.

---

## 9. Assumptions and Dependencies

### Assumptions

1. The existing `FoodBarcodeScannerScreen` in `food_search_screen.dart` can be navigated to from the FAB sheet via its existing route `/meals/food-barcode-scan`
2. `RecipeListScreen` can accept a `selectMode` query parameter; if not currently supported, a minor extension is required
3. The `PlanTier.pro` check via `planTierProvider` is the single source of truth for gate decisions — no additional feature flag is needed
4. Water logging writes to a table/entity that already exists or will be scaffolded as part of this sprint (not a dependency on another PRD)

### Dependencies

- **PRD-MEALS-V4-003 (Navigation Architecture)**: The routes `/meals/voice-log`, `/meals/meal-scan`, `/weight/log`, and `/water/log` are defined in PRD-MEALS-V4-003 and must be registered in `app_router.dart` before the FAB sheet can navigate to them
- **`mealSuggestionsProvider`**: Depends on `ai_orchestrator_service.dart` being able to accept `workflow_type: 'meal_suggestions'` with remaining macro context — requires backend Edge Function support

### Out of Scope

- Voice recognition implementation (documented as future state only)
- AI photo meal recognition implementation (documented as future state only)
- Persistent water logging history screen (only today's count is shown in FAB sheet)
- Barcode database lookup caching (handled by `food_search_provider.dart` which already has Hive caching logic)

---

## 10. Definition of Done

- [ ] `EnhancedLogBottomSheet` widget implemented and replaces existing FAB sheet handler
- [ ] All 10 action items (4 grid + 6 list) render correctly with correct icons and labels
- [ ] Voice Log and Meal Scan tiles show PRO badge and redirect free users to `/paywall`
- [ ] Voice Log and Meal Scan tiles show "coming soon" snackbar for PRO users (future feature placeholder)
- [ ] AI Suggestions pre-fetched via `mealSuggestionsProvider` — no AI calls triggered on sheet open
- [ ] Quick Add sub-sheet saves a valid `MealEntity` to `wt_meals`
- [ ] Water stepper sub-sheet saves to water log and shows today's count in the list item
- [ ] Sheet respects bottom safe area on gesture-navigation devices
- [ ] `flutter analyze` passes with zero warnings on all new files
- [ ] All navigation uses `context.go()` — no `Navigator.pushNamed()` calls

---

## 11. Glossary

| Term | Definition |
|------|------------|
| FAB | Floating Action Button — the central "+" button in the bottom navigation bar |
| PRO Badge | A small amber label reading "PRO" overlaid on a tile, indicating the feature requires a paid subscription |
| Snackbar | `ScaffoldMessenger.of(context).showSnackBar(...)` — a non-blocking bottom message bar |
| `selectMode` | Query parameter on `/recipes` that changes the recipe list into a selection UI for meal logging |
| AI Suggestions | Macro-matched meal recommendations generated by the AI orchestrator using remaining daily macros and recovery context; pre-fetched, not real-time |
