# PRD: Meals v4 — Navigation Architecture

**Document ID**: PRD-MEALS-V4-003
**Status**: Draft
**Created**: 2026-03-16
**Author**: Business Analysis
**Branch**: ralph/phase-13-ux-refinement
**Related PRDs**: PRD-MEALS-V4-001 (Dashboard Widgets), PRD-MEALS-V4-002 (Enhanced FAB)

---

## 1. Overview

This PRD documents the navigation architecture for all screens and widgets introduced by the Meals v4 enhancements. It serves as the authoritative reference for where each new screen lives in the GoRouter tree, how users reach each screen, what back navigation looks like, and which routes require new registration in `app_router.dart`.

This document does not define feature behaviour in detail — that is covered in PRD-MEALS-V4-001 and PRD-MEALS-V4-002. It defines path, placement, navigation target, back behaviour, and deep link support for each route or widget anchor.

### 1.1 Guiding Principles

1. **All navigation uses GoRouter** — `context.go()` for tab-level navigation, `context.push()` for drill-through screens that need back capability, `Navigator.pop()` only to dismiss modal bottom sheets
2. **NEVER use `Navigator.pushNamed()`** — this is a hard project constraint per CLAUDE.md
3. **Dashboard widgets are not routes** — the carousel, steps/exercise tiles, weight chart, habit card, and discover grid are embedded widgets within `DashboardScreen`. They are not registered in the GoRouter tree. Only their drill-through destinations are routes.
4. **Modal sheets are not routes** — the FAB bottom sheet, Quick Add sub-sheet, and Water stepper are modal overlays triggered via `showModalBottomSheet`. They do not have GoRouter paths.
5. **PRO gates are enforced at the widget level** — route guards do not block PRO-only routes. The presentation layer is responsible for checking `planTierProvider` and redirecting free users to `/paywall` before navigation. This preserves deep link support.

### 1.2 Current Bottom Navigation Structure

The app uses a `StatefulShellRoute.indexedStack` with 4 branches:

| Index | Tab Label | Root Route | Branch Content |
|-------|-----------|------------|----------------|
| 0 | Home | `/` | Dashboard — all dashboard widgets and their sub-routes |
| 1 | Log | `/daily-view` | Daily View / Diary |
| 2 | Workouts | `/workouts` | Workouts hub |
| 3 | Profile | `/profile` | Profile screen |

The central FAB "+" is a special action in `ScaffoldWithBottomNav` — it is not a branch. It opens the Enhanced FAB Bottom Sheet (PRD-MEALS-V4-002).

---

## 2. Route Tree

The following tree shows the complete GoRouter route structure after Meals v4 changes. New routes introduced by this PRD are marked **[NEW]**. Existing routes are unmarked.

