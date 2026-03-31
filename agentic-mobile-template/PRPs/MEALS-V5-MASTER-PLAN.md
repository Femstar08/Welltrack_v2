# WellTrack Meals v5 — Master Plan

**Created**: 2026-03-18
**Branch**: `ralph/phase-13-ux-refinement`
**Status**: Decisions locked, ready for implementation

---

## 1. What We're Building

Enhancement of the meals module from a standalone food-logging tool into a **performance-driven nutrition system** fully integrated with WellTrack's recovery engine. Inspired by MFP's dashboard patterns but differentiated by WellTrack's core identity: **recovery score drives calorie targets, math generates the plan, AI explains it.**

### New Features
1. **Dashboard Nutrition Carousel** — 4-page swipeable summary (Macros rings, Calories ring, Heart Healthy bars, Low Carb bars)
2. **Steps + Exercise Widgets** — side-by-side cards with Health Connect data + training load
3. **Weight Trend Chart** — 90-day line chart with goal target line
4. **Habit/Streak Prompt Card** — contextual nudge based on logging streak + recovery state
5. **Discover Quick Access Grid** — 2x2 feature tiles (Sleep, Recipes, Workouts, Recovery, etc.)
6. **Enhanced FAB (+) Bottom Sheet** — 2x2 grid (Log Food, Barcode, Voice Log, Meal Scan) + list (Water, Weight, Exercise, AI Suggestions, Recipes, Quick Add)

---

## 2. Architectural Decisions (Locked)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Meals carousel = section WITHIN existing dashboard** (Option B) | Dashboard is the performance hub. Meals is part of that story, not a replacement. |
| 2 | **"--" for missing micronutrient data** (Heart Healthy / Low Carb) | Ship value fast. Carousel pages 3-4 render "--" for untracked sodium/cholesterol/fiber. |
| 3 | **AI meal suggestions = "Coming Soon"** | Clear distinction between built and planned. Show Coming Soon state, don't create fake providers. |
| 4 | **New `wt_water_logs` table** for water logging | Separate concern. Don't pollute `wt_health_metrics`. New entity + repository needed. |
| 5 | **Remove `SecondaryModulesList`**, Discover grid replaces it | No duplicates or redundancies. |
| 6 | **Use `smooth_page_indicator` package** for carousel dots | Lightweight, well-maintained, animated transitions out of the box. |
| 7 | **Voice Log + Meal Scan always visible** but PRO-locked | Free users see what they're missing. Consistent with freemium philosophy. |
| 8 | **Freemium gates at widget/tap level only** | No route-level blocking. Preserves deep links. |
| 9 | **PRO users see "Recovery-Adjusted" calorie target** from prescription engine | Free users see static `MacroCalculator` target. |

---

## 3. PRD Documents

| PRD | File | Covers |
|-----|------|--------|
| Dashboard Widgets | `PRPs/meals-v4-dashboard-widgets.md` | Carousel, Steps/Exercise, Weight chart, Habit card, Discover grid |
| Enhanced FAB | `PRPs/meals-v4-enhanced-fab.md` | 2x2 grid + list layout, Voice Log, Meal Scan, Water stepper |
| Navigation Architecture | `PRPs/meals-v4-navigation-architecture.md` | Route tree, GoRouter registrations, deep link support |
| Implementation Plan | `PRPs/meals-v5-implementation-plan.md` | Full technical spec with provider architecture, widget specs, phase order |

---

## 4. Codebase Corrections (From Architecture Review)

The implementation plan found that several PRD references don't match the actual codebase:

| PRD Says | Reality | Fix |
|----------|---------|-----|
| `planTierProvider` | `currentPlanTierProvider` (FutureProvider in `freemium_repository.dart`) | Use `currentPlanTierProvider` everywhere |
| `prescriptionEngineProvider` | Static class `PrescriptionEngine`. Daily prescription via `DailyPrescriptionRepository` | New `todayCalorieSummaryProvider` composes the values |
| `recoveryScoreProvider(profileId)` | Embedded in `InsightsNotifier` state | New `todayRecoveryScoreProvider(profileId)` convenience provider |
| `FreemiumGate` uses GoRouter | Uses `Navigator.push` internally | New widgets use `context.push('/paywall')` directly |
| FAB exists in bottom nav | No FAB in `ScaffoldWithBottomNav` today | Add `FloatingActionButton` with `centerFloat` location |
| Water logging infrastructure | Nothing exists | New `wt_water_logs` table + `WaterLogEntity` + `WaterLogRepository` |

---

## 5. Files to Create

