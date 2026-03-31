# PRD: Meals v4 — Dashboard Summary Widgets

**Document ID**: PRD-MEALS-V4-001
**Status**: Draft
**Created**: 2026-03-16
**Author**: Business Analysis
**Branch**: ralph/phase-13-ux-refinement
**Blocks**: Implementation sprint for meals dashboard enhancements

---

## 1. Overview

This PRD defines the dashboard-layer widgets that bring WellTrack's Meals module to parity with best-in-class nutrition trackers while preserving WellTrack's core identity: the performance engine drives every number, AI explains but never prescribes, and recovery score is the central lens through which all food targets are framed.

The widgets described here live on **Branch 0 of the `StatefulShellRoute`** (the `/` dashboard route) and are embedded directly into `DashboardScreen`. They are not standalone routes; they are composable widgets that surface nutrition context at a glance and offer single-tap drill-through to detailed screens.

### 1.1 Product Context

WellTrack differentiates from MyFitnessPal by connecting calorie targets to recovery data. A user's calorie goal on a rest day (recovery score 35) is lower than on a push day (recovery score 88). This is not a toggle — it is the engine output. Every widget on the dashboard must reflect this truth. When a user sees "2,200 kcal remaining", that number carries a parenthetical: "(Recovery-Adjusted)". The dashboard is the moment this becomes visible.

### 1.2 Non-Negotiables

- All calorie targets displayed come from `prescription_engine.dart`, never from hardcoded or user-inputted goals alone
- Recovery score must be visibly present on the calories page of the carousel
- Freemium users see basic macro tracking; recovery-adjusted targets require PRO
- No AI calls are made from within these widgets; the AI layer is invoked only from dedicated coaching screens
- All data reads go through existing Riverpod providers — no direct Supabase calls from widgets

---

## 2. Feature 1 — Dashboard Summary Carousel

### 2.1 Description

A horizontal swipeable `PageView` occupying the top section of the dashboard, replacing or augmenting the existing `today_summary_card.dart`. The carousel has four pages with dot indicators below. Each page presents a different nutritional lens.

### 2.2 User Story

**ID**: US-MEALS-V4-001
**Epic**: Dashboard Nutrition Visibility
**Priority**: High

**As a** WellTrack user who has logged at least one meal today
**I want** to swipe through different views of my daily nutrition on the dashboard
**So that** I can see my macro balance, calorie budget, heart-health nutrients, and low-carb metrics without leaving the home screen

#### Acceptance Criteria

- [ ] Given the user is on the dashboard, when they view the carousel, then a `PageView` widget with exactly 4 pages is visible with dot indicators showing the active page
- [ ] Given the user swipes left or right, when the page changes, then the active dot indicator updates and the new page animates in using the default horizontal slide transition
- [ ] Given no meals have been logged today, when the user views any carousel page, then all progress values show "0" and goals show their current targets (not "--")
- [ ] Given the prescription engine has not run (no recovery score for today), when the user views any carousel page, then targets fall back to the `MacroCalculator`-calculated value from `nutrition_targets_provider.dart` and a subtle "Estimated target" label is shown
- [ ] Given the user taps any carousel page, when navigation occurs, then the user is taken to the `/nutrition` detail screen (see PRD-MEALS-V4-003 for route definition)

---

### 2.3 Page 1 — Macros Ring View

#### Description

Three circular progress rings side by side: Carbohydrates, Fat, Protein. Each ring shows consumed grams as a proportion of the daily goal, with "Xg left" or "Xg over" in the centre.

#### Acceptance Criteria

- [ ] Given today's meal logs exist, when the macros page renders, then three rings display `consumed / goal` with percentage fill for Carbs (blue/teal), Fat (orange), and Protein (green) respectively
- [ ] Given consumed grams exceed the goal, when the ring fills beyond 100%, then the ring displays in amber with an "over" label instead of "left"
- [ ] Given a free-tier user views the macros page, when the page renders, then Carbs, Fat, and Protein rings are all visible with live data (basic macro tracking is free per `plan_tier.dart`)
- [ ] Given a goal change occurs in `/settings/nutrition-targets`, when the user returns to the dashboard, then ring goals update within the same session without requiring a restart

#### Data Sources

