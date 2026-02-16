-- Migration: Performance Engine Tables
-- WellTrack Phase 1b
-- Creates: wt_baselines, wt_training_loads, wt_recovery_scores, wt_forecasts, wt_webhook_events
-- Alters: wt_health_metrics (adds validation_status, ingestion_source_version, processing_status)

-- ============================================================================
-- New Enums for Performance Engine
-- ============================================================================

CREATE TYPE wt_calibration_status AS ENUM (
  'pending',
  'in_progress',
  'complete'
);

CREATE TYPE wt_load_type AS ENUM (
  'cardio',
  'strength',
  'mixed'
);

CREATE TYPE wt_validation_status AS ENUM (
  'raw',
  'validated',
  'rejected'
);

CREATE TYPE wt_processing_status AS ENUM (
  'pending',
  'processed',
  'error'
);

CREATE TYPE wt_webhook_status AS ENUM (
  'pending',
  'processing',
  'completed',
  'failed',
  'dead_letter'
);

CREATE TYPE wt_forecast_model AS ENUM (
  'linear_regression'
);

-- ============================================================================
-- ALTER wt_health_metrics: Add validation and processing columns
-- ============================================================================

ALTER TABLE public.wt_health_metrics
  ADD COLUMN IF NOT EXISTS validation_status wt_validation_status NOT NULL DEFAULT 'raw',
  ADD COLUMN IF NOT EXISTS ingestion_source_version text,
  ADD COLUMN IF NOT EXISTS processing_status wt_processing_status NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS is_primary boolean NOT NULL DEFAULT false;

-- Index for finding unprocessed metrics
CREATE INDEX IF NOT EXISTS idx_health_metrics_processing
  ON public.wt_health_metrics(processing_status)
  WHERE processing_status = 'pending';

-- Index for primary records used in insights
CREATE INDEX IF NOT EXISTS idx_health_metrics_primary
  ON public.wt_health_metrics(profile_id, metric_type, start_time)
  WHERE is_primary = true;

COMMENT ON COLUMN public.wt_health_metrics.validation_status IS 'Data quality status: raw (unvalidated), validated (range-checked), rejected (out of range)';
COMMENT ON COLUMN public.wt_health_metrics.ingestion_source_version IS 'API version that produced the data (e.g., garmin-v2, healthconnect-34)';
COMMENT ON COLUMN public.wt_health_metrics.processing_status IS 'Pipeline status: pending (awaiting processing), processed (complete), error (failed)';
COMMENT ON COLUMN public.wt_health_metrics.is_primary IS 'Primary record for this profile+metric+date used in insights (one per combo)';

-- ============================================================================
-- Table: wt_baselines
-- Purpose: 14-day baseline calibration data per metric per profile
-- ============================================================================
CREATE TABLE public.wt_baselines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  metric_type wt_metric_type NOT NULL,
  baseline_value numeric(12,4),
  data_points_count int NOT NULL DEFAULT 0,
  capture_start timestamptz,
  capture_end timestamptz,
  is_complete boolean NOT NULL DEFAULT false,
  calibration_status wt_calibration_status NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_baseline_per_profile_metric UNIQUE(profile_id, metric_type)
);

-- Indexes
CREATE INDEX idx_baselines_profile_status
  ON public.wt_baselines(profile_id, calibration_status);

-- Enable RLS
ALTER TABLE public.wt_baselines ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own baselines"
  ON public.wt_baselines FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own baselines"
  ON public.wt_baselines FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own baselines"
  ON public.wt_baselines FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete their own baselines"
  ON public.wt_baselines FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- Trigger
CREATE TRIGGER set_updated_at_wt_baselines
  BEFORE UPDATE ON public.wt_baselines
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.wt_baselines IS '14-day baseline calibration per metric per profile. Locked once complete.';

