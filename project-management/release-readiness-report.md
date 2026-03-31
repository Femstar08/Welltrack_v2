# WellTrack — Release Readiness Report
**Date**: 2026-03-29
**Prepared by**: Project Manager
**Branch reviewed**: `ralph/phase-11-to-15-autonomous`
**Report scope**: Google Play Store submission readiness

---

## Executive Summary

WellTrack has made substantial progress through Phases 11–14 in an autonomous agent run completed on 2026-03-28/29. The core feature set is implemented. However, the project is **NOT ready for Play Store submission** as of today. There are confirmed compile errors in `flutter analyze`, a release signing configuration that falls back to debug keys, missing production assets, and a full regression test cycle that has not been executed on device. An estimated 5–10 days of focused work remains before submission is viable.

---

## 1. Release Readiness Assessment

### Story Completion (prd.json — Phases 11–15)

All 35 user stories in the current active PRD (`scripts/ralph/prd.json`) are marked `passes: true`. This covers:

- Phase 11 (P11-001 through P11-008): Garmin/Strava OAuth, webhooks, deep links, manual sync — COMPLETE
- Phase 12 (P12-001 through P12-007): Habits, bloodwork, kegel timer, RLS verification — COMPLETE
- Phase 14 (P14-001 through P14-014): Meals v5 dashboard widgets, enhanced FAB, nutrition screens, water/weight logging — COMPLETE
- Phase 15 (P15-001 through P15-006): Health permissions rationale, freemium gates, debug prints, analyze fixes, manifest verification, offline/notification verification — COMPLETE per ralph's log

However, a **separate Phase 15 PRD file** exists at `PRPs/phase-15-play-store-prd.json` with 11 stories all marked `passes: false`. This is the definitive Play Store checklist and it has NOT been executed.

### Flutter Analyze Status: FAILING

The `flutter_analyze.txt` file (captured from a recent run) shows **2 errors**:

| Severity | File | Issue |
|----------|------|-------|
| ERROR | `lib/features/dashboard/presentation/dashboard_screen.dart:301` | `surfaceContainerLowest` getter not defined on `AppColors` |
| ERROR | `lib/features/meals/presentation_v2/theme/obsidian_vitality_theme.dart:40` | `CardTheme` cannot be assigned to parameter type `CardThemeData?` |
| ERROR | `lib/shared/core/theme/app_theme.dart:110` | Invalid constant value |
| WARNING | `dashboard_screen.dart:6` | Unused import `go_router.dart` |
| INFO (x4) | Various | `withOpacity` deprecated (use `.withValues()`), `background` deprecated, `prefer_const_constructors` |

The `P15-004` story in ralph's active PRD was marked `passes: true` (0 errors, 0 warnings), but this contradicts the `flutter_analyze.txt` snapshot in the repository. The snapshot may predate the fix — this needs reconfirmation by running analyze fresh.

**Action required**: Run `flutter analyze` again and confirm actual current state before any submission build.

---

## 2. Technical Debt Inventory

### Hard Blockers (must fix before Play Store)

| # | Item | Location | Risk |
|---|------|----------|------|
| TD-001 | Release signing uses debug keys | `android/app/build.gradle.kts` line 37: `signingConfig = signingConfigs.getByName("debug")` | AAB will be rejected by Play Store or will generate an unsigned/debug-signed bundle |
| TD-002 | No `key.properties` file exists | `android/` directory | No keystore provisioned — no signing keys generated |
| TD-003 | `targetSdk` delegates to `flutter.targetSdkVersion` | `build.gradle.kts` line 29 | Play Store requires targetSdk >= 34 — must verify this resolves correctly or pin it explicitly |
| TD-004 | `applicationId = "com.welltrack.welltrack"` | `build.gradle.kts` | Generic ID — confirm this is the intended Play Store package name. It cannot be changed after first upload |
| TD-005 | No privacy policy URL | Play Store requirement | Health Connect apps require a live privacy policy URL before submission. Currently nothing exists |
| TD-006 | No app icon (adaptive) | `android/app/src/main/res/` | Only default Flutter launcher icons present (no branded adaptive icon with foreground/background layers) |
| TD-007 | Assets folder is empty except one sound | `assets/images/.gitkeep`, `assets/fonts/.gitkeep` | No branded images, no custom fonts loaded |
| TD-008 | `onboarding_flow_screen.dart` debug prints | Known from MEMORY.md | Acknowledged but unverified as fully removed |

