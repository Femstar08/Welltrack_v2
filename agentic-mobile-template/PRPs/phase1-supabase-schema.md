# PRP: Phase 1 — Supabase Schema + RLS

## Context
- **Project**: WellTrack — cross-platform wellness app (Flutter + Supabase)
- **Tech Stack**: Flutter/Dart + Supabase (Postgres, Auth, Edge Functions, Storage)
- **Phase**: 1 of 10 — Database foundation
- **Existing State**: 21 `wt_` tables exist in Supabase (meals, recipes, ingredients, supplements, health_metrics, etc.) but lack profile_id support, use text check constraints instead of enums, and are missing many tables needed for the full MVP.

## Strategy
- Drop all 21 existing `wt_` tables (no data to preserve) and recreate with proper structure
- Use `wt_` prefix consistently (matching existing convention)
- Add parent/dependent profile system (wt_profiles with profile_type)
- Use PostgreSQL enum types instead of text check constraints
- Create RLS helper function for profile-scoped access
- Total: 29 wt_ tables across 7 domain-ordered migration files

## Migration Files (7 total)
1. `20260215000001_extensions_and_enums.sql` — Extensions, 13 enum types, utility functions, RLS helper
2. `20260215000002_drop_old_tables.sql` — Drop all 21 existing wt_ tables + their policies/indexes
3. `20260215000003_core_profiles.sql` — wt_users, wt_profiles, wt_profile_modules + auth trigger
4. `20260215000004_meals_recipes_nutrition.sql` — 9 tables: recipes, steps, ingredients, meals, pantry, leftovers, nutrients, targets, breakdown
5. `20260215000005_supplements_workouts.sql` — 6 tables: supplements, logs, protocols, exercises, workouts, workout_logs
6. `20260215000006_health_plans_goals.sql` — 5 tables: health_metrics, health_connections, plans, plan_items, goal_forecasts
7. `20260215000007_daily_insights_reminders_ai.sql` — 6 tables: daily_logs, insights, reminders, ai_usage, ai_audit_log, ai_memory
8. `20260215000008_rls_policies.sql` — All RLS policies for all 29 tables

## Key Design Decisions
1. **Profile-scoped access**: RLS helper `get_profile_ids_for_user()` returns all profile_ids owned by auth.uid(), supporting parent+dependent pattern
2. **Enum types over check constraints**: 13 PostgreSQL enums for type safety and auto-generated client types
3. **Auto-provisioning**: Trigger on auth.users creates wt_users + primary wt_profiles on signup
4. **Dedupe hash**: Auto-generated via trigger on wt_health_metrics for cross-source deduplication
5. **pgvector**: For AI memory embeddings with ivfflat index (graceful fallback if unavailable)

## Validation
- [ ] All 21 old tables dropped without errors
- [ ] All 29 new tables created with correct columns and types
- [ ] All enum types created before table references
- [ ] All FK dependencies satisfied by migration ordering
- [ ] RLS enabled on all 29 tables
- [ ] All policies created (user-scoped, profile-scoped, reference tables)
- [ ] Indexes created for performance-critical queries
- [ ] Triggers attached (updated_at, dedupe_hash, new_user)
- [ ] Seed data inserted (nutrients + exercises)
- [ ] Migration can be applied via `supabase db push`

## Success Criteria
- [ ] `supabase db push` completes without errors
- [ ] All 29 wt_ tables visible in Supabase dashboard
- [ ] RLS policies enforce data isolation between users
- [ ] Auth signup auto-creates user + profile records
- [ ] Health metrics deduplication works via dedupe_hash

## Confidence Score: 9/10
High confidence — standard PostgreSQL schema work with well-documented Supabase patterns. Minor risk around pgvector availability on the hosted instance.
