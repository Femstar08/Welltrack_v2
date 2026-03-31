# WellTrack — Product Review
**Date:** 2026-03-29
**Reviewer:** Business Analyst / Product Owner
**Branch reviewed:** ralph/phase-11-to-15-autonomous
**Scope:** Product-market fit, feature completeness, user journey quality, monetisation

---

## Executive Summary

WellTrack has strong bones. The recovery-driven AI coaching philosophy is differentiated, the technical architecture is sound, and Phase 10 delivers a genuinely intelligent performance feedback loop. However, several critical user journeys break or dead-end before delivering value. The free tier provides almost nothing to retain a new user. The paywall is a stub. Retention mechanics (notifications, streaks) are built but not wired. The app is not yet ready for public launch in its current state — but the gap is closeable within 2–3 focused sprints.

---

## 1. User Onboarding Review

### What was found
The flow has 7 screens in this order:
1. Welcome (tagline + get started)
2. Goal selection (6 goals — grid layout)
3. Focus intensity (slider: Low / Moderate / High / Top Priority)
4. Quick profile (age, height, weight, activity level)
5. Connect devices (Health Connect, Garmin "Soon", Strava "Soon")
6. Focus introduction (sets up the "why")
7. Baseline summary (computed from inputs — 2s fake loading spinner)

### Strengths
- Screen count (7) is appropriate for a health app with complex personalisation
- Goal-first ordering is correct — users need to anchor their "why" before giving biometric data
- The "Garmin / Soon" label on connect devices is honest; it does not break the flow
- Baseline summary is a satisfying closure moment ("Your starting point")
- Back navigation is available from step 1 onward
- The data collected (goal, intensity, age, height, weight, activity level) is the minimum viable set needed for BMR and recovery baseline

### Issues Found

**Issue OB-01 — Missing name collection (Must-have)**
The welcome screen derives a display name from the email address prefix (e.g. `john.doe@gmail.com` becomes "john.doe"). This is poor UX. The Quick Profile screen collects biometrics but not the user's preferred name. First-time dashboard greeting says "Good morning, john.doe" — this immediately signals "this app does not know me."

**Issue OB-02 — Height and weight fields accept invalid values with no guard (Must-have)**
The `QuickProfileScreen` uses `FilteringTextInputFormatter.digitsOnly` which strips the decimal point, so a user entering `75.5 kg` will have the decimal silently stripped to `755`. The Continue button is also always enabled regardless of whether fields are filled, meaning a user can complete onboarding with no biometric data at all.

**Issue OB-03 — The baseline summary is cosmetic, not real (Should-have)**
The 2-second spinner labelled "Building your baseline..." is purely decorative. The `_computeBaseline()` method is hardcoded logic in the widget — it is not calling the performance engine or any real calculation. A user who selects "Performance" goal sees "VO2 Max" as their key metric but there is no VO2 max data yet. The screen creates a false expectation that WellTrack has already computed something meaningful.

**Issue OB-04 — Gender / biological sex not collected (Should-have)**
BMR calculations (Harris-Benedict and Mifflin-St Jeor) require biological sex. Without it, calorie and macro targets will be inaccurate by up to 15–20%. This field is currently absent from `OnboardingData`.

**Issue OB-05 — No value proposition moment before asking for Health Connect (Should-have)**
The Connect Devices screen appears at step 5 of 7, before users have seen any payoff from their data. Best practice is to show a compelling "here is what you will see" preview — a sample dashboard with their goal — immediately before asking for permissions. This is known as the "value before ask" pattern.

**Issue OB-06 — Vitality step (morning erection question) is in the daily check-in, not onboarding (Nice-to-have)**
This is a sensitive data point that appears without prior informed consent at the product level. The onboarding does not mention it. The first time a user sees it in their morning check-in they have no context. A single sentence in the FocusIntroduction screen explaining "we track some private health signals to detect patterns" would prepare them.

---

## 2. Core Value Proposition — Dashboard Clarity

