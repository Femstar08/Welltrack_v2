# WellTrack — Claude Code Master Prompt (Enhanced v3)

> Paste this entire prompt into Claude Code.
> You are a Principal Engineer + Product Architect.
> Build a production-grade cross-platform app called **WellTrack** using **Flutter** (Android + iOS) with **Supabase** backend.
>
> **Product positioning:** A Performance & Recovery Optimization Engine for high-achieving professionals.
> **First optimization model:** Physical fitness & VO₂ max improvement.
> **AI philosophy:** Suggestive, never prescriptive. Math generates forecasts; AI explains them.
> **Medical:** Strictly wellness — no medical claims ever.

---

## 0) Non-Negotiables

- Flutter app must be accepted by Google Play and Apple App Store.
- Native integrations: Health Connect (Android), HealthKit (iOS).
- Offline-first: full logging works offline; sync later with conflict resolution.
- Sensitive wellness data: secure by default (RLS + encrypted local storage).
- AI must be server-side (do NOT call AI directly from the mobile client).
- Central AI orchestrator with tool routing (single entrypoint).
- Persistent memory Level 3: store preferences, embeddings, longitudinal patterns.
- Freemium: gate optimization features, not basic logging.

---

## 1) Architecture Principles

### Modularity
- Each feature is a module that can be enabled/disabled per profile.
- Dashboard adapts automatically based on enabled modules.
- Feature modules: health_tracking, workout_logger, meal_planner, daily_coach, goals, supplements, recipes, insights.

### Clean Architecture
```
features/<module>/{data, domain, presentation}
shared/core/{network, storage, auth, theme, router}
```

### Data Flow
```
Garmin Watch → Garmin Connect → Health Connect → WellTrack → Room/Supabase → Dashboard/Charts/AI
```

---

## 2) Database Schema

### Core Tables (Supabase + local Room mirror)
Include (at minimum):
- `WP_users` (if needed beyond Supabase auth)
- `WP_profiles` (parent + dependents — single profile for MVP)
- `WP_profile_modules` (enabled modules per profile)
- `WP_daily_logs` (unified daily records; multiple per day; profile scoped)
- `WP_health_metrics` (normalized metrics from all sources)
- `WP_webhook_events` (queue table — never process webhooks inline)

### Workout Logger Tables (NEW — JEFIT-style)
- `WP_exercises` (exercise library: name, muscle_groups[], equipment_type, instructions, image_url, gif_url)
- `WP_workout_plans` (named plans with day assignments)
- `WP_workout_plan_exercises` (exercises within a plan, with order, target_sets, target_reps)
- `WP_workout_sessions` (completed sessions: plan_id, start_time, end_time, notes)
- `WP_workout_sets` (individual logged sets: session_id, exercise_id, set_number, weight_kg, reps, completed, estimated_1rm)
- `WP_exercise_records` (personal records per exercise: max_weight, max_reps, max_volume, max_1rm, dates)
- `WP_muscle_volume` (weekly volume per muscle group, derived)

### Meal Planning Tables (NEW)
- `WP_meals` (logged meals with macro breakdown)
- `WP_meal_plans` (AI-generated daily meal plans: date, training_day_type, total_cals, total_protein)
- `WP_meal_plan_items` (individual meals within a plan: meal_type, name, description, cals, protein, carbs, fat)
- `WP_recipes` (full recipes with ingredients, steps, prep_time, cook_time)
- `WP_recipe_steps` (ordered cooking steps)
- `WP_recipe_ingredients` (ingredients with quantities)
- `WP_recipe_favourites` (user-saved recipes)
- `WP_shopping_lists` (weekly generated shopping lists)
- `WP_shopping_list_items` (items with aisle grouping, tick-off)

