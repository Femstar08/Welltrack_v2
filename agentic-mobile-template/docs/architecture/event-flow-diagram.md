# WellTrack Event Flow Diagram

This document maps how data moves through the WellTrack system across all major workflows. Each flow shows the complete path from user action or external trigger through data validation, storage, and processing.

---

## Flow 1: User Signup & Onboarding

```mermaid
sequenceDiagram
    participant User
    participant App
    participant SupabaseAuth as Supabase Auth
    participant DB as Supabase DB
    participant Triggers as DB Triggers

    User->>App: Enters email/password
    App->>SupabaseAuth: auth.signUp()
    SupabaseAuth->>DB: INSERT auth.users
    DB->>Triggers: on_auth_user_created fires
    Triggers->>DB: handle_new_user() executes
    DB->>DB: INSERT wt_users (profile)
    DB->>DB: INSERT wt_profiles (parent, is_primary=true)
    SupabaseAuth-->>App: User session + ID
    App->>User: Navigate to onboarding
    User->>App: Sets goals, dietary restrictions
    App->>DB: UPDATE wt_profiles (goals, restrictions)
    DB->>DB: Provision default modules in wt_profile_modules
    App->>User: Navigate to dashboard
```

**Key Points:**
- Auth trigger creates both `wt_users` and parent `wt_profiles` row automatically
- Primary profile flag (`is_primary=true`) set for parent account
- Default module provisioning happens during profile update
- All operations atomic within trigger function

**Tables Touched:**
- `auth.users` (Supabase managed)
- `wt_users`
- `wt_profiles`
- `wt_profile_modules`

---

## Flow 2: Health Data Ingestion (Native — Health Connect/HealthKit)

```mermaid
sequenceDiagram
    participant BG as Background Sync
    participant Plugin as Health Plugin
    participant Local as Local DB (Isar)
    participant Validator as Validation Service
    participant DB as Supabase DB

    BG->>Plugin: Trigger sync (app open or scheduled)
    Plugin->>Plugin: Read Health Connect (Android) or HealthKit (iOS)
    Plugin->>Plugin: Normalize to wt_health_metrics format
    Plugin->>Plugin: Generate dedupe_hash (SHA256)

    alt Online
        Plugin->>DB: INSERT with ON CONFLICT (dedupe_hash) DO UPDATE
        DB->>DB: Set validation_status = 'raw'
        DB->>Validator: Background validation job
        Validator->>Validator: Check value ranges
        Validator->>DB: UPDATE validation_status ('validated' or 'rejected')

        alt Baseline incomplete
            Validator->>DB: Check if 14 days of data exists
            Validator->>DB: UPDATE wt_baselines (if threshold met)
        end
    else Offline
        Plugin->>Local: Queue in Isar DB with timestamp
        Note over Local: Synced when network available
    end
```

**Data Flow:**
1. **Collection**: Platform-specific health API read
2. **Normalization**: Convert to standard format
3. **Deduplication**: Hash-based conflict prevention
4. **Validation**: Async range checking
5. **Baseline Tracking**: 14-day rolling window

**Dedupe Hash Components:**
- `user_id + profile_id + source + metric_type + start_time + end_time`

**Tables Touched:**
- `wt_health_metrics`
- `wt_baselines` (conditional)

---

## Flow 3: Garmin Webhook Push (Phase 7)

```mermaid
sequenceDiagram
    participant Garmin
    participant Webhook as Edge Function (Webhook)
    participant DB as Supabase DB
    participant Worker as Background Worker
    participant Health as wt_health_metrics

    Garmin->>Webhook: POST webhook payload
    Webhook->>DB: INSERT wt_webhook_events (status: 'pending')
    Webhook-->>Garmin: HTTP 200 (< 30s)

    Worker->>DB: Poll for pending events
    Worker->>Worker: Parse payload by event_type
    Note over Worker: sleeps/stressDetails/userMetrics/dailies

    Worker->>Worker: Normalize to wt_health_metrics format
    Worker->>Health: INSERT with dedupe (summaryId → replace)
    Worker->>DB: UPDATE wt_health_connections.last_sync_at
    Worker->>DB: UPDATE wt_webhook_events (status: 'processed')

    alt Failure
        Worker->>DB: INCREMENT attempts
        Worker->>DB: SET next_retry_at (exponential backoff)

        alt Max attempts reached
            Worker->>DB: UPDATE status = 'dead_letter'
        end
    end
```