### What was found
The dashboard (`DashboardScreen`) renders in this order:
1. Greeting with display name
2. Nutrition Summary Carousel (4 macro pages)
3. Steps + Exercise summary tiles
4. Weight trend chart
5. Bloodwork summary card
6. Habit streak prompt
7. Discover Quick Access grid
8. Daily Coach card
9. Scenario nudges
10. Goals summary
11. Workouts card
12. Pantry + Recipe card

### Issue DB-01 — Recovery score is not on the dashboard (Must-have)**
The app's positioning is "recovery-driven fitness optimisation." The Recovery Score card (`RecoveryScoreCard`) exists as a widget and is wired to real data (Phase 10). Yet it does not appear anywhere in the current `DashboardScreen` layout. A user opening the app sees nutrition macros at the top, not their recovery status. This directly contradicts the product's stated value proposition.

The Insights screen has the recovery score, but users are not prompted to go there. The Daily Coach card shows a scenario label ("Well Rested", "Take It Easy") but this is buried at position 8 in the scroll.

Recommendation: The recovery score should be the first or second card on the dashboard, positioned above nutrition.

### Issue DB-02 — Dashboard does not adapt to the user's selected goal (Should-have)**
The `DashboardHomeProvider` correctly builds a goal-adaptive primary metric and key signals, but these are not being rendered in `DashboardScreen`. The dashboard currently shows the same layout regardless of whether the user chose "Performance," "Fat Loss," or "Reduce Stress." The goal-adaptive logic exists but is disconnected from the actual screen.

### Issue DB-03 — "Good morning" greeting does not change to afternoon/evening (Minor)**
The greeting is hardcoded as "Good morning," at line 76 of `dashboard_screen.dart`. The `_greeting()` helper function in `daily_coach_card.dart` correctly handles time-of-day but is not used in the header. This is a small trust signal — fitness apps that do not adapt to time of day feel generic.

### Issue DB-04 — Dashboard is too long with too many modules (Should-have)**
12 distinct sections in a single scroll view creates cognitive overload. Users cannot identify which modules are primary and which are secondary. The Discover Quick Access grid duplicates navigation already available from the bottom bar.

---

## 3. Feature Completeness Assessment

The following assessment is based on code inspection. "Skeleton" means a screen and provider exist but contain no real data binding or the core user interaction is unimplemented.

| Feature | Status | Notes |
|---|---|---|
| Auth (login/signup) | Complete | |
| Onboarding flow | Complete (with issues above) | |
| Health Connect sync | Wired — untested end-to-end | AndroidManifest noted as needing work in CLAUDE.md |
| Dashboard | Partial | Recovery score missing; goal-adaptive logic disconnected |
| Recovery Score calculation | Complete (Phase 10) | Not surfaced on dashboard |
| Daily Coach check-in | Complete | 5-step flow, deterministic engine wired |
| Morning check-in vitality step | Complete | Sensitive question — consent gap noted |
| Meal logging (log_meal_screen) | Skeleton | No calorie/macro input; nutrition_info is a TODO stub |
| Food search (food_search_screen) | Complete | Open Food Facts + barcode scanner wired |
| Meal plan generation | Partial | Screen exists; real generation unclear |
| Workout logging (live session) | Complete | JEFIT-style, rest timer, PR detection |
| Workout plans | Partial | Plan detail screen exists; creating plans from scratch unclear |
| Goals tracking | Partial | Goal list and detail exist; projection chart not connected to real data |
| Insights dashboard | Partial | Recovery detail screen exists; full dashboard integration unclear |
| Habits tracker | Complete | Streak, dot grid, milestone dialog all wired |
| Bloodwork | Partial | Data entry exists; AI interpretation card exists; integration completeness unclear |
| Supplements | Partial | Repository and entities exist; reminder linking to notifications unclear |
| Reminders / Notifications | Partial — critical gap | `NotificationService` is fully implemented. Connection to `ReminderRepository` is not evident in any screen. The reminder must explicitly call `scheduleNotification()` after `createReminder()` — this handoff is not confirmed wired |
| Pantry | Partial | Data exists; cross-reference with shopping unconfirmed |
| Shopping lists | Partial | Aisle mapper and detail screens exist; auto-generate from meal plan unconfirmed |
| Recipes | Partial | URL import, OCR import, browse — end-to-end completeness unclear |
| Paywall / Freemium | Stub | Upgrade button shows "Coming Soon" dialog. Payment not integrated |
| Background sync (WorkManager) | Unknown | CLAUDE.md notes this as Phase 1 priority — not confirmed wired |
| Garmin / Strava integration | Not built | Shown as "Soon" in onboarding |

