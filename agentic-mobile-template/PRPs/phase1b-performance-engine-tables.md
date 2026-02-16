# PRP: Phase 1b — Performance Engine Tables

## Project
WellTrack — Performance & Recovery Optimization Engine

## Phase
1b of 12 — Additive migration for performance engine tables

## Why
Phase 1 delivered 29 core tables. The revised spec adds a performance engine (recovery scores, training loads, forecasts, baselines) and webhook queue. These must exist before Phase 3+ can write performance data.

## Strategy
Single additive migration (000009). No breaking changes to existing tables. ALTER for wt_health_metrics adds columns with defaults so existing rows are unaffected.

## Deliverables
- 5 new tables: wt_baselines, wt_training_loads, wt_recovery_scores, wt_forecasts, wt_webhook_events
- 4 new columns on wt_health_metrics: validation_status, ingestion_source_version, processing_status, is_primary
- 6 new enums: wt_calibration_status, wt_load_type, wt_validation_status, wt_processing_status, wt_webhook_status, wt_forecast_model
- RLS policies on all new tables
- Indexes for query performance
- GRANTS for authenticated and service_role

## Key Design Decisions
- wt_training_loads.training_load is a GENERATED ALWAYS column (duration × intensity_factor) — ensures consistency
- wt_recovery_scores has CHECK constraint (0-100 range) — prevents invalid scores
- wt_webhook_events uses text CHECK instead of enum for source — allows easy extension
- wt_webhook_events is read-only for authenticated users, writable only by service_role (Edge Functions)
- wt_baselines has UNIQUE(profile_id, metric_type) — one baseline per metric per profile

## Validation Checklist
- [ ] Migration applies cleanly on top of existing 8 migrations
- [ ] All 5 new tables created with RLS enabled
- [ ] wt_health_metrics has 4 new columns with correct defaults
- [ ] Existing wt_health_metrics rows unaffected (defaults applied)
- [ ] Foreign keys reference correct existing tables
- [ ] Indexes created for performance
- [ ] Grants match security model

## Success Criteria
- Migration pushes to remote Supabase without errors
- All 34 tables visible (29 existing + 5 new)
- RLS enforces profile-scoped access on new tables
- Generated column (training_load) computes correctly
- CHECK constraint on recovery_score prevents out-of-range values

## Confidence Score
9/10 — Standard additive SQL migration with no breaking changes
