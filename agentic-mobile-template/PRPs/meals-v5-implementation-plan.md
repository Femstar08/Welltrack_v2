# Meals v5 — Implementation Plan

**Document ID**: IMPL-MEALS-V5-001
**Status**: Ready for Development
**Created**: 2026-03-16
**Author**: Solutions Architect
**Source PRDs**: PRD-MEALS-V4-001, PRD-MEALS-V4-002, PRD-MEALS-V4-003
**Branch**: ralph/phase-13-ux-refinement

---

## 1. Executive Summary

This plan covers the concrete Flutter implementation for three PRDs delivered as a single sprint. The work divides into three natural workstreams:

- **Dashboard widgets** — six `ConsumerWidget`s embedded in `DashboardScreen`, each backed by new `FutureProvider.family` providers
- **Enhanced FAB** — replace the `ScaffoldWithBottomNav` FAB handler with a `DraggableScrollableSheet` bottom sheet containing a 2x2 action grid and a six-item list
- **Navigation** — register six new GoRouter routes in `app_router.dart` inside Branch 0 and update the `needsProfile` guard

No existing screen is deleted. All existing routes remain. The `DashboardScreen`, `ScaffoldWithBottomNav`, `app_router.dart`, and `RecipeListScreen` are the only existing files that receive modifications.

---

## 2. Codebase Observations (Pre-Implementation)

These are facts about the existing code that directly affect implementation decisions.

### 2.1 Freemium Gate Architecture

`FreemiumGate` and `FreemiumGateInline` in `freemium_gate_widget.dart` use `Navigator.of(context).push(MaterialPageRoute(...))` internally for paywall navigation — not GoRouter. This must be fixed in the new widgets. Every new widget that navigates to `/paywall` must call `context.push('/paywall')` directly rather than delegating to `FreemiumGate`'s internal navigator call. The `FreemiumGate` wrapper is still appropriate for full-page gating (e.g., `HeartHealthyCarouselPage`), but tap handlers in `CaloriesBudgetCarouselPage` and `DiscoverQuickAccessGrid` must implement their own GoRouter-based navigation logic rather than relying on `FreemiumGate._navigateToPaywall`.

### 2.2 Plan Tier Provider

There is no `planTierProvider` in the codebase today. The existing `currentPlanTierProvider` is a `FutureProvider.autoDispose<PlanTier>` in `freemium_repository.dart`. All new widgets must watch `currentPlanTierProvider` for gate checks. A synchronous alias `planTierProvider` is not needed — widgets handle the `AsyncValue<PlanTier>` with `.when()` or `.valueOrNull`.

### 2.3 Prescription Engine Provider

The `PrescriptionEngine` class is a pure-Dart static utility (`prescription_engine.dart`). There is no `prescriptionEngineProvider`. Today's prescription is fetched via `DailyPrescriptionRepository.getTodayPrescription(profileId)` through `dailyPrescriptionRepositoryProvider`. The calorie adjustment for PRO users is derived from `DailyPrescriptionEntity.calorieModifier` (absolute kcal offset) and `DailyPrescriptionEntity.calorieAdjustmentPercent` applied on top of the `NutritionTargetsState` base calories. The `todayCalorieSummaryProvider` must compose these two values — base from `nutritionTargetsProvider` multiplied by `(1 + calorieAdjustmentPercent)` plus `calorieModifier`.

### 2.4 Day Type Mapping

`DailyPrescriptionEntity.planType` is a `PlanType` enum (`push`, `normal`, `easy`, `rest`). The `nutritionTargetsProvider` `NutritionTargetsState.forDayType(String dayType)` accepts `'strength'`, `'cardio'`, `'rest'`. The mapping is: `push` → `'strength'`, `normal` → `'cardio'`, `easy` → `'rest'`, `rest` → `'rest'`. This mapping belongs in the `todayCalorieSummaryProvider` implementation, not in the widget layer.

### 2.5 Recovery Score Access Pattern

`RecoveryScoreEntity` is loaded via `InsightsNotifier` in `insightsProvider`. There is no standalone `recoveryScoreProvider(profileId)`. The `todayCalorieSummaryProvider` and `habitPromptProvider` should read the recovery score from `insightsProvider((profileId: p, userId: u)).latestRecoveryScore`. The userId comes from `Supabase.instance.client.auth.currentUser?.id`. A convenience `todayRecoveryScoreProvider(profileId)` `FutureProvider.family` should be created to encapsulate this lookup for widgets that need only the score.

### 2.6 Dashboard Screen Structure

`DashboardScreen` uses a `CustomScrollView` with `SliverToBoxAdapter` children. New widgets are inserted as additional `SliverToBoxAdapter` entries. No layout restructuring of existing sections is required.

### 2.7 FAB Location

`ScaffoldWithBottomNav` renders a `BottomNavigationBar` with no FAB today. The PRD references a "central FAB" but no such FAB exists in the current codebase. The Enhanced FAB must be added to `ScaffoldWithBottomNav` as a `floatingActionButton` on the outer `Scaffold`, with `floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked`. The `BottomNavigationBar` must then switch to a `BottomAppBar` to accommodate the docked FAB notch, or the FAB is positioned as a standard centered FAB above the nav bar. Given the existing `BottomNavigationBar` (not `BottomAppBar`), the simpler approach is `FloatingActionButtonLocation.centerFloat` — no BottomAppBar migration needed.

### 2.8 Water Logging Table

No `wt_water_logs` table or water-related entity/repository exists in the codebase. Water logging infrastructure must be created as part of this sprint. The PRD allows writing to either `wt_health_metrics` (metric_type: 'water') or a dedicated table. Using `wt_health_metrics` avoids a new table migration — this is the recommended approach.

### 2.9 Goals Provider

`goalsProvider(profileId)` is already used in `DashboardScreen`. The `WeightTrendChartWidget` can use the same provider to find a `'body_composition'` goal for the target line.

### 2.10 Health Repository

`health_repository.dart` and `health_repository_impl.dart` exist. The `HealthRepository` interface defines `getMetrics(profileId, MetricType, ...)`. The `latestMetricsProvider` referenced in the PRD does not exist as a standalone provider — it needs to be created or an existing pattern in the health feature must be identified and reused.

