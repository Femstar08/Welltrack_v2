# WellTrack Module Dependency Map

**Last Updated**: 2026-02-15
**Purpose**: Maps dependencies between WellTrack's 11 MVP modules, their database tables, and build order implications.

## Overview

WellTrack uses a modular architecture where each feature module can be enabled/disabled per profile via `wt_profile_modules`. This document defines the dependency graph, ensuring proper build order and runtime module loading.

---

## Module Inventory

### 1. Profiles (Core Module)

**Status**: Always enabled, cannot be disabled
**Tables**:
- `wt_users` (auth.users FK)
- `wt_profiles` (parent + dependents)
- `wt_profile_modules` (module toggles + tile layout)

**Dependencies**: None (foundation module)
**Depended On By**: ALL other modules
**Description**: Manages user profiles, parent-dependent relationships, and module configuration per profile.

---

### 2. Daily View

**Tables**:
- `wt_daily_logs` (aggregated daily completion status)

**Dependencies**:
- **Required**: Profiles
- **Reads From**: ALL enabled modules (dynamic based on `wt_profile_modules`)

**Depended On By**: None
**Description**: Single-day checklist aggregating tasks from all enabled modules:
- Meals planned vs logged
- Supplements due vs taken
- Workouts scheduled vs completed
- Health metrics summary (steps, sleep, stress)
- Progress visualizations

**Build Implication**: Must be built AFTER all data modules exist, as it reads from them dynamically.

---

### 3. Meals + Recipe Import + Pantry Recipe Generator

**Tables**:
- `wt_meals` (logged meals)
- `wt_recipes` (saved recipes)
- `wt_recipe_steps` (step-by-step instructions)
- `wt_recipe_ingredients` (ingredient lists)
- `wt_pantry_items` (fridge/cupboard/freezer inventory)
- `wt_leftovers` (portion tracking)

**Dependencies**:
- **Required**: Profiles
- **Optional**: Nutrient Tracking (for nutrition scoring A-D), AI Orchestrator (for pantry recipe generation)

**Depended On By**: Nutrient Tracking, Daily View, Insights Dashboard
**AI Tools Used**: `generate_pantry_recipes`, `generate_recipe_steps`, `extract_recipe_from_url`, `extract_recipe_from_image` (OCR)
**Description**: Core meal logging, recipe import (URL/photo OCR/AI-generated), pantry-based recipe suggestions, and prep walkthrough with timers.

---

### 4. Nutrient Tracking

**Tables**:
- `wt_nutrients` (reference table: macros, vitamins, minerals)
- `wt_nutrient_targets` (profile-specific goals)
- `wt_meal_nutrient_breakdown` (auto-extracted from meals)

**Dependencies**:
- **Required**: Profiles, Meals (reads meal data to calculate nutrient totals)

**Depended On By**: Insights Dashboard, AI Orchestrator (context for plan generation)
**Description**: Tracks daily/weekly/monthly nutrient intake vs goals. Auto-extracted from meals; editable targets; visual progress bars and charts.

---

### 5. Supplements

**Tables**:
- `wt_supplements` (supplement catalog)
- `wt_supplement_logs` (daily intake logs)
- `wt_supplement_protocols` (AM/PM schedules, linked to goals)

**Dependencies**:
- **Required**: Profiles
- **Optional**: Goals (via `linked_goal_id` on protocols), Reminders (trigger notifications)

**Depended On By**: Daily View, Insights Dashboard
**AI Tools Used**: `recommend_supplements`
**Description**: Manual supplement entry, AM/PM protocol scheduling, goal linkage, and reminder integration.

---

### 6. Workouts

**Tables**:
- `wt_exercises` (reference table: exercise library)
- `wt_workouts` (workout plans: sets, reps, duration)
- `wt_workout_logs` (completed workouts with actual performance)

**Dependencies**:
- **Required**: Profiles
- **Optional**: Health Metrics (HR data for intensity tracking)

**Depended On By**: Performance Engine (training load calculation), Daily View, Insights Dashboard
**AI Tools Used**: `recommend_workouts`
**Description**: Manual and AI-suggested workouts, custom exercise creation, performance tracking.

---

