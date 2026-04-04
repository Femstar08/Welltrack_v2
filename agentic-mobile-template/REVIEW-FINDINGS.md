# WellTrack App — Comprehensive Review Findings

**Date:** 2026-03-12
**Branch:** ralph/phase-12-habits-bloodwork
**Reviewed by:** Claude Code (5 parallel agents)

---

## Overall Scores

| Area | Score | Verdict |
|------|-------|---------|
| Navigation & Routing | **8.5/10** | Strong — 67 routes, clean GoRouter, no violations |
| UI/UX Quality | **7.2/10** | Good fundamentals, accessibility gaps |
| State Management | **6.5/10** | Sound structure, critical invalidation gaps |
| Feature Completeness | **65%** | Architecture complete, wiring incomplete |
| Code Quality | **7.5/10** | Clean patterns, specific performance issues |

---

## 1. CRITICAL Issues (Must Fix)

### 1.1 Release build signed with debug keys
- **File:** `android/app/build.gradle.kts:36`
- Uses `signingConfigs.getByName("debug")` for release
- Google Play will reject. Create a production keystore.

### 1.2 Recovery score is a live stub
- **File:** `dashboard_provider.dart:81-102`
- `_loadRecoveryScore()` does `Future.delayed(500ms)` and nothing else
- `PerformanceEngine` already computes this — just needs wiring

### 1.3 Notifications never fire
- `NotificationService.initialize()` never called in `main.dart`
- Channel not created, `tz.local` not set, no permission requested
- All reminders (bedtime, meals, kegels, supplements) silently broken

### 1.4 Meals core loop is broken
- Users can view AI-generated meal plans but cannot:
  - Mark meals as eaten (no UI button)
  - Adjust portions (field exists, no interaction)
  - See real-time macro progress (static values)
  - Auto-generate shopping lists (ingredient extraction broken)

### 1.5 Missing provider invalidation (stale state)
- Complete workout → `insightsProvider` not invalidated → stale recovery
- Submit check-in → recovery score not recalculated
- Log bloodwork → insights not updated
- Toggle habit → dashboard not refreshed

### 1.6 Missing back buttons on 6 pushed screens
- `/reminders`, `/supplements`, `/insights`, `/health/connections`, `/recovery-detail`, `/daily-view`
- All pushed via `context.push()` but have no AppBar back button

---

## 2. HIGH Priority Issues

### 2.1 Navigation
- Bottom nav tab state resets to Home after every push
- No web deep linking (only custom `welltrack://` scheme)

### 2.2 UI/UX
- **Accessibility**: Only 35 semantic labels in entire app
- **Error messages**: Raw exceptions shown to users
- **No confirmation dialogs** on destructive actions (delete goal, archive list)
- **Hardcoded spacing**: `SizedBox(height: 100)` scattered — no spacing constants
- **No tablet/landscape support**: Single-column layout everywhere

### 2.3 State Management
- **Race conditions**: AI calls have no debounce — double-tap fires two API calls
- `goalsProvider` wraps `AsyncValue` inside `StateNotifier` (wrong pattern)
- `liveSessionProvider` is global instead of `.family`
- Auth state changes don't cascade to `activeProfileProvider`
- Errors persist across operations (never cleared before new attempts)

### 2.4 Code Quality
- **N+1 query**: `OverloadDetectionService` makes 1 query per exercise
- **Sequential queries**: `MorningCheckInNotifier.submit()` makes 5 sequential calls that could use `Future.wait`
- **Bedtime bug**: `wakeHour=7` calculates bedtime as 9 PM instead of 11 PM
- Direct `Supabase.instance.client` access in `bloodwork_provider.dart` bypasses repository
- `Hive.openBox('settings')` called twice on startup

### 2.5 Feature Gaps
- Goal projections show mock data, not real metrics
- Workout live session: rest timer doesn't auto-start, 1RM not displayed
- Freemium gates exist but aren't enforced
- Dark mode theme defined but no toggle
- Data export not implemented
- Garmin/Strava OAuth deep links declared but flows not coded

---

## 3. MEDIUM Priority Improvements

| Category | Improvement |
|----------|-------------|
| UX | Add skeleton/shimmer loading to list screens |
| UX | Add celebration animations for milestones |
| UX | Dashboard customization (reorder/hide cards) |
| UX | Add "Skip" option to morning check-in steps |
| Performance | Push week-filter to DB in `_workoutStatsProvider` |
| Performance | Cache profile data in `MealPlanNotifier` |
| Performance | Remove double `setState` in bottom nav |
| Code | Extract `_extractJsonFromMessage` to shared parser |
| Code | Pin `targetSdk = 36` explicitly |
| Security | Fix notification ID collision (hashCode & 0x7FFFFFFF) |
| Testing | Zero repository tests, widget tests, navigation tests |

---

## 4. Phase Readiness

| Phase | Status | Blockers |
|-------|--------|----------|
| Phase 3 (Health) | 90% | HC permissions not requested in UI |
| Phase 3b (Meals) | 10% | Core interaction loop broken |
| Phase 5 (Workouts) | 80% | Rest timer, 1RM, PR overlay |
| Phase 6 (Goals) | 70% | Chart not wired to real data |
| Phase 9 (Daily Coach) | 95% | Minor AI consent handling |
| Phase 10 (Performance) | 85% | Dashboard gaps |
| Phase 11 (Garmin/Strava) | 0% | Not started |
| Phase 12 (Habits) | 100% | Done |
| Phase 13 (Notifications) | 10% | Infrastructure broken |
| Phase 15 (Freemium) | 50% | Billing not integrated |

---

## 5. Action Plan (Phase 13: UX Refinement)

### Week 1: Critical Fixes (US-001 through US-005)
1. Initialize NotificationService in main.dart
2. Wire dashboard recovery score to PerformanceEngine
3. Add back buttons to all pushed screens
4. Add provider invalidation after mutations
5. Fix bedtime calculation off-by-one

### Week 2: Quality & Performance (US-006 through US-011)
6. Add debounce to AI calls
7. Convert sequential queries to Future.wait
8. Move Supabase calls from providers to repositories
9. Add confirmation dialogs to destructive actions
10. Create error message mapping utility
11. Fix N+1 queries and push filters to DB

### Week 3: Accessibility (US-012)
12. Add semantic labels and tooltips to all icon buttons

---

## 6. Test Coverage Gaps

| Area | Coverage | Notes |
|------|----------|-------|
| PrescriptionEngine | Excellent | 50+ cases |
| PerformanceEngine | Excellent | All methods tested |
| GoalEntity / ForecastEntity | Good | Domain logic covered |
| RecoveryScoreEntity | Good | Edge cases present |
| Widget tests | Zero | Only default scaffold test |
| Repository layer | Zero | Critical gap |
| Provider/Notifier layer | Zero | No tests |
| Navigation (GoRouter) | Zero | Guards untested |
| OverloadDetectionService | Zero | Pure testable service |

---

## 7. Security Notes

- RLS active on all tables
- `is_sensitive = true` on bloodwork/checkin data
- `toAiContextJson(includeVitality: false)` correctly strips sensitive fields
- AI narrative instructions include medical claim prohibitions
- Consent check correct but bypasses repository pattern
- `reminder.id.hashCode` may produce negative notification IDs (silently dropped)