### Moderate Debt (affects quality but not necessarily submission)

| # | Item | Notes |
|---|------|-------|
| TD-009 | `presentation_v2/` parallel meals implementation | `lib/features/meals/presentation_v2/` contains `dashboard_v2_screen.dart`, `obsidian_vitality_theme.dart`, and `enhanced_log_bottom_sheet_v2.dart` — these have compile warnings/errors and appear to be abandoned prototype files. They should be deleted or resolved. |
| TD-010 | `old_dashboard.dart` in root | Root-level file that should not exist in production codebase |
| TD-011 | Race condition on onboarding flash | MEMORY.md documents this: `onboardingCompleteProvider` defaults false before async load, causing brief `/onboarding` flash on cold start |
| TD-012 | Shopping module not integrated with pantry | CLAUDE.md: shopping list generation broken, no real ingredient data |
| TD-013 | Reminders not verified end-to-end on device | WorkManager and notifications are initialized, but actual scheduling and delivery on device has not been confirmed by a human |
| TD-014 | Voice Log and Meal Scan are MVP stubs | Both screens show "Coming Soon" for AI interpretation — acceptable for MVP but should be clearly communicated in Play Store listing |
| TD-015 | Water logging uses raw string `'water'` not MetricType enum | Could cause query breakage if enum is ever used for this lookup elsewhere |
| TD-016 | `FreemiumGate` internal `Navigator.push` fixed, but third-party calls not audited | Some gate calls may still bypass GoRouter |

### Known Issues from MEMORY.md (pre-existing)

- Debug print statements in `onboarding_flow_screen.dart` — listed as still present as of last memory update
- USB connection drops frequently to Samsung device — will complicate on-device testing
- Race condition: brief `/onboarding` flash on cold start

---

## 3. Code Quality Assessment

### Strengths

- Architecture is well-structured: repository pattern enforced, Riverpod providers throughout, GoRouter for all navigation
- Domain entities use Freezed consistently
- AI calls centralized through `ai_orchestrator_service.dart` — the "math first, AI explains" principle is architecturally enforced
- Supabase RLS policies verified across all sensitive tables
- `dedupe_hash` pattern applied consistently to health metrics to prevent duplicates
- The performance engine (recovery scoring, prescription engine) is deterministic and fully unit-tested

### Concerns

- The `presentation_v2/` directory creates ambiguity. These files contain compile errors (`CardTheme` vs `CardThemeData`) and deprecated APIs. Their presence alongside `presentation/` is confusing for future developers.
- `dashboard_screen.dart` references `AppColors.surfaceContainerLowest` which does not exist — this is an active compile error, not just a warning.
- `app_theme.dart` has an invalid constant value error.
- No integration tests exist. All tests are unit tests targeting pure logic (engines, entities, normalizers). There are no widget tests beyond the trivial smoke test, and no integration test suite.

### Naming and Organization

- Feature folder structure is consistent (`data/`, `domain/`, `presentation/`)
- Provider naming (`xxxProvider`, `xxxNotifier`) follows conventions
- Some inconsistency: `today_nutrition_provider.dart` is in `meals/presentation/` but provides exercise/steps data that logically belongs in `health/` — minor but worth noting

---

## 4. Test Coverage

### What Exists

| Suite | Tests | Status |
|-------|-------|--------|
| `prescription_engine_test.dart` | 60 tests | Passing (from test_results.json) |
| `performance_engine_test.dart` | Multiple | Passing |
| `recovery_score_entity_test.dart` | Multiple | Passing |
| `health_metric_entity_test.dart` | Multiple | Passing |
| `health_normalizer_test.dart` | Multiple | Passing |
| `health_validator_test.dart` | Multiple | Passing |
| `goal_entity_test.dart` | Multiple | Passing |
| `forecast_entity_test.dart` | Multiple | Passing |
| `module_metadata_test.dart` | Multiple | Passing |
| `widget_test.dart` | 1 smoke test | Status unknown (references `Initializing WellTrack...` text) |