---

## 3. Files to Create

### 3.1 New Providers (Data Layer)

| File | Type | Purpose |
|------|------|---------|
| `lib/features/meals/presentation/today_nutrition_provider.dart` | New | Houses `todayMacroSummaryProvider`, `todayCalorieSummaryProvider`, `todayMicronutrientSummaryProvider`, `todayNutritionDashboardProvider` |
| `lib/features/meals/presentation/habit_prompt_provider.dart` | New | Houses `habitPromptProvider` and `HabitPromptData` value class |
| `lib/features/meals/presentation/meal_suggestions_provider.dart` | New | Houses `mealSuggestionsProvider` and `MealSuggestionItem` value class |
| `lib/features/health/presentation/water_log_provider.dart` | New | Houses `waterLogProvider` and `WaterLogRepository` (writes to `wt_health_metrics`) |
| `lib/features/insights/presentation/today_recovery_score_provider.dart` | New | Houses `todayRecoveryScoreProvider(profileId)` convenience provider |

### 3.2 New Dashboard Widgets

| File | Widget Class | PRD Source |
|------|-------------|------------|
| `lib/features/dashboard/presentation/widgets/nutrition_summary_carousel.dart` | `NutritionSummaryCarousel` | PRD-MEALS-V4-001 §2 |
| `lib/features/dashboard/presentation/widgets/macro_rings_carousel_page.dart` | `MacroRingsCarouselPage` | PRD-MEALS-V4-001 §2.3 |
| `lib/features/dashboard/presentation/widgets/calories_budget_carousel_page.dart` | `CaloriesBudgetCarouselPage` | PRD-MEALS-V4-001 §2.4 |
| `lib/features/dashboard/presentation/widgets/heart_healthy_carousel_page.dart` | `HeartHealthyCarouselPage` | PRD-MEALS-V4-001 §2.5 |
| `lib/features/dashboard/presentation/widgets/low_carb_carousel_page.dart` | `LowCarbCarouselPage` | PRD-MEALS-V4-001 §2.6 |
| `lib/features/dashboard/presentation/widgets/nutrient_progress_bar.dart` | `NutrientProgressBar` | PRD-MEALS-V4-001 §2.5 (shared component) |
| `lib/features/dashboard/presentation/widgets/steps_summary_tile.dart` | `StepsSummaryTile` | PRD-MEALS-V4-001 §3 |
| `lib/features/dashboard/presentation/widgets/exercise_summary_tile.dart` | `ExerciseSummaryTile` | PRD-MEALS-V4-001 §3 |
| `lib/features/dashboard/presentation/widgets/weight_trend_chart_widget.dart` | `WeightTrendChartWidget` | PRD-MEALS-V4-001 §4 |
| `lib/features/dashboard/presentation/widgets/habit_streak_prompt_card.dart` | `HabitStreakPromptCard` | PRD-MEALS-V4-001 §5 |
| `lib/features/dashboard/presentation/widgets/discover_quick_access_grid.dart` | `DiscoverQuickAccessGrid`, `DiscoverTile` | PRD-MEALS-V4-001 §6 |

### 3.3 New FAB Widget

| File | Widget Class | PRD Source |
|------|-------------|------------|
| `lib/features/meals/presentation/enhanced_log_bottom_sheet.dart` | `EnhancedLogBottomSheet`, `FabActionTile`, `QuickAddSubSheet`, `WaterStepperSubSheet` | PRD-MEALS-V4-002 |

### 3.4 New Route Screens

| File | Widget Class | Route | PRD Source |
|------|-------------|-------|------------|
| `lib/features/meals/presentation/nutrition_detail_screen.dart` | `NutritionDetailScreen` | `/nutrition` | PRD-MEALS-V4-003 §3.4 |
| `lib/features/meals/presentation/voice_log_screen.dart` | `VoiceLogScreen` | `/meals/voice-log` | PRD-MEALS-V4-003 §3.2 |
| `lib/features/meals/presentation/meal_scan_screen.dart` | `MealScanScreen` | `/meals/meal-scan` | PRD-MEALS-V4-003 §3.3 |
| `lib/features/water/presentation/water_log_screen.dart` | `WaterLogScreen` | `/water/log` | PRD-MEALS-V4-003 §3.5 |
| `lib/features/health/presentation/screens/weight_log_screen.dart` | `WeightLogScreen` | `/weight/log` | PRD-MEALS-V4-003 §3.6 |

### 3.5 New Constants File

| File | Purpose |
|------|---------|
| `lib/shared/core/constants/fab_colors.dart` | Color constants for FAB grid tiles (`kFabColorLogFood`, `kFabColorBarcode`, `kFabColorVoice`, `kFabColorMealScan`) |

---

## 4. Files to Modify

| File | Change Required | Risk |
|------|----------------|------|
| `lib/shared/core/router/app_router.dart` | Add 6 new GoRoute registrations in Branch 0; update `needsProfile` guard; add 6 import aliases; update `recipes` route to pass `selectMode` | Low — additive only |
| `lib/shared/core/router/scaffold_with_bottom_nav.dart` | Add `FloatingActionButton` (center-float) to the outer `Scaffold`; wire tap to `_openLogSheet(context)` | Low — well-contained |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Insert 5 new `SliverToBoxAdapter` sections for `NutritionSummaryCarousel`, steps/exercise row, `WeightTrendChartWidget`, `HabitStreakPromptCard`, `DiscoverQuickAccessGrid` | Low — additive only |
| `lib/features/recipes/presentation/recipe_list_screen.dart` | Accept `bool selectMode` constructor parameter; conditionally render "Use this recipe" button per item | Low — backward compatible with default `selectMode: false` |

---

## 5. New Widgets — Detailed Specifications

### 5.1 NutritionSummaryCarousel

**File**: `lib/features/dashboard/presentation/widgets/nutrition_summary_carousel.dart`