### 7. Activity/Sleep (Health Metrics)

**Tables**:
- `wt_health_metrics` (normalized: sleep, stress, VO2 max, steps, HR, etc.)
- `wt_health_connections` (OAuth status for Garmin/Strava/Health Connect/HealthKit)

**Dependencies**:
- **Required**: Profiles
- **External Integrations**: Health Connect (Android), HealthKit (iOS), Garmin (Phase 7), Strava (Phase 7)

**Depended On By**: Performance Engine (recovery score, training load), Insights Dashboard, AI Orchestrator (context)
**Description**: Ingests health data from native platforms and wearables. Deduplicates by `dedupe_hash` (start_time + end_time + source + metric_type). Stores stress (0-100), sleep (hours + quality), VO2 max, steps, HR.

**Top 3 Metrics**:
1. **Stress** — Garmin Stress Score (0-100, no proxy, null if unavailable)
2. **Sleep** — Deduplicated from all sources; prefer most detailed record
3. **VO2 max** — Garmin/Strava primary; Health Connect/HealthKit optional

---

### 8. Insights Dashboard

**Tables**:
- `wt_insights` (AI-generated summaries, trends, recommendations)

**Dependencies**:
- **Required**: Profiles
- **Reads From**: ALL modules (Health Metrics, Meals, Nutrients, Workouts, Supplements)
- **Uses**: Performance Engine (recovery score, forecasts, training load)

**Depended On By**: None
**AI Tools Used**: `summarize_insights`, `update_goals`, `recalc_goal_forecast`
**Description**: Day/week/month progress vs goals. AI-generated summaries ("You're 3 days ahead of schedule on protein goals"). Displays recovery score, training load trends, goal forecasts.

---

### 9. Reminders

**Tables**:
- `wt_reminders` (scheduled reminders with trigger_time, repeat_pattern, linked module/entity)

**Dependencies**:
- **Required**: Profiles
- **Connects To**: Supplements (AM/PM protocols), Workouts (scheduled sessions), Meals (prep reminders)
- **Requires**: Push Notifications (Phase 10 implementation)

**Depended On By**: None
**Description**: Scheduler for reminders. Triggers based on time/event. Integrates with Supplements, Workouts, Meals. Requires background task runner (`workmanager`) and push notification service.

---

### 10. Module Toggles + Tile Layout Control

**Tables**:
- `wt_profile_modules` (enabled boolean, tile_order integer, tile_config jsonb)

**Dependencies**:
- **Required**: Profiles

**Depended On By**: Daily View (determines which modules to display), Dashboard (tile rendering order)
**Description**: Per-profile configuration of which modules are enabled, tile display order, and tile-specific settings (e.g., chart type, default view).

---

### 11. Freemium AI Limits

**Tables**:
- `wt_ai_usage` (metering: user_id, profile_id, tool_name, tokens_used, quota_limit, reset_at)
- `wt_ai_audit_log` (full request/response audit trail)

**Dependencies**:
- **Required**: Profiles, AI Orchestrator

**Gates**:
- Free tier: 3 AI calls/day (resets daily)
- Pro tier: unlimited AI calls + Recovery Score + Forecasting + Training Load Analysis

**Depended On By**: AI Orchestrator (enforces limits), Performance Engine (gates pro features)
**Description**: Server-side metering and enforcement. Tracks AI usage per user/profile. Returns quota exceeded errors when limits hit. Paywall stubs trigger upgrade flow.

---

## Performance Engine (Always-On System, Not a Toggleable Module)

**Tables**:
- `wt_baselines` (historical fitness baselines for comparison)
- `wt_training_loads` (calculated from workout volume + intensity)
- `wt_recovery_scores` (0-100 score from sleep + stress + HR variability)
- `wt_forecasts` (goal achievement predictions)

**Dependencies**:
- **Required**: Profiles, Health Metrics (sleep, stress, HR), Workouts (for training load input)

**Pro-Gated Features**:
- Free users: see basic trends only
- Pro users: full recovery score dashboard, forecasting, training load analysis

**Description**: Background processing engine that calculates recovery scores, training load, and goal forecasts. Runs automatically when data is available. Not user-facing as a module, but powers Insights Dashboard and AI context.