```
/splash                          (no shell — auth guard)
/login                           (no shell — auth guard)
/signup                          (no shell — auth guard)
/onboarding                      (no shell — auth guard)
/paywall                         (no shell — modal-style)

StatefulShellRoute (ScaffoldWithBottomNav)
│
├── Branch 0: Home  (root: /)
│   /                            (DashboardScreen — contains all embedded widgets)
│   │   ├── [WIDGET] NutritionSummaryCarousel
│   │   ├── [WIDGET] ExerciseSummaryRow (StepsTile + ExerciseTile)
│   │   ├── [WIDGET] WeightTrendChartWidget
│   │   ├── [WIDGET] HabitStreakPromptCard
│   │   └── [WIDGET] DiscoverQuickAccessGrid
│   │
│   ├── pantry
│   ├── pantry/photo-import
│   ├── recipes                  (RecipeListScreen — updated for selectMode)
│   ├── recipes/suggestions
│   ├── recipes/import-url
│   ├── recipes/import-ocr
│   ├── recipes/:id
│   ├── recipes/:id/edit
│   ├── shopping
│   ├── shopping/:id
│   ├── shopping/:id/photo-import
│   ├── shopping/:id/barcode-scan
│   │
│   ├── meals/log                (LogMealScreen — existing)
│   ├── meals/plan               (MealPlanScreen — existing)
│   ├── meals/prep               (MealPrepScreen — existing)
│   ├── meals/shopping-generator
│   ├── meals/food-search        (FoodSearchScreen — existing)
│   ├── meals/food-barcode-scan  (FoodBarcodeScannerScreen — existing)
│   ├── meals/nutrition-profiles
│   ├── meals/weekly-summary
│   ├── meals/diary              [NEW] MealDiaryScreen (alias or redirect to /daily-view)
│   ├── meals/voice-log          [NEW] VoiceLogScreen (PRO, future — stub for now)
│   ├── meals/meal-scan          [NEW] MealScanScreen (PRO, future — stub for now)
│   │
│   ├── nutrition                [NEW] NutritionDetailScreen (carousel drill-through)
│   ├── water/log                [NEW] WaterLogScreen
│   ├── weight/log               [NEW] WeightLogScreen
│   │
│   ├── health/connections
│   ├── health/steps
│   ├── health/sleep
│   ├── health/heart
│   ├── health/weight
│   ├── health/vo2max-entry
│   │
│   ├── insights
│   ├── recovery-detail
│   ├── goals
│   ├── goals/create
│   ├── goals/:goalId
│   ├── supplements
│   ├── bloodwork
│   ├── bloodwork/:testName
│   ├── habits
│   ├── habits/kegel-timer
│   ├── daily-coach/checkin
│   ├── daily-coach/plan
│   ├── reminders
│   ├── settings
│   ├── settings/health
│   ├── settings/nutrition-targets
│   └── settings/ingredient-preferences
│
├── Branch 1: Log (root: /daily-view)
│   /daily-view
│
├── Branch 2: Workouts (root: /workouts)
│   /workouts
│   ├── workouts/plan/:planId
│   ├── workouts/exercises
│   ├── workouts/log/:workoutId
│   ├── workouts/summary/:workoutId
│   ├── workouts/progress
│   └── workouts/body-map
│
└── Branch 3: Profile (root: /profile)
    /profile
```

---

## 3. New Routes — Detailed Specification

### 3.1 Route: `/meals/diary`

**Status**: New
**Type**: Full route (within Branch 0 shell)
**Widget**: `MealDiaryScreen` — or redirect to `/daily-view` if the daily view already serves as the diary

#### Specification

The `/meals/diary` route is referenced from two places:
- The FAB sheet — "AI Suggestions" and diary-linked CTAs
- The Habit Streak Prompt card — "Keep the streak going" CTA

If `DailyViewScreen` already provides full diary functionality (meal log by day), this route should be a **redirect** to `/daily-view` rather than a new screen.

#### Acceptance Criteria

- [ ] Given any navigation target sends the user to `/meals/diary`, when the route resolves, then either `MealDiaryScreen` renders or a redirect to `/daily-view` occurs — the user lands on a diary/food log view
- [ ] Given the user navigates to `/meals/diary` from a deep link, when the route resolves, then the bottom nav highlights the Log tab (Branch 1)

#### GoRouter Registration

```dart
// If redirect approach:
GoRoute(
  path: 'meals/diary',
  name: 'mealDiary',
  redirect: (context, state) => '/daily-view',
),

// If new screen approach:
GoRoute(
  path: 'meals/diary',
  name: 'mealDiary',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return MealDiaryScreen(profileId: profileId);
  },
),
```

**Recommendation**: Use the redirect approach to avoid screen duplication. `DailyViewScreen` should be verified as providing diary functionality — if not, it must be extended before this redirect is valid.

---

### 3.2 Route: `/meals/voice-log`

**Status**: New (stub — PRO, future feature)
**Type**: Full route (within Branch 0 shell)
**Widget**: `VoiceLogScreen` — stub screen

#### Specification

This route exists to support the PRO locked tile in the Enhanced FAB. The route is registered but leads to a stub screen that shows a "coming soon" message. When the Voice Log feature is built in a future sprint, this screen is replaced with the real implementation.