**Event Types & Mapping:**
- `sleeps` → sleep duration, stages, score
- `stressDetails` → stress score (0-100)
- `userMetrics` → VO2 max, fitness age
- `dailies` → steps, calories, HR zones

**Retry Strategy:**
- Attempt 1: Immediate
- Attempt 2: +5 minutes
- Attempt 3: +30 minutes
- Attempt 4: +2 hours
- Attempt 5: +6 hours
- After 5: Dead letter queue

**Tables Touched:**
- `wt_webhook_events`
- `wt_health_metrics`
- `wt_health_connections`

---

## Flow 4: Strava Webhook (Phase 7)

```mermaid
sequenceDiagram
    participant Strava
    participant Webhook as Edge Function (Webhook)
    participant API as Strava API
    participant DB as Supabase DB
    participant Health as wt_health_metrics

    Strava->>Webhook: POST webhook notification (event)
    Webhook->>Webhook: Validate subscription token

    alt Activity event
        Webhook->>API: GET /activities/{id} (fetch details)
        API-->>Webhook: Activity data + VO2 max (if available)
        Webhook->>DB: INSERT wt_webhook_events
        Webhook-->>Strava: HTTP 200

        Note over Webhook,DB: Background processing
        Webhook->>Health: Normalize activity → wt_health_metrics
        Webhook->>Health: Extract VO2 max if present
        Webhook->>DB: UPDATE wt_health_connections.last_sync_at
    else Subscription challenge
        Webhook-->>Strava: Echo challenge
    end
```

**Activity Data Extracted:**
- Type (run, ride, swim, etc.)
- Distance, duration, elevation
- Average HR, max HR
- VO2 max estimate (if available)
- Calories burned

**Tables Touched:**
- `wt_webhook_events`
- `wt_health_metrics`
- `wt_health_connections`

---

## Flow 5: AI Orchestrator Call

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Edge as Edge Function (/ai/orchestrate)
    participant RateLimit as check_ai_limit()
    participant Context as Context Builder
    participant OpenAI
    participant Safety as Safety Classifier
    participant DB as Supabase DB

    User->>App: Trigger AI action
    App->>Edge: POST /ai/orchestrate
    Edge->>RateLimit: Check user plan limits

    alt Limit exceeded
        RateLimit-->>App: 429 Too Many Requests
    else Limit OK
        Edge->>Context: Assemble context snapshot
        Note over Context: profile, metrics, plans, memory
        Context->>Context: Trim to 4000 tokens max

        Edge->>OpenAI: Call API (system prompt + context + user message)
        OpenAI-->>Edge: Structured JSON response

        Edge->>Safety: Classify output
        Safety->>Safety: Check for unsafe content

        alt Dry run mode
            Edge-->>App: Return proposed writes (no commit)
        else Live mode
            Edge->>DB: Execute db_writes to wt_* tables
            Edge->>DB: Call increment_ai_usage()
            Edge->>DB: INSERT wt_ai_audit_log
            Edge-->>App: Success response + assistant_message
        end
    end