---

## Dependency Graph (ASCII)

```
                              ┌─────────────┐
                              │  PROFILES   │ (Core, always enabled)
                              │   (wt_*)    │
                              └──────┬──────┘
                                     │
                ┌────────────────────┼────────────────────────────────┐
                │                    │                                │
                ▼                    ▼                                ▼
        ┌───────────────┐    ┌──────────────┐              ┌─────────────────┐
        │  MEALS        │    │  HEALTH      │              │  SUPPLEMENTS    │
        │  + RECIPES    │    │  METRICS     │              │                 │
        │  + PANTRY     │    │ (Activity/   │              └────────┬────────┘
        └───────┬───────┘    │  Sleep)      │                       │
                │            └──────┬───────┘                       │
                │                   │                                │
                ▼                   │                                │
        ┌───────────────┐           │                                │
        │  NUTRIENT     │           │                                │
        │  TRACKING     │           │                                │
        └───────┬───────┘           │                                │
                │                   │                                │
                │                   ▼                                │
                │           ┌───────────────┐                        │
                │           │  PERFORMANCE  │                        │
                │           │  ENGINE       │                        │
                │           │  (Always-On)  │                        │
                │           └───────┬───────┘                        │
                │                   │                                │
                │                   │                                │
        ┌───────┴───────┐           │              ┌─────────────┐  │
        │  WORKOUTS     │           │              │  REMINDERS  │  │
        └───────┬───────┘           │              └──────┬──────┘  │
                │                   │                     │          │
                └───────────┬───────┴─────────────────────┼──────────┘
                            │                             │
                            ▼                             │
                    ┌───────────────┐                     │
                    │  INSIGHTS     │                     │
                    │  DASHBOARD    │                     │
                    └───────┬───────┘                     │
                            │                             │
                            ▼                             ▼
                    ┌───────────────────────────────────────┐
                    │        DAILY VIEW                     │
                    │   (Reads from ALL enabled modules)    │
                    └───────────────────────────────────────┘

                            ┌─────────────────────┐
                            │  MODULE TOGGLES     │ (Controls visibility)
                            │  + TILE LAYOUT      │
                            └─────────────────────┘

                            ┌─────────────────────┐
                            │  FREEMIUM AI        │ (Gates AI features)
                            │  LIMITS             │
                            └─────────────────────┘

                    ┌───────────────────────────┐
                    │  AI ORCHESTRATOR          │ (Server-side only)
                    │  (Edge Function/Python)   │
                    │  - generate_weekly_plan   │
                    │  - generate_pantry_recipes│
                    │  - recommend_supplements  │
                    │  - recommend_workouts     │
                    │  - summarize_insights     │
                    │  - extract_recipe_from_*  │
                    └───────────────────────────┘
```

---

## Build Order Implications

### Phase 1: Foundation (COMPLETE)
**Build**: Supabase schema + RLS policies
**Modules**: Profiles (core tables only)
**Why First**: All modules require `wt_profiles` and RLS policies for data security.

---

### Phase 2: App Skeleton + Auth + Offline Engine
**Build**: Flutter scaffold, Supabase auth, Isar/Hive offline storage, background sync queue
**Modules**: Profiles (UI + state management)
**Why**: App framework must exist before building feature modules.

---

### Phase 3: OAuth Connections (Garmin + Strava)
**Build**: OAuth flows, webhook endpoints, token storage
**Modules**: Health Metrics (connections setup)
**Why**: VO2 max and Stress Score depend on external data. Must be in place before Performance Engine.

---

### Phase 4: Normalized Health Metrics Pipeline
**Build**: Health Connect/HealthKit integration, Garmin/Strava webhook handlers, deduplication logic
**Modules**: Activity/Sleep (Health Metrics)
**Tables**: `wt_health_metrics`, `wt_health_connections`
**Why**: Performance Engine, Insights, and AI Orchestrator all require normalized health data.

---

### Phase 5: AI Orchestrator Contract + Tool Registry
**Build**: Edge Function/Python microservice, tool routing, structured output format
**Tables**: `wt_ai_usage`, `wt_ai_audit_log`, `wt_ai_memory`
**Why**: Establishes AI interface before building AI-dependent modules. Prevents cost overruns and ensures scalability.