#### Acceptance Criteria

- [ ] Given a PRO user navigates to `/meals/voice-log`, when the screen renders, then it displays "Voice logging is coming soon" with a back button
- [ ] Given a free user attempts to navigate to `/meals/voice-log`, when the route is accessed, then the navigation is intercepted before leaving the FAB sheet and redirected to `/paywall` — the route itself does not enforce a gate (PRO check happens in the FAB tile tap handler)
- [ ] Given the route is registered in `app_router.dart`, when the app is analysed with `flutter analyze`, then no errors are reported

#### GoRouter Registration

```dart
GoRoute(
  path: 'meals/voice-log',
  name: 'voiceLog',
  builder: (context, state) => const VoiceLogScreen(),
),
```

#### Back Navigation

Back button on the stub screen returns to the previous route in the GoRouter stack (typically `/` or wherever the user tapped from).

---

### 3.3 Route: `/meals/meal-scan`

**Status**: New (stub — PRO, future feature)
**Type**: Full route (within Branch 0 shell)
**Widget**: `MealScanScreen` — stub screen

#### Specification

Identical pattern to `/meals/voice-log`. Registered as a stub, replaced in a future sprint.

#### Acceptance Criteria

- [ ] Given a PRO user navigates to `/meals/meal-scan`, when the screen renders, then it displays "AI meal scanning is coming soon" with a back button
- [ ] Given the route is registered, when `flutter analyze` runs, then no errors are reported

#### GoRouter Registration

```dart
GoRoute(
  path: 'meals/meal-scan',
  name: 'mealScan',
  builder: (context, state) => const MealScanScreen(),
),
```

---

### 3.4 Route: `/nutrition`

**Status**: New
**Type**: Full route (within Branch 0 shell)
**Widget**: `NutritionDetailScreen`
**Entry Points**: Tapping any page of the `NutritionSummaryCarousel`; tapping the diary nutrition summary

#### Specification

The `/nutrition` route is the drill-through destination from the dashboard carousel. It provides a full-screen view of today's nutrition: all four views from the carousel (macros rings, calories budget, heart healthy, low carb) plus a meal-by-meal breakdown of the day's food log.

This screen is distinct from `/settings/nutrition-targets` (which manages goals) and `/meals/weekly-summary` (which shows historical data). `/nutrition` is always today's data.

#### Acceptance Criteria

- [ ] Given the user taps any page of the `NutritionSummaryCarousel`, when navigation occurs, then the user arrives at `/nutrition` scrolled to the section corresponding to the carousel page they tapped (using a `tab` query parameter: `?tab=macros`, `?tab=calories`, `?tab=heart`, `?tab=lowcarb`)
- [ ] Given the user arrives at `/nutrition`, when the screen renders, then a tab bar at the top allows switching between Macros, Calories, Heart Healthy, and Low Carb views — matching the carousel pages
- [ ] Given the Calories tab is active, when a PRO user views it, then the recovery-adjusted target label and recovery score badge are visible (same as carousel Page 2)
- [ ] Given the Calories tab is active, when a free user views it, then the estimated target label is shown and the recovery score badge is locked
- [ ] Given the user scrolls below the tab views, when the scroll occurs, then a "Today's Meals" section shows each logged meal with its nutrition summary
- [ ] Given the user taps a meal entry in the "Today's Meals" section, when the tap occurs, then the meal detail bottom sheet opens (edit/delete options)
- [ ] Given the user taps the back button, when navigation occurs, then the user returns to the dashboard (`/`)
- [ ] Given a deep link to `/nutrition?tab=heart`, when the app opens, then the Nutrition Detail Screen opens with the Heart Healthy tab active

#### Query Parameters

| Parameter | Values | Behaviour |
|-----------|--------|-----------|
| `tab` | `macros`, `calories`, `heart`, `lowcarb` | Pre-selects the active tab on screen open |

#### GoRouter Registration