### Existing Tables (from original spec)
- `WP_pantry_items`, `WP_leftovers`
- `WP_nutrients`, `WP_nutrient_targets`, `WP_meal_nutrient_breakdown`
- `WP_supplements`, `WP_supplement_logs`, `WP_supplement_protocols`
- `WP_plans`, `WP_plan_items`
- `WP_goals` (NEW: metric, current_value, target_value, deadline, priority)
- `WP_goal_snapshots` (NEW: daily snapshots for projection calculation)
- `WP_goal_forecasts` (expected achievement dates with confidence)
- `WP_insights` (AI-generated summaries)
- `WP_daily_checkins` (NEW: morning check-in responses)
- `WP_daily_prescriptions` (NEW: AI-generated daily plans)
- `WP_reminders`
- `WP_ai_usage` (metering) + `WP_ai_audit_log` (traceability)
- `WT_recovery_scores` (daily composite with component breakdown)
- `WT_training_load` (daily/weekly load calculations)

Implement RLS policies: all data is profile-scoped and owned by auth user.

---

## 3) Health Metrics Pipeline

### Normalized Health Metrics Table
`WP_health_metrics` with:
- id, user_id, profile_id
- source (healthconnect, healthkit, garmin, strava, manual)
- metric_type (sleep, stress, vo2max, steps, hr, rhr, weight, body_fat, hrv, active_calories, etc.)
- value_num, value_text, unit
- start_time, end_time, recorded_at
- raw_payload_json (optional)
- dedupe_hash, created_at, updated_at

### Ingest Rules
- Sleep: ingest from Health Connect/HealthKit and Garmin; deduplicate by start/end time; prefer most detailed record
- Stress: Garmin Stress Score (0–100). If unavailable, store null — do not block pipeline
- VO₂ Max: manual entry from Garmin app (not available via Health Connect). Simple input screen, update every 1–2 weeks
- Steps, HR, Weight, Body Fat, HRV, Active Calories: automatic from Health Connect

### Garmin API Integration (MVP — Server-to-Server)
**Architecture:** PUSH only. Garmin sends data to your webhook. You do NOT poll.

**OAuth 2.0 PKCE flow:**
- Authorization endpoint: `https://connect.garmin.com/oauthConfirm`
- Token endpoint: `https://connectapi.garmin.com/oauth-service/oauth/token`
- Encrypted token storage (never store unencrypted on client)
- Token refresh with retry logic

**Webhook handling:**
- Receive POST at your registered callback URL
- Respond HTTP 200 within 30 seconds (queue for async processing)
- Store raw payload in `WP_webhook_events` first, then process
- Webhook types for MVP: `userMetrics` (VO₂ max), `stressDetails`, `dailies`, `sleeps`, `activities`

**Brand attribution (required for Garmin review):**
- Display "Garmin" trademark with ™ or ® where data is shown
- Include "Powered by Garmin Connect" or "Data from Garmin" attribution
- Never modify or abbreviate the Garmin name
- Follow Garmin's colour and logo usage guidelines

**Data validation layer:**
- Validate webhook signatures
- Check for duplicate delivery (idempotency via dedupe_hash)
- Validate data ranges (e.g. VO₂ max 10–100, stress 0–100)
- Log validation failures without blocking pipeline

---

## 4) Workout Logger (JEFIT-Style — NEW)

### Exercise Database
- Pre-loaded library: 200+ exercises covering all major muscle groups
- Categorised by: body part (chest, back, shoulders, arms, legs, core) AND equipment type (barbell, dumbbell, cable, machine, bodyweight, kettlebell, trap bar)
- Each exercise: name, target_muscles[], secondary_muscles[], instructions, image_url, gif_url
- User can add custom exercises
- Search by name, filter by muscle group or equipment

### Workout Plans
- Named plans (e.g. "4-Day Push/Pull/Legs")
- Day assignments (Monday = Lower Body, Tuesday = Upper Push, etc.)
- Each day: ordered list of exercises with target_sets and target_reps
- Plan editor: add/remove/reorder exercises, duplicate plans
- Default plan pre-loaded from user's current programme

### Live Workout Logging Screen
**Critical UX principle:** Minimal taps during a workout. Pre-loaded data from last session means most sets log with a single tap.

**Interface per exercise:**
- Header: exercise name, target muscles, GIF demo, current estimated 1RM
- Set rows: Set # | Weight (kg) | Reps | Completion tick
- Pre-loaded values: weight and reps auto-fill from last session for that exercise
- Tap tick → logs set, starts rest timer
- "+" button to add extra sets
- Swipe left/right to move between exercises

