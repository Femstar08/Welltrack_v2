# AI Orchestrator Contract

## Overview

The AI Orchestrator is the **single AI entry point** for WellTrack. All AI operations route through one Supabase Edge Function endpoint: `/ai/orchestrate`.

**Core Principles:**
- Single endpoint for all AI interactions
- Server-side only (never call OpenAI from mobile client)
- Suggestive tone enforced — never prescriptive
- No medical claims ever
- Structured outputs with validated DB writes
- Token metering and freemium limits enforced server-side

## Request Contract

```typescript
interface OrchestrateRequest {
  user_id: string;                    // auth.uid() from Supabase Auth
  profile_id: string;                 // active profile UUID
  message?: string;                   // user's natural language input
  workflow_type?: WorkflowType;       // explicit tool request
  context_override?: object;          // optional additional context
}

type WorkflowType =
  | 'generate_weekly_plan'
  | 'generate_pantry_recipes'
  | 'generate_recipe_steps'
  | 'summarize_insights'
  | 'recommend_supplements'
  | 'recommend_workouts'
  | 'update_goals'
  | 'recalc_goal_forecast'
  | 'log_event_suggestion'
  | 'extract_recipe_from_url'
  | 'extract_recipe_from_image';
```

**Request Examples:**

```typescript
// Natural language chat
{
  "user_id": "auth-uuid",
  "profile_id": "profile-uuid",
  "message": "I'm feeling tired today. What should I eat?"
}

// Explicit workflow
{
  "user_id": "auth-uuid",
  "profile_id": "profile-uuid",
  "workflow_type": "generate_pantry_recipes",
  "context_override": {
    "pantry_items": ["chicken", "broccoli", "rice"],
    "dietary_restrictions": ["gluten-free"]
  }
}
```

## Response Contract

```typescript
interface OrchestrateResponse {
  assistant_message: string;              // user-facing text (suggestive tone)
  suggested_actions: SuggestedAction[];   // app-native actions
  db_writes: DBWrite[];                   // validated writes to wt_ tables
  updated_forecast?: ForecastUpdate;      // optional goal date recalculation
  safety_flags: SafetyFlag[];             // content/medical flags
  usage: UsageInfo;                       // token/call consumption
}

interface SuggestedAction {
  action_type: string;    // e.g., 'navigate', 'log_meal', 'start_timer'
  label: string;          // button text for UI
  payload: object;        // action-specific data
}

interface DBWrite {
  table: string;          // wt_ table name
  operation: 'insert' | 'update' | 'upsert';
  data: object;           // row data (validated against schema)
  dry_run: boolean;       // if true, proposed only (not committed)
}

interface ForecastUpdate {
  goal_id: string;
  new_expected_date: string;  // ISO 8601 date
  confidence: number;         // 0.0 - 1.0
  explanation: string;        // suggestive tone explanation
}

interface SafetyFlag {
  type: 'medical_claim' | 'unsafe_value' | 'rate_limit' | 'content_filter';
  message: string;
  blocked: boolean;       // if true, operation was blocked
}

interface UsageInfo {
  tokens_used: number;
  tokens_remaining_today: number;
  calls_used_today: number;
  calls_remaining_today: number;
  plan_tier: 'free' | 'pro';
}
```

**Response Example:**

```typescript
{
  "assistant_message": "Based on your recent sleep data, you might consider lighter meals today to support your recovery. Chicken and vegetables could be a good option.",
  "suggested_actions": [
    {
      "action_type": "view_recipes",
      "label": "View Suggested Recipes",
      "payload": { "recipe_ids": ["recipe-1", "recipe-2"] }
    },
    {
      "action_type": "log_meal",
      "label": "Log This Meal",
      "payload": { "meal_type": "lunch", "suggested_items": ["grilled chicken", "steamed broccoli"] }
    }
  ],
  "db_writes": [],
  "safety_flags": [],
  "usage": {
    "tokens_used": 450,
    "tokens_remaining_today": 9550,
    "calls_used_today": 1,
    "calls_remaining_today": 2,
    "plan_tier": "free"
  }
}
```

