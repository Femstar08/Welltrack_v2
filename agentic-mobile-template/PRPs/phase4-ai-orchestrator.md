# Phase 4 PRP: AI Orchestrator — The Brain

**Project**: WellTrack — Performance & Recovery Optimization Engine
**Phase**: 4 of 12 — AI Orchestrator Edge Function (single entry point)
**Status**: READY FOR IMPLEMENTATION
**Confidence Score**: 8/10
**Date**: 2026-02-15

---

## 1. Overview & Why Now

The AI Orchestrator is the **central brain** of WellTrack. It receives all AI requests from the mobile client, assembles context (user profile, health metrics, plans, memory), routes to appropriate tools, enforces safety checks, applies rate limiting, and returns structured, validated responses.

### Why Build Phase 4 Early?
- **Single Entrypoint**: Prevents scattered AI calls; ensures cost control and safety
- **Evolves with Features**: Tools are added incrementally as features ship (Phase 5+)
- **Foundation for Freemium**: Rate limiting & metering built in from day one
- **Safety by Design**: Medical claims filtered; value validation before any DB write

### MVP Scope
- **Minimal start**: 2 tools (generate_pantry_recipes, summarize_insights) on day 1
- **Tool Registry**: Extensible pattern; add tools incrementally
- **Dry-run mode**: Developers can test without calling OpenAI
- **Cost control**: Context trimming, per-tool token caps, usage metering

---

## 2. Deliverables (Must Have)

### 2.1 Edge Function: `/ai/orchestrate`

**Location**: `supabase/functions/ai-orchestrate/index.ts`

**Request Contract**
```json
{
  "user_id": "uuid",
  "profile_id": "uuid",
  "tool": "generate_pantry_recipes",
  "messages": [
    { "role": "user", "content": "I have chicken, rice, and tomatoes" }
  ],
  "context_snapshot": {
    "pantry_items": ["chicken", "rice", "tomatoes"],
    "health_metrics": { "stress": 45, "sleep": 7.5, "vo2max": 48 },
    "active_goals": [{"name": "calories", "target": 2000, "current": 1400}],
    "preferences": {"cuisine": "asian", "dietary": ["gluten-free"]}
  },
  "dry_run": false
}
```

**Response Contract** (Success)
```json
{
  "success": true,
  "assistant_message": "Here are 5 recipes using your ingredients...",
  "suggested_actions": [
    {
      "action_type": "add_meal",
      "data": {
        "recipe_id": "uuid",
        "servings": 2,
        "estimated_prep_time_mins": 25
      }
    }
  ],
  "db_writes": [
    {
      "table": "wt_recipes",
      "action": "insert",
      "data": {
        "user_id": "uuid",
        "title": "Tomato Chicken Rice",
        "source": "ai_generated",
        "difficulty": "easy"
      },
      "dry_run": false
    }
  ],
  "safety_flags": [],
  "metadata": {
    "tool_used": "generate_pantry_recipes",
    "tokens_used": 187,
    "execution_time_ms": 245,
    "model": "gpt-4o-mini"
  }
}
```