**Class hierarchy**:
- `NutritionSummaryCarousel extends ConsumerWidget` — container
- `MacroRingsCarouselPage extends StatelessWidget` — Page 1
- `CaloriesBudgetCarouselPage extends ConsumerWidget` — Page 2
- `HeartHealthyCarouselPage extends ConsumerWidget` — Page 3
- `LowCarbCarouselPage extends ConsumerWidget` — Page 4

**State**: `PageController` owned by `NutritionSummaryCarousel`. The controller is created in `build()` or via `ref.watch` of a `StateProvider<int>` for the active page index. Use a `StateProvider<int>` approach so the dot indicator rebuilds reactively.

**Provider watches**:
- `ref.watch(todayNutritionDashboardProvider(profileId))` — combined async state
- `ref.watch(currentPlanTierProvider)` — for gate checks

**Loading state**: Render `ShimmerLoading` (existing widget at `shimmer_loading.dart`) while `AsyncLoading`.

**Error state**: Inline `Card` with "Nutrition data unavailable" text — does not crash dashboard.

**Empty state**: When `foodLogged == 0`, show zero-state card with "Log your first meal" `TextButton` navigating via `context.push('/meals/food-search')`.

**Tap navigation**: Each page is wrapped in `GestureDetector`. On tap:
- Page 1: `context.push('/nutrition?tab=macros')`
- Page 2: `context.push('/nutrition?tab=calories')`
- Page 3 and Page 4: `context.push('/nutrition?tab=heart')` / `context.push('/nutrition?tab=lowcarb')` (gate check happens inside `NutritionDetailScreen`)

**Dot indicator**: Custom `Row` of `AnimatedContainer` dots, or the `smooth_page_indicator` package if already present. Check `pubspec.yaml` first; if absent, use a custom dot row to avoid adding a package dependency without user approval.

---

### 5.2 MacroRingsCarouselPage

**Rendering**: Three `CustomPainter`-based rings side by side in a `Row`. Each ring: 80x80 dp, single arc drawn with `canvas.drawArc`. Background arc in `surfaceVariant`, foreground arc in the macro colour. Centre text: "Xg left" or "Xg over".

**Data**: Accepts `int consumed` and `int goal` for each macro. Data is passed in from `NutritionSummaryCarousel` after unwrapping `todayNutritionDashboardProvider`.

**Over-goal state**: Foreground arc colour changes to `Colors.amber` when `consumed > goal`. Label changes to "Xg over".

**No separate provider call** — all data flows down as constructor parameters from the parent carousel widget.

---

### 5.3 CaloriesBudgetCarouselPage

**Layout**: Large ring (120x120 dp) centred. Below: three `Row` pairs (label / value) for Base Goal, Food Logged, Exercise Calories. Recovery score badge: 40x40 `Container` positioned in `Stack` top-right.

**Recovery score badge logic**:
```
final tier = ref.watch(currentPlanTierProvider).valueOrNull;
final isPro = tier == PlanTier.pro;
// Badge tap:
if (isPro) {
  context.push('/recovery-detail');
} else {
  context.push('/paywall');
}
```

**Goal label**: `isPro ? '(Recovery-Adjusted: $n kcal)' : '(Estimated: $n kcal)'`

**Calories remaining formula**: `remaining = baseGoal - foodLogged + exerciseCalories`

**Over-goal ring colour**: `Colors.amber` when `remaining < 0`.

---

### 5.4 HeartHealthyCarouselPage and LowCarbCarouselPage

Both pages use `NutrientProgressBar` (shared component). Data sourced from `todayMicronutrientSummaryProvider(profileId)`.

**Freemium gating**: Wrap content in `FreemiumGate(featureName: 'full_nutrients', child: ...)`. This replaces the entire page content with the upgrade prompt for free users. The `FreemiumGate._navigateToPaywall` issue is acceptable here since it is a full-page gate and the navigation is initiated by the user tapping the "Upgrade to Pro" button inside the gate widget. No navigation from a tap on the carousel page itself occurs for free users.

**NutrientProgressBar**: `StatelessWidget` accepting `String label`, `double consumed`, `double goal`, `bool isNull` (for sodium missing data case), `Color? overGoalColor`. When `isNull`, renders "--" instead of the progress bar.

---

### 5.5 StepsSummaryTile and ExerciseSummaryTile

Contained in a single file `steps_exercise_row.dart` or as two separate files. The PRD diagram shows them as a `Row` with `Expanded` children — implement them as sibling `ConsumerWidget`s rendered from `DashboardScreen`.

**StepsSummaryTile**:
- Provider: reads `MetricType.steps` via a new `todayStepsProvider(profileId)` `FutureProvider.family` added to `today_nutrition_provider.dart`
- No Health Connect connected state: show "-- steps" with `TextButton('Connect', () => context.push('/health/connections'))`
- Tap: `context.push('/health/steps')`

**ExerciseSummaryTile**:
- Providers: `todayExerciseCaloriesProvider(profileId)` (new, reads `wt_health_metrics` MetricType.activeCaloriesBurned + `wt_workout_logs`)
- Training Load AU label: reads `insightsProvider.weeklyLoadTotal`; shown only for PRO users
- "+" tap: `showModalBottomSheet` opening `EnhancedLogBottomSheet` (reuse the FAB sheet)
- Body tap: `context.go('/workouts')`

---

### 5.6 WeightTrendChartWidget

**Chart library**: `LineChart` from `fl_chart` (confirmed project dependency per `CLAUDE.md`).

**Data**: New `weightTrendProvider(profileId)` `FutureProvider.family` that calls `HealthRepository.getMetrics(profileId, MetricType.weight, startDate: 90daysAgo, endDate: today)`.

**Free tier gating**: For `PlanTier.free`, only pass data points from the last 7 days to the chart. Apply a `Stack` with a `BackdropFilter` (blur sigma 4) over the left portion of the chart (days 8–90 zone), overlaid with a `FreemiumGateInline` widget.

**Target line**: From `goalsProvider(profileId).valueOrNull?.where((g) => g.metricType == 'weight').firstOrNull?.targetValue`. If present, add a horizontal `FlLine` to `LineChartData.extraLinesData`.