### Half-built features that would confuse users

**Meal logging is the most dangerous dead-end.** `LogMealScreen` has a comment `// TODO: Calculate nutrition based on servings consumed`. When a user logs a meal, the nutrition_info saved is:
```
{ 'source': 'recipe', 'recipe_id': ..., 'servings_consumed': 1 }
```
The macros are never computed and never shown back to the user. A user who logs breakfast and then looks at the Nutrition carousel on the dashboard will see no change. This will cause immediate churn from users expecting calorie tracking.

**The goals projection chart** is referenced in CLAUDE.md as "not connected to real data." Users who set a weight loss goal and check their projection will see placeholder behaviour.

**Reminders do not fire.** The `NotificationService` is fully built and correctly handles timezone, exact alarms, and deep-link payloads. The `ReminderRepository` persists reminders to Supabase. But there is no evidence in the codebase that `scheduleNotification()` is called when a reminder is created through the UI. Users will create reminders and receive no device notification.

---

## 4. Freemium Model Assessment

### Free Tier
Based on `PlanTier` and `CLAUDE.md`, the free tier provides:
- Basic meal and recipe logging
- Macro tracking only (no micronutrients)
- Manual workout logging
- 3 AI calls per day
- 7 days of history
- 1 profile

### Problems with the Free Tier

**Issue FM-01 — The free tier's primary logging features are broken (Must-have)**
As noted above, meal logging does not compute macros. A free user whose main value proposition is "macro tracking" receives nothing from the primary free feature. This must be fixed before any freemium strategy can be evaluated.

**Issue FM-02 — Recovery Score is entirely PRO-gated (Should-have)**
The app's tagline is recovery-driven optimisation, yet free users cannot see their recovery score. This means a new user who signs up, connects Health Connect, completes onboarding, and opens the dashboard will see no evidence of the core product differentiator. They have no reason to upgrade because they have no evidence it works.

Recommendation: Show free users a teased recovery score — display the score but blur or gate the breakdown and trend. This follows the "taste before purchase" freemium model used by Whoop (you can see your score but need to subscribe for explanation) and Oura.

**Issue FM-03 — 3 AI calls per day is not communicated to free users (Should-have)**
There is no UI element telling free users how many AI calls they have used today or how many remain. A user who hits the limit will receive an error with no context. The `remainingAICallsProvider` exists but is not surfaced.

**Issue FM-04 — No annual pricing option on the paywall (Should-have)**
The paywall shows only $9.99/month. Industry standard is to offer annual pricing (typically at a ~40% discount, e.g. $71.99/year = "$5.99/month billed annually") with the annual option visually prominent. Monthly-only paywalls convert at significantly lower rates.

**Issue FM-05 — Upgrade button is a "Coming Soon" dialog (Blocker for launch)**
`_handleUpgrade()` in `paywall_screen.dart` shows a developer dialog explaining that RevenueCat/Stripe integration is ready to be implemented. Any user who taps "Upgrade to Pro" sees this dialog. This is a launch blocker — the app cannot be monetised without payment integration.

**Issue FM-06 — Paywall has no social proof (Should-have)**
There are no testimonials, user counts, ratings, or trust signals on the paywall screen. Competitors like Whoop and Oura use community size and clinical study references prominently on conversion screens.

---

## 5. User Journey Analysis

