# WellTrack — Enhanced Build Plan v4

> **Product:** Performance & Recovery Optimization Engine
> **First optimization model:** Physical fitness & VO₂ max improvement
> **AI philosophy:** Suggestive. Math generates forecasts; AI explains them.
> **Positioning:** Strictly wellness — no medical claims ever.
> **Builder directive:** One modular performance engine with staged capability unlocks. Not 8 parallel mini apps.
>
> Foundation → Structure → Plumbing → Muscles → Brain → Intelligence → Polish

---

## What Changed from v2 → v3

| v2 (Original WellTrack) | v3 (Enhanced) | Why |
|--------------------------|---------------|-----|
| Basic workout module (manual + suggested) | Full JEFIT-style workout logger | Core daily interaction — must be excellent |
| Pantry → recipes only | + AI meal planning with daily macros | Nutrition is 80% of fitness results |
| No daily coach | AI Daily Coach with morning check-in | Turns data into daily action |
| Basic goal forecasting | Full goal tracking with projections, velocity, confidence | Key differentiator |
| No progressive overload | 1RM tracking, volume charts, smart suggestions | Essential for strength goals |
| No body map | Visual muscle map (trained this week) | Ensures balanced training |
| No shopping lists | Auto-generated shopping list from meal plan | Reduces friction |
| No meal prep | Batch cook planner for the week | Practical time-saver |
| No nutrition profiles | Cardiovascular & Hormonal nutrition profiles for AI meals | Optimise food for blood flow + testosterone |
| No morning erection tracking | Morning erection Y/N + weekly quality 1–10 (encrypted) | Key outcome metric, feeds AI correlations |
| No habit streaks | Generic streak tracker (kegels, porn-free, sleep, custom) | Accountability + milestone celebrations |
| No bloodwork logging | Lab results with reference ranges, trend charts, flags | Stop flying blind on hormones |
| No wind-down reminders | 10 PM screens-off + kegel reminders (AM/PM) | Sleep protocol + pelvic floor consistency |
| 12 phases, ~60–75 days | 16 phases, ~90–120 days | More features, more realistic |

---

## Phase 0: Architecture Lock (2–3 days) — DONE
**Why:** Skipping this causes rework. Like drawing blueprints before pouring concrete.

**Delivers:**
- Finalised ER diagram (all table relationships including new workout/meal/goal tables)
- Health metric mapping table (which source → which metric → which format)
- AI Orchestrator contract (JSON schema for inputs/outputs)
- Recovery formula spec (exact weights, inputs, calculation logic)
- Event-driven domain map (how domains communicate via services/events — no direct table queries across domains)
- Module dependency map
- Screen wireflow (how screens connect)

**Do not start coding before Phase 0 output is approved.**

**You'll need:** Nothing yet — this is planning.

---

## Phase 1: Schema + RLS (2–3 days) — DONE
**Why:** Every feature reads/writes data.

**Status:** 34 `wt_*` tables deployed in Supabase with RLS policies active. Includes `wt_profiles` with `preferred_ingredients` and `excluded_ingredients` text[] columns.

**Delivers:**
- All `WT_` tables in Supabase (including new workout, meal, goal, check-in, habit streak, and bloodwork tables)
- `WT_habit_streaks` for generic streak tracking (porn-free, kegels, sleep target, etc.)
- `WT_bloodwork_results` for lab result history with reference ranges and out-of-range flags
- `WT_daily_checkins` includes `morning_erection` (boolean) and `erection_quality_weekly` (1–10) fields marked `is_sensitive = true`
- Row Level Security on every table (extra encryption on sensitive fields)
- Composite indexes on: `(user_id, date)` and `(user_id, metric_type, start_time)`
- Database indexes for performance
- Seed data for development

**You'll need:** Supabase account (free tier fine)

**Remaining:** Add `WT_habit_streaks`, `WT_bloodwork_results` tables. Add `morning_erection` + `erection_quality_weekly` sensitive fields to `WT_daily_checkins`.

---