**"+" button**: `FloatingActionButton.small` in a `Stack`, top-right of the chart card. Navigates via `context.push('/weight/log')`.

**Tap on chart**: `GestureDetector` on the card body navigates to `context.push('/health/weight')`.

---

### 5.7 HabitStreakPromptCard

**Provider**: `habitPromptProvider(profileId)` — `FutureProvider.family<HabitPromptData, String>`.

**HabitPromptData value class** (defined in `habit_prompt_provider.dart`):
```dart
class HabitPromptData {
  const HabitPromptData({
    required this.message,
    required this.ctaLabel,
    required this.ctaRoute,
  });
  final String message;
  final String ctaLabel;
  final String ctaRoute;
}
```

**Rule evaluation order** (short-circuit after first match):
1. Recovery score < 40 for 2 consecutive days → rest day message
2. Meal logging streak >= 3 days → streak message
3. No meal logged today AND current hour >= 9 → log breakfast message
4. Default → "Set your next recovery goal"

**Important**: Rule 1 requires `insightsProvider` state. In `habitPromptProvider`, access recovery scores via `InsightsRepository.getRecoveryScores(profileId, lastTwoDays)` directly (repository call, not watching provider) to avoid circular dependencies.

**Tap navigation**: `context.push(data.ctaRoute)`.

**Card style**: `Card` with gradient (`LinearGradient` from `theme.colorScheme.primaryContainer` to `theme.colorScheme.tertiaryContainer`), message text, and `ElevatedButton` for CTA.

---

### 5.8 DiscoverQuickAccessGrid

**Widget**: `DiscoverQuickAccessGrid extends ConsumerWidget` using `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics())`.

**DiscoverTile**: `Card` with `InkWell`, `Column` (centered icon + title + tagline). Lock badge: `Positioned` `Icon(Icons.lock, size: 14)` in `Stack` top-right.

**Tile data**: Define as a `const List<_TileSpec>` private class inside the file:
```dart
class _TileSpec {
  const _TileSpec({required this.label, required this.tagline, required this.icon, required this.route, required this.isProGated});
  final String label;
  final String tagline;
  final IconData icon;
  final String route;
  final bool isProGated;
}
```

**Navigation tap handler**:
```dart
void _onTileTap(BuildContext context, WidgetRef ref, _TileSpec spec) {
  if (spec.isProGated) {
    final tier = ref.read(currentPlanTierProvider).valueOrNull;
    if (tier != PlanTier.pro) {
      context.push('/paywall');
      return;
    }
  }
  if (spec.route == '/workouts') {
    context.go('/workouts');
  } else {
    context.push(spec.route);
  }
}
```

---

### 5.9 EnhancedLogBottomSheet

**File**: `lib/features/meals/presentation/enhanced_log_bottom_sheet.dart`

**Shell**: `DraggableScrollableSheet(initialChildSize: 0.55, minChildSize: 0.40, maxChildSize: 0.90)` inside `showModalBottomSheet(isScrollControlled: true, ...)`.

**Internal layout** (fixed order):
1. Drag handle — `Center(child: Container(width: 40, height: 4, ...rounded))`
2. Section header "Log" — `Text('Log', style: titleSmall)`
3. `GridView.count(crossAxisCount: 2, shrinkWrap: true, childAspectRatio: 1.2)` with 4 `FabActionTile` children
4. `Divider(height: 32)`
5. Section header "Track" — `Text('Track', style: titleSmall)`
6. `ListView(shrinkWrap: true, children: [...])` with 6 `ListTile` children
7. `SizedBox(height: MediaQuery.of(context).padding.bottom)`

**FabActionTile**: `Material(color: tileColor, borderRadius: BorderRadius.circular(16), child: InkWell(..., child: Column(icon container + label)))`. PRO badge overlay using `Positioned`.

**Sheet dismissal before navigation**: All navigation calls are wrapped in:
```dart
Navigator.pop(context); // dismiss modal sheet
context.push('/target-route'); // or context.go(...)
```
The `Navigator.pop` here is valid because the sheet is a modal overlay — not a GoRouter route. This is the documented pattern per PRD-MEALS-V4-003 §5.2.

**QuickAddSubSheet**: `StatefulWidget` (local form state only — `GlobalKey<FormState>`, `TextEditingController`s for calories/protein/carbs/fat, `String? selectedMealType`). On save, calls `ref.read(mealRepositoryProvider).logMeal(...)` then pops twice. No Riverpod state needed for the form itself; `setState` is acceptable here because this is ephemeral UI state that lives only while the modal is open — it is the single legitimate use of `setState()` in this entire feature.

**WaterStepperSubSheet**: Same pattern as `QuickAddSubSheet`. Local `int cups` state with +/- buttons. On confirm, writes via `waterLogRepository.addWaterLog(profileId, cups, DateTime.now())`.

---

## 6. Provider Architecture

### 6.1 New Providers — Complete List

All providers use `FutureProvider.family` unless otherwise noted. All family parameters are `String profileId`.

