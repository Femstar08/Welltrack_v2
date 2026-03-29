# WellTrack Comprehensive Review — 2026-03-29

## Review Agents
- Design/UX (Senior UI Designer)
- Security (Security Engineer)
- Business Analyst (Product Owner)
- Project Manager (Release Readiness)
- Solutions Architect (Architecture)

---

## Critical Blockers

### Security
| ID | Issue | Severity |
|----|-------|----------|
| S-C1 | Live secrets in `.env` — OpenAI key, Supabase service role key. Rotate immediately. | CRITICAL |
| S-C2 | Hardcoded Supabase URL + anon key as `defaultValue` in `api_constants.dart` | CRITICAL |
| S-C3 | Free users can self-upgrade to PRO — `wt_users` UPDATE RLS has no column restriction on `plan_tier` | CRITICAL |
| S-H1 | OAuth has no CSRF state parameter — callback accepts any code | HIGH |
| S-H3 | Garmin HMAC validation silently skipped when secret not set | HIGH |
| S-H4 | `userClient` in shared Edge Function client uses service role key instead of anon key | HIGH |

### Architecture
| ID | Issue | Severity |
|----|-------|----------|
| A-C1 | GoRouter has no `refreshListenable` — auth changes don't re-evaluate guards | CRITICAL |
| A-C2 | `ref.watch` inside async bodies in `today_nutrition_provider.dart` — stale data | CRITICAL |
| A-C3 | Offline sync not connected — SyncEngine exists but no repository writes to it | CRITICAL |

### Release Blockers
| ID | Issue | Severity |
|----|-------|----------|
| PM-1 | No release signing — debug keys in build.gradle.kts. No keystore. | BLOCKER |
| PM-2 | No privacy policy URL | BLOCKER |
| PM-3 | No adaptive app icon — Flutter placeholder | BLOCKER |
| PM-4 | Payment is a stub — AlertDialog not RevenueCat | BLOCKER |

---

## Product Gaps

| ID | Issue | Priority |
|----|-------|----------|
| BA-R01 | Reminders don't fire — scheduleNotification() never called | Must-have |
| BA-R02 | Meal logging computes no macros — TODO at line 82 | Must-have |
| BA-R05 | Recovery Score absent from dashboard — core differentiator invisible | Must-have |
| BA-R04 | No display name in onboarding — greets "Good morning, john.doe" | Must-have |
| BA-R06 | Height/weight decimal input broken — digitsOnly strips decimal | Must-have |
| BA-OB04 | Biological sex not collected — BMR off by 15-20% | Should-have |
| BA-FM | Free tier delivers nothing — macro tracking broken, recovery PRO-only | Must-have |

---

## Design/UX Issues

### P0 — Correctness & Accessibility
| ID | Issue | File |
|----|-------|------|
| D-P0-1 | Hardcoded top:60 instead of SafeArea | dashboard_screen.dart:71 |
| D-P0-2 | GestureDetector without ink/semantics on cards | dashboard_screen.dart:179,206 |
| D-P0-3 | fontSize:9 on goal status badge — below WCAG | dashboard_screen.dart:410 |
| D-P0-4 | Habit toggle 36dp — below 48dp minimum | habits_screen.dart:326 |
| D-P0-5 | FAB overlaps "Log" nav tab | scaffold_with_bottom_nav.dart |
| D-P0-6 | Weight log screen has direct Supabase call (architecture violation) | weight_log_screen.dart:44 |
| D-P0-7 | Macro rings have no Semantics labels | macro_rings_carousel_page.dart |

### P1 — Visual Consistency
| ID | Issue | File |
|----|-------|------|
| D-P1-1 | Mixed horizontal padding 16dp vs 24dp | dashboard_screen.dart |
| D-P1-2 | Light-mode pastel colors in dark theme cards | habit_streak_prompt_card.dart, overtraining_warning_card.dart |
| D-P1-3 | Recovery score card uses Colors.green not AppColors | recovery_score_dashboard_card.dart |
| D-P1-4 | Shimmer skeleton doesn't match dashboard layout | shimmer_loading.dart |
| D-P1-5 | BackdropFilter on scroll tiles — performance | steps_summary_tile.dart, exercise_summary_tile.dart |
| D-P1-6 | AppBar title 28sp instead of 22sp | app_theme.dart:173 |
| D-P1-7 | Carousel height inconsistent across states | nutrition_summary_carousel.dart |

### P2 — UX Refinement
| ID | Issue | File |
|----|-------|------|
| D-P2-1 | Bloodwork tabs isScrollable with only 4 tabs | bloodwork_screen.dart:101 |
| D-P2-2 | No nav bar top border/separator | app_theme.dart:238 |
| D-P2-3 | Locked vs coming-soon indistinguishable in FAB sheet | enhanced_log_bottom_sheet.dart |
| D-P2-4 | Weight log has no previous weight context | weight_log_screen.dart |
| D-P2-5 | Habit dot grid has no color legend | habits_screen.dart:507 |

---

## Architecture Debt

| ID | Issue | Impact |
|----|-------|--------|
| A-H1 | 15-20 Supabase queries on dashboard load — N+1 | HIGH |
| A-H2 | Two parallel health repositories with overlapping queries | HIGH |
| A-H3 | ~20 screens import data layer directly | HIGH |
| A-H4 | DashboardState.errorMessage populated but never rendered | HIGH |
| A-M1 | 880-line monolithic app_router.dart | MEDIUM |
| A-M2 | 10 providers defined inside widget files | MEDIUM |
| A-M3 | meal_plan_screen.dart is 2,053-line God Widget | MEDIUM |
| A-M4 | Supabase table names scattered as strings across 35 files | MEDIUM |

---

## Strengths to Preserve

1. Deterministic prescription engine — math first, AI explains
2. Bloodwork integration alongside fitness — unique in market
3. PKCE auth, server-side OAuth token exchange, AI consent gates
4. RLS on all tables, sensitive data filtering in AI context
5. Habit tracking tied to biometric outcomes
6. Pantry-aware meal planning