## Context Builder

The orchestrator assembles a context snapshot before calling OpenAI. Context is built from the following sources in priority order:

### Context Sources (Priority Order)

1. **User Profile** (always included)
   - Demographics (age, gender, weight, height)
   - Active goals and targets
   - Dietary restrictions and preferences
   - Medical conditions/allergies (user-entered)

2. **Recent Health Metrics** (last 7 days)
   - Sleep (duration, quality score, sleep stages)
   - Stress (Garmin Stress Score 0-100)
   - VO2 max (latest value)
   - Heart rate (resting, average, max)
   - Steps and active minutes

3. **Active Plan + Completion Status**
   - Current week plan items
   - Completion rate (%)
   - Adherence patterns

4. **Recent Meals + Nutrient Intake** (last 3 days)
   - Logged meals
   - Nutrient totals vs targets
   - Calorie balance

5. **Supplement Protocol Adherence** (last 7 days)
   - Active supplements
   - Adherence rate
   - Missed doses

6. **AI Memory** (persistent)
   - User preferences (communication style, recipe complexity)
   - Learned patterns (meal timing, workout preferences)
   - Previous feedback and adjustments

7. **Baseline Values** (if calibration complete)
   - Baseline stress, sleep, HR
   - Recovery score baseline

8. **Current Recovery Score**
   - Today's recovery score (if available)
   - Readiness indicator

### Context Trimming Rules

- **Max context size**: 4000 tokens
- **Summarize rather than raw dump**: aggregate metrics, don't include every data point
- **Priority**: active goals > recent metrics > historical patterns
- **Never include**: `raw_payload_json` fields
- **Cache context snapshots**: 5 minutes per profile (Redis or in-memory)

### Context Assembly Example

```typescript
{
  "profile": {
    "age": 34,
    "gender": "female",
    "weight_kg": 68,
    "height_cm": 165,
    "goals": ["improve_sleep", "reduce_stress"],
    "restrictions": ["gluten-free", "dairy-free"]
  },
  "health_summary_7d": {
    "avg_sleep_hours": 6.2,
    "avg_stress_score": 65,
    "avg_steps": 8500,
    "vo2max_latest": 38
  },
  "plan_adherence": {
    "completion_rate": 0.72,
    "missed_items": ["yoga", "evening_walk"]
  },
  "nutrition_3d": {
    "avg_calories": 1850,
    "protein_g": 95,
    "fiber_g": 22,
    "vs_targets": { "protein": 0.95, "fiber": 0.88 }
  },
  "recovery_today": {
    "score": 62,
    "readiness": "moderate"
  },
  "ai_memory": {
    "prefers_simple_recipes": true,
    "dislikes_fish": true,
    "workout_time_preference": "morning"
  }
}
```

## Tool Registry

Each tool is a registered function with defined capabilities, constraints, and safety level.

```typescript
interface Tool {
  name: string;
  description: string;
  input_schema: object;       // JSON schema for inputs
  output_schema: object;      // JSON schema for outputs
  max_tokens: number;         // per-tool token cap
  requires_context: string[]; // which context sections needed
  writes_to: string[];        // which wt_ tables this tool writes to
  safety_level: 'safe' | 'review' | 'restricted';
}
```

### Registered Tools

#### 1. generate_weekly_plan

Creates a 7-day plan across all enabled modules (meals, workouts, supplements, activities).

- **Writes to**: `wt_plans`, `wt_plan_items`
- **Max tokens**: 2000
- **Safety level**: `review`
- **Requires context**: profile, health_summary_7d, plan_adherence, nutrition_3d, ai_memory
- **Input schema**:
  ```typescript
  {
    "start_date": "2026-02-17",
    "goals": ["improve_sleep", "reduce_stress"],
    "constraints": { "max_workout_minutes": 45 }
  }
  ```
- **Output**: Structured plan with daily items, expected outcomes, and suggested goal date

#### 2. generate_pantry_recipes