### Providers (5 files)
- `lib/features/meals/presentation/today_nutrition_provider.dart` — macro, calorie, micronutrient, combined dashboard providers
- `lib/features/meals/presentation/habit_prompt_provider.dart` — streak/recovery rule engine
- `lib/features/meals/presentation/meal_suggestions_provider.dart` — AI suggestions (Coming Soon stub)
- `lib/features/health/presentation/water_log_provider.dart` — water log reads/writes
- `lib/features/insights/presentation/today_recovery_score_provider.dart` — convenience recovery score provider

### Dashboard Widgets (11 files)
- `nutrition_summary_carousel.dart` — container with PageView + dot indicator
- `macro_rings_carousel_page.dart` — 3 circular progress rings (CustomPainter)
- `calories_budget_carousel_page.dart` — large calorie ring + recovery badge
- `heart_healthy_carousel_page.dart` — Fat/Sodium/Cholesterol progress bars
- `low_carb_carousel_page.dart` — Carbs/Sugar/Fiber progress bars
- `nutrient_progress_bar.dart` — shared reusable bar component
- `steps_summary_tile.dart` — step count from Health Connect
- `exercise_summary_tile.dart` — calories + training load
- `weight_trend_chart_widget.dart` — fl_chart 90-day line
- `habit_streak_prompt_card.dart` — contextual nudge card
- `discover_quick_access_grid.dart` — 2x2 feature tile grid

### FAB + Screens (6 files)
- `enhanced_log_bottom_sheet.dart` — 2x2 grid + list FAB sheet
- `nutrition_detail_screen.dart` — tabbed nutrition detail (route: `/nutrition`)
- `voice_log_screen.dart` — stub/Coming Soon (route: `/meals/voice-log`)
- `meal_scan_screen.dart` — stub/Coming Soon (route: `/meals/meal-scan`)
- `water_log_screen.dart` — water log UI (route: `/water/log`)
- `weight_log_screen.dart` — weight log UI (route: `/weight/log`)

### Other (1 file)
- `lib/shared/core/constants/fab_colors.dart` — FAB tile color constants

## 6. Files to Modify (4 only)

| File | Change |
|------|--------|
| `app_router.dart` | Add 6 routes, update `needsProfile` guard, recipe `selectMode` param |
| `scaffold_with_bottom_nav.dart` | Add center FAB button |
| `dashboard_screen.dart` | Insert 5 new `SliverToBoxAdapter` widget sections |
| `recipe_list_screen.dart` | Accept `selectMode` constructor param |

---

## 7. Implementation Phases

### Phase A — Foundation (Day 1)
**Goal**: Stub routes + FAB skeleton so nothing crashes when wired.
1. Create all provider files with stub/zero returns
2. Register 6 new routes with stub screens
3. Add FAB to `ScaffoldWithBottomNav`
4. Create Voice Log + Meal Scan stub screens ("Coming Soon")
5. Create Water Log + Weight Log screens with full UI
6. Update `needsProfile` guard
7. `flutter analyze` must pass

### Phase B — Providers (Days 2-3)
**Goal**: Real data flowing through all providers.
1. `todayMacroSummaryProvider` — aggregate today's meals
2. `todayMicronutrientSummaryProvider` — micronutrients (nulls = "--")
3. `todayCalorieSummaryProvider` — compose targets + prescription + exercise
4. `todayNutritionDashboardProvider` — `Future.wait` wrapper
5. `todayRecoveryScoreProvider` — direct repo call
6. `habitPromptProvider` — 4-rule engine
7. `waterLogProvider` — reads new `wt_water_logs` table
8. Defer `mealSuggestionsProvider` to Phase E

### Phase C — Dashboard Widgets (Days 4-5)
**Goal**: All new widgets visible on dashboard.
Build in order of complexity:
1. HabitStreakPromptCard (simplest)
2. DiscoverQuickAccessGrid (static grid)
3. Steps + Exercise tiles
4. NutrientProgressBar (shared)
5. MacroRingsCarouselPage (CustomPainter)
6. CaloriesBudgetCarouselPage (large ring + badge)
7. Heart Healthy + Low Carb pages
8. NutritionSummaryCarousel (compose all 4 pages)
9. WeightTrendChartWidget (fl_chart)
10. Insert all into DashboardScreen

**Dashboard order** (top → bottom):
```
TodaySummaryCard              (existing)
DailyCoachCard                (existing)
NutritionSummaryCarousel      [NEW]
Steps + Exercise Row          [NEW]
WeightTrendChartWidget        [NEW]
HabitStreakPromptCard         [NEW]
KeySignalsGrid                (existing)
IntelligenceInsightCard       (existing)
GoalsSummaryCard              (existing)
WorkoutsCard                  (existing)
PantryRecipeCard              (existing)
DiscoverQuickAccessGrid       [NEW — replaces SecondaryModulesList]
```