## Phase 2: App Skeleton + Auth + Offline (5–7 days) — DONE
**Why:** The app needs to exist, log users in, and work offline.

**Status:** Flutter project scaffolded with Clean Architecture, Supabase Auth (email/password), Hive local DB, GoRouter (20+ routes), Riverpod state management. Phase 2b onboarding UI redesign (7-screen premium flow) also complete.

**Delivers:**
- Flutter project with Clean Architecture (domain-isolated structure per Section 1 of CLAUDE.md)
- Supabase Auth (email/password)
- Encrypted local database (Room on Android equivalent)
- Offline sync: queue writes locally, last-write-wins resolution. **Do NOT overengineer** — no enterprise-grade conflict engine needed for personal use. Refine later.
- Module registry + dashboard tile system
- Navigation + routing
- Error reporting (Sentry) + logging from day one
- Single profile only (dependents later)

---

## Phase 3: Health Connect + HealthKit (3–4 days) — DONE
**Why:** Gets health data flowing without OAuth complexity.

**Status:** Health Connect integration active. Steps, Sleep, Heart/Cardio, Weight/Body, and VO2 Max entry screens all built and functional. Background sync via WorkManager registered (every 6 hours).

**Delivers:**
- Health Connect integration (Android) — steps, sleep, HR, weight, body fat, HRV, active calories, exercise sessions
- HealthKit integration (iOS) — same metrics
- Normalisation into `WT_health_metrics`
- Deduplication logic
- Background sync via WorkManager (every 2–4 hours + on app open)

**What changed:** Garmin/Strava still deferred to Phase 11. Test everything with native health data first.

---

## Phase 4: AI Orchestrator (5–7 days) — DONE
**Why:** Build the brain early so it evolves with features.

**Status:** `ai-orchestrate` edge function deployed. Tool registry, context builder (including preferred/excluded ingredients, dietary restrictions, allergies), safety validator, and usage metering all operational. Uses `gpt-4o-mini` via OpenAI.

⚠️ **Scope risk.** Implement ONLY 3 tools initially: `generate_daily_plan`, `explain_metric`, `generate_meal_plan`. Do NOT register every tool upfront. Grow the registry as each phase lands.

**Delivers:**
- `/ai/orchestrate` Edge Function
- Tool registry with initial 3 tools (add more per phase)
- Structured JSON responses
- Context builder (health data + preferences → prompts)
- Usage metering + audit log
- Cost control: context trimming, snapshot strategy, response caching
- AI guardrails: rate limiting, input/output validation, safety checks
- Sensitive data consent toggle: vitality + bloodwork data only sent to AI if user explicitly opts in

**Remaining:** Add `explain_metric` tool. Add sensitive data consent toggle for vitality/bloodwork AI sharing.

---

## Phase 5: Workout Logger — JEFIT-Style (7–10 days) ⭐ NEW — NOT STARTED
**Why:** Core daily interaction. Must be excellent. This is what you'll use every gym session.

**Delivers:**
- Exercise database (200+ pre-loaded with images/GIFs)
- Custom exercise creation
- Workout plan builder (named plans, day assignments, exercise ordering)
- Default plan pre-loaded from current 4-day split
- **Live workout logging screen:**
  - Exercise header with GIF demo + 1RM display
  - Set rows: Set # | Weight (kg) | Reps | Completion tick
  - Pre-loaded values from last session (single-tap logging)
  - Swipe between exercises
  - Rest timer (auto-start, configurable, vibrate/sound alert)
  - 1RM auto-calculation (Epley formula) + PR celebrations
- Session summary (volume, duration, PRs, muscle groups)
- Progressive overload tracking (volume trends, 1RM history charts)
- Smart overload suggestions
- Body map visualisation (muscles trained this week, colour-coded)
- Personal records log

**This is the biggest phase and highest-risk feature.** UX matters more than architecture here. If this is weak, everything collapses. Allocate at least 2 of the 7–10 days purely for UX testing and refinement. Test with actual gym sessions.

---

## Phase 6: Goals + Projections (4–5 days) ⭐ ENHANCED — DONE
**Why:** Turns tracking into motivation. Shows you when you'll hit your targets.

