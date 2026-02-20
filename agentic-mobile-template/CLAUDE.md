# WellTrack — Claude Code Master Prompt (Enhanced v4)

> Paste this entire prompt into Claude Code.
> You are a Principal Engineer + Product Architect.
> Build a production-grade cross-platform app called **WellTrack** using **Flutter** (Android + iOS) with **Supabase** backend.
>
> **Product positioning:** A Performance & Recovery Optimization Engine for high-achieving professionals.
> **First optimization model:** Physical fitness & VO₂ max improvement.
> **AI philosophy:** Suggestive, never prescriptive. Math generates forecasts; AI explains them.
> **Medical:** Strictly wellness — no medical claims ever.
> **Distribution:** Intended for eventual public release on Google Play and App Store for personal use.

---

## 0) Non-Negotiables

- Flutter app must be accepted by Google Play and Apple App Store.
- Native integrations: Health Connect (Android), HealthKit (iOS).
- Offline-first: queue writes locally, sync when connected. Use last-write-wins conflict resolution (no enterprise-grade conflict engine needed for personal use).
- Sensitive wellness data: secure by default (RLS + encrypted local storage).
- **Sensitive data policy (CRITICAL):** Morning erection tracking, erection quality, and bloodwork results must be: encrypted at rest (column-level encryption or field encryption before insert), excluded from analytics exports, never sent to AI without explicit user consent toggle, never displayed in push notification content, and labelled with `is_sensitive = true` in schema. Treat as health metadata, not sexual content.
- AI must be server-side (do NOT call AI directly from the mobile client).
- Central AI orchestrator with tool routing (single entrypoint).
- Freemium: gate intelligence features, never gate workout logging.
- No enterprise-grade concurrency, multi-user scaling, or microservice explosion. This is a single-user app first. Keep it clean, modular, single-app.

---

## 1) Architecture Principles

### Core Philosophy
> Treat this as one modular performance engine with staged capability unlocks. Not 8 parallel mini apps.

### Domain Separation (Mandatory)
No domain directly queries another domain's tables. All cross-domain interactions go through services or events.

```
core/
  auth
  sync
  health_pipeline
  ai_orchestrator
  notifications

domains/
  workouts
  goals
  recovery
  nutrition
  daily_coach
  habits
  vitality
  bloodwork
```

### Feature Modularity
- Each feature is a module that can be enabled/disabled per profile.
- Dashboard adapts automatically based on enabled modules.
- Home screen must remain calm and uncluttered. Less is more.