```dart
GoRoute(
  path: 'nutrition',
  name: 'nutritionDetail',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    final tab = state.uri.queryParameters['tab'] ?? 'macros';
    return NutritionDetailScreen(
      profileId: profileId,
      initialTab: tab,
    );
  },
),
```

#### Back Navigation

Uses `context.pop()` — returns to whatever screen launched `/nutrition`. If launched from the dashboard carousel, returns to `/`. If launched from a deep link with no history, falls back to `/`.

---

### 3.5 Route: `/water/log`

**Status**: New
**Type**: Full route (within Branch 0 shell)
**Widget**: `WaterLogScreen`
**Entry Points**: FAB sheet "Water" list item; future: water widget on dashboard

#### Specification

A simple screen for logging water intake. While the FAB sheet also supports an inline cup stepper, the full `/water/log` route provides a more complete logging experience with history and the ability to set a daily goal.

#### Acceptance Criteria

- [ ] Given the user navigates to `/water/log`, when the screen renders, then it shows: today's total cups, a stepper to add cups, today's goal, and a progress bar
- [ ] Given the user taps the "+" button to add a cup, when the tap occurs, then the count increments and the progress bar updates in real time (optimistic UI)
- [ ] Given the user has logged water today, when the screen renders, then a small history of today's logs is shown (timestamp + cups)
- [ ] Given the user taps the back button, when navigation occurs, then the user returns to the previous screen

#### GoRouter Registration

```dart
GoRoute(
  path: 'water/log',
  name: 'waterLog',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return WaterLogScreen(profileId: profileId);
  },
),
```

#### Back Navigation

`context.pop()` — returns to the caller (FAB sheet has already dismissed by the time this screen opens).

---

### 3.6 Route: `/weight/log`

**Status**: New
**Type**: Full route (within Branch 0 shell)
**Widget**: `WeightLogScreen`
**Entry Points**: FAB sheet "Weight" list item; "+" button on `WeightTrendChartWidget` on dashboard

#### Specification

A focused screen for entering a single weight measurement. It is intentionally minimal — just the input and save — because the user's intent is clear when they arrive here. The full historical view and body composition analysis live at `/health/weight`.

#### Acceptance Criteria

- [ ] Given the user navigates to `/weight/log`, when the screen renders, then it shows: a numeric input for weight, a unit selector (kg/lbs), the date (defaulting to today), and a "Save" button
- [ ] Given the user enters a valid weight and taps "Save", when the save occurs, then the weight is written to `wt_health_metrics` with `metric_type: 'weight'` and the user is returned to the previous screen with a success snackbar
- [ ] Given the user enters an implausible weight (e.g., < 20kg or > 400kg), when validation runs, then an inline error "Please enter a valid weight" is shown and the save is blocked
- [ ] Given the user taps the back button without saving, when navigation occurs, then the user returns to the previous screen with no data written
- [ ] Given a successful save, when the user returns to the dashboard, then the `WeightTrendChartWidget` reflects the new data point on next load

#### GoRouter Registration

```dart
GoRoute(
  path: 'weight/log',
  name: 'weightLog',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return WeightLogScreen(profileId: profileId);
  },
),
```

#### Back Navigation

`context.pop()` — returns to dashboard or wherever the user came from.

---

## 4. Widget-to-Route Navigation Map

This section documents every tap interaction in the new dashboard widgets and the route each tap targets. This is the definitive reference for implementing `onTap` handlers.

### 4.1 NutritionSummaryCarousel

| Tap Target | Route | Method | Notes |
|------------|-------|--------|-------|
| Macros page (Page 1) | `/nutrition?tab=macros` | `context.push` | Drill-through — back returns to dashboard |
| Calories page (Page 2) | `/nutrition?tab=calories` | `context.push` | |
| Heart Healthy page (Page 3) — PRO | `/nutrition?tab=heart` | `context.push` | Free users: same — gate is inside NutritionDetailScreen |
| Low Carb page (Page 4) — PRO | `/nutrition?tab=lowcarb` | `context.push` | |
| Recovery score badge — PRO | `/recovery-detail` | `context.push` | Free users: `context.push('/paywall')` |
| Recovery score badge — free | `/paywall` | `context.push` | |
| Zero-state CTA "Log your first meal" | `/meals/food-search` | `context.push` | |

