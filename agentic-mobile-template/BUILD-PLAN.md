# WellTrack — Build Plan v5

> **Product:** Performance & Recovery Optimization Engine
> **First optimization model:** Physical fitness & VO₂ max improvement
> **AI philosophy:** Suggestive. Math generates forecasts; AI explains them.
> **Positioning:** Strictly wellness — no medical claims ever.
> **Builder directive:** Fix what's broken before building what's new.
>
> Foundation → Repair → Wire → Intelligence → Complete → Polish

---

## ⚠️ Critical Finding (March 2026 Codebase Audit)

A full codebase review revealed that several phases previously marked DONE are **partially complete or broken in production**. The app runs and compiles cleanly, but key integrations are not wired end-to-end. No phase can be marked truly DONE until it works on a real device with real data flowing to Supabase.

**Root problems identified:**
1. Health Connect permissions not declared in AndroidManifest.xml → no health data flows
2. Notifications service not initialised → reminders never fire on device
3. Meals module generates plans but user cannot interact with them (no mark eaten, no swap, no portion adjust)
4. Shopping list does not pull real ingredients — broken end-to-end
5. Goals projection chart not connected to real metric data
6. prescription_engine.dart and performance_engine.dart running on stub/mock data
7. Food database missing entirely — users cannot log real food they ate

**Resolution:** Phase 3b (Module Repair) inserted before any new development. Nothing new gets built until existing features work properly.

---

## What Changed v4 → v5

| Area | v4 | v5 | Reason |
|------|----|----|--------|
| Phase 3 status | DONE | ⚠️ INCOMPLETE | AndroidManifest missing — no HC data flows |
| Phase 5 status | DONE | ⚠️ INCOMPLETE | Live session UX needs finishing + testing |
| Phase 8 status | DONE | ⚠️ INCOMPLETE | Meal interactions broken, no food DB |
| Phase 9 | NOT STARTED | NOT STARTED | Unchanged — correct |
| Phase 10 status | PARTIAL | ⚠️ BLOCKED | Blocked until Phase 3b completes |
| Phase 13 | NOT STARTED | ⚠️ PARTIALLY BROKEN | Notification service exists but silent |
| **New Phase 3b** | — | **REPAIR** | Fix all broken modules before new builds |
| Meals spec | Basic | **52-feature spec** | Full competitive benchmarking done |
| Food database | Not mentioned | **Open Food Facts API** | Critical gap — without it logging is broken |
| Timeline | ~50–70 days remaining | ~55–75 days remaining | Phase 3b adds ~10–15 days |

---

## Phase 0: Architecture Lock — ✅ DONE
Architecture, ER diagram, module dependency map, AI contract all locked.

---

## Phase 1: Schema + RLS — ✅ DONE
34 `wt_*` tables deployed in Supabase with RLS policies active.

**Remaining before Phase 3b:**
- Verify `wt_health_metrics` has `dedupe_hash` UNIQUE constraint active
- Verify `wt_reminders` table structure matches notification_service.dart expectations
- Add `wt_food_log` table for individual food item logging (needed for Phase 3b meals repair)

---

## Phase 2: App Skeleton + Auth + Offline — ✅ DONE
Flutter scaffolded, Supabase auth, Hive local DB, GoRouter, Riverpod all working.
App compiles clean (0 errors, 50 minor warnings — all non-breaking).

---

## Phase 3: Health Connect + HealthKit — ⚠️ INCOMPLETE
**Status:** Integration code is complete and production-quality. Health Connect is NOT receiving data because Android permissions are not declared.

**health_service.dart** — fully built, reads all metric types
**health_repository_impl.dart** — fully built, bulk upserts to Supabase with dedup
**health_background_sync.dart** — built but WorkManager not registered in main.dart

### Remaining Work (estimate: 1–2 days)

**3.1 — AndroidManifest.xml permissions (30 mins) — CRITICAL**
File: `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>` tag:
```xml
<uses-permission android:name="android.permission.health.READ_SLEEP" />
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_HEART_RATE" />
<uses-permission android:name="android.permission.health.READ_WEIGHT" />
<uses-permission android:name="android.permission.health.READ_EXERCISE" />
<uses-permission android:name="android.permission.health.READ_DISTANCE" />
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />
<uses-permission android:name="android.permission.health.READ_BODY_FAT" />
```