```

**Context Snapshot Includes:**
- User profile (goals, restrictions, preferences)
- Recent health metrics (last 14 days)
- Active plans and progress
- AI memory (preferences, patterns)
- Baseline and forecast data

**System Prompt Tone:**
- Suggestive, not prescriptive
- Evidence-based recommendations
- Respects user autonomy

**Rate Limit Checks:**
- Daily token count vs. plan limit
- Daily API calls vs. plan limit
- Reset at midnight UTC

**Tables Touched:**
- `wt_ai_usage`
- `wt_ai_audit_log`
- Various `wt_*` tables (based on workflow)

---

## Flow 6: Pantry → Recipes → Prep

```mermaid
sequenceDiagram
    participant User
    participant App
    participant AI as /ai/orchestrate
    participant DB as Supabase DB

    User->>App: Opens "Cook with what I have"
    App->>DB: SELECT * FROM wt_pantry_items
    DB-->>App: List of available items
    App->>User: Display pantry inventory

    User->>App: Request recipe suggestions
    App->>AI: workflow_type = 'generate_pantry_recipes'
    Note over AI: Context: pantry items + dietary restrictions
    AI-->>App: 5-10 recipe suggestions (no DB writes)
    App->>User: Display recipe cards (tags, time, difficulty, nutrition score A-D)

    User->>App: Selects recipe
    App->>AI: workflow_type = 'generate_recipe_steps'
    AI->>DB: INSERT wt_recipes
    AI->>DB: INSERT wt_recipe_steps (order_index)
    AI->>DB: INSERT wt_recipe_ingredients
    AI-->>App: Recipe ID + full details

    App->>User: Start prep walkthrough
    User->>App: Complete steps (timers, checklist)

    User->>App: Mark meal complete
    App->>DB: INSERT wt_meals
    App->>DB: Auto-extract → INSERT wt_meal_nutrient_breakdown

    User->>App: Capture leftovers
    App->>DB: INSERT wt_leftovers
    App->>DB: UPDATE wt_pantry_items (decrement quantities)
```

**Recipe Suggestion Scoring:**
- Ingredient match percentage
- Prep + cook time
- Difficulty level
- Nutrition score (A-D based on macro balance)
- User preference alignment

**Prep Walkthrough Features:**
- Step-by-step checklist
- Built-in timers per step
- Ingredient staging prompts
- Equipment reminders

**Tables Touched:**
- `wt_pantry_items`
- `wt_recipes`
- `wt_recipe_steps`
- `wt_recipe_ingredients`
- `wt_meals`
- `wt_meal_nutrient_breakdown`
- `wt_leftovers`

---

## Flow 7: Offline Sync

```mermaid
sequenceDiagram
    participant App
    participant Local as Local DB (Isar)
    participant Network as Network Monitor
    participant Sync as Sync Engine
    participant DB as Supabase DB

    App->>Network: Detect network status

    alt Offline
        App->>Local: Queue write {table, operation, data, created_at, retry_count}
        Note over Local: FIFO queue with timestamps
    end

    Network->>Sync: Network restored
    Sync->>Local: SELECT * FROM queue ORDER BY created_at

    loop For each queued entry
        Sync->>DB: Attempt Supabase write

        alt Success
            DB-->>Sync: Write confirmed
            Sync->>Local: DELETE from queue
        else Conflict detected
            Sync->>Sync: Apply conflict resolution strategy
            Note over Sync: Last-write-wins by updated_at (server timestamp)

            alt Merge strategy (table-specific)
                Sync->>DB: Merge and write
                Sync->>Local: DELETE from queue
            end
        else Failure
            Sync->>Local: INCREMENT retry_count
            Sync->>Local: SET next_retry_at (exponential backoff)

            alt Max retries (5) exceeded
                Sync->>Local: Move to dead_letter_queue
                Sync->>App: Notify user of sync failure
            end
        end
    end