### Journey 1: Signup to First Health Sync
1. Signup — Auth flow is complete
2. Onboarding (7 steps) — Complete but issues OB-01 through OB-05
3. Connect Health Connect — Works if AndroidManifest is properly configured
4. Dashboard — Shows "---" for all health metrics until first sync completes
5. First sync — Background sync via WorkManager; timing uncertain

**Friction point:** There is no empty state guidance on the dashboard. A user who just completed onboarding sees a dashboard full of "---" values and a spinner. There is no "your first sync is happening, check back in a few minutes" message. This is a high-churn moment.

### Journey 2: First Workout
1. Navigate to Workouts from bottom nav
2. Create or select a plan
3. Start live session (WorkoutLoggingScreen) — Complete, JEFIT-style
4. Log sets, use rest timer — Complete
5. Session summary — Screen exists

**Friction point:** It is unclear from code inspection whether a new user can easily create their first workout plan without pre-existing data. The exercise browser exists but the "new plan from scratch" path needs verification.

### Journey 3: First Meal Log
1. Navigate to Meals
2. Search food or log from recipe — Food search screen is complete
3. Select food item, specify quantity
4. Confirm log

**Friction point — Critical:** After logging, macros are not computed. The nutrition carousel does not update. This is a broken journey for the app's most commonly expected feature.

### Journey 4: Daily Check-in
1. Dashboard shows Daily Coach card with "Start Check-In" CTA
2. 5-step check-in (feeling, sleep, schedule, vitality, injuries)
3. Prescription engine runs deterministically
4. Today's Plan screen shows scenario label and workout directive

This journey is the most complete in the app. The prescription engine is well-designed. The only issue is the vitality step (OB-06 above) and the fact that the Daily Coach card is at position 8 in the dashboard scroll.

### Journey 5: First Recovery Score
1. Connect Health Connect (done during onboarding or settings)
2. Allow 14-day baseline calibration to complete (enforced by `BaselineCalibration`)
3. Navigate to Insights

**Friction point:** Users must wait 14 days for the baseline before the recovery score unlocks. This is technically correct for accuracy but creates a 14-day dead zone where the app's primary value proposition is inaccessible. There is no progress indicator showing "12 of 14 days calibrated."

---

## 6. Competitive Differentiation

### vs. MyFitnessPal
- MyFitnessPal's core strength is its food database (14M+ items). WellTrack uses Open Food Facts (free, good coverage, but smaller). WellTrack's differentiation must not be food logging depth — MFP will always win there.
- WellTrack's advantage: recovery score + AI coaching + workout integration in one app. MFP does none of these.
- WellTrack's gap: meal logging UX is currently inferior to MFP.

### vs. Whoop
- Whoop requires a hardware wearable subscription ($239+/year). WellTrack works with any Android phone or Garmin watch through Health Connect.
- Whoop's core product is the recovery score and strain algorithm. WellTrack has a recovery score with a comparable methodology (sleep quality 30%, HRV/HR 25%, load 25%, sleep duration 20%).
- WellTrack's advantage: no hardware required, includes nutrition + meal planning, lower price point.
- WellTrack's gap: Whoop's HRV-driven recovery algorithm is more sophisticated and has clinical studies behind it. WellTrack's is a reasonable approximation.

### vs. Oura Ring
- Oura requires hardware ($299+ ring) + $5.99/month subscription.
- WellTrack advantage: same hardware-free argument as vs. Whoop.
- WellTrack gap: Oura's sleep stage detection is from a medical-grade sensor. WellTrack relies on Health Connect sleep data which varies by device.

### Unique Differentiators WellTrack has that competitors lack
1. **Deterministic prescription engine** — The "math first, AI explains" principle is a genuine differentiator. Whoop and Oura use AI to both calculate AND explain, creating a black box. WellTrack's approach is more trustworthy and auditable.
2. **Bloodwork integration** — None of the three primary competitors track bloodwork results alongside fitness metrics. This is genuinely unique.
3. **Habit tracking tied to biometric outcomes** — The kegel tracker and vitality tracking (morning erection as a proxy for testosterone/sleep health) is niche but strongly differentiated for a male performance-focused audience.
4. **Pantry-aware meal planning** — Auto-generating shopping lists that cross-reference pantry stock is more sophisticated than anything MFP, Whoop, or Oura offer.