### 4.2 Steps Tile

| Tap Target | Route | Method | Notes |
|------------|-------|--------|-------|
| Steps tile (any area) | `/health/steps` | `context.push` | |
| "Connect" link (no Health Connect) | `/health/connections` | `context.push` | |

### 4.3 Exercise Tile

| Tap Target | Route | Method | Notes |
|------------|-------|--------|-------|
| Exercise tile body | `/workouts` | `context.go` | Switches to Workouts tab |
| "+" add button | FAB bottom sheet | `showModalBottomSheet` | Opens `EnhancedLogBottomSheet` |

### 4.4 WeightTrendChartWidget

| Tap Target | Route | Method | Notes |
|------------|-------|--------|-------|
| Chart area | `/health/weight` | `context.push` | Full weight and body composition screen |
| "+" button | `/weight/log` | `context.push` | |
| PRO upsell overlay (free user) | `/paywall` | `context.push` | For 90-day history lock |

### 4.5 HabitStreakPromptCard

| Tap Target | Route | Method | Notes |
|------------|-------|--------|-------|
| "Keep the streak" CTA | `/meals/diary` | `context.push` | Resolves to diary or `/daily-view` redirect |
| "Log breakfast" CTA | `/meals/food-search` | `context.push` | |
| "Consider a rest day" CTA | `/daily-coach/plan` | `context.push` | |
| "Set your next recovery goal" CTA | `/goals/create` | `context.push` | |

### 4.6 DiscoverQuickAccessGrid

| Tile | Route — Free User | Route — PRO User | Method |
|------|-------------------|------------------|--------|
| Sleep | `/health/sleep` | `/health/sleep` | `context.push` |
| Recipes | `/recipes` | `/recipes` | `context.push` |
| Workouts | `/workouts` | `/workouts` | `context.go` (switches tab) |
| Sync | `/health/connections` | `/health/connections` | `context.push` |
| Recovery | `/paywall` | `/recovery-detail` | `context.push` |
| Daily Coach | `/paywall` | `/daily-coach/plan` | `context.push` |

### 4.7 Enhanced FAB Bottom Sheet

| Action | Route | Method | Notes |
|--------|-------|--------|-------|
| Log Food | `/meals/food-search` | `Navigator.pop` + `context.push` | Dismiss sheet first |
| Barcode Scan | `/meals/food-barcode-scan` | `Navigator.pop` + `context.push` | |
| Voice Log — free | `/paywall` | `Navigator.pop` + `context.push` | |
| Voice Log — PRO | `/meals/voice-log` | `Navigator.pop` + `context.push` | Snackbar "coming soon" |
| Meal Scan — free | `/paywall` | `Navigator.pop` + `context.push` | |
| Meal Scan — PRO | `/meals/meal-scan` | `Navigator.pop` + `context.push` | Snackbar "coming soon" |
| Water | Water stepper sub-sheet | `showModalBottomSheet` | Nested modal |
| Weight | `/weight/log` | `Navigator.pop` + `context.push` | |
| Exercise | `/workouts` | `Navigator.pop` + `context.go` | Switches tab |
| AI Suggestions — free | `/paywall` | `Navigator.pop` + `context.push` | |
| AI Suggestions — PRO | Suggestions sheet | `showModalBottomSheet` | Nested modal |
| From Recipes | `/recipes?selectMode=true` | `Navigator.pop` + `context.push` | |
| Quick Add | Quick Add sub-sheet | `showModalBottomSheet` | Nested modal |

---

## 5. Back Navigation Behaviour

### 5.1 General Rule

All routes registered under Branch 0 (`/`) support the Android system back button and the iOS swipe-back gesture by default through GoRouter's `context.pop()`. The following specific cases require attention:

| Route | Back Destination | Behaviour |
|-------|-----------------|-----------|
| `/nutrition` | `/` (dashboard) | `context.pop()` — standard |
| `/weight/log` | Previous screen | `context.pop()` — standard |
| `/water/log` | Previous screen | `context.pop()` — standard |
| `/meals/voice-log` | Previous screen | `context.pop()` — standard |
| `/meals/meal-scan` | Previous screen | `context.pop()` — standard |
| `/paywall` | Previous screen | `context.pop()` — standard |

### 5.2 Modal Sheet Back Behaviour

Modal bottom sheets (FAB sheet, Quick Add sub-sheet, Water stepper, AI Suggestions sheet) are dismissed via:
- Swipe down gesture (built into `DraggableScrollableSheet`)
- Tap on the scrim behind the sheet
- `Navigator.pop(context)` called from within the sheet

These are not GoRouter routes and do not appear in the navigation stack. Back from a sheet returns to the screen behind it (typically `/`).

### 5.3 Deep Link Entry Back Behaviour

When a user enters the app via a deep link to a nested route (e.g., `/nutrition?tab=heart`), the GoRouter stack may not contain `/` as a predecessor. In this case:

- If the stack is empty above the shell, `context.pop()` on `/nutrition` should navigate to `/` (the dashboard)
- This is handled by the `StatefulShellRoute` — Branch 0's root route `/` is always the fallback

No special handling is required beyond ensuring all new routes are registered as children of the `/` route inside Branch 0.

---

## 6. Deep Link Support

All routes registered in this PRD support deep linking. The following deep link patterns are valid:

| Deep Link | Screen Opened | Auth Required |
|-----------|--------------|---------------|
| `welltrack://nutrition` | NutritionDetailScreen (macros tab) | Yes |
| `welltrack://nutrition?tab=calories` | NutritionDetailScreen (calories tab) | Yes |
| `welltrack://nutrition?tab=heart` | NutritionDetailScreen (heart healthy tab) | Yes |
| `welltrack://nutrition?tab=lowcarb` | NutritionDetailScreen (low carb tab) | Yes |
| `welltrack://weight/log` | WeightLogScreen | Yes |
| `welltrack://water/log` | WaterLogScreen | Yes |
| `welltrack://meals/diary` | MealDiaryScreen or redirect to daily-view | Yes |
| `welltrack://meals/voice-log` | VoiceLogScreen (stub) | Yes |
| `welltrack://meals/meal-scan` | MealScanScreen (stub) | Yes |

Deep links that target PRO-only routes (`/recovery-detail`, `/daily-coach/plan`) are handled by the existing freemium gate at the presentation layer — the route resolves and the screen checks the plan tier on mount.

Deep link validation is handled by the existing `RouteGuards.checkAll()` in `route_guards.dart`. The guard redirects unauthenticated deep link attempts to `/login` and post-login restores the intended route via GoRouter's redirect mechanism.

---

## 7. Route Registration in `app_router.dart`

The following code additions must be made to `app_router.dart` inside Branch 0's `routes` list. All additions are siblings of the existing meal and health routes.

### 7.1 New Import Declarations

```dart
// New meals v4 screens
import '../../../features/meals/presentation/meal_diary_screen.dart'
    as meal_diary;
import '../../../features/meals/presentation/voice_log_screen.dart'
    as voice_log;
import '../../../features/meals/presentation/meal_scan_screen.dart'
    as meal_scan;
import '../../../features/meals/presentation/nutrition_detail_screen.dart'
    as nutrition_detail;
import '../../../features/water/presentation/water_log_screen.dart'
    as water_log;
import '../../../features/health/presentation/screens/weight_log_screen.dart'
    as weight_log;
```

### 7.2 New GoRoute Registrations

These routes are inserted inside Branch 0's `routes` list, in the Meals sub-section:

```dart
// ── Meals v4 additions ───────────────────────────────────────
GoRoute(
  path: 'meals/diary',
  name: 'mealDiary',
  // Redirect to daily-view if DailyViewScreen serves as diary.
  // Replace with builder if a dedicated MealDiaryScreen is created.
  redirect: (context, state) => '/daily-view',
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
GoRoute(
  path: 'nutrition',
  name: 'nutritionDetail',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    final tab = state.uri.queryParameters['tab'] ?? 'macros';
    return nutrition_detail.NutritionDetailScreen(
      profileId: profileId,
      initialTab: tab,
    );
  },
),
GoRoute(
  path: 'water/log',
  name: 'waterLog',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return water_log.WaterLogScreen(profileId: profileId);
  },
),
GoRoute(
  path: 'weight/log',
  name: 'weightLog',
  builder: (context, state) {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    return weight_log.WeightLogScreen(profileId: profileId);
  },
),
```

### 7.3 Existing Route Updated: `/recipes`

The `RecipeListScreen` at path `recipes` must be updated to accept a `selectMode` query parameter:

```dart
GoRoute(
  path: 'recipes',
  name: 'recipeList',
  builder: (context, state) {
    final selectMode =
        state.uri.queryParameters['selectMode'] == 'true';
    return recipe_list.RecipeListScreen(selectMode: selectMode);
  },
),
```

The `RecipeListScreen` widget must be updated to accept a `bool selectMode` parameter and conditionally render "Use this recipe" buttons instead of the default "View" action.

### 7.4 Route Guard Update

The existing `needsProfile` check in `app_router.dart` must be extended to include the new routes:

```dart
final needsProfile = requestedPath == '/' ||
    requestedPath == '/daily-view' ||
    requestedPath.startsWith('/health/') ||
    requestedPath == '/insights' ||
    requestedPath == '/supplements' ||
    requestedPath == '/workouts' ||
    requestedPath.startsWith('/workouts/') ||
    requestedPath.startsWith('/goals') ||
    requestedPath.startsWith('/meals/') ||
    requestedPath.startsWith('/daily-coach/') ||
    requestedPath == '/bloodwork' ||
    requestedPath.startsWith('/bloodwork/') ||
    requestedPath == '/habits' ||
    requestedPath == '/habits/kegel-timer' ||
    requestedPath == '/nutrition' ||        // [NEW]
    requestedPath == '/water/log' ||        // [NEW]
    requestedPath == '/weight/log';         // [NEW]
```

---

## 8. Screen Classification

The table below classifies each item in the Meals v4 ecosystem as either a widget (embedded in a parent screen), a route (a GoRouter-registered screen), or a modal (a `showModalBottomSheet` overlay).

| Item | Classification | Parent / Route |
|------|---------------|----------------|
| `NutritionSummaryCarousel` | Widget | Embedded in `DashboardScreen` |
| `MacroRingsCarouselPage` | Widget | Child of `NutritionSummaryCarousel` |
| `CaloriesBudgetCarouselPage` | Widget | Child of `NutritionSummaryCarousel` |
| `HeartHealthyCarouselPage` | Widget | Child of `NutritionSummaryCarousel` |
| `LowCarbCarouselPage` | Widget | Child of `NutritionSummaryCarousel` |
| `StepsSummaryTile` | Widget | Embedded in `DashboardScreen` |
| `ExerciseSummaryTile` | Widget | Embedded in `DashboardScreen` |
| `WeightTrendChartWidget` | Widget | Embedded in `DashboardScreen` |
| `HabitStreakPromptCard` | Widget | Embedded in `DashboardScreen` |
| `DiscoverQuickAccessGrid` | Widget | Embedded in `DashboardScreen` |
| `EnhancedLogBottomSheet` | Modal | Triggered by FAB tap in `ScaffoldWithBottomNav` |
| Water Stepper Sub-sheet | Modal | Triggered from `EnhancedLogBottomSheet` |
| Quick Add Sub-sheet | Modal | Triggered from `EnhancedLogBottomSheet` |
| AI Suggestions Sub-sheet | Modal | Triggered from `EnhancedLogBottomSheet` |
| `NutritionDetailScreen` | Route | `/nutrition` |
| `WaterLogScreen` | Route | `/water/log` |
| `WeightLogScreen` | Route | `/weight/log` |
| `VoiceLogScreen` | Route (stub) | `/meals/voice-log` |
| `MealScanScreen` | Route (stub) | `/meals/meal-scan` |
| `MealDiaryScreen` | Route (redirect) | `/meals/diary` → `/daily-view` |

