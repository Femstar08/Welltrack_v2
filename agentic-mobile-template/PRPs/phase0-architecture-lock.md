# Product Requirements Prompt: Phase 0 — Architecture Lock

## Project Information
- **Project**: WellTrack
- **Phase**: 0 — Architecture Lock
- **Type**: Design & Documentation
- **Created**: 2026-02-15
- **Status**: Planning

## Why This Phase Exists

Phase 0 prevents costly rework by defining all system relationships, contracts, data flows, and mathematical formulas before any code is written. This architecture lock ensures:

1. **No Ambiguity**: Every data flow, integration point, and calculation is documented
2. **No Rework**: Decisions are validated early, preventing late-stage architectural changes
3. **Team Alignment**: All stakeholders understand system behavior before implementation
4. **Testable Design**: Formulas and contracts are documented with test cases
5. **Scalable Foundation**: Architecture supports modular growth and feature toggles

This is a **document-first approach**: architecture documents are the source of truth, and implementation follows the spec exactly.

## Deliverables

Phase 0 produces 8 critical architecture documents:

### 1. Entity-Relationship (ER) Diagram
**File**: `docs/architecture/er-diagram.md` + visual (Mermaid or draw.io)

**Contents**:
- All `wt_` tables with columns, types, constraints
- Primary keys, foreign keys, indexes
- RLS policy annotations
- Cardinality (1:1, 1:N, N:M)
- Table groupings (Core, Health, AI, Plans, etc.)

**Validation**:
- Every table from CLAUDE.md appears in diagram
- All foreign keys have matching parent tables
- Indexes cover query patterns from AI orchestrator
- RLS policies enforce profile-scoped data access

### 2. Health Metric Mapping & Normalization Schema
**File**: `docs/architecture/health-metric-mapping.md`

**Contents**:
- Source mapping table (Health Connect, HealthKit, Garmin, Strava -> `wt_health_metrics`)
- Deduplication strategy (dedupe_hash formula, conflict resolution rules)
- Top 3 metrics (Stress, Sleep, VO2 max) with source priority
- Unit normalization (e.g., HR in BPM, VO2 max in mL/kg/min, Sleep in minutes)
- Null handling rules (missing Stress = null, never proxy)
- Sample payloads for each source

**Validation**:
- Stress from Garmin only (0-100, store as-is or null)
- Sleep deduplication by start/end time with source priority
- VO2 max from Garmin/Strava preferred, HealthKit/Health Connect optional
- All sources map to `wt_health_metrics` schema

### 3. AI Orchestrator Contract
**File**: `docs/architecture/ai-orchestrator-contract.md`

**Contents**:
- API endpoint specification (`/ai/orchestrate`)
- Request schema (user_id, profile_id, context_snapshot, user_message, workflow_type)
- Response schema (assistant_message, suggested_actions[], db_writes[], updated_forecast, safety_flags)
- Tool registry (12 tools with input/output contracts)
- Context snapshot structure (profile state, health metrics, active goals, recent logs)
- Rate limiting & metering rules (freemium daily caps)
- Error codes & retry logic

**Validation**:
- Every tool has documented inputs, outputs, side effects
- Context snapshot includes normalized health metrics
- Freemium limits enforced server-side (wt_ai_usage table)
- Safety flags prevent harmful or off-spec suggestions

### 4. Module Dependency Map
**File**: `docs/architecture/module-dependency-map.md`

**Contents**:
- Dependency graph for 11 MVP modules
- Hard dependencies (e.g., Insights depends on all logging modules)
- Soft dependencies (e.g., Workouts can suggest based on Activity/Sleep if enabled)
- Toggle propagation rules (disabling a module hides dependent UI but preserves data)
- Shared services (auth, offline engine, health sync)

**Validation**:
- No circular dependencies
- Core modules (Profiles, Daily View) always enabled
- Disabling a module doesn't break app navigation
- Data persists even when module is toggled off

### 5. Event Flow Diagram
**File**: `docs/architecture/event-flow-diagram.md`

**Contents**:
- User action triggers (e.g., "Log meal", "Sync health data", "Generate plan")
- Offline-first flow (local write -> queue -> background sync)
- Webhook ingestion flow (Garmin/Strava push -> queue -> dedupe -> normalize -> insights)
- AI orchestration flow (user chat -> context assembly -> tool execution -> response)
- Conflict resolution flow (offline edit + server edit -> merge strategy)

**Validation**:
- All writes work offline and sync later
- Webhooks never block user actions (queue-based)
- Conflicts are resolvable (last-write-wins or user prompt)
- AI calls are async and cancellable