-- ============================================================================
-- Table: wt_training_loads
-- Purpose: Training load per workout (duration x intensity_factor)
-- ============================================================================
CREATE TABLE public.wt_training_loads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  workout_id uuid REFERENCES public.wt_workouts(id) ON DELETE SET NULL,
  load_date date NOT NULL DEFAULT CURRENT_DATE,
  duration_minutes numeric(8,2) NOT NULL,
  intensity_factor numeric(4,2) NOT NULL DEFAULT 1.0,
  training_load numeric(10,2) GENERATED ALWAYS AS (duration_minutes * intensity_factor) STORED,
  load_type wt_load_type NOT NULL DEFAULT 'mixed',
  avg_hr_bpm numeric(5,1),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_training_loads_profile_date
  ON public.wt_training_loads(profile_id, load_date);
CREATE INDEX idx_training_loads_profile_date_range
  ON public.wt_training_loads(profile_id, load_date DESC);

-- Enable RLS
ALTER TABLE public.wt_training_loads ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own training loads"
  ON public.wt_training_loads FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own training loads"
  ON public.wt_training_loads FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own training loads"
  ON public.wt_training_loads FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete their own training loads"
  ON public.wt_training_loads FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- Trigger
CREATE TRIGGER set_updated_at_wt_training_loads
  BEFORE UPDATE ON public.wt_training_loads
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.wt_training_loads IS 'Per-workout training load. training_load = duration_minutes * intensity_factor (generated column).';
COMMENT ON COLUMN public.wt_training_loads.intensity_factor IS 'Intensity multiplier: 0.5 (easy) to 1.5 (HIIT). Derived from HR zones or activity type.';

-- ============================================================================
-- Table: wt_recovery_scores
-- Purpose: Daily composite recovery score
-- Formula: (stress_norm * 0.25) + (sleep_norm * 0.30) + (hr_norm * 0.20) + (load_norm * 0.25)
-- ============================================================================
CREATE TABLE public.wt_recovery_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  score_date date NOT NULL DEFAULT CURRENT_DATE,
  stress_component numeric(5,2),
  sleep_component numeric(5,2),
  hr_component numeric(5,2),
  load_component numeric(5,2),
  recovery_score numeric(5,2) NOT NULL,
  components_available int NOT NULL DEFAULT 4,
  raw_data jsonb DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_recovery_per_profile_date UNIQUE(profile_id, score_date),
  CONSTRAINT recovery_score_range CHECK (recovery_score >= 0 AND recovery_score <= 100)
);

-- Indexes
CREATE INDEX idx_recovery_scores_profile_date
  ON public.wt_recovery_scores(profile_id, score_date DESC);

-- Enable RLS
ALTER TABLE public.wt_recovery_scores ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own recovery scores"
  ON public.wt_recovery_scores FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own recovery scores"
  ON public.wt_recovery_scores FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own recovery scores"
  ON public.wt_recovery_scores FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete their own recovery scores"
  ON public.wt_recovery_scores FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- Trigger
CREATE TRIGGER set_updated_at_wt_recovery_scores
  BEFORE UPDATE ON public.wt_recovery_scores
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.wt_recovery_scores IS 'Daily composite recovery score. Formula: stress(0.25) + sleep(0.30) + HR(0.20) + load(0.25). Pro-gated feature.';
COMMENT ON COLUMN public.wt_recovery_scores.components_available IS 'Number of components with data (4 = all, fewer = weight redistributed)';

-- ============================================================================
-- Table: wt_forecasts
-- Purpose: Deterministic goal forecasts using linear regression
-- ============================================================================
CREATE TABLE public.wt_forecasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  goal_forecast_id uuid REFERENCES public.wt_goal_forecasts(id) ON DELETE SET NULL,
  metric_type wt_metric_type NOT NULL,
  current_value numeric(12,4),
  target_value numeric(12,4) NOT NULL,
  slope numeric(12,6),
  intercept numeric(12,4),
  r_squared numeric(5,4),
  projected_date date,
  confidence numeric(5,2),
  data_points int NOT NULL DEFAULT 0,
  model_type wt_forecast_model NOT NULL DEFAULT 'linear_regression',
  calculated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_forecasts_profile_metric
  ON public.wt_forecasts(profile_id, metric_type);