Add inside `<activity>` tag:
```xml
<intent-filter>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
</intent-filter>
```

Create `android/app/src/main/res/values/health_permissions.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <array name="health_permissions">
        <item>androidx.health.permission.Steps</item>
        <item>androidx.health.permission.HeartRate</item>
        <item>androidx.health.permission.SleepSession</item>
        <item>androidx.health.permission.Weight</item>
        <item>androidx.health.permission.Distance</item>
        <item>androidx.health.permission.ActiveCaloriesBurned</item>
        <item>androidx.health.permission.BodyFat</item>
    </array>
</resources>
```

**3.2 — Register WorkManager background sync (1 day)**
File: `lib/main.dart`
- Register WorkManager callback before `runApp()`
- Background task calls `HealthService.syncHealthData()` → `HealthRepositoryImpl.saveHealthMetrics()`
- Sync interval: 15 minutes (WorkManager minimum)

**3.3 — Verify data flows (30 mins)**
- Grant permissions on device
- Wait 15 minutes or trigger manual sync
- Check `wt_health_metrics` in Supabase dashboard — rows should appear
- Confirm `source` field shows `health_connect`

**Do not proceed to Phase 3b until Supabase shows real health data rows.**

---

## Phase 3b: Module Repair — 🔴 NEW (estimate: 10–15 days)

**This phase must complete before any new phases begin.**
The codebase has every module built but none working end-to-end. Fix existing features to production quality before adding new ones.

---

### 3b.1 — Notifications Fix (2 days)
File: `lib/features/reminders/data/notification_service.dart`
File: `lib/main.dart`

**Problem:** Reminders are created in the database but the device never receives a notification.

**Fix:**
- Initialise `flutter_local_notifications` in `main.dart` before `runApp()`
- Request `POST_NOTIFICATIONS` permission on Android 13+ on app first launch
- Add to AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
- Add boot receiver so reminders reschedule after device restart
- Each reminder saved to DB must also call `notification_service.scheduleNotification()`
- Tapping notification must deep link to relevant module screen
- Test: create reminder → lock phone → wait → notification fires ✅

---

### 3b.2 — Food Database Integration (3 days)
**Problem:** No food database exists. Users cannot log real food — only AI-generated meals.

**Solution:** Integrate Open Food Facts API (free, no API key required)

Base URL: `https://world.openfoodfacts.org`

**Search by keyword:**
```
GET /cgi/search.pl?search_terms={query}&search_simple=1&action=process&json=1&fields=product_name,nutriments,image_url,brands
```

**Search by barcode:**
```
GET /api/v0/product/{barcode}.json
```

**Implementation:**
- Create `lib/features/meals/data/food_database_service.dart`
- Returns: food name, calories per 100g, protein, carbs, fat, photo URL
- Cache results in Hive to reduce API calls (key = product name or barcode)
- UK foods well covered — supplement with USDA API if gaps found
- Connect to existing barcode scanner (`mobile_scanner`) — scanner exists, database connection missing
- Add photo search using existing `google_mlkit_text_recognition` for food label OCR

---

### 3b.3 — Meals Module Repair (4 days)
**Problem:** Meal plan generates but user cannot interact with it meaningfully.

**Full meals spec:** 52 features across 5 sections (see WellTrack-Meals-Module-Spec.docx)

**Critical interactions to implement first (24 critical features):**

*Daily logging:*
- Mark planned meal as eaten — one tap, updates macro progress bar instantly
- Mark eaten with portion adjustment (50%, 75%, 125%, 150% — or custom)
- Log food not in plan — triggers food database search (3b.2 required first)
- Real-time macro progress bar on meals screen and dashboard

*Meal plan management:*
- Swap meal — show 3 macro-matched alternatives, user selects one (not auto-swap)
- Regenerate single meal slot — keep rest of plan intact
- Delete entire plan and regenerate fresh
- Calorie target pulls from recovery score daily (connects to Phase 10 engine)
- Dietary restriction filter applied to all AI generation

*Shopping list (connects to 3b.5):*
- Auto-generate from meal plan with quantities aggregated across week
- Cross-reference with pantry — exclude items already in stock
- Tick off items while shopping