**Rest timer:**
- Auto-starts after logging a set
- Configurable per exercise type (default: 90s compounds, 60s isolation)
- Vibration alert when rest is over
- Manual override (skip or extend)

**1RM tracking:**
- Auto-calculate estimated 1RM using Epley formula: `1RM = weight × (1 + reps/30)`
- Display current 1RM on exercise header
- Highlight new personal records with visual celebration
- Store in `WP_exercise_records`

**Session summary (after completing all exercises):**
- Total volume lifted (sets × reps × weight)
- Session duration
- Personal records hit
- Muscle groups worked
- Comparison vs last session of same plan day

### Progressive Overload Tracking
- Weekly total volume chart per muscle group
- 1RM history line chart per exercise over weeks/months
- Personal records log (all-time bests per exercise)
- Smart suggestions: "You've done 85 kg × 12 for 3 weeks — try 90 kg × 10 next"

### Body Map Visualisation
- Visual muscle map showing muscles trained this week
- Colour coded: green (well-trained), amber (lightly trained), grey (not hit)
- Tap muscle → shows contributing exercises and volume
- Ensures balanced training across the week

---

## 5) AI Meal Planning & Nutrition Engine (NEW)

### Macro Calculation
Daily targets calculated from: current weight, goal, activity level, training schedule.

| Day Type | Strategy |
|----------|----------|
| Strength training day | Higher calories, higher carbs for performance |
| Cardio day | Moderate calories, moderate carbs |
| Rest day | Lower calories, calorie deficit for fat loss |

Auto-adjust macros when new weight is logged.

### AI Meal Generation
AI generates daily meal plans with 3 meals + 1–2 snacks. Each meal includes:
- Name and description
- Full macro breakdown (calories, protein, carbs, fat per serving)
- Portion sizes in grams
- Step-by-step recipe with prep and cook time
- Swap option: tap "Swap" → AI generates alternative hitting same macros
- Cuisine preference support (Nigerian, British, Mediterranean, Asian, etc.)

### Meal Prep Assistant
Weekly meal prep screen:
- Identifies which meals can be batch-cooked
- Consolidated shopping list sorted by supermarket aisle
- Estimated prep time, cook time, storage instructions
- Tick-off items as you shop, mark meals as prepped

### Recipe Database
Categorised by: goal alignment, cuisine type, prep time, diet type.
User can favourite recipes → AI prioritises them in future plans.

### Recipe Import (Existing WellTrack Feature)
- **URL paste** (Phase 9): User pastes URL → server extracts recipe → user confirms
- **Photo OCR** (Phase 12): User photographs recipe → OCR → extraction → confirm
- **AI-generated**: From pantry items or macro targets
- **Saved**: User's stored favourites

---

## 6) AI Daily Coach (NEW)

### Morning Check-In
When user opens app (or via morning notification):

| Question | Input |
|----------|-------|
| How are you feeling? | Great / Good / Tired / Sore / Unwell |
| How did you sleep? | Auto-filled from Garmin sleep data. User can override |
| Any injuries or pain? | Optional free text |
| What's your schedule today? | Busy / Normal / Flexible |

Store responses in `WP_daily_checkins`.

### Daily Prescription Logic
AI combines check-in + Health Connect data + goals to generate today's plan:

| Scenario | Signals | Prescription |
|----------|---------|-------------|
| Well rested, feeling great | 7+ hrs sleep, low RHR, "Great" | Full planned workout. Push progressive overload. Standard meals. |
| Tired but not sore | <6 hrs sleep, "Tired" | Keep workout, reduce volume 20%. Extra carbs at breakfast. Bedtime reminder. |
| Very sore | "Sore", heavy session yesterday | Active recovery: light walk + stretching. High-protein meals. |
| Behind on steps | 3 PM and <4,000 steps | Nudge: "A 30-min walk after work gets you to your goal." |
| Weight stalling | No change 2+ weeks | Suggest reducing rest-day calories by 100–200. Add one cardio session. |
| Busy day | Schedule = "Busy" | Quick 30-min workout variant. Simple grab-and-go meals. |
| Unwell | "Unwell" | No workout. Hydration focus. Light meals. Rest day. |