### Clean Architecture (per domain)
```
features/<domain>/{data, domain, presentation}
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
- `WT_users` (if needed beyond Supabase auth)
- `WT_profiles` (parent + dependents — single profile for MVP)
- `WT_profile_modules` (enabled modules per profile)
- `WT_daily_logs` (unified daily records; multiple per day; profile scoped)
- `WT_health_metrics` (normalized metrics from all sources)
- `WT_webhook_events` (queue table — never process webhooks inline)

### Workout Logger Tables (NEW — JEFIT-style)
- `WT_exercises` (exercise library: name, muscle_groups[], equipment_type, instructions, image_url, gif_url)
- `WT_workout_plans` (named plans with day assignments)
- `WT_workout_plan_exercises` (exercises within a plan, with order, target_sets, target_reps)
- `WT_workout_sessions` (completed sessions: plan_id, start_time, end_time, notes)
- `WT_workout_sets` (individual logged sets: session_id, exercise_id, set_number, weight_kg, reps, completed, estimated_1rm)
- `WT_exercise_records` (personal records per exercise: max_weight, max_reps, max_volume, max_1rm, dates)
- `WT_muscle_volume` (weekly volume per muscle group, derived)

### Meal Planning Tables (NEW)
- `WT_meals` (logged meals with macro breakdown)
- `WT_meal_plans` (AI-generated daily meal plans: date, training_day_type, total_cals, total_protein)
- `WT_meal_plan_items` (individual meals within a plan: meal_type, name, description, cals, protein, carbs, fat)
- `WT_recipes` (full recipes with ingredients, steps, prep_time, cook_time)
- `WT_recipe_steps` (ordered cooking steps)
- `WT_recipe_ingredients` (ingredients with quantities)
- `WT_recipe_favourites` (user-saved recipes)
- `WT_shopping_lists` (weekly generated shopping lists)
- `WT_shopping_list_items` (items with aisle grouping, tick-off)

### Existing Tables (from original spec)
- `WT_pantry_items`, `WT_leftovers`
- `WT_nutrients`, `WT_nutrient_targets`, `WT_meal_nutrient_breakdown`
- `WT_supplements`, `WT_supplement_logs`, `WT_supplement_protocols`
- `WT_plans`, `WT_plan_items`
- `WT_goals` (metric, current_value, target_value, deadline, priority)
- `WT_goal_snapshots` (daily snapshots for projection calculation)
- `WT_goal_forecasts` (expected achievement dates with confidence)
- `WT_insights` (AI-generated summaries)
- `WT_daily_checkins` (morning check-in responses)
- `WT_daily_prescriptions` (AI-generated daily plans)
- `WT_reminders`
- `WT_ai_usage` (metering) + `WT_ai_audit_log` (traceability)
- `WT_recovery_scores` (daily composite with component breakdown)
- `WT_training_load` (daily/weekly load calculations)

### Habit & Streak Tracking Tables (NEW)
> **UI PLACEMENT:** These features live inside Log > Secondary tab or Profile > Health Records. Do NOT surface aggressively on the home dashboard.
- `WT_habit_streaks` (generic streak tracker: habit_type, current_streak_days, longest_streak, last_logged_date, is_active)
  - Supports: porn_free, kegels_am, kegels_pm, sleep_target, steps_target, or any user-defined habit
- `WT_bloodwork_results` (lab results over time: test_name, value_num, unit, reference_range_low, reference_range_high, test_date, notes)
  - Pre-loaded test types: total_testosterone, free_testosterone, shbg, oestradiol, prolactin, fasting_glucose, hba1c, total_cholesterol, ldl, hdl, triglycerides, tsh, vitamin_d, blood_pressure_systolic, blood_pressure_diastolic
  - Trend charts per test over time
  - Flag values outside reference range

Implement RLS policies: all data is profile-scoped and owned by auth user.

---

## 3) Health Metrics Pipeline

### Normalized Health Metrics Table
`WT_health_metrics` with:
- id, user_id, profile_id
- source (healthconnect, healthkit, garmin, strava, manual)
- metric_type (sleep, stress, vo2max, steps, hr, rhr, weight, body_fat, hrv, active_calories, etc.)
- value_num, value_text, unit
- start_time, end_time, recorded_at
- raw_payload_json (optional)
- dedupe_hash, created_at, updated_at

### Ingest Rules
- Sleep: ingest from Health Connect/HealthKit and Garmin; deduplicate by start/end time; prefer most detailed record
- Stress: Garmin Stress Score (0-100). If unavailable, store null -- do not block pipeline
- VO2 Max: not available via Health Connect. Manual entry screen for users without Garmin (update every 1-2 weeks). When Garmin is connected (Phase 11), auto-ingest from Garmin Connect. **UX requirement:** If user has no Garmin linked, show a contextual banner on the VO2 Max input screen: "Connect Garmin for automatic VO2 Max tracking" with a link to Health Connections. Never silently leave the field empty -- prompt the user to enter manually or connect a device
- Steps, HR, Weight, Body Fat, HRV, Active Calories: automatic from Health Connect

### Garmin API Integration (MVP -- Server-to-Server)
**Architecture:** PUSH only. Garmin sends data to your webhook. You do NOT poll.

**OAuth 2.0 PKCE flow:**
- Authorization endpoint: `https://connect.garmin.com/oauthConfirm`
- Token endpoint: `https://connectapi.garmin.com/oauth-service/oauth/token`
- Encrypted token storage (never store unencrypted on client)
- Token refresh with retry logic

**Webhook handling:**
- Receive POST at your registered callback URL
- Respond HTTP 200 within 30 seconds (queue for async processing)
- Store raw payload in `WT_webhook_events` first, then process
- Webhook types for MVP: `userMetrics` (VO2 max), `stressDetails`, `dailies`, `sleeps`, `activities`