---

## 7. Missing Features

The following are features users would expect that are currently absent:

**Must-have before launch:**
- Payment / subscription processing (RevenueCat integration) — the paywall is a stub
- Macro calculation on meal logging — the most basic expected behaviour of a nutrition tracker
- Recovery score visible on the free tier (teased/blurred) — users need to see the product works before paying
- Empty state guidance on the post-onboarding dashboard ("your first sync is in progress")
- Display name collection in onboarding

**Should-have within first 2 sprints post-launch:**
- Goal progress notifications ("You're 80% toward your step goal today")
- 14-day calibration progress indicator
- Annual pricing plan on the paywall
- Weekly summary push notification (the feature is PRO-gated and the logic exists; the notification trigger is missing)
- Garmin direct integration (currently "Soon" in onboarding — creates unmet expectation)
- AI call counter visible to free users

**Nice-to-have:**
- Social/community features — none of the competitors have done this well; it's an open opportunity
- Apple Watch / WearOS companion app
- Export to PDF (especially for bloodwork — useful for sharing with doctors)
- Dark/light mode user toggle (currently follows system)
- Imperial units option (height in feet/inches, weight in lbs) — critical for US market

---

## 8. Paywall / Monetisation Assessment

### Current State
- Price: $9.99/month (monthly only)
- Upgrade flow: Shows "Coming Soon" dialog — payment not implemented
- Paywall screen: Functional UI with feature comparison table and benefits list
- Gate enforcement: `FreemiumRepository.isFeatureAvailable()` is wired; `featureAvailableProvider` exists

### Issues Already Documented Above
- FM-05 (blocker): No actual payment integration
- FM-04: No annual plan
- FM-06: No social proof

### Additional Monetisation Observations

**Issue FM-07 — Free tier gating is too aggressive for a cold-start product (Must-have)**
Recovery score, adaptive plans, training load, and the insights dashboard are all PRO-only. A new user who has never paid for WellTrack has no way to experience the product's actual value. The comparison table on the paywall shows a long list of lock icons but the user has not yet verified that any of these features work. This will result in very low trial-to-paid conversion.

Best practice for this type of app is a 14-day free trial of PRO (which conveniently aligns with the 14-day baseline calibration period). Users get to see the recovery score just as it unlocks, then are asked to pay.

**Issue FM-08 — No paywall entry point from the dashboard (Should-have)**
There is no path from the main dashboard to the paywall unless a user taps a gated feature. Users do not browse to the paywall to discover what they are missing — they need to be shown locked cards on the dashboard with a tap-to-upgrade affordance.

---

## 9. Retention Hooks Assessment

### Daily Check-in (retention hook 1)
- Implementation: Complete and well-designed
- Friction: Buried at scroll position 8 on dashboard
- Missing: No push notification to prompt the check-in at a user-defined morning time

### Habit Streaks (retention hook 2)
- Implementation: Complete — 30-day dot grid, streak count, milestone dialog
- Missing: No streak-ending warning notification ("Don't break your 14-day streak — log your habit before midnight")

### Recovery Score (retention hook 3)
- Implementation: Complete on the Insights screen
- Missing: Not surfaced on the dashboard; 14-day wait means no hook for the first 2 weeks; no push notification for score availability

### Reminders / Notifications (retention hook 4)
- Implementation: `NotificationService` is fully built with correct timezone handling, deep-linking, and repeat rules
- Critical gap: `scheduleNotification()` is never called from the `ReminderRepository.createReminder()` path. Users who create reminders in the UI will receive no device notifications. This must be wired.

### Weekly AI Summary (retention hook 5)
- Implementation: The feature is built and PRO-gated
- Missing: The notification trigger that tells users "your weekly summary is ready" does not appear to be wired