**Tool Registry**:
- `generate_weekly_plan`
- `generate_pantry_recipes`
- `generate_recipe_steps`
- `extract_recipe_from_url`
- `extract_recipe_from_image` (OCR)
- `summarize_insights`
- `recommend_supplements`
- `recommend_workouts`
- `update_goals`
- `recalc_goal_forecast`
- `log_event_suggestion`

---

### Phase 6: Pantry → Recipes → Prep (End-to-End)
**Build**: Meals, Recipes, Pantry, Recipe Import (URL + Photo OCR), Prep Walkthrough
**Modules**: Meals + Recipe Import + Pantry Recipe Generator
**Tables**: `wt_meals`, `wt_recipes`, `wt_recipe_steps`, `wt_recipe_ingredients`, `wt_pantry_items`, `wt_leftovers`
**Why**: High user value, first complete workflow, ties to Nutrients module.

---

### Phase 7: Nutrient Tracking
**Build**: Nutrient auto-extraction from meals, goal setting, progress visualizations
**Modules**: Nutrient Tracking
**Tables**: `wt_nutrients`, `wt_nutrient_targets`, `wt_meal_nutrient_breakdown`
**Depends On**: Meals (reads meal data)
**Why**: Extends Meals module with nutrition intelligence.

---

### Phase 8: Supplements + Workouts
**Build**: Supplement protocols, workout plans, exercise library
**Modules**: Supplements, Workouts
**Tables**: `wt_supplements`, `wt_supplement_logs`, `wt_supplement_protocols`, `wt_exercises`, `wt_workouts`, `wt_workout_logs`
**Why**: Core tracking modules that feed into Performance Engine and Daily View.

---

### Phase 9: Performance Engine (Always-On System)
**Build**: Training load calculation, recovery score algorithm, goal forecasting
**Tables**: `wt_baselines`, `wt_training_loads`, `wt_recovery_scores`, `wt_forecasts`
**Depends On**: Health Metrics (sleep, stress, HR), Workouts (training volume)
**Why**: Requires data from Health Metrics and Workouts to generate meaningful outputs.

---

### Phase 10: Reminders + Push Notifications
**Build**: Reminder scheduler, push notification service, background task runner
**Modules**: Reminders
**Tables**: `wt_reminders`
**Depends On**: Supplements, Workouts, Meals (trigger sources)
**Why**: Requires existing modules to have schedulable events.

---

### Phase 11: Insights Dashboard + AI Summaries
**Build**: Aggregated progress views, AI-generated insights, goal tracking
**Modules**: Insights Dashboard
**Tables**: `wt_insights`
**Depends On**: ALL data modules (Health Metrics, Meals, Nutrients, Workouts, Supplements), Performance Engine
**Why**: Reads from all modules to generate comprehensive insights. Must be built last.

---

### Phase 12: Daily View
**Build**: Single-day checklist aggregating all enabled modules
**Modules**: Daily View
**Tables**: `wt_daily_logs`
**Depends On**: ALL modules (dynamic based on `wt_profile_modules`)
**Why**: Must be built after all data modules exist, as it reads from them dynamically.

---

### Phase 13: Module Toggles + Tile Layout Control
**Build**: UI for enabling/disabling modules, drag-and-drop tile reordering
**Modules**: Module Toggles + Tile Layout Control
**Tables**: `wt_profile_modules` (already exists from Phase 1, UI built here)
**Why**: Final UX polish, allows users to customize dashboard.

---

### Phase 14: Freemium AI Limits + Paywall Stubs
**Build**: Server-side metering, quota enforcement, paywall UI stubs
**Modules**: Freemium AI Limits
**Tables**: `wt_ai_usage`, `wt_ai_audit_log`
**Why**: Monetization layer, enforces AI usage limits.

---

## Module Registry Design

### Concept
Each module self-registers with the app at runtime, declaring its metadata, dependencies, and UI configuration. The dashboard reads `wt_profile_modules` to determine which tiles to show and in what order.

### Module Registration Schema