Takes pantry items (fridge/cupboard/freezer) and returns 5-10 recipe suggestions with tags, time, difficulty, nutrition score.

- **Writes to**: None (suggestions only)
- **Max tokens**: 1500
- **Safety level**: `safe`
- **Requires context**: profile (restrictions), ai_memory
- **Input schema**:
  ```typescript
  {
    "pantry_items": ["chicken", "broccoli", "rice", "onion", "garlic"],
    "storage_location": { "chicken": "fridge", "broccoli": "fridge", "rice": "cupboard" },
    "meal_type": "dinner"
  }
  ```
- **Output**: Recipe suggestions with nutrition_score (A-D), prep_time, cook_time, difficulty

#### 3. generate_recipe_steps

Given a recipe title and ingredients, generates step-by-step preparation instructions.

- **Writes to**: `wt_recipe_steps`
- **Max tokens**: 1000
- **Safety level**: `safe`
- **Requires context**: profile (cooking skill level from ai_memory)
- **Input schema**:
  ```typescript
  {
    "recipe_id": "uuid",
    "recipe_title": "Garlic Chicken Stir-Fry",
    "ingredients": ["chicken breast", "broccoli", "garlic", "soy sauce"]
  }
  ```
- **Output**: Numbered steps with estimated time per step, optional timers

#### 4. summarize_insights

Generates period summary (daily/weekly/monthly) from health metrics and logs.

- **Writes to**: `wt_insights`
- **Max tokens**: 1000
- **Safety level**: `safe`
- **Requires context**: health_summary_7d (or 30d), plan_adherence, nutrition_3d, recovery_today
- **Input schema**:
  ```typescript
  {
    "period": "week",
    "start_date": "2026-02-08",
    "end_date": "2026-02-14"
  }
  ```
- **Output**: Summary text (suggestive tone) + key patterns + recommended adjustments

#### 5. recommend_supplements

Suggests supplements based on goals, nutrient gaps, and current protocol.

- **Writes to**: None (suggestions only)
- **Max tokens**: 800
- **Safety level**: `review`
- **Requires context**: profile (goals, restrictions), nutrition_3d, health_summary_7d
- **Input schema**:
  ```typescript
  {
    "goals": ["improve_sleep", "boost_immunity"],
    "current_supplements": ["vitamin_d", "magnesium"]
  }
  ```
- **Output**: Suggested supplements with dosage, timing, reasoning (suggestive tone)

#### 6. recommend_workouts

Suggests workouts based on recovery score, goals, and adherence patterns.

- **Writes to**: None (suggestions only)
- **Max tokens**: 800
- **Safety level**: `review`
- **Requires context**: recovery_today, health_summary_7d, plan_adherence, ai_memory
- **Input schema**:
  ```typescript
  {
    "recovery_score": 62,
    "available_time_minutes": 30,
    "equipment": ["bodyweight", "dumbbells"]
  }
  ```
- **Output**: Suggested workouts with intensity level, duration, rationale

#### 7. update_goals

Modifies goal targets (e.g., adjust protein target, change weight goal).

- **Writes to**: `wt_goal_forecasts`
- **Max tokens**: 500
- **Safety level**: `review`
- **Requires context**: profile, nutrition_3d (for nutrient goals), health_summary_7d (for fitness goals)
- **Input schema**:
  ```typescript
  {
    "goal_id": "uuid",
    "new_target": 100,
    "reason": "Increasing protein to support muscle recovery"
  }
  ```
- **Output**: Updated goal with new forecast and explanation

#### 8. recalc_goal_forecast

Recalculates projected achievement dates based on current progress and trends.

- **Writes to**: `wt_goal_forecasts`
- **Max tokens**: 500
- **Safety level**: `safe` (deterministic math, AI narrative only)
- **Requires context**: profile (goal), plan_adherence, health_summary_7d
- **Input schema**:
  ```typescript
  {
    "goal_id": "uuid"
  }
  ```
- **Output**: New expected date, confidence score, explanation (suggestive tone)