**Status:** Goal setup screen, goal detail screen with projections, goals list with progress rings, daily snapshots, forecast engine — all built and functional.

**Delivers:**
- Goal setup screen (metric, current value, target, deadline, priority)
- Pre-loaded goals from your current plan (weight, VO₂ max, RHR, steps, sleep, strength, cardio)
- Exercise-specific goals (e.g. Trap Bar DL 1RM: 119 → 160 kg)
- Projection algorithm (weighted moving average, 14–28 day window, 2× recent bias)
- Goal detail screen: progress bar, trend arrow, projected date, status badge, velocity, confidence range
- Dashboard progress rings with status colours
- Daily goal snapshots stored for trend calculation
- "At current pace, goal will not be reached by deadline" warning

---

## Phase 7: Pantry → Recipes → Prep (5–7 days) — DONE
**Why:** Existing WellTrack feature. High user value, proves AI + schema work together.

**Status:** Pantry screen, recipe suggestions, recipe detail, recipe list/edit, URL import, OCR import, shopping lists with detail/photo-import/barcode-scan, photo pantry import — all built.

⚠️ **Some version of this already exists.** Refactor into domain isolation. Ensure meal logs feed goals and macro data feeds recovery. Do NOT rewrite from scratch unless necessary.

**Delivers:**
- Pantry input screen (fridge/cupboard/freezer)
- AI generates recipe options from pantry items
- Recipe cards with tags, time, difficulty, nutrition
- Step-by-step prep walkthrough with timers + checklist
- Leftover capture → feeds next recipe suggestion
- Nutrient auto-extraction from logged meals

---

## Phase 8: AI Meal Planning (6–8 days) ⭐ NEW — PARTIAL
**Why:** Nutrition is 80% of fitness results. AI removes the guesswork.

**Status:** Meal plan screen, nutrition targets screen, shopping list generator screen, ingredient preferences screen (preferred + excluded) — all built. Macro calculator and meal plan repository exist.

**Delivers:**
- Daily macro calculation (auto-adjusts based on weight, goal, training day type)
- **Nutrition profiles** — user-selectable biases for meal generation:
  - *Cardiovascular & Blood Flow*: prioritises beetroot, dark leafy greens, watermelon, pomegranate, dark chocolate 85%+, garlic (nitric oxide boosters)
  - *Hormonal Support*: prioritises whole eggs, fatty fish, zinc-rich foods, cruciferous veg, magnesium-rich foods
  - Profiles stack and are preferences, not hard constraints
- AI meal generation: 3 meals + 1–2 snacks per day
- Each meal: name, description, full macro breakdown, portion sizes in grams
- Full recipe with step-by-step instructions, prep time, cook time
- Swap button: AI generates alternative hitting same macros
- Cuisine preference support (Nigerian, British, Mediterranean, Asian, etc.)
- Weekly meal prep screen (batch cook planner)
- Auto-generated shopping list sorted by supermarket aisle
- Recipe favourites → AI prioritises in future plans
- Recipe database: browse by goal, cuisine, prep time, diet type
- Manual food logging fallback

**API cost management:** Cache weekly meal plans. Only regenerate on swap or new week.

**Remaining:** Nutrition profiles UI (cardiovascular/hormonal selection). Meal swap functionality. Weekly meal prep screen. Cuisine preference setting.

---

## Phase 9: AI Daily Coach (5–7 days) ⭐ NEW — NOT STARTED
**Why:** The intelligence layer that ties everything together. Turns data into daily action.

⚠️ **High coupling risk.** Keep prescription logic rule-based first (if/else decision tree). AI only narrates the output. Morning check-in must be lightweight (< 30 seconds). Workout modification must not corrupt workout history.