```
todayMacroSummaryProvider(profileId)
  → FutureProvider.family<TodayMacroSummary, String>
  → Depends: mealRepositoryProvider
  → Returns: {carbsG: int, fatG: int, proteinG: int}

todayCalorieSummaryProvider(profileId)
  → FutureProvider.family<TodayCalorieSummary, String>
  → Depends: mealRepositoryProvider, dailyPrescriptionRepositoryProvider,
             nutritionTargetsProvider(profileId), healthRepositoryProvider,
             currentPlanTierProvider
  → Returns: {baseGoal: int, foodLogged: int, exerciseCalories: int, remaining: int,
              isRecoveryAdjusted: bool}

todayMicronutrientSummaryProvider(profileId)
  → FutureProvider.family<TodayMicronutrientSummary, String>
  → Depends: mealRepositoryProvider
  → Returns: {fatTotalG: double?, sodiumMg: double?, cholesterolMg: double?,
              netCarbsG: double?, sugarG: double?, fiberG: double?}

todayNutritionDashboardProvider(profileId)
  → FutureProvider.family<TodayNutritionDashboard, String>
  → Depends: todayMacroSummaryProvider, todayCalorieSummaryProvider,
             todayMicronutrientSummaryProvider (via Future.wait)
  → Returns: combined state struct

todayStepsProvider(profileId)
  → FutureProvider.family<int?, String>
  → Depends: healthRepositoryProvider (MetricType.steps, today)

todayExerciseCaloriesProvider(profileId)
  → FutureProvider.family<TodayExerciseSummary, String>
  → Depends: healthRepositoryProvider (MetricType.activeCaloriesBurned),
             workoutLogsProvider(profileId) (for today's sessions)
  → Returns: {calories: int, activeMinutes: int, loadAu: double?}

weightTrendProvider(profileId)
  → FutureProvider.family<List<WeightDataPoint>, String>
  → Depends: healthRepositoryProvider (MetricType.weight, 90-day range)

habitPromptProvider(profileId)
  → FutureProvider.family<HabitPromptData, String>
  → Depends: mealRepositoryProvider, insightsRepositoryProvider (direct repo call)

mealSuggestionsProvider(profileId)
  → FutureProvider.family<List<MealSuggestionItem>, String>
  → Depends: todayMacroSummaryProvider, aiOrchestratorServiceProvider,
             currentPlanTierProvider (returns empty list for free users)

waterLogProvider(profileId)
  → FutureProvider.family<int, String>  (today's total cups)
  → Depends: waterLogRepository (reads wt_health_metrics where metric_type='water')

todayRecoveryScoreProvider(profileId)
  → FutureProvider.family<RecoveryScoreEntity?, String>
  → Depends: insightsRepositoryProvider (reads wt_recovery_scores for today)
```

### 6.2 Value Classes (not persisted)

Defined in `today_nutrition_provider.dart`:
```dart
class TodayMacroSummary { final int carbsG, fatG, proteinG; }
class TodayCalorieSummary { final int baseGoal, foodLogged, exerciseCalories, remaining; final bool isRecoveryAdjusted; }
class TodayMicronutrientSummary { final double? fatTotalG, sodiumMg, cholesterolMg, netCarbsG, sugarG, fiberG; }
class TodayNutritionDashboard { final TodayMacroSummary macros; final TodayCalorieSummary calories; final TodayMicronutrientSummary micronutrients; }
class TodayExerciseSummary { final int calories, activeMinutes; final double? loadAu; }
class WeightDataPoint { final DateTime date; final double weightKg; }
```

Defined in `habit_prompt_provider.dart`:
```dart
class HabitPromptData { final String message, ctaLabel, ctaRoute; }
```

Defined in `meal_suggestions_provider.dart`:
```dart
class MealSuggestionItem { final String name, reasoning; final int calories, carbsG, fatG, proteinG; }
```

### 6.3 Provider Dependency Graph

```
todayNutritionDashboardProvider
  ├── todayMacroSummaryProvider → mealRepositoryProvider
  ├── todayCalorieSummaryProvider
  │     ├── mealRepositoryProvider
  │     ├── dailyPrescriptionRepositoryProvider
  │     ├── nutritionTargetsProvider
  │     ├── healthRepositoryProvider
  │     └── currentPlanTierProvider
  └── todayMicronutrientSummaryProvider → mealRepositoryProvider

habitPromptProvider
  ├── mealRepositoryProvider
  └── insightsRepositoryProvider

mealSuggestionsProvider
  ├── todayMacroSummaryProvider
  ├── aiOrchestratorServiceProvider
  └── currentPlanTierProvider

waterLogProvider → healthRepositoryProvider
weightTrendProvider → healthRepositoryProvider
todayStepsProvider → healthRepositoryProvider
todayExerciseCaloriesProvider → healthRepositoryProvider
todayRecoveryScoreProvider → insightsRepositoryProvider
```

No circular dependencies. No provider watches another provider that could create a rebuild loop.

### 6.4 `nutritionTargetsProvider` Integration Note

`nutritionTargetsProvider(profileId)` is a `StateNotifierProvider`. Its `NutritionTargetsNotifier.loadTargets()` must be called before `todayCalorieSummaryProvider` reads it. In practice, `NutritionTargetsScreen` already calls `loadTargets()`. However, `DashboardScreen` does not. The `todayCalorieSummaryProvider` must call `nutritionTargetsProvider(profileId).notifier.loadTargets(...)` — but providers cannot call notifier methods. The correct pattern is: in `todayCalorieSummaryProvider`, read `nutritionTargetsProvider(profileId)` state directly. If `state.isLoading == true` or `state.rest.calories == 0`, fall back to `MacroCalculator.calculateDailyTargets(...)` with default values. This avoids a blocking dependency on `nutritionTargetsProvider` initialization.

---

## 7. Route Changes

### 7.1 New Route Registrations in `app_router.dart`

All six new routes are added inside Branch 0's `routes` list, alongside the existing meal and health route siblings. Exact placement: after the `meals/weekly-summary` route block and before the `health/connections` block.

```
meals/diary       → redirect to '/daily-view'
meals/voice-log   → VoiceLogScreen (stub)
meals/meal-scan   → MealScanScreen (stub)
nutrition         → NutritionDetailScreen (query param: tab)
water/log         → WaterLogScreen
weight/log        → WeightLogScreen
```

### 7.2 `needsProfile` Guard Update

Add to the existing `needsProfile` boolean in `app_router.dart`:
```dart
requestedPath == '/nutrition' ||
requestedPath == '/water/log' ||
requestedPath == '/weight/log'
```

### 7.3 Recipe Route Update

The existing `recipes` `GoRoute` builder changes from:
```dart
builder: (context, state) => const recipe_list.RecipeListScreen(),
```
to:
```dart
builder: (context, state) {
  final selectMode = state.uri.queryParameters['selectMode'] == 'true';
  return recipe_list.RecipeListScreen(selectMode: selectMode);
},
```

### 7.4 Import Aliases Required