**test_results.txt confirms**: "Some tests failed" — 4 test failures were present in the last recorded run. The nature of those failures is not immediately clear from the log format, but this must be resolved before submission.

### What is Missing (High Priority)

- No integration tests for auth flows (signup, login, onboarding)
- No widget tests for any feature screen
- No tests for repository layer (Supabase interactions are completely untested)
- No tests for GoRouter navigation guards
- No end-to-end tests for the Health Connect permission flow
- No tests for the freemium gate logic
- No tests for the notification service
- No tests for any of the Phase 14 new widgets (NutritionSummaryCarousel, WeightTrendChartWidget, etc.)

**Coverage estimate**: Approximately 15–20% of business logic is covered. Data layer and presentation layer are essentially untested.

---

## 5. Documentation Assessment

### Strengths

- `CLAUDE.md` is thorough and current (v4 as marked, content reflects Phase 10+ state)
- `scripts/ralph/progress.txt` is an excellent autonomous-agent log with learnings that serve as institutional memory
- PRPs directory provides detailed PRDs for each phase — good specification quality
- `MEMORY.md` captures cross-session context effectively

### Gaps

- No `README.md` for the project root (there may be one at the workspace level but none in `agentic-mobile-template/`)
- No onboarding guide for a new human developer (how to set up env, run locally, connect to Supabase, etc.)
- No API documentation for Supabase Edge Functions
- No changelog / release notes document
- `CLAUDE.md` describes the codebase status as of Phase 3 in its feature status table — this is outdated. Multiple features marked "Built but..." are now complete. Future developers reading CLAUDE.md will get a misleading picture of what's done.
- Architecture diagram exists in CLAUDE.md but does not reflect the current Garmin/Strava webhook pipeline

---

## 6. Dependencies Assessment

### pubspec.yaml Review

```
flutter_riverpod: ^2.4.0    — Current stable is 2.6.x. Consider upgrading.
supabase_flutter: ^2.3.0    — Current stable is 2.8.x. Minor versions may have bug fixes.
go_router: ^14.0.0          — Current stable is 14.x. OK.
health: ^13.3.0             — Current stable is 13.3.x. OK.
fl_chart: ^0.68.0           — Current is 0.70.x. Consider upgrading.
mobile_scanner: ^6.0.0      — Version 6 is current. OK.
flutter_local_notifications: ^17.2.0 — Current is 18.x. Potential breaking change.
google_mlkit_text_recognition: ^0.13.0 — OK.
workmanager: ^0.9.0         — OK.
```

### Concerns

- No version pinning anywhere — all `^` (caret) constraints. For a production app, minor version bumps can introduce breaking changes in Flutter plugins. Consider pinning critical packages for the release build.
- `mockito: ^5.4.0` is in dev_dependencies but is largely unused (only `Fake` subclasses in widget_test.dart, not `@GenerateMocks`). Mockito's code generation is not being used. Simplify or remove.
- `audioplayers: ^6.0.0` — only one sound file exists (`timer_done.mp3`). Confirm this is actually wired and needed; audio plugin adds APK size.
- `vibration: ^3.1.7` — verify this is used; haptics without a clear use case adds permission baggage.
- No `flutter_native_splash` despite Phase 15 PRD (US-008) requiring a splash screen configuration.

---

## 7. CI/CD Assessment

**There is no CI/CD pipeline.** The `.github/` directory does not exist. No GitHub Actions workflows are configured.

### Impact

- No automated test runs on push or PR
- No automated `flutter analyze` gate
- No build verification before merges
- The entire quality assurance burden falls on the autonomous agent's self-checks and manual verification

### Recommendation