**Brand attribution (required for Garmin review):**
- Display "Garmin" trademark with (TM) or (R) where data is shown
- Include "Powered by Garmin Connect" or "Data from Garmin" attribution
- Never modify or abbreviate the Garmin name
- Follow Garmin's colour and logo usage guidelines

**Data validation layer:**
- Validate webhook signatures
- Check for duplicate delivery (idempotency via dedupe_hash)
- Validate data ranges (e.g. VO2 max 10-100, stress 0-100)
- Log validation failures without blocking pipeline

---

## 4) Workout Logger (JEFIT-Style -- NEW)

> **BUILDER NOTE:** UX matters more than architecture here. This is the highest-risk feature. If this is weak, everything collapses. Every tap must be optimised. Rest timer must not fail in background. Auto-fill previous session weights is mandatory. Swipe gesture must be fluid. This phase deserves dedicated testing time.

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
- Tap tick -> logs set, starts rest timer
- "+" button to add extra sets
- Swipe left/right to move between exercises

**Rest timer:**
- Auto-starts after logging a set
- Configurable per exercise type (default: 90s compounds, 60s isolation)
- Alert when rest is over: vibration + optional sound (user chooses in Settings: vibrate only, sound only, both, or silent)
- Manual override (skip or extend)

**1RM tracking:**
- Auto-calculate estimated 1RM using Epley formula: `1RM = weight * (1 + reps/30)`
- Display current 1RM on exercise header
- Highlight new personal records with visual celebration
- Store in `WT_exercise_records`

**Session summary (after completing all exercises):**
- Total volume lifted (sets x reps x weight)
- Session duration
- Personal records hit
- Muscle groups worked
- Comparison vs last session of same plan day

### Progressive Overload Tracking
- Weekly total volume chart per muscle group
- 1RM history line chart per exercise over weeks/months
- Personal records log (all-time bests per exercise)
- Smart suggestions: "You've done 85 kg x 12 for 3 weeks -- try 90 kg x 10 next"

### Body Map Visualisation
- Visual muscle map showing muscles trained this week
- Colour coded: green (well-trained), amber (lightly trained), grey (not hit)
- Tap muscle -> shows contributing exercises and volume
- Ensures balanced training across the week

---

## 5) AI Meal Planning & Nutrition Engine (NEW)

> **BUILDER NOTE:** Very complex feature. Cache weekly plans in DB -- avoid regenerating daily. Separate generation logic from presentation layer. Cuisine + nutrition profiles are preferences, not hard constraints. Avoid perfect macro precision obsession -- within +/-10% of targets is acceptable.

### Macro Calculation
Daily targets calculated from: current weight, goal, activity level, training schedule.

| Day Type | Strategy |
|----------|----------|
| Strength training day | Higher calories, higher carbs for performance |
| Cardio day | Moderate calories, moderate carbs |
| Rest day | Lower calories, calorie deficit for fat loss |

Auto-adjust macros when new weight is logged.

### Nutrition Profiles (AI Meal Generation Weighting)
Users can enable nutrition profiles that bias AI meal generation toward specific food groups without overriding macro targets:

| Profile | Prioritises | Reduces |
|---------|-------------|---------|
| **Default** | Balanced whole foods | Processed foods |
| **Cardiovascular & Blood Flow** | Beetroot, dark leafy greens (spinach, rocket, kale), watermelon, pomegranate, dark chocolate 85%+, garlic -- all nitric oxide boosters | Added sugar, refined carbs |
| **Hormonal Support** | Whole eggs, fatty fish (salmon, mackerel, sardines), zinc-rich foods (pumpkin seeds, chickpeas, red meat), cruciferous vegetables (broccoli, cauliflower), magnesium-rich foods (almonds, avocado) | Excess soy, heavily processed foods |

Profiles stack -- enabling both Cardiovascular and Hormonal means AI includes foods from both lists. The AI weighting is a preference, not a hard constraint: if a meal doesn't include a profile food, that's fine as long as macros are hit.

### AI Meal Generation
AI generates daily meal plans with 3 meals + 1-2 snacks. Each meal includes:
- Name and description
- Full macro breakdown (calories, protein, carbs, fat per serving)
- Portion sizes in grams
- Step-by-step recipe with prep and cook time
- Swap option: tap "Swap" -> AI generates alternative hitting same macros
- Cuisine preference support (Nigerian, British, Mediterranean, Asian, etc.)