**Delivers:**
- Morning check-in screen (feeling, sleep auto-fill, **morning erection Y/N**, injuries, schedule)
- **Weekly check-in** (Sunday): erection quality 1–10 slider — private, encrypted
- Morning erection + erection quality data feeds into trend charts and AI correlation engine
- Daily prescription logic engine (check-in + Health Connect data → plan)
- Today's Plan screen: workout card + meals card + steps ring + focus tip + bedtime
- Scenario handling: tired, sore, unwell, busy, behind on steps, weight stalling
- Workout modification logic (reduce volume, swap exercises for injuries)
- Adaptive intelligence (learns patterns over time, including sleep → morning erection correlation)
- Bedtime reminder calculation

---

## Phase 10: Performance Intelligence Engine (5–7 days) — PARTIAL
**Why:** This is your moat. This is where WellTrack becomes a performance system, not just a tracker.

**Status:** Insights dashboard screen built with recovery score display (calibrating state). Recovery score entity and basic calculation exist.

**Build in this exact order:**

**Step 1 — Recovery Score (build first):**
- Proprietary composite: Stress trend (0.25) + Sleep quality (0.30) + RHR trend (0.20) + Load trend (0.25)
- Score 0–100, recalculated daily, stored with component breakdown
- Primary performance indicator on dashboard

**Step 2 — Training Load model:**
- `Load = Duration × Intensity Factor`
- Weekly load tracking, trend detection, recovery ratio
- Overtraining detection (load spike > 150% of 4-week average)

**Step 3 — Baseline Calibration Mode:**
- 14-day baseline capture required before optimization unlocks
- Dashboard shows "Collecting your baseline..." with day counter
- Baseline comparison ("vs your first 14 days") available on all charts after

**Step 4 — Deterministic Insights (all SQL, not AI):**
- Sleep trend (7/14/30-day averages)
- VO₂ max trend (slope, moving average)
- Stress trend, training load trend

**Step 5 — AI narrative layer (last):**
- AI explains the math, suggests actions
- AI does NOT calculate. Math calculates. AI narrates.
- Dashboard: recovery score, load chart, VO₂ max trend with forecast line

**Remaining:** Training load model, baseline calibration mode, deterministic SQL insights, AI narrative layer.

---

## Phase 11: Garmin + Strava Integration (5–7 days) — NOT STARTED
**Why:** App is stable. Now handle OAuth + webhook complexity.

**Delivers:**
- Garmin OAuth 2.0 PKCE connect/disconnect flow
- Strava OAuth connect/disconnect flow
- Encrypted token storage
- Webhook receivers (Supabase Edge Functions) with queue-first architecture
- Backfill job (last 14 days on first connect)
- Connection status UI + last sync timestamps
- Garmin brand attribution (required for review)
- Data validation layer (signatures, dedup, range checks)
- Stress score + VO₂ max now flowing into pipeline

**You'll need:** Garmin Developer account, Strava Developer account

---

## Phase 12: Supplements + Habits + Bloodwork (5–6 days) — PARTIAL
**Why:** Completes the daily habit engine and health data picture.

**Status:** Supplements screen built. Daily view screen exists.

⚠️ **UI placement:** These features live inside Log → Secondary tab or Profile → Health Records. Do NOT surface aggressively on home dashboard. Keep bloodwork UI minimal for v1 (input + trend chart, nothing fancy).

**Delivers:**
- Supplements tracker (AM/PM protocols, link to goals)
- **Habit Streak Tracker** (generic, reusable):
  - Pre-loaded habits: Kegels AM, Kegels PM, Porn-free, Sleep target hit, Steps target hit
  - User can add custom habits
  - Daily tick-off (tap to complete)
  - Current streak + longest streak display
  - Streak milestone celebrations (7, 30, 90, 180 days)
- **Kegel protocol** pre-loaded as an exercise in the habit tracker:
  - Quick Flicks (10 reps × 3 sets), Long Holds (10 reps, progressive duration), Reverse Kegels (10 reps)
  - Simple "Done" tick per session (AM/PM), no need to log individual reps