Six new import aliases added at the top of `app_router.dart`:
```dart
import '../../../features/meals/presentation/nutrition_detail_screen.dart' as nutrition_detail;
import '../../../features/meals/presentation/voice_log_screen.dart' as voice_log;
import '../../../features/meals/presentation/meal_scan_screen.dart' as meal_scan;
import '../../../features/water/presentation/water_log_screen.dart' as water_log;
import '../../../features/health/presentation/screens/weight_log_screen.dart' as weight_log;
```
The `meals/diary` redirect requires no screen import.

### 7.5 FAB Registration in `ScaffoldWithBottomNav`

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _openLogSheet(context),
  child: const Icon(Icons.add),
),
floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
```

`_openLogSheet` is a top-level function or static method:
```dart
void _openLogSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EnhancedLogBottomSheet(),
  );
}
```

`ScaffoldWithBottomNav` must import `EnhancedLogBottomSheet`. Since `ScaffoldWithBottomNav` is currently a pure `StatelessWidget` with no Riverpod, it must remain so — `EnhancedLogBottomSheet` is a `ConsumerWidget` and will self-provision its providers from the context it receives when the sheet mounts.

---

## 8. Phase-by-Phase Implementation Order

### Phase A — Foundation (build first, everything else depends on this)

**Estimated scope**: 1 developer day

1. Create all provider files with stub implementations returning empty/zero data
2. Register all 6 new routes in `app_router.dart` with stub screen builders
3. Add the FAB button to `ScaffoldWithBottomNav` (opens an empty sheet placeholder)
4. Create `VoiceLogScreen` and `MealScanScreen` stub screens
5. Create `WaterLogScreen` and `WeightLogScreen` with full UI but wired to `waterLogProvider` stub
6. Update `needsProfile` guard
7. Run `flutter analyze` — must pass zero warnings before proceeding

**Why first**: Stub routes prevent navigation crashes when dashboard widgets reference them. FAB registration unblocks the sheet work.

---

### Phase B — Provider Implementation

**Estimated scope**: 1.5 developer days

1. Implement `todayMacroSummaryProvider` — aggregate `wt_meals.nutritionInfo` for today
2. Implement `todayMicronutrientSummaryProvider` — aggregate micronutrient fields; handle null fields correctly
3. Implement `todayCalorieSummaryProvider` — compose macro targets + prescription modifier + exercise calories; test the `PlanType` → dayType mapping
4. Implement `todayNutritionDashboardProvider` — `Future.wait` wrapper
5. Implement `todayRecoveryScoreProvider` — direct `InsightsRepository.getRecoveryScores` call for today
6. Implement `habitPromptProvider` — rule engine; test all 4 rule paths
7. Implement `waterLogProvider` — reads `wt_health_metrics` where `metric_type = 'water'` for today
8. Defer `mealSuggestionsProvider` to Phase E (depends on AI orchestrator capability verification)

**Why second**: Widget work is blocked on real data flowing through providers.

---

### Phase C — Dashboard Widgets

**Estimated scope**: 2 developer days

Build and integrate widgets in this order (each one is independently testable):

1. `HabitStreakPromptCard` — simplest widget, no custom painting
2. `DiscoverQuickAccessGrid` — straightforward grid, no async complexity
3. `StepsSummaryTile` and `ExerciseSummaryTile` — simple stat tiles
4. `NutrientProgressBar` — shared component, needed by carousel pages 3 and 4
5. `MacroRingsCarouselPage` — custom painting; build and test ring CustomPainter in isolation
6. `CaloriesBudgetCarouselPage` — large ring + recovery score badge
7. `HeartHealthyCarouselPage` and `LowCarbCarouselPage` — reuse NutrientProgressBar
8. `NutritionSummaryCarousel` — compose the four pages with PageController + dot indicator
9. `WeightTrendChartWidget` — fl_chart integration; defer to last within this phase
10. Insert all widgets into `DashboardScreen` as `SliverToBoxAdapter` entries

**Dashboard section order** (top to bottom after existing `TodaySummaryCard`):
```
TodaySummaryCard          (existing)
DailyCoachCard            (existing)
DashboardScenarioNudges   (existing)
OvertTrainingWarningCard  (existing)
NutritionSummaryCarousel  [NEW]
Steps + Exercise Row      [NEW]
WeightTrendChartWidget    [NEW]
HabitStreakPromptCard     [NEW]
KeySignalsGrid            (existing — moved below new nutrition section)
IntelligenceInsightCard   (existing)
TrendsPreviewCard         (existing)
GoalsSummaryCard          (existing)
WorkoutsCard              (existing)
PantryRecipeCard          (existing)
DiscoverQuickAccessGrid   [NEW — replaces or augments SecondaryModulesList]
SecondaryModulesList      (existing — keep; DiscoverGrid is a visual upgrade above it)
```

---

### Phase D — Enhanced FAB Sheet

**Estimated scope**: 1.5 developer days

1. Build `FabActionTile` widget
2. Build `EnhancedLogBottomSheet` shell with `DraggableScrollableSheet`
3. Implement all 4 grid tiles (Log Food, Barcode Scan, Voice Log PRO stub, Meal Scan PRO stub)
4. Implement all 6 list tiles (Water, Weight, Exercise, AI Suggestions, From Recipes, Quick Add)
5. Build `WaterStepperSubSheet` (nested modal) with `waterLogRepository` write
6. Build `QuickAddSubSheet` with `mealRepositoryProvider.logMeal` write
7. Wire FAB button in `ScaffoldWithBottomNav` to open `EnhancedLogBottomSheet`
8. Verify sheet dismissal + navigation for every action item on device

---

### Phase E — NutritionDetailScreen and AI Suggestions

**Estimated scope**: 1 developer day

1. Build `NutritionDetailScreen` with `TabBar` (Macros / Calories / Heart Healthy / Low Carb) using the same four carousel page widgets (reused as tab content, not carousel pages)
2. Add "Today's Meals" section below tabs — list of `MealEntity` with delete/edit bottom sheet
3. Handle `?tab=` query parameter for initial tab selection
4. Implement `mealSuggestionsProvider` — requires verification that `ai_orchestrator_service.dart` can accept `workflow_type: 'meal_suggestions'`; if not, stub returns empty list with a note for backend team
5. Wire "AI Suggestions" FAB tile to the suggestions modal sheet

---

### Phase F — Polish and Verification

**Estimated scope**: 0.5 developer day

1. `flutter analyze` — zero warnings on all new files
2. Verify freemium gate states: free user sees correct locked/blurred states
3. Verify recovery-adjusted calorie label shows prescription engine output for PRO
4. Verify all navigation tap targets on device (Android)
5. Verify back navigation for each new route
6. Verify `RecipeListScreen` `selectMode` flow end-to-end

---

## 9. Risk Assessment

### 9.1 High Complexity — Requires Care

**`todayCalorieSummaryProvider` composition**

The calorie goal for PRO users requires chaining `nutritionTargetsProvider`, `dailyPrescriptionRepositoryProvider`, and `currentPlanTierProvider`. The `nutritionTargetsProvider` is a `StateNotifierProvider` that requires `loadTargets()` to be called before its state is populated. If `DashboardScreen` mounts before `NutritionTargetsScreen` has been visited, the targets will be zero. Mitigation: `todayCalorieSummaryProvider` should call `MacroCalculator.calculateDailyTargets(...)` directly using profile data as a fallback, rather than depending solely on `nutritionTargetsProvider` state. This makes the provider self-sufficient.

**Custom ring painter**

`MacroRingsCarouselPage` requires a `CustomPainter` that draws three arcs. This is straightforward Dart canvas work but requires careful testing across screen sizes. The rings must not clip on small screens (360dp width). Minimum ring diameter: 72dp. Allocate time for responsive sizing.

**`WeightTrendChartWidget` fl_chart integration**

`fl_chart`'s `LineChart` requires careful `FlSpot` data construction and axis configuration. The dashed target line uses `extraLinesData`. The free-tier blur overlay using `BackdropFilter` must be tested for performance — `BackdropFilter` is GPU-intensive. Alternative: a solid semi-transparent overlay with `Container(color: Colors.black.withOpacity(0.6))` is simpler and more performant than a blur.

---

### 9.2 Medium Complexity — Test Carefully

**`DraggableScrollableSheet` on small screens**

On 360dp-height screens, the sheet at `initialChildSize: 0.55` may clip the list section. Test on a device with < 700dp screen height (e.g., Pixel 3a). The `maxChildSize: 0.90` should allow the user to drag it up to reveal all items.

**`NutritionDetailScreen` tab + query parameter**

GoRouter's `state.uri.queryParameters['tab']` is read at build time in the route builder. The `NutritionDetailScreen` receives `initialTab: String` as a constructor parameter and sets its `TabController` index from it. If a user navigates to `/nutrition` without a tab parameter, the default must be `'macros'`.

**`mealSuggestionsProvider` AI dependency**

The `ai_orchestrator_service.dart` `orchestrate()` method accepts a `workflowType` string. Whether `'meal_suggestions'` is a supported workflow in the Supabase Edge Function is unknown from client-side code alone. This must be verified with the backend before Phase E. If unsupported, `mealSuggestionsProvider` should return an empty list silently rather than throwing.

---

### 9.3 Low Complexity — Straightforward

- Stub screens (`VoiceLogScreen`, `MealScanScreen`) — minimal UI
- `WaterLogScreen` — simple counter screen
- `WeightLogScreen` — single input form with validation
- `HabitStreakPromptCard` — rule evaluation in provider, widget is a simple card
- `DiscoverQuickAccessGrid` — static tile data, simple grid
- Route registrations in `app_router.dart` — additive only
- `RecipeListScreen` `selectMode` extension — adds one parameter and one conditional render

---

### 9.4 User Decisions Required Before Implementation

The following questions require product/user decisions and cannot be resolved architecturally:

**Decision 1 — Sodium and Micronutrient Data Gap**
The Open Food Facts integration stores data in `wt_meals.nutritionInfo` JSONB. Whether sodium, cholesterol, and fiber fields are currently being populated depends on how `FoodSearchScreen` writes meals. If these fields are absent in the DB for existing meal logs, `HeartHealthyCarouselPage` and `LowCarbCarouselPage` will show "--" for all values even for PRO users. Decision needed: should the team audit existing `wt_meals` records and the food search write path before implementing these pages, or accept that they show "--" initially and improve over time?

**Decision 2 — `mealSuggestionsProvider` Backend Prerequisite**
AI Suggestions in the FAB sheet require a `meal_suggestions` workflow in the Supabase Edge Function (`ai_orchestrator_service.dart` → Supabase `ai-orchestrator` function). This workflow does not exist in the current codebase. Decision: implement as a stub that always returns empty list and shows "Suggestions unavailable" for now, or block Phase E on backend Edge Function work?

**Decision 3 — Water Logging Table**
Write water logs to `wt_health_metrics` (metric_type: 'water', value: cups) or create a new `wt_water_logs` table. Using `wt_health_metrics` is simpler and consistent with how other health data is stored. However, it mixes intentional log entries with passively synced health data. Decision: use `wt_health_metrics` for now, or create a dedicated table?

**Decision 4 — Dashboard Widget Ordering**
The current `DashboardScreen` has a well-established section order (TodaySummary → DailyCoach → KeySignals → Intelligence → Trends → Goals → Workouts → Pantry → SecondaryModules). The five new sections will make the dashboard significantly longer. Decision: should `SecondaryModulesList` be removed once `DiscoverQuickAccessGrid` is in place (the grid covers similar navigation), or should both exist simultaneously?

**Decision 5 — `smooth_page_indicator` Dependency**
The carousel dot indicator can be built with a custom `Row` of `AnimatedContainer` dots (zero dependencies) or using the `smooth_page_indicator` package (better animation). Decision: add the package or use a custom implementation?

---

## 10. Adherence to Non-Negotiables

| Rule | How This Plan Complies |
|------|----------------------|
| All state via Riverpod — no `setState()` | `setState()` used only in `QuickAddSubSheet` and `WaterStepperSubSheet` for ephemeral form state in modal overlays, which is the accepted Flutter pattern for single-use UI state that does not need to survive widget disposal |
| GoRouter `context.push()`/`pop()` — no `Navigator.pushNamed()` | All navigation in new widgets uses `context.push()` or `context.go()`. `Navigator.pop()` is used only to dismiss modal bottom sheets, which is the documented GoRouter/Flutter modal pattern |
| Recovery score drives calorie targets via prescription engine | `todayCalorieSummaryProvider` reads `DailyPrescriptionEntity.calorieAdjustmentPercent` and `calorieModifier` for PRO users; falls back to `MacroCalculator` for free users |
| Freemium gating via `currentPlanTierProvider` (existing, equivalent to `subscription_provider`) | All gate checks use `ref.watch(currentPlanTierProvider)` or `FreemiumGate`/`FreemiumGateInline` widgets |
| Integrate with `recoveryScoreProvider` | `todayRecoveryScoreProvider` wraps `InsightsRepository` recovery score access; `CaloriesBudgetCarouselPage` and `habitPromptProvider` both consume it |
| Integrate with `baselineCalibrationProvider` | No direct integration required for this sprint — baseline calibration gates whether a recovery score exists; if no score exists today, the carousel falls back to "Estimated" label, which is already the correct behaviour |
| Offline-first: Hive for local storage | The new providers read from Supabase repositories. Offline-first caching via Hive is handled by the existing `sync_engine.dart` pattern. For this sprint, the providers are online-first with graceful degradation (show "--" when data is unavailable). Full Hive caching for nutrition summary data is deferred — it is not blocking and can be added in a follow-on sprint |
| No AI calls from widgets | `mealSuggestionsProvider` is a `FutureProvider` initiated at dashboard mount time; no AI calls occur in widget `build()` methods |
| All data reads through existing repositories | Every new provider reads from an existing repository class (`mealRepositoryProvider`, `healthRepositoryProvider`, `dailyPrescriptionRepositoryProvider`, `insightsRepositoryProvider`) or a new repository added to this sprint (`waterLogRepository`) |

---

## 11. File Path Summary

### Files to Create (28 total)

**Providers**
- `/lib/features/meals/presentation/today_nutrition_provider.dart`
- `/lib/features/meals/presentation/habit_prompt_provider.dart`
- `/lib/features/meals/presentation/meal_suggestions_provider.dart`
- `/lib/features/health/presentation/water_log_provider.dart`
- `/lib/features/insights/presentation/today_recovery_score_provider.dart`

**Dashboard Widgets**
- `/lib/features/dashboard/presentation/widgets/nutrition_summary_carousel.dart`
- `/lib/features/dashboard/presentation/widgets/macro_rings_carousel_page.dart`
- `/lib/features/dashboard/presentation/widgets/calories_budget_carousel_page.dart`
- `/lib/features/dashboard/presentation/widgets/heart_healthy_carousel_page.dart`
- `/lib/features/dashboard/presentation/widgets/low_carb_carousel_page.dart`
- `/lib/features/dashboard/presentation/widgets/nutrient_progress_bar.dart`
- `/lib/features/dashboard/presentation/widgets/steps_summary_tile.dart`
- `/lib/features/dashboard/presentation/widgets/exercise_summary_tile.dart`
- `/lib/features/dashboard/presentation/widgets/weight_trend_chart_widget.dart`
- `/lib/features/dashboard/presentation/widgets/habit_streak_prompt_card.dart`
- `/lib/features/dashboard/presentation/widgets/discover_quick_access_grid.dart`

**FAB**
- `/lib/features/meals/presentation/enhanced_log_bottom_sheet.dart`

**New Route Screens**
- `/lib/features/meals/presentation/nutrition_detail_screen.dart`
- `/lib/features/meals/presentation/voice_log_screen.dart`
- `/lib/features/meals/presentation/meal_scan_screen.dart`
- `/lib/features/water/presentation/water_log_screen.dart`
- `/lib/features/health/presentation/screens/weight_log_screen.dart`

**Constants**
- `/lib/shared/core/constants/fab_colors.dart`

**Data infrastructure (water logging)**
- `/lib/features/water/data/water_log_repository.dart`
- `/lib/features/water/domain/water_log_entity.dart`

### Files to Modify (4 total)

- `/lib/shared/core/router/app_router.dart`
- `/lib/shared/core/router/scaffold_with_bottom_nav.dart`
- `/lib/features/dashboard/presentation/dashboard_screen.dart`
- `/lib/features/recipes/presentation/recipe_list_screen.dart`

---

## 12. Definition of Done

- [ ] All 28 new files created; `flutter analyze` passes with zero warnings
- [ ] All 4 modified files updated; `flutter analyze` still passes with zero warnings
- [ ] `NutritionSummaryCarousel` displays correct live data from `todayNutritionDashboardProvider` on device
- [ ] `CaloriesBudgetCarouselPage` shows "Recovery-Adjusted" label for PRO user and "Estimated" for free user
- [ ] Recovery score badge navigation verified: PRO → `/recovery-detail`, free → `/paywall`
- [ ] `WeightTrendChartWidget` shows 90-day data for PRO, 7-day data with blur overlay for free
- [ ] `HabitStreakPromptCard` rule engine triggers correct message for each condition
- [ ] `DiscoverQuickAccessGrid` lock badge appears on Recovery and Daily Coach tiles for free users
- [ ] `EnhancedLogBottomSheet` opens from FAB; all 10 actions navigate correctly
- [ ] Voice Log and Meal Scan tiles show PRO badge; free users redirected to `/paywall`
- [ ] `QuickAddSubSheet` saves valid `MealEntity` to `wt_meals` on device
- [ ] `WaterStepperSubSheet` writes to `wt_health_metrics`; today's count reflects in `waterLogProvider`
- [ ] All 6 new routes registered; deep link patterns from PRD §6 verified on device
- [ ] Back navigation verified for each new route (Android system back button)
- [ ] `RecipeListScreen` `selectMode` query parameter accepted and handled
- [ ] No `Navigator.pushNamed()` calls introduced anywhere in new code
- [ ] `todayNutritionDashboardProvider` handles loading, error, and empty states without crashing `DashboardScreen`