---

## 9. Assumptions and Dependencies

### Assumptions

1. `DailyViewScreen` at `/daily-view` functions as the meal diary. The `/meals/diary` route redirects to it. If `DailyViewScreen` does not have diary functionality, a dedicated `MealDiaryScreen` must be built before the redirect can be replaced.
2. The `RecipeListScreen` can be updated to accept a `bool selectMode` parameter without breaking existing recipe list behaviour.
3. Weight logging via `/weight/log` writes to `wt_health_metrics` using the same `MetricType.weight` path as Health Connect weight data, with `source: 'manual'` to distinguish it.
4. The water logging route writes to either `wt_health_metrics` (metric_type: 'water') or a dedicated `wt_water_logs` table — the route architecture is the same either way.

### Dependencies

- **PRD-MEALS-V4-001**: The dashboard widgets that provide the carousel, steps/exercise row, weight chart, habit card, and discover grid are specified in PRD-MEALS-V4-001. The routes defined here are the drill-through targets for those widgets.
- **PRD-MEALS-V4-002**: The Enhanced FAB bottom sheet is specified in PRD-MEALS-V4-002. The routes defined here are the navigation targets for the FAB sheet actions.
- **`app_router.dart`**: All route additions described in Section 7 must be applied to the existing router file. The file is at `lib/shared/core/router/app_router.dart`.
- **`route_guards.dart`**: The `needsProfile` list in the router's `redirect` function must be updated per Section 7.4.

### Out of Scope

- New bottom navigation tabs (the 4-tab structure is unchanged)
- Route-level PRO guards (gates are enforced at widget/tap level, not route level)
- Push notification deep links beyond the patterns listed in Section 6
- Web URL routing (this is a mobile app; web routing is not in scope)

---

## 10. Definition of Done

- [ ] All 6 new routes registered in `app_router.dart` with correct builders
- [ ] `needsProfile` guard extended to include `/nutrition`, `/water/log`, `/weight/log`
- [ ] `RecipeListScreen` updated to accept and handle `selectMode` query parameter
- [ ] All `context.go()` and `context.push()` calls in new widgets use route names or paths from this document — no hardcoded strings other than the canonical paths defined here
- [ ] Deep link patterns in Section 6 verified by navigating to each URL during device testing
- [ ] Back navigation verified for each new route — Android system back button returns to expected screen
- [ ] `flutter analyze` passes with zero warnings on `app_router.dart` and all new screen files
- [ ] No `Navigator.pushNamed()` calls introduced anywhere in the new code

---

## 11. Glossary

| Term | Definition |
|------|------------|
| `context.go()` | GoRouter navigation that replaces the current route stack — used for tab-level switches |
| `context.push()` | GoRouter navigation that adds to the route stack — used for drill-through screens where back is expected |
| `context.pop()` | GoRouter navigation that removes the current route from the stack — equivalent to back button |
| `StatefulShellRoute` | GoRouter's persistent shell that maintains tab state and renders the bottom navigation bar |
| Branch | One tab in the `StatefulShellRoute.indexedStack`, identified by its root route path |
| `showModalBottomSheet` | Flutter API for displaying a non-routed overlay sheet anchored to the bottom of the screen |
| Widget | A UI component embedded inside a screen — not registered in GoRouter, not reachable by deep link |
| Route | A GoRouter-registered screen reachable by path, navigation call, and deep link |
| `selectMode` | Query parameter on the `/recipes` route that changes the list UI to a selection mode for logging |
| Stub Screen | A minimal screen implementation showing a placeholder message, used to register a route that will be fully implemented in a future sprint |