| Data | Provider | Table |
|------|----------|-------|
| Consumed macros | `mealRepositoryProvider` → aggregate today's `nutritionInfo` JSONB | `wt_meals` |
| Daily macro targets | `nutritionTargetsProvider(profileId)` | Calculated by `MacroCalculator` or custom override in `wt_custom_macro_targets` |

#### WellTrack Integration Points

- Macro targets for the day are derived from `NutritionTargetsState.forDayType(dayType)` where `dayType` is determined by today's prescription engine output
- If prescription engine has not run, `dayType` defaults to `'rest'` for conservative targets

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| View consumed macros (Carbs, Fat, Protein) | Yes | Yes |
| View ring goals | Yes | Yes |
| Recovery-adjusted macro goals | No — shows static calculated goal | Yes — shows prescription-engine goal |

#### Flutter Implementation Notes

- Widget class: `MacroRingsCarouselPage` — a `StatelessWidget` accepting consumed and goal values
- Use `fl_chart`'s `PieChart` or a custom `CustomPainter` ring; single-segment ring with background track
- Consume via `ref.watch(todayMacroSummaryProvider(profileId))` — a new `FutureProvider.family` that aggregates `wt_meals` for today and returns `{carbsG, fatG, proteinG}`
- Targets from `ref.watch(nutritionTargetsProvider(profileId)).forDayType(todayDayType)`

---

### 2.4 Page 2 — Calories Budget View

#### Description

A single large ring showing calories remaining. Below the ring, a three-row breakdown: Base Goal, Food Logged, Exercise Calories. The goal label explicitly states its origin: "(Recovery-Adjusted: X kcal)" for PRO users, or "(Estimated: X kcal)" for free users. A recovery score badge sits in the top-right corner of this page.

**Formula displayed:**
```
Remaining = Base Goal - Food Logged + Exercise Calories
```

#### Acceptance Criteria

- [ ] Given a PRO user with today's recovery score available, when the calories page renders, then the goal label reads "(Recovery-Adjusted: [N] kcal)" where N comes from `prescription_engine.dart`
- [ ] Given a free user, when the calories page renders, then the goal label reads "(Estimated: [N] kcal)" sourced from `MacroCalculator`
- [ ] Given exercise has been logged, when the calories page renders, then the "Exercise" row shows calories burned and the ring reflects the adjusted remaining balance
- [ ] Given the recovery score badge is tapped by a free user, when the tap occurs, then the `FreemiumGate` widget triggers navigation to `/paywall`
- [ ] Given the recovery score badge is tapped by a PRO user, when the tap occurs, then navigation goes to `/recovery-detail`
- [ ] Given calories consumed exceed the goal, when the ring is full, then it renders in amber/red and remaining shows as negative (e.g., "-150 kcal")

#### Data Sources

| Data | Provider / Source | Table |
|------|-------------------|-------|
| Base calorie goal | `prescriptionEngineProvider` (PRO) or `MacroCalculator` (free) | `wt_prescription_outputs` / calculated |
| Food logged calories | Aggregated from today's `wt_meals.nutritionInfo.calories` | `wt_meals` |
| Exercise calories | `liveSessionProvider` or `healthProviderProvider` — `MetricType.activeCaloriesBurned` | `wt_health_metrics` / `wt_workout_logs` |
| Recovery score | `recoveryScoreProvider(profileId)` → today's `RecoveryScoreEntity` | `wt_recovery_scores` |

#### WellTrack Integration Points

- The recovery score badge reuses the existing `RecoveryScoreCard` widget from `lib/features/insights/presentation/widgets/recovery_score_card.dart` in compact mode
- The `prescriptionEngineProvider` must supply today's calorie target; this is the authoritative value for PRO users
- Exercise calories are the sum of: (a) workout session calories from `wt_workout_logs` and (b) active calories from Health Connect via `wt_health_metrics`

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| View calories remaining ring | Yes | Yes |
| Recovery-adjusted goal label | No — "Estimated" | Yes — "Recovery-Adjusted" |
| Recovery score badge (tappable) | Shows lock icon → paywall | Shows score → recovery detail |
| Exercise calorie adjustment | Yes — uses Health Connect data | Yes |

#### Flutter Implementation Notes