### 6. Performance Engine Design
**File**: `docs/architecture/performance-engine-design.md`

**Contents**:
- **Composite Recovery Score Formula**: Weighted avg of Sleep Quality (40%), HRV (30%), Resting HR (20%), Stress (10%)
- **Training Load Formula**: Weekly volume × intensity factor
- **Readiness Score**: Recovery - Training Load fatigue decay
- **Baseline Calibration**: 14-day rolling avg per metric
- **Trend Detection**: 7-day slope + statistical significance test
- **Performance vs Recovery Matrix**: 2x2 grid (High/Low Performance × High/Low Recovery)
- **AI Narrative Layer**: Deterministic scores + GPT-4 natural language summary

**Validation**:
- Formulas are deterministic (same inputs = same outputs)
- Baseline requires 14 days of data before scores are shown
- Missing metrics degrade gracefully (e.g., no HRV -> adjust weights)
- AI narrative is suggestive, never prescriptive

### 7. VO2 Max Data Flow
**File**: `docs/architecture/vo2max-data-flow.md`

**Contents**:
- Source priority: Garmin > Strava > HealthKit > Health Connect
- Ingestion flow (OAuth -> webhook/polling -> raw_payload_json -> normalized value)
- Deduplication by recorded_at timestamp (±1 hour window)
- Trend calculation (30-day moving avg, 90-day trend line)
- Goal forecasting integration (VO2 max improvement -> adjusted plan timeline)

**Validation**:
- Multiple sources don't create duplicate records
- Trend calculation handles sparse data (weekly VO2 max tests)
- Improvement rate feeds into AI plan adjustments

### 8. Webhook Queue Architecture
**File**: `docs/architecture/webhook-queue-architecture.md`

**Contents**:
- Queue table schema (`wt_webhook_queue`: id, source, event_type, payload_json, status, retry_count, created_at, processed_at)
- Processing flow: receive -> enqueue -> background worker -> dedupe -> normalize -> insert wt_health_metrics
- Retry logic: exponential backoff, max 5 retries, dead letter queue for failures
- Idempotency: dedupe_hash prevents duplicate processing
- Monitoring: queue depth alerts, processing lag metrics

**Validation**:
- Webhook endpoints return 200 immediately (no blocking DB writes)
- Background worker processes queue in FIFO order
- Failed events are retryable without data loss
- Queue depth monitored for backpressure

## Strategy: Document-First Approach

1. **Create All 8 Documents**: Complete architecture specs before writing code
2. **Cross-Reference**: Ensure consistency across docs (e.g., ER diagram matches metric mapping)
3. **Review & Validate**: Stakeholder review of all docs with validation checklists
4. **Lock Architecture**: Freeze design decisions; changes require formal review
5. **Implementation Follows Spec**: Code must match architecture docs exactly
6. **Test Against Spec**: Unit tests validate formulas, integration tests validate flows

## Key Design Decisions

### 1. Performance Engine is Deterministic Math + AI Narrative
- **Deterministic Layer**: Formulas produce repeatable scores for testing and debugging
- **AI Narrative Layer**: GPT-4 translates scores into actionable, personalized insights
- **Why**: Separates testable math from creative AI; prevents "black box" decisions

### 2. Suggestive, Never Prescriptive
- AI outputs are suggestions with user confirmation required
- No automated changes to workouts, meals, or goals without user approval
- Safety flags prevent harmful suggestions (e.g., excessive training load)
- **Why**: User agency + liability protection + App Store compliance

### 3. Webhook Queue (Never Inline)
- All webhook ingestion is async via queue table
- Endpoints return 200 immediately, process later
- **Why**: Prevents timeout failures, handles traffic spikes, enables retry logic

### 4. Baseline Calibration (14-Day Minimum)
- Performance scores require 14 days of data for personalized baseline
- Before baseline: show raw metrics only, no composite scores
- **Why**: Prevents misleading scores from insufficient data; establishes individual norms

### 5. Composite Recovery Score
- Formula: `(Sleep * 0.4) + (HRV * 0.3) + (RestingHR * 0.2) + (Stress * 0.1)`
- Each metric normalized to 0-100 scale relative to user's baseline
- Missing metrics redistribute weights proportionally
- **Why**: Evidence-based weights from sports science literature; adaptable to available data

### 6. Stress from Garmin Only
- Do not derive stress proxies from HR or HRV
- Store null if Garmin Stress Score unavailable
- **Why**: Proxy metrics are unreliable and misleading; better to have no data than bad data

