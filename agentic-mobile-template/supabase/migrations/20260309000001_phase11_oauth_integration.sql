-- Migration: Phase 11 OAuth Integration — Schema Gaps
-- WellTrack Phase 11 (Garmin + Strava direct integration)
--
-- Fills three gaps identified by auditing the webhook Edge Functions
-- against the existing schema:
--
--   1. wt_webhook_events missing strava_object_id column
--      — webhook-strava/index.ts inserts it but the column was never created
--
--   2. wt_metric_type enum missing body_battery
--      — Garmin-exclusive metric; referenced by process-webhooks function
--
--   3. wt_health_connections missing expression indexes on connection_metadata
--      — both Edge Functions filter by connection_metadata->>'garmin_user_id'
--        and connection_metadata->>'athlete_id'; without indexes these are
--        sequential scans that will slow webhook user resolution under load
--
-- All changes are fully idempotent (safe to run multiple times).
-- ============================================================================

-- ============================================================================
-- 1. Add strava_object_id to wt_webhook_events
-- ============================================================================
-- The Strava webhook payload carries object_id (the Strava activity/athlete ID).
-- The full activity must be fetched from the Strava API during async processing,
-- so storing the raw object_id at queue time is required by process-webhooks.
-- webhook-strava/index.ts already inserts this column — schema must match.

ALTER TABLE public.wt_webhook_events
  ADD COLUMN IF NOT EXISTS strava_object_id text;

COMMENT ON COLUMN public.wt_webhook_events.strava_object_id IS
  'Strava object_id from the webhook payload (activity or athlete ID). '
  'Full details fetched from Strava API during async processing.';

-- Index for looking up queued events by Strava object (e.g. deduplication checks)
CREATE INDEX IF NOT EXISTS idx_webhook_events_strava_object
  ON public.wt_webhook_events(strava_object_id)
  WHERE strava_object_id IS NOT NULL;

-- ============================================================================
-- 2. Add body_battery to wt_metric_type enum
-- ============================================================================
-- Garmin Body Battery is an energy-reserve score (0–100) computed from HRV,
-- stress, sleep, and activity data. It is a Garmin-exclusive metric not
-- available through Health Connect; it arrives only via the direct Garmin
-- webhook. Adding it to wt_metric_type allows wt_health_metrics rows to
-- store it with proper typing alongside vo2max, stress, hrv, etc.

DO $$
BEGIN
  ALTER TYPE public.wt_metric_type ADD VALUE 'body_battery';
EXCEPTION
  WHEN duplicate_object THEN
    -- Value already present; nothing to do.
    NULL;
END $$;

-- ============================================================================
-- 3. Expression indexes on wt_health_connections.connection_metadata
-- ============================================================================
-- Both webhook Edge Functions resolve an external provider ID to an auth user
-- by querying wt_health_connections with a JSONB text extraction filter:
--
--   Garmin:  .eq('connection_metadata->>garmin_user_id', garminUserId)
--   Strava:  .eq('connection_metadata->>athlete_id', ownerId)
--
-- These are invoked on every inbound webhook event. Without expression indexes
-- PostgreSQL falls back to a sequential scan of all connections rows.
-- Partial WHERE clauses limit the index to rows for each provider, keeping
-- index size and maintenance overhead small.

CREATE INDEX IF NOT EXISTS idx_health_connections_garmin_user_id
  ON public.wt_health_connections((connection_metadata->>'garmin_user_id'))
  WHERE provider = 'garmin';

CREATE INDEX IF NOT EXISTS idx_health_connections_strava_athlete_id
  ON public.wt_health_connections((connection_metadata->>'athlete_id'))
  WHERE provider = 'strava';

-- ============================================================================
-- MIGRATION COMPLETE
-- Changes:
--   wt_webhook_events  — 1 new column (strava_object_id), 1 new index
--   wt_metric_type     — 1 new enum value (body_battery)
--   wt_health_connections — 2 new expression indexes
-- ============================================================================