CREATE INDEX idx_forecasts_goal
  ON public.wt_forecasts(goal_forecast_id)
  WHERE goal_forecast_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.wt_forecasts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own forecasts"
  ON public.wt_forecasts FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own forecasts"
  ON public.wt_forecasts FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own forecasts"
  ON public.wt_forecasts FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete their own forecasts"
  ON public.wt_forecasts FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- Trigger
CREATE TRIGGER set_updated_at_wt_forecasts
  BEFORE UPDATE ON public.wt_forecasts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE public.wt_forecasts IS 'Deterministic metric forecasts via linear regression. Pro-gated feature.';
COMMENT ON COLUMN public.wt_forecasts.slope IS 'Rate of change per day (e.g., mL/kg/min per day for VO2 max)';
COMMENT ON COLUMN public.wt_forecasts.r_squared IS 'Coefficient of determination (0-1). Confidence = r_squared * 100.';

-- ============================================================================
-- Table: wt_webhook_events
-- Purpose: Async webhook processing queue. Never process webhooks inline.
-- ============================================================================
CREATE TABLE public.wt_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  garmin_user_id text,
  strava_athlete_id text,
  status wt_webhook_status NOT NULL DEFAULT 'pending',
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 5,
  last_error text,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  next_retry_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT valid_webhook_source CHECK (source IN ('garmin', 'strava'))
);

-- Indexes for worker pickup (pending events ready for processing)
CREATE INDEX idx_webhook_events_status_retry
  ON public.wt_webhook_events(status, next_retry_at)
  WHERE status IN ('pending', 'failed');

-- Index for looking up events by source user
CREATE INDEX idx_webhook_events_source_user
  ON public.wt_webhook_events(source, user_id);

-- Index for chronological processing
CREATE INDEX idx_webhook_events_received_at
  ON public.wt_webhook_events(received_at);

-- Index for Garmin user lookup
CREATE INDEX idx_webhook_events_garmin_user
  ON public.wt_webhook_events(garmin_user_id)
  WHERE garmin_user_id IS NOT NULL;

-- Index for Strava athlete lookup
CREATE INDEX idx_webhook_events_strava_athlete
  ON public.wt_webhook_events(strava_athlete_id)
  WHERE strava_athlete_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.wt_webhook_events ENABLE ROW LEVEL SECURITY;

-- RLS: Webhook events are server-managed. Users can only view their own.
-- Insert/update/delete is service_role only (Edge Functions).
CREATE POLICY "Users can view their own webhook events"
  ON public.wt_webhook_events FOR SELECT
  USING (user_id = auth.uid());

-- Service role bypass for Edge Functions (implicit via service_role key)

COMMENT ON TABLE public.wt_webhook_events IS 'Async webhook processing queue. Receive → queue → respond 200 → process later. Never inline.';
COMMENT ON COLUMN public.wt_webhook_events.garmin_user_id IS 'Garmin userId (persists across re-registrations). Used to resolve to auth user.';
COMMENT ON COLUMN public.wt_webhook_events.next_retry_at IS 'Exponential backoff: base_delay * 2^(attempts-1). Base = 60s.';

-- ============================================================================
-- GRANTS
-- ============================================================================

-- Performance engine tables: full CRUD for authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_baselines TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_training_loads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_recovery_scores TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_forecasts TO authenticated;

-- Webhook events: read-only for authenticated (writes via service_role)
GRANT SELECT ON public.wt_webhook_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_webhook_events TO service_role;

-- ============================================================================
-- MIGRATION COMPLETE
-- Total new tables: 5 (wt_baselines, wt_training_loads, wt_recovery_scores,
--                      wt_forecasts, wt_webhook_events)
-- Altered tables: 1 (wt_health_metrics — 4 new columns)
-- New enums: 6 (wt_calibration_status, wt_load_type, wt_validation_status,
--               wt_processing_status, wt_webhook_status, wt_forecast_model)
-- ============================================================================