### Meal Prep Assistant
Weekly meal prep screen:
- Identifies which meals can be batch-cooked
- Consolidated shopping list sorted by supermarket aisle
- Estimated prep time, cook time, storage instructions
- Tick-off items as you shop, mark meals as prepped

### Recipe Database
Categorised by: goal alignment, cuisine type, prep time, diet type.
User can favourite recipes -> AI prioritises them in future plans.

### Recipe Import (Existing WellTrack Feature)
- **URL paste** (Phase 9): User pastes URL -> server extracts recipe -> user confirms
- **Photo OCR** (Phase 12): User photographs recipe -> OCR -> extraction -> confirm
- **AI-generated**: From pantry items or macro targets
- **Saved**: User's stored favourites

---

## 6) AI Daily Coach (NEW)

> **BUILDER NOTE:** High coupling risk. Keep prescription logic rule-based first (if/else decision tree). AI only narrates the output -- it does NOT make the workout/meal decisions. Workout modification must not corrupt workout history. Morning check-in should be lightweight (< 30 seconds to complete).

### Morning Check-In
When user opens app (or via morning notification):

| Question | Input |
|----------|-------|
| How are you feeling? | Great / Good / Tired / Sore / Unwell |
| How did you sleep? | Auto-filled from Garmin sleep data. User can override |
| Morning erection today? | Yes / No (private, encrypted, used for trend tracking) |
| Any injuries or pain? | Optional free text |
| What's your schedule today? | Busy / Normal / Flexible |

Additionally, prompt weekly (every Sunday):
| Weekly question | Input |
|-----------------|-------|
| Erection quality this week? | 1-10 slider (private, encrypted) |

Store responses in `WT_daily_checkins`. Morning erection and erection quality fields are marked `is_sensitive = true` in schema and excluded from any data export unless user explicitly opts in.

### Daily Prescription Logic
AI combines check-in + Health Connect data + goals to generate today's plan:

| Scenario | Signals | Prescription |
|----------|---------|-------------|
| Well rested, feeling great | 7+ hrs sleep, low RHR, "Great" | Full planned workout. Push progressive overload. Standard meals. |
| Tired but not sore | <6 hrs sleep, "Tired" | Keep workout, reduce volume 20%. Extra carbs at breakfast. Bedtime reminder. |
| Very sore | "Sore", heavy session yesterday | Active recovery: light walk + stretching. High-protein meals. |
| Behind on steps | 3 PM and <4,000 steps | Nudge: "A 30-min walk after work gets you to your goal." |
| Weight stalling | No change 2+ weeks | Suggest reducing rest-day calories by 100-200. Add one cardio session. |
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
- Consistently skip Wednesday workouts -> suggest swapping days
- Always swap out a particular meal -> stop suggesting that recipe
- Resting HR spikes after poor sleep -> surface the correlation
- Better performance on high-carb training days -> adjust future macros
- Morning erections correlate with 7+ hours sleep -> surface the connection (private insight)
- Erection quality improves after cardio-heavy weeks -> reinforce cardio consistency
- Recovery score trends with erection quality over time -> surface pattern if strong correlation found

---

## 7) Goal Tracking & Projection Engine (ENHANCED)

### Goal Setup
Users set targets for each metric with a deadline and priority:
- Weight, VO2 Max, Resting HR, Steps, Sleep, Strength frequency, Cardio frequency
- Exercise-specific goals (e.g. Trap Bar Deadlift 1RM: 119 -> 160 kg)

### Projection Algorithm (Deterministic -- Math First)
**Layer 1 -- Deterministic (SQL/math):**
- Data window: last 14-28 days of readings
- Rate of change: (current - value N days ago) / N days
- Recent bias: last 7 days weighted 2x vs prior 7 days
- Projection: (Target - Current) / Rate of Change = Estimated Days Remaining
- Confidence band: optimistic (best 7-day rate) and pessimistic (worst 7-day rate)

**Layer 2 -- AI Narrative (explanation only):**
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
- Captures: stress average, sleep consistency, VO2 max trend, training load baseline, resting HR baseline, step average, weight trend

After 14 days:
- Baseline locked in
- Optimization features unlock
- All future data compared against baseline
- "vs your baseline" comparisons available on all charts