- **Bloodwork Log screen:**
  - Input lab results: test name (dropdown of pre-loaded types), value, date
  - Pre-loaded test types: total testosterone, free testosterone, SHBG, oestradiol, prolactin, fasting glucose, HbA1c, cholesterol panel, TSH, vitamin D, blood pressure
  - Reference ranges displayed beside each result
  - Out-of-range values flagged with amber/red
  - Trend chart per test over time (line chart)
  - AI can interpret results and suggest retests (suggestive, not prescriptive)
- Daily View (single-day checklist across all modules)
- Reminders table + scheduler hooks

**Remaining:** Habit streak tracker, kegel protocol, bloodwork log screen, reminders scheduler.

---

## Phase 13: Notifications (3–4 days) — NOT STARTED
**Why:** Nudges and celebrations drive consistency.

**Delivers:**
- Morning check-in notification
- **AM kegel reminder** (default 7:30 AM)
- Step nudge (afternoon if below target)
- **PM kegel reminder** (default 9 PM)
- Daily check-in reminder (evening)
- **Wind-down reminder** (default 10 PM — "Screens off. Start your wind-down routine.")
- **Bedtime reminder** (calculated from wake time + 7-hour target, default 10:45 PM)
- Sunday weekly report
- Milestone celebrations (new PR, streak milestones at 7/30/90/180 days, goal milestones)
- Workout reminder (30 min before planned session)

---

## Phase 14: Recipe URL Import (3 days) — DONE
**Why:** Extends recipe system with web imports.

**Status:** URL import screen and OCR import screen both built and functional.

**Delivers:**
- User pastes URL → server extracts recipe → user confirms/edits
- Stores to recipe tables, available for meal planning

---

## Phase 15: Freemium + Paywall (3–4 days) — PARTIAL
**Why:** Monetisation layer.

**Status:** Paywall screen scaffold exists. Feature flags infrastructure in place.

**Delivers:**
- Free tier: full tracking, basic charts, 3 AI calls/day
- Pro tier: projections, recovery score, daily coach, meal planning, meal prep, advanced charts, unlimited AI
- In-app purchase integration
- AI quota display in settings
- Pro upsell prompts at feature gates

**Remaining:** In-app purchase integration, AI quota tracking display, feature gate enforcement.

---

## Phase 16: OCR + Polish + Launch (4–5 days) — NOT STARTED
**Why:** Final features and launch readiness.

**Delivers:**
- Recipe photo OCR (photograph recipe → extract → confirm)
- Dark/light theme
- Onboarding flow
- Data export (CSV)
- Performance optimisation + battery testing
- Play Store / App Store preparation
- Garmin production review submission

---

## Effort Summary

| Phase | Scope | Est. Days | Status |
|-------|-------|-----------|--------|
| 0 | Architecture Lock | 2–3 | DONE |
| 1 | Schema + RLS | 2–3 | DONE |
| 2 | Scaffold + Auth + Offline | 5–7 | DONE |
| 3 | Health Connect / HealthKit | 3–4 | DONE |
| 4 | AI Orchestrator | 5–7 | DONE |
| 5 | **Workout Logger (JEFIT-style)** | **7–10** | NOT STARTED |
| 6 | **Goals + Projections** | **4–5** | DONE |
| 7 | Pantry → Recipes → Prep | 5–7 | DONE |
| 8 | **AI Meal Planning** | **6–8** | PARTIAL |
| 9 | **AI Daily Coach** | **5–7** | NOT STARTED |
| 10 | Performance Intelligence | 5–7 | PARTIAL |
| 11 | Garmin + Strava | 5–7 | NOT STARTED |
| 12 | Supplements + **Habits + Bloodwork** | **5–6** | PARTIAL |
| 13 | Notifications | 3–4 | NOT STARTED |
| 14 | Recipe URL Import | 3 | DONE |
| 15 | Freemium + Paywall | 3–4 | PARTIAL |
| 16 | OCR + Polish + Launch | 4–5 | NOT STARTED |
| **Total** | | **~72–96 focused days** | |

**Completed:** ~30–35 days of work across Phases 0–4, 6, 7, 14.
**Remaining:** ~45–60 focused days (Phases 5, 8 remainder, 9–13, 15 remainder, 16).
**Realistic range with integration friction:** 60–80 more days to launch-ready.

