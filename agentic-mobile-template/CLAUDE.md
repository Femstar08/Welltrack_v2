# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

**WellTrack** is a production-grade cross-platform wellness app built with **Flutter** (Android + iOS) and **Supabase** backend. The app is modular: each feature module can be enabled/disabled per profile and the dashboard adapts automatically. This repo also contains an agentic template system (`.agent/`) with a knowledge base and ML learning system for structured feature development.

## Non-negotiables

- App must be accepted by Google Play and Apple App Store
- Native health integrations: Health Connect (Android), HealthKit (iOS)
- Offline-first: full logging works offline; sync later with conflict resolution
- Sensitive wellness data: secure by default (RLS + encrypted local storage)
- AI is server-side only (never call OpenAI directly from the mobile client)
- Central AI orchestrator with tool routing (single entrypoint)
- Persistent memory Level 3: preferences, embeddings, longitudinal patterns
- Freemium: AI usage limited by plan; enforce limits with server-side metering

## Tech Stack

### Frontend (Flutter/Dart)
- State management: **Riverpod** (preferred) or Bloc
- Local DB: **Hive** (replaced Isar due to AGP incompatibility)
- Secure storage: `flutter_secure_storage`
- Background tasks: `workmanager` / `background_fetch`
- Charts: `fl_chart`
- HTTP: `dio`

### Backend (Supabase)
- Auth: email/password only for MVP
- Postgres tables prefixed with `wt_`
- Storage for images/files
- Edge Functions for AI orchestration + webhooks

### AI (Server-Side Only)
- OpenAI via Edge Function or Python microservice behind an endpoint
- Embeddings: pgvector (preferred) or text + heuristic scoring fallback

### External Health Data
- Android: Health Connect
- iOS: HealthKit
- Garmin: OAuth + webhook push model (MVP)
- Strava: OAuth + webhook/events or polling (MVP)

## Commands

```bash
# Flutter
flutter run                        # Run app (debug)
flutter run --release              # Run app (release)
flutter build apk                  # Build Android APK
flutter build ios                  # Build iOS
flutter test                       # Run all tests
flutter test test/unit/            # Run unit tests only
flutter test --name "test name"    # Run single test by name
flutter analyze                    # Dart analyzer (lint)
dart format .                      # Format code

# Supabase
supabase start                     # Start local Supabase
supabase db reset                  # Reset DB + apply migrations
supabase migration new <name>      # Create new migration
supabase functions serve           # Serve Edge Functions locally
supabase functions deploy <name>   # Deploy Edge Function

# Knowledge base CLI (agentic template system)
pip install -r requirements.txt
python .agent/execution/context_engineering_utils.py init
python .agent/execution/context_engineering_utils.py get-patterns [library]
python .agent/execution/context_engineering_utils.py get-metrics <feature_type>
python .agent/execution/context_engineering_utils.py generate-report [days]
```

## Project Architecture (Flutter Clean Architecture)

```
lib/
  features/<module>/
    data/           # Repositories, data sources, models
    domain/         # Entities, use cases, repository interfaces
    presentation/   # Screens, widgets, state (Riverpod providers)
  shared/core/
    network/        # Dio client, interceptors, offline queue
    storage/        # Hive setup, encrypted storage
    auth/           # Supabase auth service
    theme/          # App theme, colors, typography
    router/         # GoRouter or auto_route config

supabase/
  migrations/       # SQL migrations (wt_ prefixed tables)
  functions/        # Edge Functions (Deno/TypeScript)
```

## MVP Modules (All Toggleable Per Profile)

1. **Profiles** — parent + dependents under parent
2. **Daily View** — single-day checklist across enabled modules + progress visuals
3. **Meals + Recipe Import + Pantry Recipe Generator** — fridge/cupboard/freezer items -> recipe ideas -> step-by-step prep
4. **Nutrient Tracking** — auto-extracted from meals; editable goals; visual progress day/week/month
5. **Supplements** — manual add, AM/PM protocol, link to goals
6. **Workouts** — manual + suggested; custom exercises
7. **Activity/Sleep** — from Health Connect/HealthKit (steps, sleep, HR)
8. **Insights Dashboard** — day/week/month progress vs goals + AI summary
9. **Reminders** — table and scheduler hooks
10. **Module Toggles + Tile Layout Control** — hide/rearrange dashboard tiles
11. **Freemium AI Limits** — daily token/call caps + paywall stubs