---

## 9) Performance Intelligence Engine (Existing WellTrack IP)

> **This is your moat.** Build in this exact order: (1) Recovery Score first, (2) Load model second, (3) Baseline gating third, (4) AI explanation last. Do NOT mix AI into the calculation layer.

### Training Load Model
```
Load Score = Duration (min) x Intensity Factor
```
Intensity factors: Light (0.5), Moderate (1.0), Hard (1.5), Very Hard (2.0)

Derive:
- Weekly load total
- Load trend (increasing/decreasing/stable)
- Recovery ratio (load vs recovery score)
- Overtraining detection (load spike > 150% of 4-week average)

### Recovery Score (WellTrack Composite -- Proprietary)
```
WT_recovery_score = weighted combination of:
  - Stress trend (lower = better recovery) -- weight: 0.25
  - Sleep quality score -- weight: 0.30
  - Resting HR trend (declining = recovering) -- weight: 0.20
  - Training load trend (decreasing after peak = recovering) -- weight: 0.25
```
- Score: 0-100 (0 = depleted, 100 = fully recovered)
- Recalculate daily
- Store with component breakdown for transparency
- Primary performance indicator on dashboard (Pro feature)

### Insights Architecture
All core trend calculations MUST be deterministic SQL, not AI-generated:
- Sleep trend = SQL (7/14/30 day averages, consistency score)
- VO2 max trend = SQL (slope, moving average)
- Stress trend = SQL (daily average, weekly comparison)
- Training load trend = SQL (rolling sum, recovery ratio)
- Recovery score = SQL (weighted composite)

AI generates the narrative layer only -- explaining trends and suggesting actions.

---

## 10) AI Orchestrator

### Architecture
- Single endpoint: `/ai/orchestrate`
- Inputs: user_id, profile_id, context snapshot, user message, workflow type
- Routing: decides which tool to call

### Tool Registry
**MVP tools (Phase 4 -- implement these first, do NOT register everything at once):**
- `generate_daily_plan` (morning check-in -> workout + meals + tips)
- `explain_metric` (AI explains a trend or score in plain language)
- `generate_meal_plan` (daily/weekly meal generation)

**Phase 8+ tools (add as each phase lands):**
- `generate_meal_swap` (replace one meal, maintain macros)
- `generate_weekly_plan` (overall weekly planning)
- `generate_pantry_recipes`
- `generate_recipe_steps`
- `suggest_progressive_overload` (workout suggestions)
- `summarize_insights` (weekly narrative)
- `recommend_supplements`
- `recalc_goal_forecast` (trigger forecast recalculation)
- `generate_shopping_list` (from meal plan)
- `correlate_health_trends` (find patterns between metrics, e.g. sleep -> morning erections)
- `summarize_bloodwork` (interpret bloodwork results, flag out-of-range, suggest retests)

Grow the registry gradually. Each new phase registers its tools. Do not front-load.

### AI Context Updates
Orchestrator must include in context snapshots:
- Normalized health metrics (stress, sleep, VO2 max, RHR, HRV)
- Latest recovery score + components
- Training load (current week vs 4-week average)
- Goal progress (current values vs targets)
- Recent workout history (last 7 days)
- Check-in responses (morning erection trend -- last 7 days, **only if user has enabled "Share vitality data with AI" consent toggle**)
- Dietary preferences, enabled nutrition profiles, and favourited recipes
- Active habit streaks (current + longest)
- Latest bloodwork results (**only if user has enabled consent toggle**, with flags for out-of-range values)

### Cost Control
- Context trimming (summarised state, not raw data)
- Response caching for repeated queries
- Meal plans cached weekly (regenerate only on swap)
- AI usage metered via `WT_ai_usage`
- Free tier: limited calls/day. Pro tier: higher limits.

### AI Guardrails
- Rate limiting: max N calls per user per hour
- Input validation: reject nonsensical or adversarial inputs
- Output validation: verify AI responses match expected JSON schema
- Safety checks: flag any content that could be interpreted as medical advice
- Fallback: if AI fails, show deterministic data only (never a blank screen)

---

## 11) Notifications & Nudges