- Widget class: `CaloriesBudgetCarouselPage`
- The recovery score badge is a `GestureDetector` wrapping a small `Container` (40x40) in the top-right; uses `FreemiumGateInline` pattern from `freemium_gate_widget.dart`
- Calorie goal source is determined by `ref.watch(planTierProvider)` — if `PlanTier.pro`, read from prescription engine; otherwise use `MacroCalculator`
- New provider needed: `todayCalorieSummaryProvider(profileId)` — `FutureProvider.family` returning `{baseGoal, foodLogged, exerciseCalories, remaining}`

---

### 2.5 Page 3 — Heart Healthy View

#### Description

Progress bars for Fat (total), Sodium, and Cholesterol. Each row shows current / goal with a horizontal bar. Goals reflect established dietary guidelines (saturated fat < 20g, sodium < 2300mg, cholesterol < 300mg) adjusted by the user's nutrition profile.

#### Acceptance Criteria

- [ ] Given today's meals have been logged with full micronutrient data, when the heart healthy page renders, then Fat, Sodium, and Cholesterol progress bars show accurate consumed / goal values
- [ ] Given a free user views this page, when the page renders, then a `FreemiumGateInline` overlay displays with message "Full micronutrient tracking requires Pro" — the bars are visible but blurred/locked
- [ ] Given consumed sodium exceeds 2,300mg, when the bar renders, then it displays in red with an over-goal indicator
- [ ] Given no sodium data is available in logged meals (Open Food Facts data gap), when the page renders, then sodium shows "--" rather than "0" to avoid misleading a user into thinking they have consumed zero sodium

#### Data Sources

| Nutrient | Source Field | Default Goal |
|----------|-------------|--------------|
| Total Fat (g) | `nutritionInfo.fat_total_g` | From `wt_nutrition_profiles` or 65g default |
| Sodium (mg) | `nutritionInfo.sodium_mg` | 2,300mg (WHO guideline) |
| Cholesterol (mg) | `nutritionInfo.cholesterol_mg` | 300mg (dietary guideline) |

#### WellTrack Integration Points

- Micronutrient data sourced from Open Food Facts API (already integrated via `food_search_provider.dart`) and stored in `wt_meals.nutritionInfo` JSONB
- PRO gate uses `PlanTier.nutrientLevel == 'full'` from `plan_tier.dart`

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See Fat/Sodium/Cholesterol bars | Visible but blurred with lock | Fully visible |
| Tap to full micronutrient screen | Redirects to paywall | Opens `/nutrition` detail |

#### Flutter Implementation Notes

- Widget class: `HeartHealthyCarouselPage`
- Use `FreemiumGate` wrapping the entire page content, `featureName: 'full_nutrients'`
- Progress bar component: reusable `NutrientProgressBar` widget (horizontal `LinearProgressIndicator` with label row above)

---

### 2.6 Page 4 — Low Carb View

#### Description

Progress bars for Net Carbs, Sugar, and Fiber. Suited for users following ketogenic or low-carb protocols. Net Carbs = Total Carbs - Fiber.

#### Acceptance Criteria

- [ ] Given today's meals have been logged, when the low carb page renders, then Net Carbs, Sugar, and Fiber progress bars display consumed / goal
- [ ] Given the user has not set a custom carb goal, when the page renders, then default goals are: Net Carbs 50g (keto-friendly default), Sugar 50g, Fiber 25g
- [ ] Given a free user views this page, when the page renders, then the same `FreemiumGateInline` overlay as the Heart Healthy page is shown (full micronutrients require PRO)
- [ ] Given net carbs exceed the goal, when the bar renders, then it shows in amber with an over-goal label; Fiber exceeding goal renders in green (positive outcome)

#### Data Sources

| Nutrient | Source Field | Default Goal |
|----------|-------------|--------------|
| Net Carbs (g) | `nutritionInfo.carbs_g - nutritionInfo.fiber_g` | 50g |
| Sugar (g) | `nutritionInfo.sugar_g` | 50g |
| Fiber (g) | `nutritionInfo.fiber_g` | 25g |

#### Freemium Gating

Same gating as Page 3 (Heart Healthy) — requires `PlanTier.pro` for full micronutrient access.

#### Flutter Implementation Notes