## Top 3 Health Metrics (Must Ingest)

1. **Stress** — Garmin Stress Score (0-100). Ingest as-is; no derived proxy. Store null if unavailable.
2. **Sleep** — From Health Connect/HealthKit and Garmin. Deduplicate by start/end time; prefer most detailed record.
3. **VO2 max** — Garmin/Strava as primary sources; Health Connect/HealthKit as optional.

## Database Schema (Supabase `wt_` Tables)

**Core**: `wt_users`, `wt_profiles`, `wt_profile_modules`
**Daily**: `wt_daily_logs`
**Meals & Recipes**: `wt_meals`, `wt_recipes`, `wt_recipe_steps`, `wt_recipe_ingredients`, `wt_pantry_items`, `wt_leftovers`
**Nutrition**: `wt_nutrients`, `wt_nutrient_targets`, `wt_meal_nutrient_breakdown`
**Supplements**: `wt_supplements`, `wt_supplement_logs`, `wt_supplement_protocols`
**Workouts**: `wt_workouts`, `wt_exercises`, `wt_workout_logs`
**Health**: `wt_health_metrics` (normalized), `wt_health_connections` (OAuth status)
**Plans & Goals**: `wt_plans`, `wt_plan_items`, `wt_goal_forecasts`
**Insights & Reminders**: `wt_insights`, `wt_reminders`
**AI**: `wt_ai_usage` (metering), `wt_ai_audit_log`, `wt_ai_memory` (preferences, embeddings, patterns)

### `wt_health_metrics` Required Columns
id, user_id, profile_id, source (healthconnect/healthkit/garmin/strava), metric_type (sleep/stress/vo2max/steps/hr/etc.), value_num, value_text, unit, start_time, end_time, recorded_at, raw_payload_json, dedupe_hash, created_at, updated_at

All tables must have RLS policies: data is profile-scoped and owned by auth user.

## AI Orchestrator

Single endpoint: `/ai/orchestrate`

**Inputs**: user_id, profile_id, context snapshot, user message, optional workflow type

**Tool Registry**:
`generate_weekly_plan`, `generate_pantry_recipes`, `generate_recipe_steps`, `summarize_insights`, `recommend_supplements`, `recommend_workouts`, `update_goals`, `recalc_goal_forecast`, `log_event_suggestion`, `extract_recipe_from_url`, `extract_recipe_from_image` (OCR)

**Output format** (structured JSON):
- `assistant_message` — user-facing text
- `suggested_actions[]` — app-native actions
- `db_writes[]` — validated writes to wt_ tables
- `updated_forecast` — optional goal date recalculation
- `safety_flags` — if any

Context snapshots must include normalized health metrics (stress/sleep/vo2max) for plan generation, insights, and goal forecasting.

## Key Workflows

### A) AI Chat -> Plan Generator
User chats -> orchestrator asks structured questions -> generates weekly plan (meals, workouts, supplements, activities) + daily tasks + expected achievement date -> writes to DB as "recommended plan" with user-editable overrides

### B) Pantry -> Recipes -> Prep Walkthrough
User triggers "Cook with what I have" -> enters pantry items (fridge/cupboard/freezer) -> AI returns 5-10 recipe options with tags, time, difficulty, nutrition score A-D -> user selects recipe -> step-by-step prep + timers + checklist + leftover capture

### C) Recipe Import
- **URL paste**: fetch page -> extract title, servings, prep_time, cook_time, ingredients[], steps[] -> user confirms/edits -> save
- **Photo OCR**: photograph recipe -> server-side OCR -> same extraction -> user confirms/edits -> save
- **AI-generated**: from pantry items
- Then "Add to plan" and "Generate shopping list"

### D) Logs -> Insights -> Next Week Plan
Daily logs drive weekly/monthly insights. AI generates adjustments and recalculates expected goal date dynamically.

## Build Order

