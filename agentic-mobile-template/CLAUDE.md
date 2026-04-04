# WellTrack — Claude Code Master Prompt (v4)

> You are a Principal Engineer + Product Architect working on an **existing, partially-built** Flutter app.
> Do NOT scaffold from scratch. The codebase already exists — read the existing files before making changes.
> Always check what's already built before writing new code.

---

## Product

**WellTrack** is a Performance & Recovery Optimization Engine for high-achieving professionals.
- Cross-platform: Flutter (Android + iOS) + Supabase backend
- Data aggregator: Health Connect (Android) → HealthKit (iOS) → WellTrack → Supabase
- AI philosophy: **Math generates the plan. AI explains it.** Never reverse this.
- Positioning: Strictly wellness — zero medical claims, ever.
- AI plans are always SUGGESTIVE ("consider this"), never PRESCRIPTIVE ("do this")

---

## Non-Negotiables

- Flutter app accepted by Google Play and Apple App Store
- Health Connect (Android) + HealthKit (iOS) — native integrations, already coded in `health_service.dart`
- Offline-first: full logging works offline, sync later with conflict resolution (Hive + WorkManager)
- AI is server-side only — never call Claude/OpenAI directly from the Flutter client
- Central AI orchestrator: `shared/core/ai/ai_orchestrator_service.dart` is the single entry point
- Freemium: gate optimization features, not basic logging
- Sensitive wellness data: RLS on all Supabase tables + encrypted local storage (flutter_secure_storage)
- Deduplication: all health metrics use `dedupe_hash` (SHA-256) to prevent duplicate inserts

---

## Current Tech Stack

```
Flutter (Dart) + Riverpod (state) + GoRouter (navigation)
Supabase (backend + auth + realtime)
Hive (offline local storage)
WorkManager (background sync)
Health package v13.3.0 (Health Connect + HealthKit)
Dio (networking)
FL Chart (charts)
Google MLKit (OCR)
```

---

## Architecture: Data Flow

```
Garmin Watch  ──┐
Wear OS Watch ──┼──→  Health Connect (Android)  ──→  health_service.dart  ──→  health_repository_impl.dart  ──→  Supabase
Android Phone ──┘      HealthKit (iOS)               (reads platform data)      (bulk upsert + dedup)           wt_health_metrics table

                                                                ↓
                                                    performance_engine.dart
                                                    (recovery score calculation)
                                                                ↓
                                                    prescription_engine.dart
                                                    (tomorrow's plan — math-based)
                                                                ↓
                                                    ai_orchestrator_service.dart
                                                    (AI narrates the WHY)
                                                                ↓
                                                    daily_coach screens
                                                    (user sees plan)
```

---

## Codebase Structure (already built)

```
lib/
├── main.dart
├── app.dart
├── features/
│   ├── auth/              ✅ Complete — login, signup, Supabase auth
│   ├── health/            ⚠️  Built but Health Connect NOT wired (AndroidManifest missing)
│   ├── daily_coach/       ⚠️  Built but running on stub/mock data
│   ├── dashboard/         ⚠️  Built but widgets show placeholder data
│   ├── insights/          ⚠️  Built but not connected to real health data
│   ├── workouts/          ⚠️  Partially complete — live session needs finishing
│   ├── meals/             ⚠️  Generates meals but user interaction broken
│   ├── goals/             ⚠️  Goal projection chart not connected to real data
│   ├── recipes/           ⚠️  URL import + OCR exists, needs end-to-end test
│   ├── shopping/          ⚠️  List generation broken — no real ingredient data
│   ├── reminders/         🔴  Reminders created but notifications never fire
│   ├── supplements/       ⚠️  Basic log works, reminders not linked
│   ├── pantry/            ⚠️  Exists but not cross-referenced with shopping
│   ├── freemium/          ⚠️  Gate logic exists but not enforced properly
│   ├── profile/           ✅  Onboarding flow built
│   └── settings/          ✅  Health settings screen built
└── shared/core/
    ├── ai/                ✅  Orchestrator built — verify it calls Supabase Edge Functions, not client-side
    ├── health/            ⚠️  health_service.dart complete — needs AndroidManifest wiring
    ├── sync/              ⚠️  Conflict resolver + sync engine built — needs WorkManager registration
    └── router/            ✅  GoRouter with route guards
```