- Widget class: `LowCarbCarouselPage`
- Reuses `NutrientProgressBar` component from Page 3
- Net Carbs calculation: performed in the `todayMicronutrientSummaryProvider` — do not compute in the widget layer

---

### 2.7 Carousel Container

#### Acceptance Criteria (Container-Level)

- [ ] Given the dashboard loads, when the carousel widget mounts, then it reads data from providers and shows a `ShimmerLoading` placeholder (reuse existing `shimmer_loading.dart`) until data is ready
- [ ] Given a provider error occurs, when the carousel tries to render, then a non-fatal inline error state is shown ("Nutrition data unavailable") — the error does not crash the dashboard
- [ ] Given the user has not logged any meals today, when the carousel renders, then it shows zero-state with a "Log your first meal" CTA tapping to `/meals/food-search`

#### Flutter Implementation Notes

- Widget class: `NutritionSummaryCarousel` — `ConsumerWidget`
- Contains a `PageController` with `viewportFraction: 1.0` and `PageView.builder` for 4 pages
- `SmoothPageIndicator` package (or custom dot row) sits below the `PageView`
- Parent provider: `todayNutritionDashboardProvider(profileId)` — a combined `FutureProvider.family` that resolves macro summary, calorie summary, and micronutrient summary in parallel using `Future.wait`

---

## 3. Feature 2 — Steps and Exercise Widgets

### 3.1 Description

Two compact stat tiles displayed side-by-side in a `Row` below the carousel. Left tile: Steps. Right tile: Exercise. Together they communicate today's movement context.

### 3.2 User Stories

#### US-MEALS-V4-002 — Steps Widget

**ID**: US-MEALS-V4-002
**Epic**: Dashboard Movement Context
**Priority**: Medium

**As a** WellTrack user connected to Health Connect
**I want** to see my current step count and daily goal on the dashboard
**So that** I know how close I am to my activity target without opening a separate screen

##### Acceptance Criteria

- [ ] Given Health Connect is connected and steps data is available, when the steps widget renders, then it shows: a walking icon, today's step count, the goal (default 10,000), and a linear progress bar
- [ ] Given Health Connect is not connected, when the steps widget renders, then it shows "-- steps" with a "Connect" link tapping to `/health/connections`
- [ ] Given the step count reaches or exceeds 10,000, when the widget renders, then the progress bar and count text display in green
- [ ] Given the user taps the steps widget, when navigation occurs, then the user is taken to `/health/steps`

##### Data Sources

- Provider: `latestMetricsProvider(profileId)` → `MetricType.steps`
- Goal: 10,000 steps (hardcoded default; future: `wt_goals` table lookup for step goal)

#### US-MEALS-V4-003 — Exercise Widget

**ID**: US-MEALS-V4-003
**Epic**: Dashboard Movement Context
**Priority**: Medium

**As a** WellTrack user
**I want** to see today's exercise calories burned and workout duration on the dashboard
**So that** I understand how my training affects my calorie budget

##### Acceptance Criteria

- [ ] Given a workout session was completed today, when the exercise widget renders, then it shows: calories burned (from `wt_workout_logs` or Health Connect), total active minutes, and a "+" button to log exercise
- [ ] Given no workout has been logged today, when the widget renders, then calories and duration show "0" with the "+" button still visible
- [ ] Given the user taps the "+" button, when navigation occurs, then a bottom sheet opens with the option to start a workout (`/workouts`) or log exercise manually
- [ ] Given the user taps the exercise tile body (not the "+" button), when navigation occurs, then the user is taken to `/workouts`
- [ ] Given the Training Load AU value is available from `liveSessionProvider`, when the exercise widget renders, then a small secondary label shows "Load: [X] AU" beneath the calories

##### Data Sources

| Data | Provider | Table |
|------|----------|-------|
| Exercise calories | `healthRepositoryProvider` → `MetricType.activeCaloriesBurned` | `wt_health_metrics` |
| Session duration | `workoutLogsProvider(profileId)` → today's logs | `wt_workout_logs` |
| Training load AU | `liveSessionProvider` or `trainingLoadProvider` | Derived from `wt_workout_logs` |

##### WellTrack Integration Points