**Response Contract** (Error)
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "error_code": "RATE_LIMIT_EXCEEDED",
  "retry_after_seconds": 3600
}
```

### 2.2 Tool Registry

**Location**: `supabase/functions/ai-orchestrate/tools.ts`

Initial tools (MVP = 2):
1. **generate_pantry_recipes** — Pantry items → Recipe list with nutrition
2. **summarize_insights** — Health metrics + logs → Weekly/monthly narrative
3. **generate_weekly_plan** — User goals + health → Weekly meal/workout/supplement plan
4. **generate_recipe_steps** — Recipe ID → Step-by-step prep with timers
5. **recommend_supplements** — Goals + health metrics → Supplement suggestions
6. **recommend_workouts** — Goals + fitness level → Workout suggestions
7. **update_goals** — User request → Updated nutrition/fitness targets
8. **recalc_goal_forecast** — Historical logs + new goal → ETA to achievement
9. **log_event_suggestion** — Unusual pattern detected → Suggest manual log
10. **extract_recipe_from_url** — URL → Recipe title/servings/ingredients/steps
11. **extract_recipe_from_image** — Image bytes + OCR → Recipe extraction

Each tool definition includes:
- **Schema**: Input parameters & constraints
- **System Instruction**: Tone, disclaimers, output format
- **Token Budget**: Max tokens per tool call
- **Output Validation**: What fields are mandatory, ranges for numeric values
- **Safety Rules**: Medical claim rejection filters, PII redaction

### 2.3 Context Builder

**Location**: `supabase/functions/ai-orchestrate/context-builder.ts`

Assembles user context snapshot (max ~4000 tokens):
```typescript
interface ContextSnapshot {
  user_id: string;
  profile_id: string;
  profile_name: string;
  age: number | null;
  active_modules: string[];
  pantry_items?: string[];
  health_metrics?: {
    stress?: number; // 0-100, null if unavailable
    sleep?: number; // hours, avg last 7 days
    vo2max?: number; // ml/kg/min
    steps?: number; // daily avg last 7 days
    heart_rate?: number; // resting BPM
  };
  active_goals?: Array<{
    id: string;
    name: string;
    target: number;
    current: number;
    unit: string;
    deadline?: string; // ISO date
  }>;
  recent_logs?: Array<{
    log_type: string;
    value: number;
    unit: string;
    logged_at: string;
  }>;
  preferences?: {
    cuisine?: string;
    dietary_restrictions?: string[];
    workout_intensity?: "light" | "moderate" | "intense";
    supplement_preference?: "minimal" | "balanced" | "comprehensive";
  };
  ai_memory?: {
    past_requests?: string[]; // last 5 unique requests (hashed)
    learned_preferences?: Record<string, string>;
    patterns_detected?: string[]; // e.g., "high_stress_correlation_with_poor_sleep"
  };
}
```

**Assembly Logic**:
- **Active modules**: Query `wt_profile_modules` for enabled features
- **Health metrics**: Fetch from `wt_health_metrics` (last 7-30 days, normalized)
- **Goals & progress**: Query `wt_nutrient_targets`, `wt_plans`, `wt_daily_logs`
- **Preferences**: Query `wt_ai_memory` for user preferences & learned patterns
- **Recent logs**: Last 10 logs from `wt_daily_logs` (trimmed to key fields)
- **Token accounting**: Estimate context tokens; truncate if > 4000

### 2.4 Structured JSON Responses

All responses follow the **Orchestrator Response Schema**:

```typescript
interface OrchestratorResponse {
  // User-facing narrative
  assistant_message: string;

  // Suggested actions (app interprets these natively)
  suggested_actions: Array<{
    action_type: string; // "add_meal", "start_workout", "set_reminder"
    data: Record<string, any>; // Tool-specific payload
    confidence?: number; // 0-1, how confident is this suggestion?
  }>;

  // Validated DB writes (app executes via Supabase client RLS)
  db_writes: Array<{
    table: string; // e.g., "wt_recipes"
    action: "insert" | "update" | "delete";
    data: Record<string, any>;
    constraints?: { // Validation before write
      required_fields?: string[];
      value_ranges?: Record<string, [number, number]>;
      enum_values?: Record<string, string[]>;
    };
    dry_run?: boolean; // If true, don't actually execute
  }>;

  // Updated forecast (for goal recalculation)
  updated_forecast?: {
    goal_id: string;
    new_eta_date: string; // ISO date
    confidence: number; // 0-1
    reasoning: string;
  };

  // Safety & compliance flags
  safety_flags: Array<{
    flag: "medical_claim" | "pii_detected" | "invalid_value" | "out_of_bounds";
    message: string;
    severity: "warning" | "error";
  }>;

  // Metadata
  metadata: {
    tool_used: string;
    tokens_used: number;
    execution_time_ms: number;
    model: string;
    context_tokens: number;
  };
}
```

### 2.5 Rate Limiting via `wt_ai_usage`

**Table Schema** (already designed in Phase 1):
```sql
CREATE TABLE wt_ai_usage (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES wt_users(id),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id),
  tool_name TEXT NOT NULL,
  tokens_used INT NOT NULL,
  cost_cents INT, -- for future monetization
  request_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Rate Limiting Rules**:
- **Free tier**: 50 tool calls / day, 10k tokens / day
- **Pro tier**: 500 tool calls / day, 100k tokens / day
- **Enterprise**: Unlimited
- **Per-tool caps**: Some tools (OCR, image extraction) limited to 20/day

**Logic**:
1. Check `wt_ai_usage` for today's usage (aggregated by user_id + date)
2. If exceeded, return `RATE_LIMIT_EXCEEDED` error with `retry_after_seconds`
3. If within limit, log usage AFTER successful response

### 2.6 Audit Logging via `wt_ai_audit_log`

**Table Schema**:
```sql
CREATE TABLE wt_ai_audit_log (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES wt_users(id),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id),
  tool_name TEXT NOT NULL,
  request_summary TEXT, -- first 500 chars of user message
  response_summary TEXT, -- AI response snippet
  safety_flags JSONB, -- any warnings/errors
  db_writes_count INT,
  tokens_used INT,
  execution_time_ms INT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**What Gets Logged**:
- Every request (success or failure)
- Tool name, user ID, profile ID
- First 500 chars of user message (for debugging)
- Response snippet & safety flags
- Token count & execution time

**Purpose**:
- Compliance & debugging
- Cost analysis
- Pattern detection (e.g., unusual usage spikes)

### 2.7 Safety Checks

**Medical Claims Filter**:
- System prompt explicitly forbids medical diagnoses or prescriptions
- Post-response regex check for keywords: ("cure", "treat disease", "prevent disease", "medication")
- If detected, flag as `medical_claim` (severity: error), strip claim from response

**Value Validation**:
- All numeric outputs validated against ranges:
  - Calories per meal: 100–2000
  - Sleep: 4–12 hours
  - Stress: 0–100
  - Heart rate: 40–200 BPM
- Enum values (e.g., workout intensity) checked against allowed values
- If invalid, flag + reject write

**PII Redaction**:
- Remove email addresses, phone numbers from responses
- Flag as `pii_detected` if found in AI output

**Malformed JSON**:
- If OpenAI returns invalid JSON in `db_writes`, reject with error

### 2.8 Dry-Run Mode

**Env Var**: `AI_ORCHESTRATOR_DRY_RUN=true`

**Behavior**:
- All tool calls execute normally
- **Except** DB writes & rate limit logging are marked `dry_run: true`
- Return response as-is (so dev can verify structure)
- No actual database mutations
- No usage metered

**Use Case**:
```bash
# Local dev
AI_ORCHESTRATOR_DRY_RUN=true supabase functions serve
# Test without hitting real DB or OpenAI quota
```

### 2.9 Cost Controls

**Context Trimming**:
- If context > 3500 tokens, trim in priority order:
  1. Keep: user message + health metrics (essential)
  2. Trim: recent logs (keep last 5 only)
  3. Trim: past requests history (keep 3)
  4. Trim: preferences (keep top 3)
  5. Warn user if critical context omitted

**Per-Tool Token Caps**:
- `generate_pantry_recipes`: max 200 tokens
- `summarize_insights`: max 400 tokens
- `extract_recipe_from_image`: max 600 tokens (OCR expensive)
- Others: max 300 tokens

**Fallback**: If cap exceeded, return cached result or simplified response

### 2.10 Suggestive Tone Enforcement

**System Prompt Template**:
```
You are an AI wellness assistant for WellTrack. Your tone is:
- Supportive, not preachy
- Suggestive, not prescriptive ("You might consider..." not "You must...")
- Non-medical (never diagnose or treat diseases)
- Encouraging for small wins

Never:
- Diagnose medical conditions
- Prescribe medications or treatments
- Claim to prevent or cure disease
- Use absolute statements ("will cure", "guaranteed")