---

## Milestone Checkpoints

| Milestone | When | What You Can Do | Status |
|-----------|------|-----------------|--------|
| **Usable tracker** | End of Phase 3 (~2 weeks) | See your Health Connect data on a dashboard | DONE |
| **Gym companion** | End of Phase 5 (~5 weeks) | Log workouts JEFIT-style with 1RM tracking | NEXT |
| **Goal-driven** | End of Phase 6 (~6 weeks) | Track goals with timeline projections | DONE |
| **Meal-planned** | End of Phase 8 (~9 weeks) | AI generates daily meals + recipes + shopping lists | PARTIAL |
| **Daily coached** | End of Phase 9 (~11 weeks) | Morning check-in → personalised daily plan | -- |
| **Performance engine** | End of Phase 10 (~12 weeks) | Recovery score, load analysis, baseline comparisons | PARTIAL |
| **Fully connected** | End of Phase 11 (~14 weeks) | Garmin data flowing via webhooks | -- |
| **Launch ready** | End of Phase 16 (~18–20 weeks) | Polished, monetised, store-ready | -- |

---

## Prerequisites (Set Up Before Phase 1)

| What | When Needed | Where | Status |
|------|-------------|-------|--------|
| Supabase account | Phase 1 | supabase.com (free tier) | DONE (project nppjffhzkzfduulbbcih) |
| Flutter SDK + Android Studio | Phase 2 | flutter.dev | DONE |
| Anthropic API key (Claude) | Phase 4 | console.anthropic.com | DONE (using OpenAI gpt-4o-mini) |
| Exercise image/GIF assets | Phase 5 | Open-source or licensed library | NEEDED |
| Garmin Developer account | Phase 11 | developer.garmin.com | -- |
| Strava Developer account | Phase 11 | developers.strava.com | -- |
| Google Play Developer account | Phase 16 | play.google.com/console ($25 one-time) | -- |
| Apple Developer account (if iOS) | Phase 16 | developer.apple.com ($99/year) | -- |

---

## Key Principles (Carried Forward)

1. **Math first, AI explains.** Forecasts are deterministic. AI narrates.
2. **Suggestive, not prescriptive.** "Consider this" not "Do this."
3. **No medical claims.** "Helps you train consistently toward your goals."
4. **Gate intelligence, never gate logging.** Free users track everything. Pro unlocks intelligence.
5. **Offline-first.** Queue writes, last-write-wins, sync when connected. No enterprise-grade conflict engine.
6. **Baseline before optimization.** 14 days of data before features unlock.
7. **Minimal taps in the gym.** Pre-loaded data, single-tap logging, auto-timers.
8. **One phase at a time.** Don't ask Claude Code to build everything at once.
9. **Domain isolation.** No domain directly queries another domain's tables.
10. **Dashboard stays calm.** Home screen is minimal and uncluttered. Less is more.

---

## Major Risk Flags

1. **Scope creep within each phase** — finish one completely before starting the next
2. **UI overcrowding** — dashboard must be minimal, not a data dump
3. **AI overuse** — start with 3 tools, grow gradually per phase
4. **Sensitive data mishandling** — encrypt, isolate, require consent for AI sharing
5. **Overcoupling domains** — enforce service/event boundaries strictly
6. **Underestimating workout logger complexity** — allocate testing time
7. **Meal planning macro precision obsession** — ±10% of targets is acceptable

---

## Builder Brief

> Treat this as a modular performance system. Prioritise workout UX, deterministic projections, and recovery engine. AI explains; math calculates. No feature should directly couple to another domain. Sensitive data must be encrypted and isolated. Home screen must remain calm and uncluttered. We build one phase at a time — no parallel mega-build.

### V1 Prioritisation
- **Elite:** Workout logger
- **Minimal:** Bloodwork UI (input + trend chart, nothing fancy)
- **Simple:** Vitality tracking (Y/N toggle, nothing more)
- **Basic:** AI meal planning (weekly cache, simple swaps)
- Everything else can mature later