```dart
// lib/shared/core/modules/module_registry.dart

class ModuleMetadata {
  final String id;                     // e.g., "meals", "workouts", "health_metrics"
  final String displayName;             // e.g., "Meals & Recipes"
  final IconData icon;                  // Material icon
  final bool defaultEnabled;            // true if enabled by default for new profiles
  final bool canDisable;                // false for Profiles (core module)
  final List<String> requiredTables;    // e.g., ["wt_meals", "wt_recipes"]
  final List<String> optionalDeps;      // e.g., ["nutrients", "ai_orchestrator"]
  final List<String> requiredDeps;      // e.g., ["profiles"]
  final String route;                   // e.g., "/meals"
  final Widget Function() tileBuilder;  // Dashboard tile widget
  final Map<String, dynamic>? defaultTileConfig; // jsonb tile_config defaults
}
```

### Example Module Registration

```dart
// lib/features/meals/meals_module.dart

final mealsModule = ModuleMetadata(
  id: 'meals',
  displayName: 'Meals & Recipes',
  icon: Icons.restaurant_menu,
  defaultEnabled: true,
  canDisable: true,
  requiredTables: [
    'wt_meals',
    'wt_recipes',
    'wt_recipe_steps',
    'wt_recipe_ingredients',
    'wt_pantry_items',
    'wt_leftovers',
  ],
  requiredDeps: ['profiles'],
  optionalDeps: ['nutrients', 'ai_orchestrator'],
  route: '/meals',
  tileBuilder: () => MealsTile(),
  defaultTileConfig: {
    'chart_type': 'weekly_bar',
    'show_calories': true,
  },
);
```

### Module Registry Singleton

```dart
// lib/shared/core/modules/module_registry.dart

class ModuleRegistry {
  static final ModuleRegistry _instance = ModuleRegistry._internal();
  factory ModuleRegistry() => _instance;
  ModuleRegistry._internal();

  final Map<String, ModuleMetadata> _modules = {};

  void register(ModuleMetadata module) {
    _modules[module.id] = module;
  }

  ModuleMetadata? getModule(String id) => _modules[id];

  List<ModuleMetadata> getAllModules() => _modules.values.toList();

  List<ModuleMetadata> getEnabledModules(List<String> enabledIds) {
    return enabledIds
        .map((id) => _modules[id])
        .whereType<ModuleMetadata>()
        .toList();
  }

  bool validateDependencies(ModuleMetadata module, List<String> enabledIds) {
    // Check if all required dependencies are enabled
    for (final dep in module.requiredDeps) {
      if (!enabledIds.contains(dep)) {
        return false;
      }
    }
    return true;
  }
}
```

### Dashboard Tile Rendering

```dart
// lib/features/dashboard/presentation/dashboard_screen.dart

class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileModules = ref.watch(profileModulesProvider);
    final registry = ModuleRegistry();

    // Filter enabled modules from wt_profile_modules
    final enabledModules = profileModules
        .where((pm) => pm.enabled)
        .map((pm) => registry.getModule(pm.moduleId))
        .whereType<ModuleMetadata>()
        .toList();

    // Sort by tile_order from wt_profile_modules
    enabledModules.sort((a, b) {
      final aOrder = profileModules
          .firstWhere((pm) => pm.moduleId == a.id)
          .tileOrder;
      final bOrder = profileModules
          .firstWhere((pm) => pm.moduleId == b.id)
          .tileOrder;
      return aOrder.compareTo(bOrder);
    });

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
      ),
      itemCount: enabledModules.length,
      itemBuilder: (context, index) {
        final module = enabledModules[index];
        return module.tileBuilder();
      },
    );
  }
}
```

### wt_profile_modules Table Schema

```sql
CREATE TABLE wt_profile_modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  module_id TEXT NOT NULL, -- 'meals', 'workouts', 'health_metrics', etc.
  enabled BOOLEAN NOT NULL DEFAULT true,
  tile_order INTEGER NOT NULL DEFAULT 0,
  tile_config JSONB DEFAULT '{}'::jsonb, -- module-specific settings
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(profile_id, module_id)
);

-- RLS: Users can only see their own profile modules
ALTER TABLE wt_profile_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile modules"
  ON wt_profile_modules FOR SELECT
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update own profile modules"
  ON wt_profile_modules FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));
```