```

**Conflict Resolution Strategies:**
- **wt_meals, wt_workouts**: Last-write-wins (server timestamp)
- **wt_health_metrics**: Dedupe hash prevents conflicts
- **wt_pantry_items**: Quantity sum (if both devices logged usage)
- **wt_profiles**: Field-level merge (preferences, goals)

**Exponential Backoff:**
- Retry 1: Immediate
- Retry 2: +30 seconds
- Retry 3: +2 minutes
- Retry 4: +10 minutes
- Retry 5: +30 minutes

**Dead Letter Queue Notification:**
- In-app alert with details
- Option to manually retry or discard
- Logging to support diagnostics

**Tables Touched:**
- All `wt_*` tables (potentially)
- Local Isar sync queue table

---

## Flow 8: Performance Engine Pipeline

```mermaid
sequenceDiagram
    participant Source as Health Data Source
    participant Metrics as wt_health_metrics
    participant Components as Component Tables
    participant Engine as Performance Engine
    participant Recovery as wt_recovery_scores
    participant Forecast as wt_forecasts
    participant AI as AI Narrative Generator

    Source->>Metrics: Health data arrives (any source)

    alt Sleep data
        Metrics->>Components: UPDATE sleep component
    else Stress data (Garmin only)
        Metrics->>Components: UPDATE stress component
        Note over Components: NULL if unavailable
    else HR data
        Metrics->>Components: UPDATE HR component
    else Workout logged
        Metrics->>Components: Calculate training_load
        Note over Components: duration × intensity_factor
        Metrics->>Components: INSERT wt_training_loads
    end

    Note over Engine: Daily at midnight (or on demand)
    Engine->>Components: Calculate 7-day rolling training load sum
    Engine->>Engine: Calculate recovery_score
    Note over Engine: (stress×0.25) + (sleep×0.30) + (HR×0.20) + (load×0.25)
    Engine->>Recovery: INSERT wt_recovery_scores

    alt Baseline complete AND goal exists
        Engine->>Engine: Run linear regression on target metric
        Engine->>Engine: Calculate slope, projected_date, confidence
        Engine->>Forecast: INSERT/UPDATE wt_forecasts
        Engine->>AI: Request narrative explanation
        AI-->>Engine: Human-readable forecast explanation
    end
```

**Component Normalization (0-100 scale):**
- **Stress**: Inverse (lower = better) → 100 - stress_score
- **Sleep**: Hours / target × 100
- **HR**: Resting HR inverse normalized
- **Load**: Training load / baseline × 100

**Recovery Score Formula:**
```
recovery_score =
  (stress_normalized × 0.25) +
  (sleep_normalized × 0.30) +
  (hr_normalized × 0.20) +
  (load_normalized × 0.25)
```

**Linear Regression for Forecasting:**
- Uses last 30 days of target metric
- Calculates slope (rate of improvement)
- Projects to goal target value
- Confidence based on R² value

**AI Narrative Example:**
> "Based on your current progress (0.2 kg/week average), you're on track to reach your 75 kg target by May 15, 2026. Your recovery score is trending upward, indicating good adaptation to your training load."

**Tables Touched:**
- `wt_health_metrics`
- `wt_training_loads`
- `wt_recovery_scores`
- `wt_forecasts`
- `wt_baselines`

---

## Flow 9: Plan Generation

```mermaid
sequenceDiagram
    participant User
    participant App
    participant AI as /ai/orchestrate
    participant Context as Context Builder
    participant DB as Supabase DB
    participant Daily as Daily View

    User->>App: Requests new plan
    App->>AI: workflow_type = 'generate_weekly_plan'

    AI->>Context: Assemble context
    Note over Context: goals, metrics, recovery score,<br/>baseline, dietary restrictions

    AI->>AI: Generate 7-day plan
    Note over AI: meals, workouts, supplements, activity targets

    AI->>DB: INSERT wt_plans (status: 'draft')
    AI->>DB: INSERT wt_plan_items (7 days × modules)
    Note over DB: module, item_type, item_data, scheduled_date
    AI-->>App: Plan preview

    User->>App: Reviews plan

    alt User accepts
        App->>DB: UPDATE wt_plans (status: 'active')
    else User edits
        User->>App: Modify items
        App->>DB: UPDATE wt_plan_items
        App->>DB: UPDATE wt_plans (status: 'active')
    end

    loop Daily
        Daily->>DB: SELECT active plan items for today
        DB-->>Daily: Today's tasks
        Daily->>User: Display in Daily View

        User->>App: Complete item
        App->>DB: UPDATE wt_plan_items.completed = true
    end

    Note over AI,DB: End of week
    AI->>DB: Generate insights from completed items
    AI->>DB: Recalculate forecast based on progress
    AI->>DB: INSERT wt_insights