Always:
- Use phrases like "consider", "you might", "some evidence suggests"
- Include disclaimers for health-related advice
- Cite data (e.g., "based on your 7-day average")
- Encourage professional consultation for medical concerns
```

---

## 3. Implementation Plan

### Phase 3a: Setup & OpenAI Integration (1–2 days)

1. **Create Edge Function scaffold**
   ```bash
   supabase functions new ai-orchestrate
   ```

2. **Set up OpenAI client**
   - Install `openai` npm package
   - Store API key in Supabase secrets: `OPENAI_API_KEY`
   - Create helper: `createOpenAIClient(apiKey)`

3. **Implement request validation**
   - Verify user JWT
   - Check `user_id` & `profile_id` in token
   - Validate request shape (tool, messages, context_snapshot)

4. **Implement response wrapper**
   - `OrchestratorResponse` type
   - Error responses (rate limit, validation, server error)

### Phase 3b: Context Builder (1 day)

1. **Create context-builder.ts**
   - Query helper for each data type (health metrics, goals, logs, etc.)
   - Implement token estimation (rough: 1 token ≈ 0.75 words)
   - Implement trimming logic

2. **Test context assembly**
   - Unit test: verify context structure
   - Unit test: verify token cap enforcement

### Phase 3c: Tool Registry (2 days)

1. **Create tools.ts**
   - Define `Tool` interface (name, schema, system instruction, token budget, output validation)
   - Implement 2 MVP tools:
     - `generate_pantry_recipes`
     - `summarize_insights`
   - Stub remaining 9 tools (accept request, return placeholder)

2. **Implement tool dispatcher**
   ```typescript
   function callTool(tool: Tool, context: ContextSnapshot, messages: Message[]): Promise<any>
   ```

3. **Test tool calls**
   - Unit test: mock OpenAI responses
   - Dry-run test: verify response structure

### Phase 3d: Rate Limiting & Metering (1 day)

1. **Implement rate limit checker**
   - Query `wt_ai_usage` for today (aggregated)
   - Compare against tier limits (free 50/day, pro 500/day)
   - Return retry-after if exceeded

2. **Implement usage logger**
   - Insert record into `wt_ai_usage` after successful call
   - Include tokens_used, cost_cents (optional)

3. **Test rate limiting**
   - Unit test: verify limit is enforced
   - Unit test: verify retry-after calculation

### Phase 3e: Audit Logging (1 day)

1. **Implement audit logger**
   - Insert record into `wt_ai_audit_log` for every request
   - Capture request summary, response summary, safety flags, metrics

2. **Test audit logging**
   - Verify record created for each request
   - Verify no PII in summaries

### Phase 3f: Safety Checks (1 day)

1. **Implement medical claims filter**
   - Regex for forbidden keywords
   - Post-response check; flag + strip if detected

2. **Implement value validation**
   - For each `db_writes[]` item, validate against constraints
   - Flag invalid values; reject write

3. **Implement PII redaction**
   - Check response for email/phone patterns
   - Redact or flag

4. **Test safety**
   - Unit test: medical claim is caught & flagged
   - Unit test: invalid numeric value is rejected
   - Unit test: PII is redacted

### Phase 3g: Integration & E2E (1–2 days)

1. **Integration test: full orchestrator flow**
   - Mock user, profile, context
   - Call `/ai/orchestrate` with valid request
   - Verify response structure, rate limiting, audit log

2. **E2E test: dry-run mode**
   - Set `AI_ORCHESTRATOR_DRY_RUN=true`
   - Verify no DB mutations

3. **E2E test: rate limit scenario**
   - Manually fill `wt_ai_usage` table
   - Call orchestrator; verify rate limit error

4. **Deploy to staging**
   - Verify Edge Function deploys
   - Test with real OpenAI (low-volume)

---

## 4. Success Criteria

- [ ] `/ai/orchestrate` endpoint exists and responds to valid requests
- [ ] Request validation passes for valid input, rejects invalid
- [ ] Context builder assembles snapshot with all required fields
- [ ] 2 MVP tools (pantry recipes, summarize insights) work end-to-end
- [ ] Responses conform to `OrchestratorResponse` schema
- [ ] Rate limiting enforced (free tier 50/day, pro 500/day)
- [ ] All requests logged to `wt_ai_audit_log`
- [ ] Medical claims filter catches > 90% of disallowed phrases
- [ ] Invalid numeric values rejected (safety check)
- [ ] Dry-run mode prevents DB mutations
- [ ] Response time < 5 seconds (including OpenAI latency)
- [ ] No PII in audit logs
- [ ] Suggestive tone enforced (system prompt + output validation)
- [ ] Token counting accurate (within ±10%)
- [ ] Code coverage > 85% (unit + integration tests)

---

## 5. Failure Prevention & Known Risks

| Risk | Mitigation |
|------|-----------|
| OpenAI rate limit hit | Implement exponential backoff; cache common responses |
| Context too large | Token trimming with priority order; warn user if critical data omitted |
| Invalid DB writes crash app | All writes validated against schema before returning; dry-run mode catches issues |
| Medical claims slip through | Regex filter + manual review of top 10 responses in staging |
| PII leaked in logs | Redaction before any write to audit log; automated PII scan on merge |
| Rate limit evaded | Check aggregated usage daily; per-tool caps prevent OCR abuse |
| Slow response | Context trimming; token budget per tool; OpenAI streaming (future optimization) |
| Dry-run mode forgotten in prod | Clear env var documentation; CI check for production deployment |

---

## 6. Dependencies & Prerequisites

**Must Be Complete Before Starting**:
- [x] Phase 1: Supabase schema + RLS (tables: `wt_ai_usage`, `wt_ai_audit_log`, `wt_ai_memory`)
- [x] Phase 2: Flutter auth + offline engine (JWT token available)
- [ ] Supabase project created & secrets configured (OPENAI_API_KEY)

**Nice to Have**:
- Phase 3: Health metrics pipeline (for context assembly)
- Sample user data in dev database

---

## 7. Test Plan

### Unit Tests
- `context-builder.test.ts`: Token estimation, context trimming, data assembly
- `tools.test.ts`: Tool schema validation, mock OpenAI responses
- `rate-limiter.test.ts`: Limit enforcement, retry-after calculation
- `safety.test.ts`: Medical claim detection, PII redaction, value validation

### Integration Tests
- Full orchestrator flow: request → context → tool call → response → audit log
- Rate limit scenario: exceed quota, verify error
- Dry-run mode: verify no DB mutations
- Multiple tools in sequence

### E2E Tests
- Deploy to staging; test with real OpenAI (low-volume API key)
- Verify audit logs written
- Test response latency

**Target Coverage**: > 85% (lines of code)

---

## 8. Rollout Plan

### Week 1: Core Orchestrator
- Edge Function, request validation, response wrapper

### Week 2: Context & Tools
- Context builder, 2 MVP tools (pantry recipes, insights)

### Week 3: Metering & Safety
- Rate limiting, audit logging, safety checks

### Week 4: Testing & Deploy
- Unit + integration tests, dry-run mode, staging deployment

### Week 5+: Iterate
- Add tools incrementally as features ship
- Monitor cost & latency
- Update system prompt based on feedback

---

## 9. Open Questions & Decisions

1. **OpenAI Model Choice**: Using GPT-4o-mini (cost-effective, good quality). Switch to GPT-4 for complex tasks later if needed.
2. **Token Counting**: Using rough estimate (1 token ≈ 0.75 words). May implement `js-tiktoken` for accuracy if needed.
3. **Streaming Responses**: MVP uses request-response. Streaming (for long narratives) added in Phase 5+.
4. **Webhook-Based Triggers**: AI only responds to explicit user requests in MVP. Scheduled insights (e.g., weekly summary) added later.
5. **Tool Execution Order**: Sequential in MVP. Parallel execution (if safe) added later for latency optimization.

---

## 10. Sign-Off

**Prepared by**: AI Orchestration Team
**Date**: 2026-02-15
**Status**: APPROVED FOR IMPLEMENTATION
**Confidence**: 8/10 — Well-defined contract, straightforward OpenAI integration, clear validation rules

**Next Steps**:
1. Create Supabase secrets (OPENAI_API_KEY)
2. Set up local Edge Function dev environment
3. Begin Phase 3a (setup & OpenAI integration)