### Phase D — Enhanced FAB (Days 6-7)
**Goal**: FAB opens rich bottom sheet with all actions working.
1. Build `FabActionTile` widget
2. Build `EnhancedLogBottomSheet` shell
3. 4 grid tiles (Log Food, Barcode, Voice PRO, Meal Scan PRO)
4. 6 list tiles (Water, Weight, Exercise, AI Suggestions, Recipes, Quick Add)
5. `WaterStepperSubSheet` (nested modal)
6. `QuickAddSubSheet` (manual entry form)
7. Wire to `ScaffoldWithBottomNav`

### Phase E — Nutrition Detail + AI (Day 8)
**Goal**: Full nutrition drill-down screen.
1. `NutritionDetailScreen` with TabBar (reuses carousel page widgets)
2. Today's Meals list section
3. Handle `?tab=` query param
4. AI Suggestions — verify orchestrator support or mark Coming Soon

### Phase F — Polish (Day 9)
1. Dark mode verification across all new widgets
2. Shimmer loading states
3. Error/empty states for every widget
4. On-device testing (Samsung SM-S906B)
5. `flutter analyze` final pass

---

## 8. Provider Dependency Graph

```
todayNutritionDashboardProvider(profileId)
  ├── todayMacroSummaryProvider → mealRepositoryProvider
  ├── todayCalorieSummaryProvider
  │     ├── mealRepositoryProvider
  │     ├── dailyPrescriptionRepositoryProvider
  │     ├── nutritionTargetsProvider
  │     ├── healthRepositoryProvider
  │     └── currentPlanTierProvider
  └── todayMicronutrientSummaryProvider → mealRepositoryProvider

habitPromptProvider → mealRepositoryProvider + insightsRepositoryProvider
waterLogProvider → waterLogRepository (new wt_water_logs table)
weightTrendProvider → healthRepositoryProvider
todayStepsProvider → healthRepositoryProvider
todayExerciseCaloriesProvider → healthRepositoryProvider + workoutLogsProvider
todayRecoveryScoreProvider → insightsRepositoryProvider
```

No circular dependencies.

---

## 9. New Routes

| Route | Screen | Notes |
|-------|--------|-------|
| `/meals/diary` | redirect → `/daily-view` | Avoids screen duplication |
| `/meals/voice-log` | `VoiceLogScreen` | Stub — Coming Soon (PRO) |
| `/meals/meal-scan` | `MealScanScreen` | Stub — Coming Soon (PRO) |
| `/nutrition` | `NutritionDetailScreen` | Query param `?tab=macros\|calories\|heart\|lowcarb` |
| `/water/log` | `WaterLogScreen` | Full UI, writes to `wt_water_logs` |
| `/weight/log` | `WeightLogScreen` | Full UI, writes to `wt_health_metrics` |

---

## 10. Freemium Gating

| Feature | Free | PRO |
|---------|------|-----|
| Macros carousel (page 1) | Yes | Yes |
| Calories carousel (page 2) | Static target | Recovery-adjusted target |
| Heart Healthy (page 3) | Locked | Yes |
| Low Carb (page 4) | Locked | Yes |
| Steps/Exercise widgets | Yes | Yes + training load AU |
| Weight chart | 7-day only | 90-day |
| Log Food / Barcode | Yes | Yes |
| Voice Log | Locked | Yes |
| Meal Scan | Locked | Yes |
| AI Suggestions | Locked | Coming Soon |
| Water / Weight / Exercise log | Yes | Yes |

---

## 11. Playground Prototype

Interactive HTML prototype: `welltrack-meals-playground.html` (v5)
- Open in browser to preview all screens
- Sidebar controls for screen/tab switching
- Toggle recovery score, daily coach, premium features, dark mode
- Swipeable carousel with touch support
- Implementation prompt output updates per active screen

---

## 12. Reference Documents

- Playground: `/welltrack-meals-playground.html`
- PRD 1 (Dashboard): `PRPs/meals-v4-dashboard-widgets.md`
- PRD 2 (FAB): `PRPs/meals-v4-enhanced-fab.md`
- PRD 3 (Navigation): `PRPs/meals-v4-navigation-architecture.md`
- Tech Spec: `PRPs/meals-v5-implementation-plan.md`
- Decisions: Memory → `project_meals_v5_decisions.md`