Before Play Store submission, at minimum set up a GitHub Actions workflow that:
1. Runs `flutter analyze --fatal-warnings`
2. Runs `flutter test`
3. Optionally: runs `flutter build appbundle --release` (requires secrets for signing and .env)

This is a 2–4 hour setup effort with high ROI given the autonomous development model being used.

---

## 8. Play Store Risk Assessment

### Critical Risks (Submission Blockers)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Release signing not configured — debug key used | CONFIRMED | BLOCKER | Generate keystore, configure `key.properties`, update `build.gradle.kts` before building AAB |
| Privacy policy URL not live | CONFIRMED | BLOCKER | Health Connect apps require a live URL. Create static HTML page, host on GitHub Pages or similar |
| `flutter analyze` errors unresolved | PROBABLE | BLOCKER | Re-run analyze, fix `surfaceContainerLowest`, `CardTheme`, and invalid constant errors before build |
| Test failures in last run | CONFIRMED | HIGH | Identify the 4 failing tests, fix them before submission |
| Adaptive app icon missing | CONFIRMED | BLOCKER | Google Play requires adaptive icons. Current icons are default Flutter assets |
| `targetSdk` not explicitly set to 34+ | UNKNOWN | BLOCKER | `flutter.targetSdkVersion` may resolve below 34. Verify or pin explicitly |

### High Risks (May Cause Rejection or Poor UX)

| Risk | Notes |
|------|-------|
| Health Connect policy compliance | Google scrutinizes health apps heavily. The health permissions rationale screen was built (P15-001), but it needs to be verified it is shown BEFORE the system permission dialog in all paths (onboarding AND settings re-authorization) |
| No regression test on real device | USB drops frequently. An untested release on a production device is high risk. The full regression checklist in `phase-15-play-store-prd.json` US-011 has not been executed |
| BootReceiver in manifest not fully tested | `BootReceiver.kt` exists but notification rescheduling on boot has not been verified on device |
| `HealthConnectPermissionsRationaleActivity.kt` — native Android activity | This requires the Activity to be functional in Kotlin. It is declared in the manifest but its implementation needs device verification |
| Onboarding flash race condition | Brief `/onboarding` screen flash on cold start is a UX defect that could result in a negative review |
| Shopping list non-functional | If a user navigates to shopping list, it is broken. This should either be removed from navigation or have a clear "Coming Soon" state |

### Lower Risks (Post-Launch)

| Risk | Notes |
|------|-------|
| Garmin/Strava OAuth token storage | Tokens stored encrypted in `wt_health_connections` — Supabase RLS protects server side. Local client security relies on `flutter_secure_storage`. Verify encrypted storage is used for any locally cached tokens. |
| AI rate limiting for free users | 3 AI calls/day for free users — enforcement is server-side in Edge Functions. Verify this is actually enforced, not just documented. |
| `presentation_v2/` orphaned files | These files contribute compile errors. Until deleted, they are a liability. |
| Supabase project name mismatch | Supabase project is named "DocuMindL" — this is a different project's name. Confirm the correct project is wired for production. |

---

## 9. Open Items Before Play Store Submission

The following is a prioritized list of work remaining, ordered by criticality.

### Phase A — Hard Blockers (must complete in sequence)

| ID | Task | Effort | Owner |
|----|------|--------|-------|
| OI-001 | Generate release keystore and configure `key.properties` + `build.gradle.kts` signing block | 1–2 hrs | Developer |
| OI-002 | Run `flutter analyze` fresh, fix all errors (surfaceContainerLowest, CardTheme, invalid const, app_theme.dart) | 2–4 hrs | Developer |
| OI-003 | Identify and fix 4 failing unit tests from last test run | 1–2 hrs | Developer |
| OI-004 | Delete or fix `lib/features/meals/presentation_v2/` (orphaned prototype files with compile errors) | 30 mins | Developer |
| OI-005 | Create and host privacy policy page covering health data, AI, Garmin/Strava | 2–4 hrs | Developer/PM |
| OI-006 | Design and implement adaptive app icon for all Android densities | 2–4 hrs | Designer/Developer |
| OI-007 | Pin `targetSdk = 34` explicitly in `build.gradle.kts` | 15 mins | Developer |
| OI-008 | Execute `flutter build appbundle --release --dart-define-from-file=.env` and verify AAB generates without errors | 1 hr | Developer |