---

## Immediate Priorities (Phase 1 — Foundation)

These MUST be done before anything else. Nothing can be tested on real data until these are complete.

### 1.1 — AndroidManifest.xml (CRITICAL — 30 mins)
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

Add inside `<activity>` tag (Health Connect availability intent):
```xml
<intent-filter>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
</intent-filter>
<meta-data
    android:name="health_permissions"
    android:resource="@array/health_permissions" />
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

### 1.2 — Register Background Sync with WorkManager
File: `lib/main.dart` + `lib/features/health/data/health_background_sync.dart`

- Register WorkManager callback in `main()` before `runApp()`
- Background task must call `HealthService.syncHealthData()` then `HealthRepositoryImpl.saveHealthMetrics()`
- Sync interval: 15 minutes minimum (WorkManager constraint)
- Test: close app → wait → reopen → Supabase `wt_health_metrics` table should have new rows

### 1.3 — Verify Supabase Schema
Confirm these tables exist with correct columns and RLS enabled:
- `wt_health_metrics` — with `dedupe_hash` UNIQUE constraint
- `wt_profiles`
- `wt_workouts` + `wt_workout_logs`
- `wt_meals` + `wt_meal_plans`
- `wt_goals`
- `wt_reminders`

### 1.4 — Fix Notification Service
File: `lib/features/reminders/data/notification_service.dart`

The reminder creation works but `flutter_local_notifications` is not scheduling the actual device notification.
- Ensure `flutter_local_notifications` is initialised in `main.dart`
- Request notification permission on Android 13+ (`POST_NOTIFICATIONS`)
- Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
- Ensure reminders reschedule on device reboot via `RECEIVE_BOOT_COMPLETED` receiver

---

## Phase 2 — Rules Engine

File: `lib/features/insights/data/performance_engine.dart`
File: `lib/features/daily_coach/data/prescription_engine.dart`

### Recovery Score (0–100)
Calculate daily from real Supabase data — never mock data:

```
recovery_score = (
  sleep_score * 0.30 +      // actual sleep vs 7.5hr target
  sleep_quality * 0.20 +    // (REM + deep) % of total — target 40%+
  hr_score * 0.25 +          // resting HR vs personal 14-day baseline
  load_score * 0.25          // 7-day training load (high load = lower score)
)
```

### Tomorrow's Plan (prescription_engine.dart)
Use recovery score to determine plan — no AI guesswork, pure logic:

| Score | Plan Type | Workout | Calories |
|-------|-----------|---------|----------|
| 80–100 | Push day | Progressive overload | Full target |
| 60–79 | Normal day | Standard plan | Maintenance |
| 40–59 | Easy day | Light / active recovery | -10% |
| 0–39 | Rest day | Mobility / walk only | Sleep-focused macros |

AI layer (`ai_orchestrator_service.dart`) then generates the narrative explaining WHY — not what to do.

---

## Phase 3 — Module Completion

Complete each module to the spec below. All modules must use real Supabase data — no stubs.

### Meals Module (52 features — see full spec)

**Critical gap — Food Database API:**
Integrate Open Food Facts (free) as primary food database.
API endpoint: `https://world.openfoodfacts.org/cgi/search.pl`
- Search by keyword → return name, calories, macros, photo
- Search by barcode → `https://world.openfoodfacts.org/api/v0/product/{barcode}.json`
- Cache results in Hive locally to reduce API calls
- UK foods fallback: Open Food Facts has strong UK supermarket coverage

**Meal plan interactions required:**
- Mark meal as eaten (one tap)
- Mark eaten with portion adjustment
- Log food not in plan (search food database)
- Swap meal — show 3 macro-matched alternatives, user selects one
- Regenerate single meal slot
- Delete and regenerate entire plan
- Calorie target auto-adjusts from recovery score daily
- Macro progress bar updates in real time

