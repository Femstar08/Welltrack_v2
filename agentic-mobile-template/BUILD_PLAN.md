# WellTrack — Phased Build Plan

> Think of this like building a house: foundation first (database), then structure (app skeleton), then plumbing (data pipelines), then rooms (features), then furnishing (AI + polish).

---

## Phase 1: Foundation — Supabase Schema + RLS
**Why first:** Every feature reads/writes data. No data layer = nothing works.

**Delivers:**
- All 30+ `WP_` tables created in Supabase
- Row Level Security (RLS) on every table — ensures users only see their own data
- Database indexes for performance
- Seed data for development/testing

**You'll need to:**
- Have a Supabase project created (free tier is fine to start)
- Run the SQL migration file Claude Code generates

---

## Phase 2: App Skeleton — Flutter Scaffold + Auth + Offline Engine
**Why second:** The app needs to exist, log users in, and handle being offline.

**Delivers:**
- Flutter project with Clean Architecture folder structure
- Supabase Auth integration (email/password sign-up/login)
- Encrypted local database (Isar or Hive)
- Offline sync engine — logs data locally, syncs when online, handles conflicts
- Module registry — the system that lets you toggle features on/off per profile
- Dashboard tile system — tiles rearrange based on which modules are enabled
- Navigation + routing

**Analogy:** This is the empty house with walls, doors, electricity, and plumbing — no furniture yet.

---

## Phase 3: Health Connections — Garmin + Strava OAuth
**Why third:** Stress and VO₂ max (two of your top 3 metrics) come from here.

**Delivers:**
- Garmin OAuth connect/disconnect flow
- Strava OAuth connect/disconnect flow
- Secure token storage (encrypted)
- Webhook receivers (Supabase Edge Functions) — Garmin/Strava push data to your app
- Backfill job — pulls last 14 days of data on first connect
- Connection status UI — shows "Connected / Last synced 2 hours ago"

**You'll need to:**
- Register as a Garmin developer and create an app (gets you API keys)
- Register as a Strava developer and create an app (gets you API keys)
- I'll walk you through both step-by-step

---

## Phase 4: Health Metrics Pipeline
**Why fourth:** Normalises all health data into one consistent format.

**Delivers:**
- Health Connect integration (Android) — reads sleep, stress, steps, HR
- HealthKit integration (iOS) — reads sleep, steps, HR
- Garmin/Strava data normalisation — maps their formats to yours
- Deduplication logic — if Garmin and HealthKit both report sleep, picks the best record
- `WP_health_metrics` populated with clean, queryable data

**Analogy:** Like having different bank statements (Garmin, Apple, Google) all converted into one spreadsheet with the same columns.

---

## Phase 5: AI Orchestrator — The Brain
**Why fifth:** AI features all route through one controlled gateway.

**Delivers:**
- `/ai/orchestrate` Edge Function — single entry point for all AI
- Tool registry — each AI capability is a registered "tool" the orchestrator can call
- Structured JSON responses — the AI returns actions, not just text
- Context builder — pulls user's health data, preferences, history into AI prompts
- Usage metering — tracks every AI call for freemium limits
- Audit log — records what AI said and did (traceability)

**Analogy:** Think of this as a receptionist who takes every request, decides which specialist to send it to, and returns a structured answer — not a free-for-all where the app calls AI everywhere.

---

## Phase 6: Pantry → Recipes → Prep (First End-to-End Feature)
**Why sixth:** High user value. Proves the whole stack works together.

**Delivers:**
- Pantry input screen — add items by category (fridge/cupboard/freezer)
- AI generates 5–10 recipe options from your pantry items
- Recipe card view — tags, time, difficulty, nutrition score A–D
- Step-by-step prep walkthrough with timers and checklist
- Leftover capture — "I have 200g chicken left" → saves for next recipe suggestion
- Nutrient extraction — each meal logged auto-calculates nutrients

---

## Phase 7: Recipe Import — URL + Photo OCR
**Why seventh:** Extends your recipe library beyond AI-generated ones.

**Delivers:**
- URL paste → server extracts recipe → user confirms/edits → saves
- Photo capture → OCR server-side → extracts recipe → user confirms/edits → saves
- Both feed into the same recipe/meal/nutrient pipeline

**You'll need to:**
- Decide on OCR provider (Google Vision API is reliable; there are free-tier options)

---

## Phase 8: Remaining Modules
**Delivers:**
- Supplements tracker (AM/PM protocols, link to goals)
- Workouts (manual + suggested, custom exercises)
- Reminders (scheduler hooks, notifications)
- Profiles (parent + dependents, module toggles per profile)
- Daily View (checklist across all enabled modules)

---

## Phase 9: Insights Dashboard + AI Summaries
**Why near-last:** Insights need data from all other modules to be meaningful.

**Delivers:**
- Day/week/month progress views
- Charts: nutrient progress, health metrics trends, workout consistency
- AI-generated weekly summary — "Your sleep improved 12% this week. Stress score trending down since you added magnesium."
- Goal forecasting — "At this pace, you'll hit your target weight by March 15"
- Plan adjustment suggestions — "Consider adding a rest day; your stress score spiked"

---

## Phase 10: Freemium + Paywall
**Why last:** Monetisation wraps around working features.

**Delivers:**
- AI usage display in settings — "5 of 10 daily AI calls used"
- Server-side enforcement — blocks AI calls when limit exceeded
- Paywall stubs — "Upgrade to Pro" screens (ready for Stripe/RevenueCat integration)
- Tier definitions: Free vs Pro limits

---

## What You Need Before Starting

| Item | Why | Action |
|------|-----|--------|
| Supabase account | Database + auth + edge functions | Sign up at supabase.com (free tier) |
| Flutter installed | Build the app | I'll guide you through setup |
| Garmin Developer account | API access for stress/VO₂ max | Register at developer.garmin.com |
| Strava Developer account | API access for VO₂ max + activities | Register at developers.strava.com |
| OpenAI API key | Powers the AI orchestrator | Sign up at platform.openai.com |
| Apple Developer account | iOS App Store submission | $99/year at developer.apple.com |
| Google Play Developer account | Android Play Store submission | $25 one-time at play.google.com/console |

---

## Estimated Effort (with Claude Code)

| Phase | Estimated Time |
|-------|---------------|
| Phase 1: Schema | 1–2 days |
| Phase 2: Scaffold | 3–5 days |
| Phase 3: OAuth | 2–3 days |
| Phase 4: Health pipeline | 2–3 days |
| Phase 5: AI Orchestrator | 3–5 days |
| Phase 6: Pantry→Recipes | 3–5 days |
| Phase 7: URL + OCR import | 2–3 days |
| Phase 8: Remaining modules | 5–7 days |
| Phase 9: Insights | 3–5 days |
| Phase 10: Freemium | 1–2 days |
| **Total** | **~25–40 days** |

These assume using Claude Code for heavy lifting. Manual coding would be 3–4x longer.