### 7. Deduplication by Time Window + Source Priority
- Sleep: ±30 min start/end window, prefer most detailed record (stages > duration only)
- VO2 max: ±1 hour window, prefer Garmin > Strava > HealthKit
- **Why**: Multiple sources create duplicates; priority rules ensure best data quality

### 8. Offline-First with Conflict Resolution
- All writes succeed locally (Isar/Hive), sync in background
- Conflicts resolved by last-write-wins or user prompt (configurable per data type)
- **Why**: App must work without connectivity; wellness logging is time-sensitive

## Validation Checklist

### Phase 0 Completion Criteria
- [ ] All 8 architecture documents created and committed to `docs/architecture/`
- [ ] ER diagram includes all `wt_` tables from CLAUDE.md
- [ ] Health metric mapping covers all 4 sources (Health Connect, HealthKit, Garmin, Strava)
- [ ] AI orchestrator contract defines all 12 tool signatures
- [ ] Module dependency map shows no circular dependencies
- [ ] Event flow diagram covers offline-first + webhook + AI flows
- [ ] Performance engine formulas documented with test cases
- [ ] VO2 max data flow includes deduplication and trend calculation
- [ ] Webhook queue architecture includes retry logic and monitoring

### Cross-Document Consistency
- [ ] Table names in ER diagram match health metric mapping schema
- [ ] AI orchestrator context snapshot includes metrics from health metric mapping
- [ ] Event flows reference correct table names from ER diagram
- [ ] Module dependencies align with AI tool capabilities
- [ ] Performance engine formulas reference correct health metric fields

### Testability
- [ ] All formulas have documented test cases (baseline, edge cases, missing data)
- [ ] API contracts include sample requests/responses
- [ ] Deduplication rules have example collision scenarios
- [ ] Conflict resolution strategies have example merge cases

### Stakeholder Review
- [ ] Product owner approves all 8 documents
- [ ] Backend engineer validates DB schema and RLS policies
- [ ] Mobile engineer validates offline-first flows
- [ ] AI engineer validates orchestrator contract and tool registry

## Success Criteria

1. **Architecture Completeness**: All 8 documents exist and pass validation checklist
2. **No Ambiguity**: Every data flow, formula, and integration point is specified
3. **Cross-Reference Integrity**: No conflicts between documents (e.g., table names match)
4. **Testable Design**: Formulas and contracts have documented test cases
5. **Stakeholder Approval**: All reviewers sign off on architecture lock
6. **Implementation Readiness**: Phase 1 (Supabase Schema + RLS) can start immediately after lock

## Confidence Score: 8/10

### Why 8/10
- **High Confidence**: Design phase with no code dependencies; all decisions are research-backed
- **Known Unknowns**: Real-world data variability (e.g., Garmin API edge cases) may require minor adjustments
- **Mitigation**: Architecture allows for additive changes (new metrics, new sources) without breaking existing flows

### Risk Factors
1. **Third-Party API Changes**: Garmin/Strava may change webhook payloads
   - **Mitigation**: Store raw_payload_json for reprocessing; versioned parsers
2. **Formula Validation**: Recovery score weights may need tuning after user testing
   - **Mitigation**: Formulas are configurable; weights stored in `wt_performance_config` table
3. **Scalability**: Webhook queue processing may lag under high load
   - **Mitigation**: Horizontal scaling of background workers; queue depth monitoring

### Confidence Boosters
- Architecture follows Flutter Clean Architecture + Supabase best practices
- Design decisions align with App Store guidelines (user agency, data privacy)
- Offline-first pattern is proven for wellness apps
- Deterministic formulas are testable and debuggable

## Next Steps After Phase 0

1. **Lock Architecture**: Commit all 8 docs, create `ARCHITECTURE_LOCKED.md` manifest
2. **Phase 1 Start**: Implement Supabase schema (tables, RLS, migrations) per ER diagram
3. **Continuous Validation**: Code reviews must reference architecture docs
4. **Architecture Change Process**: Any deviation requires PRP amendment + stakeholder approval

## Related Documents
- [CLAUDE.md](../CLAUDE.md) — Project-wide instructions
- [INITIAL.md](../INITIAL.md) — Original feature request
- [BUILD_PLAN.md](../BUILD_PLAN.md) — 10-phase build order
- `.agent/orchestration/directives/mobile_feature_development.md` — 6-phase process
- `.agent/context/GLOBAL_RULES.md` — Coding standards

---

**Document Status**: Draft
**Requires Review By**: Product Owner, Backend Engineer, Mobile Engineer, AI Engineer
**Estimated Completion**: 3-5 days (research + documentation)
**Blocks**: Phase 1 (Supabase Schema + RLS)