#### 9. log_event_suggestion

Suggests logging entries based on context (e.g., "You might want to log your evening meal").

- **Writes to**: None (suggestions only)
- **Max tokens**: 300
- **Safety level**: `safe`
- **Requires context**: plan_adherence, nutrition_3d
- **Input schema**:
  ```typescript
  {
    "time_of_day": "evening",
    "last_logged": "lunch"
  }
  ```
- **Output**: Suggested log entry with action payload

#### 10. extract_recipe_from_url

Fetches URL, extracts recipe (title, servings, prep_time, cook_time, ingredients, steps).

- **Writes to**: `wt_recipes`, `wt_recipe_ingredients`, `wt_recipe_steps`
- **Max tokens**: 1500
- **Safety level**: `safe`
- **Requires context**: profile (restrictions for validation)
- **Input schema**:
  ```typescript
  {
    "url": "https://example.com/recipe"
  }
  ```
- **Output**: Structured recipe data for user confirmation before saving

#### 11. extract_recipe_from_image

OCR + extraction from photographed recipe (cookbook, card, handwritten).

- **Writes to**: `wt_recipes`, `wt_recipe_ingredients`, `wt_recipe_steps`
- **Max tokens**: 2000
- **Safety level**: `safe`
- **Requires context**: profile (restrictions for validation)
- **Input schema**:
  ```typescript
  {
    "image_url": "https://storage.supabase.co/..."
  }
  ```
- **Output**: Structured recipe data for user confirmation before saving

## Guardrails

### Rate Limiting

**Free Tier:**
- 3 AI calls per day
- 10,000 tokens per day

**Pro Tier:**
- Unlimited AI calls
- 500,000 tokens per day (soft cap)

**Enforcement:**
- Tracked in `wt_ai_usage` table
- Server-side check via `check_ai_limit(user_id, profile_id)` function
- Returns `rate_limit` safety flag if exceeded
- Client shows upgrade prompt

### Safety Classification

All numeric values validated before DB writes:

- **Weight**: 20-500 kg
- **Height**: 50-300 cm
- **Calories**: 500-10,000 per day
- **Protein**: 0-500g per day
- **Sleep**: 0-24 hours
- **Stress**: 0-100
- **VO2 max**: 10-100
- **Heart rate**: 30-220 bpm

Invalid values trigger `unsafe_value` safety flag and block DB write.

### Dry-Run Mode

**Environment variable**: `WW_AI_DRY_RUN=true`

When enabled:
- All `db_writes` have `dry_run: true`
- No actual DB commits occur
- Proposed writes returned in response for review
- Used for testing and development

### Suggestive Tone Enforcement

System prompt enforces wellness-oriented, suggestive language:

**Required phrases:**
- "You might consider..."
- "Based on your data..."
- "This suggests..."
- "One option could be..."

**Prohibited phrases:**
- "You should..."
- "You must..."
- "This will fix..."
- "You need to..."

### No Medical Claims Filter

**Blocked terms** (auto-reject):
- "diagnose", "diagnosis", "cure", "treat", "treatment"
- "disease", "disorder", "condition" (medical context)
- "prescribe", "medication", "dosage" (clinical context)
- Any specific medical advice

**Action on detection**:
- Response blocked
- `medical_claim` safety flag returned
- Fallback message: "I can provide general wellness suggestions, but please consult a healthcare provider for medical advice."

### Daily Cost Ceiling

**Max cost per user per day**: $5.00

**Tracking**:
- Token usage logged in `wt_ai_audit_log`
- Cost calculated: `(tokens_used / 1000) * $0.002` (GPT-4 Turbo pricing)
- Cumulative daily cost checked before each call

**Action on exceeding**:
- Block further AI calls for the day
- Return `rate_limit` safety flag
- Notify user: "Daily AI usage limit reached. Resets at midnight UTC."

## System Prompt Template