### Today's Plan Screen
Single screen showing personalised day:
- **Workout card:** Today's session (or rest note) with duration. Tap to start logging.
- **Meals card:** Breakfast, lunch, dinner, snacks with macro summaries. Tap for recipe.
- **Steps target:** Progress ring with projected completion.
- **Focus tip:** One actionable insight.
- **Bedtime reminder:** Based on wake time and 7+ hour sleep target.

### Adaptive Intelligence
The AI learns from patterns over time:
- Consistently skip Wednesday workouts → suggest swapping days
- Always swap out a particular meal → stop suggesting that recipe
- Resting HR spikes after poor sleep → surface the correlation
- Better performance on high-carb training days → adjust future macros

---

## 7) Goal Tracking & Projection Engine (ENHANCED)

### Goal Setup
Users set targets for each metric with a deadline and priority:
- Weight, VO₂ Max, Resting HR, Steps, Sleep, Strength frequency, Cardio frequency
- Exercise-specific goals (e.g. Trap Bar Deadlift 1RM: 119 → 160 kg)

### Projection Algorithm (Deterministic — Math First)
**Layer 1 — Deterministic (SQL/math):**
- Data window: last 14–28 days of readings
- Rate of change: (current – value N days ago) / N days
- Recent bias: last 7 days weighted 2× vs prior 7 days
- Projection: (Target – Current) / Rate of Change = Estimated Days Remaining
- Confidence band: optimistic (best 7-day rate) and pessimistic (worst 7-day rate)

**Layer 2 — AI Narrative (explanation only):**
- AI receives deterministic forecast + supporting data
- Generates human-readable explanation
- Can suggest adjustments but NEVER overrides the math

### Goal Display (per goal)
- Progress bar (percentage toward target)
- Trend arrow (improving, stagnant, declining)
- Projected date ("At this rate, you'll reach 93 kg by September 2026")
- Status badge: On Track (green), Slightly Behind (amber), Off Track (red)
- Weekly velocity (e.g. "Losing 0.75 kg/week")
- Confidence range (best/worst case projections)

### Dashboard Goals Overview
Mini progress rings for each goal with status colour. Next milestone with countdown.

---

## 8) Baseline Calibration (Required Before Optimization)

First 14 days after onboarding = **Baseline Establishment Mode**.

During baseline:
- All data collection is active
- Dashboard shows "Collecting your baseline..." with day counter
- No optimization features, forecasts, or suggestions
- Captures: stress average, sleep consistency, VO₂ max trend, training load baseline, resting HR baseline, step average, weight trend

After 14 days:
- Baseline locked in
- Optimization features unlock
- All future data compared against baseline
- "vs your baseline" comparisons available on all charts

---

## 9) Performance Intelligence Engine (Existing WellTrack IP)

### Training Load Model
```
Load Score = Duration (min) × Intensity Factor
```
Intensity factors: Light (0.5), Moderate (1.0), Hard (1.5), Very Hard (2.0)

Derive:
- Weekly load total
- Load trend (increasing/decreasing/stable)
- Recovery ratio (load vs recovery score)
- Overtraining detection (load spike > 150% of 4-week average)

### Recovery Score (WellTrack Composite — Proprietary)
```
WT_recovery_score = weighted combination of:
  - Stress trend (lower = better recovery) — weight: 0.25
  - Sleep quality score — weight: 0.30
  - Resting HR trend (declining = recovering) — weight: 0.20
  - Training load trend (decreasing after peak = recovering) — weight: 0.25
```
- Score: 0–100 (0 = depleted, 100 = fully recovered)
- Recalculate daily
- Store with component breakdown for transparency
- Primary performance indicator on dashboard (Pro feature)