- Training Load AU is a performance engine output — it feeds into recovery score calculation
- Exercise calories shown here are the same value added to the calorie budget on carousel Page 2 — both read from the same provider to guarantee consistency

##### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See exercise calories and duration | Yes | Yes |
| See Training Load AU label | No — hidden | Yes — shown |

##### Flutter Implementation Notes

- Widget class: `ExerciseSummaryTile` — `ConsumerWidget`
- Both Step and Exercise tiles wrapped in `Expanded` inside a `Row` with `mainAxisAlignment: MainAxisAlignment.spaceEvenly`
- Tiles use `Card` with 8dp corner radius matching app theme

---

## 4. Feature 3 — Weight Trend Chart

### 4.1 Description

A compact line chart showing the user's weight over the last 90 days. A target line indicates the body composition goal. A "+" button enables manual weight logging. Tapping the chart navigates to `/health/weight` for the full weight and body composition screen.

### 4.2 User Story

**ID**: US-MEALS-V4-004
**Epic**: Body Composition Visibility
**Priority**: Medium

**As a** WellTrack user tracking weight or body composition
**I want** to see a 90-day weight trend chart on my dashboard
**So that** I can quickly assess whether I am progressing toward my body composition goal

#### Acceptance Criteria

- [ ] Given weight data exists in `wt_health_metrics` for the last 90 days, when the widget renders, then a line chart displays the weight trend using `fl_chart`'s `LineChart`
- [ ] Given fewer than 3 weight data points exist, when the widget renders, then a zero-state message reads "Log weight to see your trend" with the "+" button prominent
- [ ] Given a body composition goal exists in `wt_goals`, when the chart renders, then a horizontal dashed target line is overlaid at the goal weight value
- [ ] Given the user taps the "+" button, when navigation occurs, then the user is taken to `/weight/log` (see PRD-MEALS-V4-003 for route definition)
- [ ] Given the user taps the chart area, when navigation occurs, then the user is taken to `/health/weight`
- [ ] Given a free user views the chart, when the chart renders, then only the last 7 days of data are shown (matching `PlanTier.historyDays == 7`); the remaining 83 days are obscured with a "Unlock 90-day history" PRO upsell overlay

#### Data Sources

| Data | Provider | Table |
|------|----------|-------|
| Weight measurements | `healthRepositoryProvider.getMetrics(profileId, MetricType.weight, ...)` | `wt_health_metrics` |
| Body composition goal | `goalsProvider(profileId)` → filter for goal type `'body_composition'` | `wt_goals` |

#### Freemium Gating

| Capability | Free | PRO |
|------------|------|-----|
| See weight trend chart | Yes — 7 days | Yes — 90 days |
| Target line from goal | Yes | Yes |
| Manual weight log | Yes | Yes |

#### Flutter Implementation Notes

- Widget class: `WeightTrendChartWidget` — `ConsumerWidget`
- Chart component: `LineChart` from `fl_chart` (already a project dependency)
- Reuse `MetricChart` pattern from `lib/features/health/presentation/widgets/metric_chart.dart`
- For free users, render the full chart but apply a `Stack` with a `BackdropFilter` blur over the left portion (days 8-90) with a `FreemiumGateInline` widget on top
- The "+" button is a `FloatingActionButton.small` positioned using `Stack` in the top-right of the chart card

---

## 5. Feature 4 — Habit and Streak Prompt Card

### 5.1 Description

A contextual prompt card that surfaces a relevant recovery or habit suggestion based on the user's recent behaviour. It is not AI-generated — it is rule-based and deterministic, keeping it free-tier compatible.

### 5.2 User Story

**ID**: US-MEALS-V4-005
**Epic**: Habit Formation and Engagement
**Priority**: Low

**As a** WellTrack user
**I want** to see a contextual prompt on my dashboard that recognises my recent logging consistency
**So that** I feel encouraged to maintain healthy habits and understand what to focus on next

#### Acceptance Criteria