**Shopping list:**
- Auto-generate from meal plan with quantities aggregated
- Cross-reference with pantry (pantry_repository.dart) — only list missing items
- Items grouped by category (produce, dairy, meat, frozen)
- Tick off items while shopping

### Workouts Module

**Live session (workout_logging_screen.dart):**
- Set logging: reps, weight, RPE (rate of perceived exertion)
- Rest timer fires automatically after each set (uses rest_timer_provider.dart)
- 1RM auto-calculated from logged sets (Epley formula: weight × (1 + reps/30))
- Overload detection: flag when user should increase weight (overload_detection_service.dart)
- Session summary screen shows volume, PRs, and AI recommendation for next session

**Plan management:**
- Users can create custom plans or use AI-generated plans
- Exercise browser with search + muscle group filter (body_map_screen.dart)
- Progressive overload suggestions surfaced proactively

### Goals Module

File: `lib/features/goals/presentation/widgets/goal_projection_chart.dart`

- Connect projection chart to real metric data from `wt_health_metrics`
- VO₂ max trend line based on actual logged workouts + Health Connect data
- Weight goal projection based on calorie deficit/surplus trend
- Milestone notifications when user hits intermediate targets

### Reminders Module

- Reminders created in UI must fire as device notifications (fix per Phase 1.4)
- Reminders link to relevant module (meal reminder → opens meal log, workout reminder → opens session)
- Smart timing: suggest optimal reminder times based on user's historical patterns

### Insights Module

File: `lib/features/insights/presentation/insights_dashboard_screen.dart`

- Recovery score card shows today's score + 7-day trend
- Training load chart (acute vs chronic load ratio)
- VO₂ max trend — primary performance metric
- Sleep quality trend
- All charts pull from `wt_health_metrics` — no mock data

---

## Phase 4 — Garmin Webhooks (Server-Side)

Garmin data flows through Health Connect automatically on Android (Garmin Connect app → Health Connect → WellTrack).
This is sufficient for MVP.

Server-side Garmin webhooks are Phase 4 for users who want direct integration:

**Supabase Edge Function: `garmin-webhook`**
- Receives POST from Garmin Health API (server-to-server)
- Validates HMAC signature
- Maps Garmin fields to `wt_health_metrics` schema
- Upserts with `dedupe_hash` conflict handling
- Priority metrics: stress score, VO₂ max estimate, body battery, sleep stages

**Required Garmin API scopes:**
- `ACTIVITY_IMPORT` — workout data
- `DAILY` — steps, calories, stress, sleep
- `HEALTH_SNAPSHOT` — HRV, SpO2

---

## Phase 5 — Play Store Submission

- Build AAB (not APK): `flutter build appbundle --release`
- Health Connect requires Privacy Policy URL — must be live before submission
- Add Health Permissions rationale screen (required by Google Play health data policy)
- Freemium paywall must be active
- Target SDK: Android 14 (API 34) minimum for Health Connect v2

---

## AI Rules

- AI calls go through `ai_orchestrator_service.dart` — never direct from screens
- Math calculates first, AI explains second — never reverse
- All AI responses are labelled as suggestions in the UI
- AI never gives specific calorie targets without the math engine running first
- Rate limit: freemium users get 3 AI explanations/day; premium unlimited

---

## Freemium Gates

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

---

## Code Standards

- All new code uses Riverpod providers — no setState()
- Freezed for all entities and state classes
- Repository pattern: data layer never imported directly by presentation layer
- All Supabase calls go through repository classes — never direct from providers
- Offline-first: write to Hive first, sync to Supabase via sync_engine.dart
- Error handling: all async operations wrapped in try/catch with AppLogger
- No hardcoded strings — use constants from `shared/core/constants/`

---

## How to Work With This Codebase

1. Before writing any code — read the existing file first
2. Extend existing classes — do not create duplicate files
3. If a screen exists, fix it — do not create a new screen
4. Run `flutter analyze` after every set of changes
5. Test on real Android device — emulator does not support Health Connect
6. When in doubt about what's already built — ask before creating