**Priority notifications (implement first, keep conservative -- avoid spam):**
- **Morning check-in** (configurable time, default 7 AM)
- **Workout reminder** (30 min before planned session time)
- **Wind-down reminder** (default 10 PM -- "Screens off. Start your wind-down routine.")
- **Milestone celebrations** (new PR, new low weight, consistent streak, streak milestones at 7/30/90/180 days)

**Secondary notifications (add later, user must opt-in):**
- AM kegel reminder (default 7:30 AM)
- PM kegel reminder (default 9 PM)
- Step nudge (if below target threshold by afternoon)
- Bedtime reminder (calculated from wake time + 7-hour target, default 10:45 PM)
- Daily check-in reminder (configurable, default 9 PM)
- Sunday weekly report

---

## 12) Freemium Strategy

**Core principle:** Gate optimization, not logging.

### Free Tier
- Full data tracking (all health metrics, workout logging, food logging)
- Basic charts (7-day views)
- Basic dashboard
- Manual VO2 Max entry
- Exercise database access
- 3 AI calls/day

### Pro Tier
- Goal projections with timeline forecasts
- Recovery score (proprietary composite)
- Training load analysis + overtraining detection
- AI Daily Coach (morning check-in -> daily prescription)
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

| Screen | Module | Purpose | Status |
|--------|--------|---------|--------|
| Onboarding | core | Goals, preferences, Health Connect setup | BUILT |
| Dashboard (Home) | core | Today's snapshot + goal overview rings | BUILT |
| Morning Check-In | daily_coach | How are you feeling? Quick-tap inputs | -- |
| Today's Plan | daily_coach | AI-prescribed workout + meals + tips | -- |
| Workout Logger | workout_logger | JEFIT-style set/rep/weight logging | BUILT |
| Exercise Library | workout_logger | Browse/search exercises with GIFs | BUILT |
| Workout Plans | workout_logger | Create/edit weekly plans | BUILT |
| Session Summary | workout_logger | Post-workout stats + PRs | BUILT |
| Body Map | workout_logger | Visual muscle map for the week | BUILT |
| Meal Plan | meal_planner | Daily meals with macros, tap for recipe | BUILT |
| Recipe Detail | meal_planner | Full recipe with ingredients + steps | BUILT |
| Meal Prep | meal_planner | Weekly batch cook planner | -- |
| Shopping List | meal_planner | Auto-generated, sorted by aisle | BUILT |
| Food Log | meal_planner | Manual meal/nutrition entry fallback | BUILT |
| Pantry | recipes | Fridge/cupboard/freezer input | BUILT |
| Recipe Suggestions | recipes | AI-generated from pantry | BUILT |
| Goal Setup | goals | Set metric, target, deadline | BUILT |
| Goal Detail | goals | Chart, projection, trend, milestones | BUILT |
| Steps | health_tracking | Bar chart, goal line, weekly avg | BUILT |
| Sleep | health_tracking | Stacked bars (deep/light/REM), avg | BUILT |
| Heart & Cardio | health_tracking | RHR line chart, VO2 Max manual input | BUILT |
| Weight & Body | health_tracking | Line chart with projection overlay | BUILT |
| Supplements | supplements | AM/PM protocols, link to goals | BUILT |
| Bloodwork Log | health_tracking | Input lab results, trend charts per test, out-of-range flags | -- |
| Habit Streaks | habits | Active streaks (kegels, porn-free, sleep target, etc.), longest streaks, daily tick-off | -- |
| Weekly Report | insights | Wins, misses, projected dates, volume | -- |
| Insights Dashboard | insights | Recovery score, load chart, AI narrative | BUILT |
| Settings | core | Notifications, units, theme, rest timers, AI quota, connections, ingredient preferences | BUILT |
| Health Connections | core | Garmin/Strava connect/disconnect + status | BUILT |

---

## 14) Build Order

Start by generating the full scaffold, then implement phase by phase. See BUILD-PLAN.md for detailed sequencing.