---

## 10. Prioritised Recommendations

### Must-have (Required before any public release)

| ID | Recommendation | Rationale |
|---|---|---|
| R-01 | Wire `scheduleNotification()` to `createReminder()` in the UI flow | Reminders are a core retention hook; currently silently broken |
| R-02 | Implement macro calculation in `LogMealScreen` | The primary free tier feature does not work |
| R-03 | Integrate RevenueCat for subscription management | Paywall shows "Coming Soon" — app cannot earn revenue |
| R-04 | Add display name field to QuickProfileScreen in onboarding | "Good morning, john.doe" breaks the premium feel |
| R-05 | Place Recovery Score card at top of dashboard (position 1 or 2) | Core value proposition is invisible on the main screen |
| R-06 | Fix height/weight input validation and decimal handling | `FilteringTextInputFormatter.digitsOnly` strips decimals silently |
| R-07 | Add post-onboarding empty state with sync progress indicator | High-churn moment: users see "---" everywhere after onboarding |
| R-08 | Show recovery score to free users (teased/blurred breakdown) | Users need to experience the value before being asked to pay |

### Should-have (Next sprint after launch-blocking items)

| ID | Recommendation | Rationale |
|---|---|---|
| R-09 | Add 14-day calibration progress indicator to dashboard | Reduces the "dead zone" frustration during first 2 weeks |
| R-10 | Add annual pricing tier to paywall | Dramatically improves conversion; industry standard |
| R-11 | Offer 14-day free PRO trial aligned with calibration period | "Value before ask" — users see recovery score just as it unlocks |
| R-12 | Add daily check-in push notification at user-set morning time | Retention hook 1 has no trigger |
| R-13 | Add streak-ending warning notification | Retention hook 2 has no trigger |
| R-14 | Add AI call counter widget visible to free users on dashboard | Transparency reduces frustration; drives upgrade intent |
| R-15 | Wire goal-adaptive dashboard layout (connect `dashboardHomeProvider` to `DashboardScreen`) | Goal-adaptive logic exists but is disconnected from the actual UI |
| R-16 | Add biological sex field to onboarding | Required for accurate BMR/calorie targets |

### Nice-to-have (Post-launch roadmap)

| ID | Recommendation | Rationale |
|---|---|---|
| R-17 | Imperial units option (lbs, feet/inches) | Required for US market |
| R-18 | PDF export for bloodwork results | Genuine differentiator; supports doctor sharing workflow |
| R-19 | "Value preview" screen before Health Connect permission request | Increases Health Connect opt-in rate |
| R-20 | Social proof on paywall (user count, rating, testimonial) | Standard conversion rate optimisation |
| R-21 | Weekly summary push notification | PRO retention hook exists but has no delivery trigger |
| R-22 | Add explicit AI data consent explanation during onboarding (before vitality questions appear in check-in) | Informed consent for sensitive data collection |
| R-23 | Reduce dashboard to 6–7 sections; move secondary modules to a "More" tab | Cognitive overload from 12 sections |

---

## Appendix: Key Files Reviewed

- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/profile/presentation/onboarding/onboarding_flow_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/profile/presentation/onboarding/onboarding_state.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/profile/presentation/onboarding/screens/` (all 7 screens)
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/dashboard/presentation/dashboard_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/dashboard/presentation/dashboard_home_provider.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/freemium/presentation/paywall_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/freemium/domain/plan_tier.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/freemium/data/freemium_repository.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/reminders/data/notification_service.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/reminders/data/reminder_repository.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/daily_coach/presentation/morning_checkin_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/daily_coach/data/prescription_engine.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/habits/presentation/habits_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/meals/presentation/log_meal_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/meals/presentation/food_search_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/workouts/presentation/workout_logging_screen.dart`
- `/mnt/c/Users/Oluwa/DesktopProjects/welltrack_v2/agentic-mobile-template/lib/features/insights/presentation/widgets/recovery_score_card.dart`