---

### 3b.4 — Workout Live Session Completion (2 days)
File: `lib/features/workouts/presentation/workout_logging_screen.dart`

**Problem:** Live session screen exists but rest timer and overload detection output not fully wired.

**Fix:**
- Rest timer auto-starts after each set is logged — uses `rest_timer_provider.dart`
- Vibration + sound alert when rest period ends (`vibration` package already installed)
- 1RM auto-calculates from logged sets (Epley: `weight × (1 + reps/30)`) and displays live
- PR detection: if today's 1RM > personal best → PR celebration overlay
- `overload_detection_service.dart` output surfaces as suggestion card on session summary
- Session summary shows: total volume, duration, PRs hit, muscle groups trained, AI suggestion for next session

---

### 3b.5 — Shopping List Repair (2 days)
File: `lib/features/shopping/data/`

**Problem:** Shopping list creation works but ingredients are not being pulled from meal plans correctly.

**Fix:**
- `shopping_list_repository.dart` must query current meal plan → extract all ingredients → aggregate quantities
- Cross-reference `pantry_repository.dart` — items in pantry excluded from list
- `aisle_mapper.dart` must categorise all ingredients (produce, dairy, meat, frozen, dry goods)
- Barcode scanner on shopping list — scan item to tick it off automatically
- Manual add for non-meal-plan items (household staples)

---

### 3b.6 — Goals Chart Connection (1 day)
File: `lib/features/goals/presentation/widgets/goal_projection_chart.dart`

**Problem:** Projection chart exists but shows mock/static data.

**Fix:**
- Connect to `wt_health_metrics` via `health_repository_impl.dart`
- VO₂ max trend pulls from actual workout + Health Connect data
- Weight projection pulls from logged weight entries
- "At current pace" calculation runs against real data points
- Warning fires when projected date > goal deadline

---

### 3b.7 — Performance Engine Connection (1 day)
Files: `performance_engine.dart`, `prescription_engine.dart`

**Problem:** Engines exist but run on stub data.

**Fix — connect to real Supabase data:**

Recovery score formula (exact weights):
```
recovery_score = (
  sleep_score      × 0.30   // actual sleep vs 7.5hr target
  sleep_quality    × 0.20   // (REM + deep) % — target 40%+
  rhr_score        × 0.25   // resting HR vs personal 14-day baseline
  load_score       × 0.25   // 7-day training load — high load = lower score
)
```

Prescription logic (rule-based first, AI narrates):
| Score | Plan | Workout | Calories |
|-------|------|---------|----------|
| 80–100 | Push | Progressive overload | Full target |
| 60–79 | Normal | Standard plan | Maintenance |
| 40–59 | Easy | Light / active recovery | −10% |
| 0–39 | Rest | Mobility / walk only | Sleep-focused |

---

## Phase 4: AI Orchestrator — ✅ DONE (verify)
`ai-orchestrate` edge function deployed. Tool registry, context builder, safety validator, usage metering operational.

**Verify after Phase 3b:**
- AI orchestrator receives real recovery score (not stub)
- AI narrative for daily plan pulls from prescription_engine output
- Sensitive data consent toggle working (vitality + bloodwork data)
- `explain_metric` tool added to registry

---

## Phase 5: Workout Logger — ⚠️ INCOMPLETE
Workout plan builder, exercise browser, body map, progress charts — all built.
Live session needs finishing per Phase 3b.4.

**After 3b.4 completes, Phase 5 is DONE.**

---

## Phase 6: Goals + Projections — ⚠️ INCOMPLETE
Goal screens built. Projection chart not connected to real data.

**After 3b.6 completes, Phase 6 is DONE.**

---

## Phase 7: Pantry → Recipes → Prep — ✅ DONE
Pantry, recipes, URL import, OCR import — all built and functional.

**Verify:** Pantry cross-references shopping list (connects to 3b.5).

---

## Phase 8: AI Meal Planning — ⚠️ INCOMPLETE
Meal plan generation works. User interactions broken.

**After 3b.2 + 3b.3 complete, Phase 8 is DONE.**

**Remaining beyond 3b:**
- Nutrition profiles (cardiovascular + hormonal) feeding AI generation
- Weekly meal prep / batch cook planner
- Macro cycling (training day vs rest day targets)
- End-of-day variance summary (planned vs actually eaten)
- Weekly nutrition summary