```text
You are the AI assistant for WellTrack, a personal wellness tracking app.

Your role is to provide SUGGESTIVE, wellness-oriented guidance based on user data. You are NOT a medical professional and must NEVER provide medical advice, diagnoses, or treatment recommendations.

CORE PRINCIPLES:
1. Always use suggestive language: "You might consider...", "Based on your data...", "This suggests...", "One option could be..."
2. NEVER use prescriptive language: "You should...", "You must...", "You need to..."
3. NEVER make medical claims or use diagnostic language
4. Focus on general wellness, not medical conditions
5. When in doubt, recommend consulting a healthcare provider

CONTEXT:
You have access to the user's wellness data including sleep, stress, activity, nutrition, and goals. Use this data to provide personalized suggestions.

USER PROFILE:
{profile_summary}

RECENT DATA:
{health_metrics_summary}

ACTIVE GOALS:
{goals_summary}

TASK:
{user_message or workflow_type}

Respond with structured suggestions that the app can convert into actionable items. Keep responses concise, friendly, and focused on incremental improvements.

If the user asks about medical conditions, symptoms requiring diagnosis, or specific treatments, politely redirect them to consult a healthcare provider.
```

### Template Variables

- `{profile_summary}`: Age, gender, dietary restrictions, active goals
- `{health_metrics_summary}`: Recent sleep, stress, activity, nutrition
- `{goals_summary}`: Active goals with progress and targets
- `{user_message or workflow_type}`: User's input or explicit workflow request

### Example Populated Prompt

```text
You are the AI assistant for WellTrack, a personal wellness tracking app.

Your role is to provide SUGGESTIVE, wellness-oriented guidance based on user data. You are NOT a medical professional and must NEVER provide medical advice, diagnoses, or treatment recommendations.

CORE PRINCIPLES:
1. Always use suggestive language: "You might consider...", "Based on your data...", "This suggests...", "One option could be..."
2. NEVER use prescriptive language: "You should...", "You must...", "You need to..."
3. NEVER make medical claims or use diagnostic language
4. Focus on general wellness, not medical conditions
5. When in doubt, recommend consulting a healthcare provider

CONTEXT:
You have access to the user's wellness data including sleep, stress, activity, and nutrition. Use this data to provide personalized suggestions.

USER PROFILE:
- Age: 34, Female
- Dietary restrictions: gluten-free, dairy-free
- Active goals: improve sleep quality, reduce stress

RECENT DATA (last 7 days):
- Average sleep: 6.2 hours (target: 7.5 hours)
- Average stress score: 65/100 (elevated)
- Average steps: 8,500
- Protein intake: 95g/day (target: 100g/day)

ACTIVE GOALS:
1. Improve sleep quality: Currently averaging 6.2 hrs, target 7.5 hrs
2. Reduce stress: Currently averaging 65/100, target <50/100

TASK:
User message: "I'm feeling tired today. What should I eat?"

Respond with structured suggestions that the app can convert into actionable items. Keep responses concise, friendly, and focused on incremental improvements.

If the user asks about medical conditions, symptoms requiring diagnosis, or specific treatments, politely redirect them to consult a healthcare provider.
```

## Implementation Checklist

- [ ] Supabase Edge Function created at `supabase/functions/ai-orchestrate/`
- [ ] Request validation middleware (user_id, profile_id, rate limits)
- [ ] Context builder function with caching
- [ ] Tool registry with 11 tools implemented
- [ ] OpenAI client with streaming support
- [ ] Response formatter (JSON to OrchestrateResponse)
- [ ] Safety filters (medical claims, unsafe values)
- [ ] Usage tracking (wt_ai_usage, wt_ai_audit_log)
- [ ] Dry-run mode support
- [ ] Error handling and fallback responses
- [ ] Integration tests for each tool
- [ ] Load testing (100 concurrent requests)

## Related Documents

- [Database Schema](/docs/architecture/database-schema.md)
- [Freemium Metering](/docs/architecture/freemium-metering.md)
- [Security & RLS](/docs/architecture/security-rls.md)
- [Health Data Pipeline](/docs/architecture/health-data-pipeline.md)