### Module Initialization on Profile Creation

When a new profile is created, seed `wt_profile_modules` with all modules and their default enabled states:

```sql
-- Function to initialize profile modules
CREATE OR REPLACE FUNCTION initialize_profile_modules()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wt_profile_modules (profile_id, module_id, enabled, tile_order)
  VALUES
    (NEW.id, 'profiles', true, 0),      -- Always enabled, cannot disable
    (NEW.id, 'daily_view', true, 1),
    (NEW.id, 'meals', true, 2),
    (NEW.id, 'nutrients', true, 3),
    (NEW.id, 'supplements', false, 4),   -- Disabled by default
    (NEW.id, 'workouts', true, 5),
    (NEW.id, 'health_metrics', true, 6),
    (NEW.id, 'insights', true, 7),
    (NEW.id, 'reminders', false, 8),     -- Disabled by default
    (NEW.id, 'module_toggles', true, 9),
    (NEW.id, 'ai_limits', true, 10);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-initialize modules on profile creation
CREATE TRIGGER on_profile_created
  AFTER INSERT ON wt_profiles
  FOR EACH ROW
  EXECUTE FUNCTION initialize_profile_modules();
```

---

## Module Dependency Validation Rules

### At Module Enable Time
When a user enables a module via Module Toggles UI:
1. Check if all `requiredDeps` are enabled
2. If not, prompt user: "This module requires [X, Y, Z]. Enable them first?"
3. If yes, enable dependencies in correct order
4. If no, cancel enable operation

### At Module Disable Time
When a user disables a module:
1. Check if other enabled modules depend on it
2. If yes, prompt user: "Disabling this will also disable [A, B, C]. Continue?"
3. If yes, disable in reverse dependency order
4. If no, cancel disable operation

### Example Validation Logic

```dart
// lib/features/module_toggles/domain/module_toggle_service.dart

class ModuleToggleService {
  final ModuleRegistry _registry;
  final ProfileModulesRepository _repo;

  Future<void> enableModule(String moduleId, String profileId) async {
    final module = _registry.getModule(moduleId);
    if (module == null) throw ModuleNotFoundException(moduleId);

    final currentlyEnabled = await _repo.getEnabledModuleIds(profileId);

    // Validate dependencies
    for (final depId in module.requiredDeps) {
      if (!currentlyEnabled.contains(depId)) {
        throw MissingDependencyException(
          'Module "$moduleId" requires "${depId}" to be enabled first.',
        );
      }
    }

    // Enable module
    await _repo.setModuleEnabled(profileId, moduleId, enabled: true);
  }

  Future<void> disableModule(String moduleId, String profileId) async {
    final module = _registry.getModule(moduleId);
    if (module == null) throw ModuleNotFoundException(moduleId);

    // Prevent disabling core modules
    if (!module.canDisable) {
      throw CannotDisableCoreModuleException(moduleId);
    }

    final currentlyEnabled = await _repo.getEnabledModuleIds(profileId);
    final allModules = _registry.getAllModules();

    // Find modules that depend on this one
    final dependents = allModules.where((m) {
      return m.requiredDeps.contains(moduleId) &&
             currentlyEnabled.contains(m.id);
    }).toList();

    if (dependents.isNotEmpty) {
      throw HasDependentsException(
        'Cannot disable "$moduleId" because it is required by: '
        '${dependents.map((m) => m.displayName).join(', ')}',
      );
    }

    // Disable module
    await _repo.setModuleEnabled(profileId, moduleId, enabled: false);
  }
}
```

---

## Summary

This dependency map establishes:
1. **Clear module boundaries** — each module owns specific tables and features
2. **Explicit dependencies** — required vs optional, preventing circular dependencies
3. **Build order** — phases align with dependency graph (foundation → data → aggregation → UX)
4. **Runtime validation** — users cannot enable modules without their dependencies
5. **Scalability** — new modules register themselves; dashboard adapts dynamically

**Key Takeaway**: Profiles is the foundation. Health Metrics and Meals are core data modules. Performance Engine and Insights Dashboard are aggregation layers. Daily View is the user-facing aggregator. Module Toggles control visibility. AI Limits gate premium features.