---

## Phase 9: AI Daily Coach — 🔴 NOT STARTED
**Prerequisite:** Phase 3 (real health data) + Phase 3b.7 (prescription engine on real data) must complete first.

**Delivers:**
- Morning check-in screen (feeling, sleep auto-fill, morning erection Y/N, injuries, schedule)
- Weekly check-in (Sunday): erection quality 1–10 — private, encrypted
- Today's Plan screen: workout card + meals card + steps ring + focus tip + bedtime
- Scenario handling: tired, sore, unwell, busy, behind on steps
- Workout modification logic for injuries
- Bedtime reminder calculation
- Adaptive intelligence (learns patterns over time)

⚠️ Keep prescription logic rule-based (if/else). AI only narrates. Morning check-in < 30 seconds.

---

## Phase 10: Performance Intelligence Engine — ⚠️ BLOCKED
Insights dashboard and recovery score entity exist. Blocked until Phase 3 delivers real data.

**After Phase 3 + 3b complete, build in this order:**
1. Recovery score on real data (3b.7 does this)
2. Training load model (`Load = Duration × Intensity Factor`)
3. Baseline calibration mode (14-day counter, "Collecting your baseline...")
4. Deterministic SQL insights (sleep/VO₂/stress/load trends — no AI)
5. AI narrative layer last — explains the math, never replaces it

---

## Phase 11: Garmin + Strava Direct Integration — 🔴 NOT STARTED
Garmin data already flows via Health Connect (Garmin Connect app → HC → WellTrack).
This phase adds direct server-to-server webhook integration for users without Garmin Connect.

**Delivers:**
- Garmin OAuth 2.0 PKCE connect/disconnect
- Strava OAuth connect/disconnect
- Supabase Edge Function webhook receivers with HMAC validation
- Backfill job (last 14 days on first connect)
- Stress score + VO₂ max + body battery flowing directly
- Garmin brand attribution (required for Garmin review approval)

**You'll need:** Garmin Developer account (developer.garmin.com), Strava Developer account

---

## Phase 12: Supplements + Habits + Bloodwork — ⚠️ PARTIAL
Supplements screen built. Reminders not linked (fixed in 3b.1).

**Remaining:**
- Habit streak tracker (porn-free, kegels, sleep target, steps target, custom)
- Streak milestones: 7 / 30 / 90 / 180 days with celebrations
- Kegel protocol pre-loaded (Quick Flicks, Long Holds, Reverse Kegels)
- Bloodwork log: input lab results, reference ranges, out-of-range flags, trend charts
- Pre-loaded test types: testosterone, SHBG, oestradiol, glucose, HbA1c, cholesterol, TSH, Vit D, BP
- AI interpretation of bloodwork (suggestive only)
- Daily View single-day checklist across all modules

---

## Phase 13: Notifications — ⚠️ PARTIALLY BROKEN → fixed in Phase 3b.1
After 3b.1, remaining notification work:

**Remaining beyond 3b.1:**
- AM kegel reminder (default 7:30 AM)
- PM kegel reminder (default 9 PM)
- Wind-down reminder (default 10 PM)
- Bedtime reminder (calculated from wake time + 7hr target)
- Step nudge (afternoon if below daily target)
- Sunday weekly report notification
- Milestone celebrations (PRs, streaks, goal milestones)
- Workout reminder (30 min before planned session)
- All notifications deep link to relevant screen

---

## Phase 14: Recipe URL Import — ✅ DONE
URL import and OCR import screens built and functional.

---

## Phase 15: Freemium + Paywall — ⚠️ PARTIAL
Paywall screen scaffold and feature flags exist. Gate enforcement not active.

**Remaining:**
- In-app purchase integration (Google Play Billing)
- AI quota tracking display in settings
- Enforce feature gates properly:

| Feature | Free | Premium |
|---------|------|---------|
| Health Connect sync | ✅ | ✅ |
| Basic logging (meals, workouts) | ✅ | ✅ |
| 7-day history | ✅ | ✅ |
| Recovery score | ❌ | ✅ |
| AI daily plan | ❌ | ✅ |
| VO₂ max forecasting | ❌ | ✅ |
| Meal plan generation | ❌ | ✅ |
| Unlimited history | ❌ | ✅ |
| Insights dashboard | ❌ | ✅ |
| Bloodwork AI interpretation | ❌ | ✅ |