### Insights Architecture
All core trend calculations MUST be deterministic SQL, not AI-generated:
- Sleep trend = SQL (7/14/30 day averages, consistency score)
- VO₂ max trend = SQL (slope, moving average)
- Stress trend = SQL (daily average, weekly comparison)
- Training load trend = SQL (rolling sum, recovery ratio)
- Recovery score = SQL (weighted composite)

AI generates the narrative layer only — explaining trends and suggesting actions.

---

## 10) AI Orchestrator

### Architecture
- Single endpoint: `/ai/orchestrate`
- Inputs: user_id, profile_id, context snapshot, user message, workflow type
- Routing: decides which tool to call

### Tool Registry
- `generate_daily_plan` (morning check-in → workout + meals + tips)
- `generate_meal_plan` (daily/weekly meal generation)
- `generate_meal_swap` (replace one meal, maintain macros)
- `generate_weekly_plan` (overall weekly planning)
- `generate_pantry_recipes` (existing)
- `generate_recipe_steps` (existing)
- `suggest_progressive_overload` (workout suggestions)
- `summarize_insights` (weekly narrative)
- `recommend_supplements` (existing)
- `recalc_goal_forecast` (trigger forecast recalculation)
- `generate_shopping_list` (from meal plan)

### AI Context Updates
Orchestrator must include in context snapshots:
- Normalized health metrics (stress, sleep, VO₂ max, RHR, HRV)
- Latest recovery score + components
- Training load (current week vs 4-week average)
- Goal progress (current values vs targets)
- Recent workout history (last 7 days)
- Check-in responses
- Dietary preferences and favourited recipes

### Cost Control
- Context trimming (summarised state, not raw data)
- Response caching for repeated queries
- Meal plans cached weekly (regenerate only on swap)
- AI usage metered via `WP_ai_usage`
- Free tier: limited calls/day. Pro tier: higher limits.

### AI Guardrails
- Rate limiting: max N calls per user per hour
- Input validation: reject nonsensical or adversarial inputs
- Output validation: verify AI responses match expected JSON schema
- Safety checks: flag any content that could be interpreted as medical advice
- Fallback: if AI fails, show deterministic data only (never a blank screen)

---

## 11) Notifications & Nudges