- [ ] Given the user has logged meals on 3 or more consecutive days, when the dashboard loads, then the card reads "You have logged meals [N] days in a row! Keep the streak going." with a CTA to `/meals/diary`
- [ ] Given the user has not logged a meal today and it is past 9am, when the dashboard loads, then the card reads "Log breakfast to start tracking today" with a CTA to `/meals/food-search`
- [ ] Given the user's recovery score is below 40 for 2 consecutive days, when the dashboard loads, then the card reads "Your recovery has been low — consider a rest day today" with a CTA to `/daily-coach/plan`
- [ ] Given no specific condition is triggered, when the dashboard loads, then a default card reads "Set your next recovery goal" with a CTA to `/goals/create`
- [ ] Given the user taps the CTA button, when navigation occurs, then the user is taken to the specified route

#### Data Sources

| Condition | Provider |
|-----------|----------|
| Meal logging streak | Derived from `mealRepositoryProvider.getMealsByDateRange` for last 7 days |
| Today's meal logged | `todayNutritionDashboardProvider(profileId).foodLogged > 0` |
| Recovery score trend | `recoveryScoreProvider(profileId)` for last 2 days |

#### WellTrack Integration Points

- Rule evaluation is performed in `habitPromptProvider(profileId)` — a new `FutureProvider.family` that evaluates conditions in priority order and returns a `HabitPromptData` value object `{message, ctaLabel, ctaRoute}`
- Conditions are evaluated deterministically — no AI calls

#### Freemium Gating

This feature is fully free. The recovery-score-based condition requires a PRO recovery score to be available; if not available, that condition is simply skipped and the next rule fires.

#### Flutter Implementation Notes

- Widget class: `HabitStreakPromptCard` — `ConsumerWidget`
- Renders as a `Card` with a teal/green gradient background, one line of motivational text, and an `ElevatedButton` CTA
- New provider: `habitPromptProvider(profileId)` → `AsyncValue<HabitPromptData>`

---

## 6. Feature 5 — Discover / Quick Access Grid

### 6.1 Description

A 2-column grid of quick-access tiles near the bottom of the dashboard. Each tile has an icon, title, and a one-line tagline. The grid acts as a fast-navigation layer into key WellTrack modules.

### 6.2 User Story

**ID**: US-MEALS-V4-006
**Epic**: Dashboard Navigation Efficiency
**Priority**: Medium

**As a** WellTrack user
**I want** to see a grid of quick-access tiles for key features on my dashboard
**So that** I can navigate to Sleep, Recipes, Workouts, Sync, Recovery, and Daily Coach in one tap

#### Acceptance Criteria

- [ ] Given the dashboard loads, when the discover grid renders, then exactly 6 tiles appear in a 2-column grid: Sleep, Recipes, Workouts, Sync, Recovery, and Daily Coach
- [ ] Given the user taps Sleep, when navigation occurs, then the user is taken to `/health/sleep`
- [ ] Given the user taps Recipes, when navigation occurs, then the user is taken to `/recipes`
- [ ] Given the user taps Workouts, when navigation occurs, then the user is taken to `/workouts`
- [ ] Given the user taps Sync, when navigation occurs, then the user is taken to `/health/connections`
- [ ] Given the user taps Recovery, when navigation occurs, then the user is taken to `/recovery-detail` if PRO, or to `/paywall` if free
- [ ] Given the user taps Daily Coach, when navigation occurs, then the user is taken to `/daily-coach/plan`
- [ ] Given a PRO feature tile (Recovery), when the user is on the free tier, then the tile displays a subtle lock badge in the corner

#### Grid Tile Definitions

| Tile | Icon | Tagline | Route | PRO Gate |
|------|------|---------|-------|----------|
| Sleep | `Icons.bedtime_outlined` | "Track rest quality" | `/health/sleep` | No |
| Recipes | `Icons.menu_book_outlined` | "Browse saved recipes" | `/recipes` | No |
| Workouts | `Icons.fitness_center_outlined` | "Log a session" | `/workouts` | No |
| Sync | `Icons.sync_outlined` | "Health Connect" | `/health/connections` | No |
| Recovery | `Icons.favorite_outlined` | "Today's readiness" | `/recovery-detail` | Yes |
| Daily Coach | `Icons.smart_toy_outlined` | "Your daily plan" | `/daily-coach/plan` | Yes |

#### Freemium Gating

Recovery and Daily Coach tiles are visible to all users but show a lock badge for free users. Tapping a locked tile navigates to `/paywall` rather than the feature route.

#### Flutter Implementation Notes