---

## Phase 16: Polish + Launch — 🔴 NOT STARTED

**Delivers:**
- Dark / light theme
- Data export (CSV)
- Performance optimisation + battery testing
- Health Connect privacy policy (required for Play Store submission)
- Health permissions rationale screen (required by Google Play health data policy)
- Build AAB: `flutter build appbundle --release` (Play Store gets ~25MB, not 70MB APK)
- Play Store listing + screenshots
- Garmin production review submission (separate process — apply early)
- App Store submission if iOS build active

---

## Updated Effort Summary

| Phase | Scope | Est. Days | Status |
|-------|-------|-----------|--------|
| 0 | Architecture Lock | 2–3 | ✅ DONE |
| 1 | Schema + RLS | 2–3 | ✅ DONE (verify HC table) |
| 2 | Scaffold + Auth + Offline | 5–7 | ✅ DONE |
| 3 | Health Connect / HealthKit | 3–4 | ⚠️ 1–2 days remaining |
| **3b** | **Module Repair** | **10–15** | 🔴 NEW — must do first |
| 4 | AI Orchestrator | 5–7 | ✅ DONE (verify after 3b) |
| 5 | Workout Logger | 7–10 | ⚠️ fixed in 3b.4 |
| 6 | Goals + Projections | 4–5 | ⚠️ fixed in 3b.6 |
| 7 | Pantry → Recipes | 5–7 | ✅ DONE |
| 8 | AI Meal Planning | 6–8 | ⚠️ fixed in 3b.2 + 3b.3 |
| 9 | AI Daily Coach | 5–7 | 🔴 NOT STARTED |
| 10 | Performance Intelligence | 5–7 | ⚠️ BLOCKED → unblocked by 3b |
| 11 | Garmin + Strava Direct | 5–7 | 🔴 NOT STARTED |
| 12 | Supplements + Habits + Bloodwork | 5–6 | ⚠️ PARTIAL |
| 13 | Notifications (remaining) | 2–3 | ⚠️ core fixed in 3b.1 |
| 14 | Recipe URL Import | 3 | ✅ DONE |
| 15 | Freemium + Paywall | 3–4 | ⚠️ PARTIAL |
| 16 | Polish + Launch | 4–5 | 🔴 NOT STARTED |
| **Total remaining** | | **~55–75 days** | |

---

## Revised Milestone Checkpoints

| Milestone | Prerequisite | What It Proves |
|-----------|-------------|----------------|
| **Real data flowing** | Phase 3 complete | Health Connect → Supabase working |
| **App works properly** | Phase 3b complete | All existing features work end-to-end |
| **Intelligent planning** | Phase 9 complete | Morning check-in → personalised daily plan |
| **Full performance engine** | Phase 10 complete | Recovery score on real data, VO₂ trends |
| **Fully connected** | Phase 11 complete | Direct Garmin webhooks active |
| **Launch ready** | Phase 16 complete | Polished, monetised, store-ready |

---

## Key Principles (Unchanged)

1. **Math first, AI explains.** Forecasts are deterministic. AI narrates.
2. **Suggestive, not prescriptive.** "Consider this" not "Do this."
3. **No medical claims.** Ever.
4. **Gate intelligence, never gate logging.** Free users track everything. Pro unlocks intelligence.
5. **Fix before build.** No new features until existing ones work properly.
6. **Offline-first.** Queue writes, sync when connected.
7. **Baseline before optimization.** 14 days of data before features unlock.
8. **One phase at a time.** Never ask Claude Code to build everything at once.
9. **Domain isolation.** No domain directly queries another domain's tables.
10. **Dashboard stays calm.** Less is more.

---

## Builder Brief

> The codebase is further along than it appears but less complete than it looks. Every module exists. Most are partially wired. Fix the wiring before adding rooms. Start with Phase 3 (AndroidManifest — 30 minutes) then work through Phase 3b systematically. Once all existing features work on real data, resume the original build sequence from Phase 9. The performance intelligence engine is the product's moat — protect it.