### Phase B — Quality Gates (complete before submission)

| ID | Task | Effort |
|----|------|--------|
| OI-009 | Execute full regression checklist (US-011 from phase-15-play-store-prd.json) on Samsung SM S906B | 4–6 hrs |
| OI-010 | Verify Health Connect permissions rationale screen shown BEFORE system dialog in both onboarding and settings paths | 1 hr |
| OI-011 | Verify notification scheduling end-to-end on device (create reminder, wait, verify it fires) | 1 hr |
| OI-012 | Verify BootReceiver reschedules notifications after device reboot | 30 mins |
| OI-013 | Fix onboarding flash race condition (brief /onboarding screen on cold start) | 1–2 hrs |
| OI-014 | Either fix shopping list or add clear "Coming Soon" state to prevent broken user experience | 1 hr |
| OI-015 | Update `CLAUDE.md` feature status table to reflect current implemented state | 1 hr |

### Phase C — Play Store Listing Assets (required for submission)

| ID | Task | Effort |
|----|------|--------|
| OI-016 | Create feature graphic (1024x500) for Play Store listing | 2 hrs |
| OI-017 | Capture phone screenshots (minimum 2, ideally 5–8) from real device | 1 hr |
| OI-018 | Write short description (80 chars), full description (4000 chars max), category selection | 2 hrs |
| OI-019 | Add privacy policy link to in-app Settings screen | 30 mins |

### Phase D — Nice to Have Before Launch

| ID | Task | Effort |
|----|------|--------|
| OI-020 | Set up GitHub Actions CI (flutter analyze + flutter test on PR) | 3–4 hrs |
| OI-021 | Upgrade `flutter_riverpod` to ^2.6.x, `supabase_flutter` to ^2.8.x | 2–4 hrs (test for regressions) |
| OI-022 | Add `flutter_native_splash` splash screen configuration | 1–2 hrs |
| OI-023 | Resolve `withOpacity` deprecation warnings across codebase (use `.withValues()`) | 1 hr |
| OI-024 | Create README.md with local dev setup instructions | 2 hrs |

---

## 10. Recommended Next Steps

**Immediate (this week):**

1. Assign OI-001 through OI-008 to a developer. These are the hard gates. Until signing is configured and `flutter analyze` is clean, no AAB can be built for submission.
2. Begin OI-005 (privacy policy) in parallel — this does not require a developer and can be written by the PM or product owner.
3. Begin OI-006 (app icon) in parallel — this is a design task that can run concurrently.

**Following week:**

4. Complete OI-009 (device regression) once blockers are cleared. Block 4–6 hours on the Samsung device.
5. Execute OI-010 through OI-014 (quality verification items).
6. Complete OI-016 through OI-019 (listing assets) for Play Store console entry.

**Before first build submission:**

7. Final `flutter analyze` must return 0 errors, 0 warnings.
8. `flutter test` must return 0 failures.
9. AAB generated with release signing config.
10. Privacy policy URL must be live and reachable.

**Estimated time to Play Store submission readiness**: 8–14 working days at normal velocity (faster if developer focus is dedicated to this).

---

## Appendix A: Files Reviewed

- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/CLAUDE.md`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/pubspec.yaml`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/scripts/ralph/prd.json`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/scripts/ralph/progress.txt`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/PRPs/phase-15-play-store-prd.json`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/PRPs/MEALS-V5-MASTER-PLAN.md`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/flutter_analyze.txt`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/test_results.txt` (partial)
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/android/app/src/main/AndroidManifest.xml`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/android/app/build.gradle.kts`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/android/app/src/main/res/values/health_permissions.xml`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/test/widget_test.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/test/unit/daily_coach/prescription_engine_test.dart`
- All files in `lib/features/` (glob scan)
- All files in `test/` directory
- `assets/` directory structure