- Widget class: `DiscoverQuickAccessGrid` — `ConsumerWidget`
- Tile widget: `DiscoverTile` — a `Card` with `InkWell`, `Column` (icon + title + tagline), and optional lock badge overlay
- Grid uses `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics())`
- Lock badge: a small `Icon(Icons.lock, size: 14)` positioned via `Stack` in the top-right corner of the tile
- Tile tap handler checks `ref.read(planTierProvider)` before navigating — PRO tiles redirect free users to `/paywall`

---

## 7. Provider Summary

The following new Riverpod providers are required by the features in this PRD:

| Provider | Type | Returns | Depends On |
|----------|------|---------|------------|
| `todayMacroSummaryProvider(profileId)` | `FutureProvider.family` | `{carbsG, fatG, proteinG}` consumed today | `mealRepositoryProvider` |
| `todayCalorieSummaryProvider(profileId)` | `FutureProvider.family` | `{baseGoal, foodLogged, exerciseCalories, remaining}` | `prescriptionEngineProvider`, `mealRepositoryProvider`, `healthRepositoryProvider` |
| `todayMicronutrientSummaryProvider(profileId)` | `FutureProvider.family` | `{fatTotalG, sodiumMg, cholesterolMg, netCarbsG, sugarG, fiberG}` | `mealRepositoryProvider` |
| `todayNutritionDashboardProvider(profileId)` | `FutureProvider.family` | Combined nutrition state for carousel | Above three providers via `Future.wait` |
| `habitPromptProvider(profileId)` | `FutureProvider.family` | `HabitPromptData {message, ctaLabel, ctaRoute}` | `mealRepositoryProvider`, `recoveryScoreProvider` |

---

## 8. Assumptions and Dependencies

### Assumptions

1. `nutritionInfo` JSONB in `wt_meals` contains at minimum `calories`, `carbs_g`, `fat_g`, `protein_g` for all logged meals from the food search flow
2. The prescription engine runs daily and its output is available in `wt_prescription_outputs` by the time the dashboard loads
3. `fl_chart` is already a project dependency (confirmed in CLAUDE.md)
4. `ShimmerLoading` widget from `shimmer_loading.dart` is reusable as-is

### Dependencies

- **Prescription engine output**: The recovery-adjusted calorie goal on carousel Page 2 requires `prescription_engine.dart` to have executed for today. If not available, a graceful fallback to `MacroCalculator` applies.
- **Open Food Facts nutrient data**: Pages 3 and 4 (Heart Healthy, Low Carb) are only meaningful if micronutrient fields are populated. These depend on the food search integration storing full nutrient profiles in `wt_meals.nutritionInfo`.
- **Health Connect permissions**: Steps and exercise data require Health Connect to be connected and permissions granted.

### Out of Scope

- Real-time WebSocket updates to carousel values (polling on screen focus is sufficient)
- AI-generated narrative text within any carousel page (AI belongs in coaching screens only)
- Custom goal-setting UI (covered by existing `/settings/nutrition-targets` route)
- Social or sharing features on any widget

---

## 9. Definition of Done

- [ ] All 6 widget classes implemented as `ConsumerWidget`s with no direct Supabase calls
- [ ] All 5 new providers implemented, tested with mock data, and integrated with real repositories
- [ ] Freemium gates verified: free users see correct locked/blurred states; PRO users see full data
- [ ] Recovery-adjusted calorie label confirmed to display prescription engine output for PRO users
- [ ] `flutter analyze` passes with zero warnings on all new files
- [ ] Widgets handle loading, error, and empty states without crashing
- [ ] Navigation from each tap target verified on device

---

## 10. Glossary

| Term | Definition |
|------|------------|
| Recovery-Adjusted Target | A calorie or macro goal calculated by `prescription_engine.dart` using today's recovery score — not a static user preference |
| Day Type | Classification of today's training plan: `strength`, `cardio`, or `rest` — determined by prescription engine output |
| Net Carbs | Total carbohydrates minus dietary fiber |
| Training Load AU | Arbitrary Unit measure of cumulative training stress, derived from `wt_workout_logs` in `performance_engine.dart` |
| PRO | `PlanTier.pro` subscription tier as defined in `plan_tier.dart` |