```

**Plan Item Structure:**
```json
{
  "plan_id": "uuid",
  "module": "meals",
  "item_type": "breakfast",
  "item_data": {
    "recipe_id": "uuid",
    "servings": 1,
    "target_time": "08:00"
  },
  "scheduled_date": "2026-02-15",
  "completed": false
}
```

**Plan Status States:**
- `draft` — Generated but not accepted
- `active` — User accepted, in progress
- `completed` — All items done or week ended
- `archived` — Historical record

**Weekly Insights Generated:**
- Completion rate by module
- Nutrition adherence (actual vs. targets)
- Training load vs. recovery balance
- Goal progress delta
- AI suggestions for next week

**Tables Touched:**
- `wt_plans`
- `wt_plan_items`
- `wt_insights`
- `wt_forecasts`
- `wt_baselines`

---

## Cross-Cutting Concerns

### Authentication Flow
All API calls include:
```
Authorization: Bearer <supabase_access_token>
```

Row-Level Security (RLS) enforces:
```sql
-- Example policy
CREATE POLICY "Users can only access their own data"
ON wt_health_metrics
FOR ALL
USING (auth.uid() = user_id);
```

### Error Handling Pattern
```
Try operation
  → If success: return result
  → If retriable error: queue for retry
  → If permanent error: log to wt_error_log + notify user
```

### Audit Trail
All AI operations and sensitive data changes logged to:
- `wt_ai_audit_log` — AI calls, tokens used, workflow type
- `wt_audit_log` — Data modifications (who, what, when)

### Performance Monitoring
Key metrics tracked:
- API response times (p50, p95, p99)
- Database query duration
- AI token usage per user/plan
- Webhook processing latency
- Sync queue depth and retry rates

---

## Data Flow Summary

| Flow | Trigger | Source | Destination | Latency |
|------|---------|--------|-------------|---------|
| Signup | User action | App | auth.users → wt_users → wt_profiles | < 2s |
| Native Health | Background sync | Health Connect/HealthKit | wt_health_metrics | < 5s |
| Garmin Webhook | Garmin push | Garmin API | wt_webhook_events → wt_health_metrics | < 60s |
| Strava Webhook | Strava push | Strava API | wt_webhook_events → wt_health_metrics | < 60s |
| AI Orchestrator | User/scheduled | App | OpenAI → wt_* tables | 2-10s |
| Pantry → Recipe | User action | App | AI → wt_recipes | 5-15s |
| Offline Sync | Network restore | Local Isar | Supabase DB | Variable |
| Performance Engine | Daily/on-demand | wt_health_metrics | wt_recovery_scores, wt_forecasts | < 30s |
| Plan Generation | User/AI | AI | wt_plans, wt_plan_items | 10-20s |

---

## Notes for Developers

1. **Always respect offline-first**: Queue writes to local DB when network unavailable
2. **Dedupe hashes prevent duplicates**: Use consistent hash generation across sources
3. **RLS is non-negotiable**: Every table must have policies restricting to user's own data
4. **Webhooks must respond fast**: Acknowledge within 30s, process asynchronously
5. **AI context is expensive**: Trim to 4000 tokens max, prioritize recent + relevant data
6. **Conflict resolution is table-specific**: Document strategy per table in schema
7. **Baseline requires 14 days**: Don't calculate recovery scores or forecasts until baseline complete
8. **Rate limiting is server-side**: Never trust client for AI usage enforcement

---

**Document Version:** 1.0
**Last Updated:** 2026-02-15
**Maintained By:** Backend Team