| Priority | What | Why | Status |
|----------|------|-----|--------|
| Phase 0 | Architecture Lock | Prevents rework | DONE |
| Phase 1 | Schema + RLS | Everything depends on storage | DONE (34 wt_* tables, RLS active) |
| Phase 2 | Scaffold + Auth + Offline | App must exist | DONE (+ Phase 2b onboarding redesign) |
| Phase 3 | Health Connect / HealthKit | Gets data flowing | DONE (steps, sleep, heart, weight, VO2max screens) |
| Phase 4 | AI Orchestrator | Brain built early | DONE (edge function deployed, tool registry, context builder) |
| Phase 5 | Workout Logger | Core daily interaction | DONE (JEFIT-style: plans, per-set logging, rest timer, 1RM, body map, 181 exercises) |
| Phase 6 | Goals + Projections | Core value prop | DONE (goal setup, detail, projections) |
| Phase 7 | Pantry -> Recipes -> Prep | High user value | DONE (pantry, recipes, shopping lists, URL/OCR import) |
| Phase 8 | AI Meal Planning | Daily nutrition engine | PARTIAL (meal plan screen, nutrition targets, shopping generator, ingredient preferences) |
| Phase 9 | AI Daily Coach | Intelligence layer | -- |
| Phase 10 | Performance Engine | Recovery score, load, insights | PARTIAL (insights dashboard, recovery score display) |
| Phase 11 | Garmin + Strava | OAuth + webhooks | -- |
| Phase 12 | Supplements + Habits + Bloodwork | Habit engine + health records | PARTIAL (supplements screen built) |
| Phase 13 | Notifications | Nudges, celebrations | -- |
| Phase 14 | Recipe URL Import | Extends recipe system | DONE (URL + OCR import screens) |
| Phase 15 | Freemium + Paywall | Monetisation | PARTIAL (paywall screen scaffold) |
| Phase 16 | OCR + Polish + Launch | Final features | -- |

---

## 15) Coding Conventions

- **File naming**: Components `PascalCase.dart`, utilities `snake_case.dart` (Dart convention)
- **File size limit**: < 500 lines per file; split into modules if exceeding
- **Commit format**: `type(scope): description` (feat/fix/docs/style/refactor/test/chore)
- **Branch naming**: `main`, `develop`, `feature/*`, `fix/*`, `hotfix/*`
- **Sensitive data**: Never store tokens unencrypted on client; use `flutter_secure_storage`
- **All DB tables**: prefixed with `wt_` (Supabase deployed) or `WT_` (spec reference)
- **Navigation**: GoRouter only (`context.go()` / `context.push()`). NEVER use `Navigator.pushNamed()`
- **State management**: Riverpod
- **Local DB**: Hive (replaced Isar -- AGP 8.11.1 incompatible)

---

## 16) Builder Brief

> Treat this as a modular performance system. Prioritise workout UX, deterministic projections, and recovery engine. AI explains; math calculates. No feature should directly couple to another domain. Sensitive data must be encrypted and isolated. Home screen must remain calm and uncluttered. We build one phase at a time -- no parallel mega-build.

### Major Risk Flags
1. **Scope creep within each phase** -- finish one before starting the next
2. **UI overcrowding** -- dashboard must be minimal, not a data dump
3. **AI overuse** -- start with 3 tools, grow gradually
4. **Sensitive data mishandling** -- encrypt, isolate, require consent
5. **Overcoupling domains** -- enforce service/event boundaries
6. **Underestimating workout logger complexity** -- this deserves the most testing time
7. **Meal planning macro precision obsession** -- +/-10% is acceptable

### Simplification Guidance
For v1, prioritise:
- **Elite** workout logger
- **Minimal** bloodwork UI (input + trend chart, nothing fancy)
- **Simple** vitality tracking (Y/N toggle, nothing more)
- **Basic** AI meal planning (weekly cache, simple swaps)
- Everything else can mature later

### Key Principles
1. **Math first, AI explains.** Forecasts are deterministic. AI narrates.
2. **Suggestive, not prescriptive.** "Consider this" not "Do this."
3. **No medical claims.** "Helps you train consistently toward your goals."
4. **Gate optimization, not logging.** Free users track everything. Pro unlocks intelligence.
5. **Offline-first.** Everything works without internet. Sync when connected.
6. **Baseline before optimization.** 14 days of data before features unlock.
7. **Minimal taps in the gym.** Pre-loaded data, single-tap logging, auto-timers.
8. **One phase at a time.** Don't ask Claude Code to build everything at once.