- **Morning check-in** (configurable time, default 7 AM)
- **Step nudge** (if below target threshold by afternoon)
- **Daily check-in reminder** (configurable, default 9 PM, to review today's stats)
- **Sunday weekly report** (summary of week with wins and misses)
- **Milestone celebrations** (new PR, new low weight, consistent streak)
- **Bedtime reminder** (calculated from wake time + 7-hour target)
- **Workout reminder** (30 min before planned session time)

---

## 12) Freemium Strategy

**Core principle:** Gate optimization, not logging.

### Free Tier
- Full data tracking (all health metrics, workout logging, food logging)
- Basic charts (7-day views)
- Basic dashboard
- Manual VO₂ Max entry
- Exercise database access
- 3 AI calls/day

### Pro Tier
- Goal projections with timeline forecasts
- Recovery score (proprietary composite)
- Training load analysis + overtraining detection
- AI Daily Coach (morning check-in → daily prescription)
- AI Meal Planning (daily/weekly generation + swaps)
- Meal prep assistant + shopping lists
- 30-day / 90-day / all-time chart views
- Weekly AI insight reports
- Progressive overload suggestions
- Body map visualisation
- Unlimited AI calls
- Baseline comparison ("vs your first 14 days")

---

## 13) Screens (Complete List)

| Screen | Module | Purpose |
|--------|--------|---------|
| Onboarding | core | Goals, preferences, Health Connect setup |
| Dashboard (Home) | core | Today's snapshot + goal overview rings |
| Morning Check-In | daily_coach | How are you feeling? Quick-tap inputs |
| Today's Plan | daily_coach | AI-prescribed workout + meals + tips |
| Workout Logger | workout_logger | JEFIT-style set/rep/weight logging |
| Exercise Library | workout_logger | Browse/search exercises with GIFs |
| Workout Plans | workout_logger | Create/edit weekly plans |
| Session Summary | workout_logger | Post-workout stats + PRs |
| Body Map | workout_logger | Visual muscle map for the week |
| Meal Plan | meal_planner | Daily meals with macros, tap for recipe |
| Recipe Detail | meal_planner | Full recipe with ingredients + steps |
| Meal Prep | meal_planner | Weekly batch cook planner |
| Shopping List | meal_planner | Auto-generated, sorted by aisle |
| Food Log | meal_planner | Manual meal/nutrition entry fallback |
| Pantry | recipes | Fridge/cupboard/freezer input |
| Recipe Suggestions | recipes | AI-generated from pantry |
| Goal Setup | goals | Set metric, target, deadline |
| Goal Detail | goals | Chart, projection, trend, milestones |
| Steps | health_tracking | Bar chart, goal line, weekly avg |
| Sleep | health_tracking | Stacked bars (deep/light/REM), avg |
| Heart & Cardio | health_tracking | RHR line chart, VO₂ Max manual input |
| Weight & Body | health_tracking | Line chart with projection overlay |
| Supplements | supplements | AM/PM protocols, link to goals |
| Weekly Report | insights | Wins, misses, projected dates, volume |
| Insights Dashboard | insights | Recovery score, load chart, AI narrative |
| Settings | core | Notifications, units, theme, rest timers, AI quota, connections |
| Health Connections | core | Garmin/Strava connect/disconnect + status |

---

## 14) Build Order

Start by generating the full scaffold, then implement phase by phase. See BUILD-PLAN.md for detailed sequencing.

| Priority | What | Why |
|----------|------|-----|
| Phase 0 | Architecture Lock | Prevents rework |
| Phase 1 | Schema + RLS | Everything depends on storage |
| Phase 2 | Scaffold + Auth + Offline | App must exist |
| Phase 3 | Health Connect / HealthKit | Gets data flowing |
| Phase 4 | AI Orchestrator | Brain built early |
| Phase 5 | Workout Logger | Core daily interaction |
| Phase 6 | Goals + Projections | Core value prop |
| Phase 7 | Pantry → Recipes → Prep | High user value |
| Phase 8 | AI Meal Planning | Daily nutrition engine |
| Phase 9 | AI Daily Coach | Intelligence layer |
| Phase 10 | Performance Engine | Recovery score, load, insights |
| Phase 11 | Garmin + Strava | OAuth + webhooks |
| Phase 12 | Supplements + Reminders | Habit engine |
| Phase 13 | Notifications | Nudges, celebrations |
| Phase 14 | Recipe URL Import | Extends recipe system |
| Phase 15 | Freemium + Paywall | Monetisation |
| Phase 16 | OCR + Polish + Launch | Final features |

---

## 15) Coding Conventions

- **File naming**: Components `PascalCase.dart`, utilities `snake_case.dart` (Dart convention)
- **File size limit**: < 500 lines per file; split into modules if exceeding
- **Commit format**: `type(scope): description` (feat/fix/docs/style/refactor/test/chore)
- **Branch naming**: `main`, `develop`, `feature/*`, `fix/*`, `hotfix/*`
- **Sensitive data**: Never store tokens unencrypted on client; use `flutter_secure_storage`
- **All DB tables**: prefixed with `wt_` (Supabase deployed) or `WP_`/`WT_` (spec reference)
- **Navigation**: GoRouter only (`context.go()` / `context.push()`). NEVER use `Navigator.pushNamed()`
- **State management**: Riverpod
- **Local DB**: Hive (replaced Isar — AGP 8.11.1 incompatible)

---

## 16) Key Principles

1. **Math first, AI explains.** Forecasts are deterministic. AI narrates.
2. **Suggestive, not prescriptive.** "Consider this" not "Do this."
3. **No medical claims.** "Helps you train consistently toward your goals."
4. **Gate optimization, not logging.** Free users track everything. Pro unlocks intelligence.
5. **Offline-first.** Everything works without internet. Sync when connected.
6. **Baseline before optimization.** 14 days of data before features unlock.
7. **Minimal taps in the gym.** Pre-loaded data, single-tap logging, auto-timers.
8. **One phase at a time.** Don't ask Claude Code to build everything at once.