| Phase | What | Why First |
|-------|------|-----------|
| 1 | Supabase schema + RLS | Everything depends on storage + permissions |
| 2 | Flutter scaffold + auth + offline engine | App skeleton must exist |
| 2b | Onboarding UI redesign (7-screen flow) | First user experience, captures goal for dashboard personalization |
| 3 | OAuth connections (Garmin + Strava) | VO2 max + Stress depend on this |
| 4 | Normalized Health Metrics pipeline | Enables insights + AI context |
| 5 | AI Orchestrator contract + tool registry | Keeps AI scalable + controlled costs |
| 6 | Pantry -> Recipes -> Prep (end-to-end) | High user value, ties to meals/nutrients |
| 7 | Recipe URL import + Photo OCR | Extends recipe system |
| 8 | Remaining modules (supplements, workouts, reminders) | Build on foundation |
| 9 | Insights dashboard + AI summaries | Requires data from all modules |
| 10 | Freemium metering + paywall stubs | Monetization layer |

Start with Phase 1 and 2, then Pantry -> Recipes -> Prep as first end-to-end workflow.

## Onboarding UI Design

### Design Philosophy
- Apple Health-inspired: clean, minimal, calm, premium
- No clutter, no gamification, no motivational hype
- Confident, calm, intelligent tone
- Goal-driven experience for busy professionals, parents, and wellness users

### 7-Screen Onboarding Flow

| Screen | Title | Purpose |
|--------|-------|---------|
| 1 | Welcome | Brand introduction — "Your health. Intelligently managed." |
| 2 | Primary Goal | Select focus: Performance, Stress, Sleep, Strength, Fat Loss, Wellness |
| 3 | Focus Intensity | Slider: Low / Moderate / High / Top Priority |
| 4 | Quick Profile | Age, Height, Weight, Activity Level (minimal form) |
| 5 | Connect Devices | Optional: Garmin, Strava, or Skip |
| 6 | 21-Day Focus | Introduce 21-day cycle concept, confirm goal + duration |
| 7 | Baseline Summary | Show starting snapshot, then "Enter WellTrack" |

### Goal-to-Dashboard Mapping
Selected goal influences dashboard metric priority:
- **Reduce Stress** → Stress score + Sleep prominently displayed
- **Improve Performance** → VO2 max + Recovery prominently displayed
- **Improve Sleep** → Sleep quality + consistency prominently displayed
- **Build Strength / Lose Fat** → Workouts + Nutrition prominently displayed

### Visual System
- Light mode: soft neutral background, calm teal accent, large typography, high whitespace
- Dark mode: near-black background, soft grey text, same accent, no neon
- Transitions: smooth slide between screens, light haptic on selection
- No illustrations, no heavy gradients, no emojis in UI

### Navigation
- All navigation uses GoRouter (`context.go()` / `context.push()`)
- NEVER use `Navigator.pushNamed()` or `Navigator.pushReplacementNamed()`
- Dashboard route is `/` (not `/dashboard`)

## Agentic Template System

### File Reading Order
When building a feature using the agentic system, read in this order:
1. `PROJECT_CONTEXT.md` — tech stack and patterns
2. `INITIAL.md` — feature request with requirements
3. `.agent/context/GLOBAL_RULES.md` — coding standards
4. `.agent/orchestration/directives/mobile_feature_development.md` — 6-phase build process
5. `.agent/orchestration/knowledge_base/*.yaml` — learned failure patterns and success metrics

### 6-Phase Feature Development Process
1. **Research** — read context files, check knowledge base for failure patterns
2. **Generate PRP** — Product Requirements Prompt with plan, failure prevention, confidence score (1-10), success criteria. Output to `PRPs/<feature-name>.md`
3. **Pre-Execution Validation** — verify dependencies, env vars, baseline tests
4. **Implementation** — build following the PRP
5. **Testing** — unit, integration, E2E; test on both platforms
6. **Post-Implementation Analysis** — record metrics, update knowledge base

### Knowledge Base
Located at `.agent/orchestration/knowledge_base/`. Managed via `ContextEngineeringUtils` in `.agent/execution/context_engineering_utils.py`. The system self-anneals: failures are recorded and prevent repeat mistakes.

## Coding Conventions

- **File naming**: Components `PascalCase.dart`, utilities `snake_case.dart` (Dart convention)
- **File size limit**: < 500 lines per file; split into modules if exceeding
- **Commit format**: `type(scope): description` (feat/fix/docs/style/refactor/test/chore)
- **Branch naming**: `main`, `develop`, `feature/*`, `fix/*`, `hotfix/*`
- **Sensitive data**: Never store tokens unencrypted on client; use `flutter_secure_storage`
- **Confidence scoring**: Rate implementation difficulty 1-10; if < 5, ask for more context before proceeding
- **All DB tables**: prefixed with `wt_`
