-- Migration: Health Metrics, Plans, and Goals Tables
-- WellTrack Phase 1
-- Creates: wt_health_metrics, wt_health_connections, wt_plans, wt_plan_items, wt_goal_forecasts
-- Also adds FK from wt_supplement_protocols.linked_goal_id to wt_goal_forecasts

-- ============================================================================
-- Table: wt_health_metrics
-- Purpose: Normalized health data from all connected sources (Apple Health, Fitbit, Oura, etc.)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_health_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  source wt_health_source NOT NULL,
  metric_type wt_metric_type NOT NULL,
  value_num numeric(12,4),
  value_text text,
  unit text NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  recorded_at timestamptz DEFAULT now() NOT NULL,
  raw_payload_json jsonb,
  dedupe_hash text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_health_metrics
CREATE UNIQUE INDEX idx_health_metrics_dedupe ON public.wt_health_metrics(dedupe_hash);
CREATE INDEX idx_health_metrics_profile_type_time ON public.wt_health_metrics(profile_id, metric_type, start_time);
CREATE INDEX idx_health_metrics_source_type_time ON public.wt_health_metrics(source, metric_type, start_time, end_time);

-- Enable RLS
ALTER TABLE public.wt_health_metrics ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wt_health_metrics
CREATE POLICY "Users can view their own health metrics"
  ON public.wt_health_metrics FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own health metrics"
  ON public.wt_health_metrics FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own health metrics"
  ON public.wt_health_metrics FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own health metrics"
  ON public.wt_health_metrics FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at_health_metrics
  BEFORE UPDATE ON public.wt_health_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Trigger for dedupe hash generation
CREATE OR REPLACE FUNCTION public.generate_health_metric_dedupe_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.dedupe_hash := encode(
    digest(
      CONCAT(
        COALESCE(NEW.profile_id::text, ''),
        COALESCE(NEW.source::text, ''),
        COALESCE(NEW.metric_type::text, ''),
        COALESCE(NEW.start_time::text, ''),
        COALESCE(NEW.end_time::text, ''),
        COALESCE(NEW.value_num::text, ''),
        COALESCE(NEW.value_text, '')
      ),
      'sha256'
    ),
    'hex'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_health_metric_dedupe_hash
  BEFORE INSERT OR UPDATE ON public.wt_health_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.generate_health_metric_dedupe_hash();

-- ============================================================================
-- Table: wt_health_connections
-- Purpose: Store OAuth connections and sync status for health data providers
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_health_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  provider wt_health_source NOT NULL,
  access_token_encrypted text,
  refresh_token_encrypted text,
  token_expires_at timestamptz,
  is_connected boolean DEFAULT false NOT NULL,
  last_sync_at timestamptz,
  connection_metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT unique_profile_provider UNIQUE(profile_id, provider)
);

-- Enable RLS
ALTER TABLE public.wt_health_connections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wt_health_connections
CREATE POLICY "Users can view their own health connections"
  ON public.wt_health_connections FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own health connections"
  ON public.wt_health_connections FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own health connections"
  ON public.wt_health_connections FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own health connections"
  ON public.wt_health_connections FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at_health_connections
  BEFORE UPDATE ON public.wt_health_connections
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Table: wt_plans
-- Purpose: Weekly/daily AI-generated health plans
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  plan_type wt_plan_type DEFAULT 'weekly' NOT NULL,
  title text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status wt_plan_status DEFAULT 'draft' NOT NULL,
  ai_generated boolean DEFAULT false NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_plans
CREATE INDEX idx_plans_profile_start_date ON public.wt_plans(profile_id, start_date);

-- Enable RLS
ALTER TABLE public.wt_plans ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wt_plans
CREATE POLICY "Users can view their own plans"
  ON public.wt_plans FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own plans"
  ON public.wt_plans FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own plans"
  ON public.wt_plans FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own plans"
  ON public.wt_plans FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at_plans
  BEFORE UPDATE ON public.wt_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Table: wt_plan_items
-- Purpose: Individual scheduled activities/recommendations within a plan
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.wt_plans(id) ON DELETE CASCADE,
  module text NOT NULL,
  item_type text NOT NULL,
  item_data jsonb DEFAULT '{}' NOT NULL,
  scheduled_date date NOT NULL,
  scheduled_time time,
  completed boolean DEFAULT false NOT NULL,
  completed_at timestamptz,
  user_override boolean DEFAULT false NOT NULL,
  sort_order int DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_plan_items
CREATE INDEX idx_plan_items_plan_date ON public.wt_plan_items(plan_id, scheduled_date);

-- Enable RLS
ALTER TABLE public.wt_plan_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wt_plan_items
CREATE POLICY "Users can view their own plan items"
  ON public.wt_plan_items FOR SELECT
  USING (
    plan_id IN (
      SELECT id FROM public.wt_plans WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert their own plan items"
  ON public.wt_plan_items FOR INSERT
  WITH CHECK (
    plan_id IN (
      SELECT id FROM public.wt_plans WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update their own plan items"
  ON public.wt_plan_items FOR UPDATE
  USING (
    plan_id IN (
      SELECT id FROM public.wt_plans WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete their own plan items"
  ON public.wt_plan_items FOR DELETE
  USING (
    plan_id IN (
      SELECT id FROM public.wt_plans WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at_plan_items
  BEFORE UPDATE ON public.wt_plan_items
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Table: wt_goal_forecasts
-- Purpose: AI-generated health goal predictions and progress tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_goal_forecasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  goal_description text NOT NULL,
  target_value numeric(12,4),
  current_value numeric(12,4),
  unit text,
  expected_date date,
  confidence_score numeric(3,2),
  last_recalculated_at timestamptz,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_goal_forecasts
CREATE INDEX idx_goal_forecasts_profile_active ON public.wt_goal_forecasts(profile_id) WHERE is_active = true;

-- Enable RLS
ALTER TABLE public.wt_goal_forecasts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wt_goal_forecasts
CREATE POLICY "Users can view their own goal forecasts"
  ON public.wt_goal_forecasts FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own goal forecasts"
  ON public.wt_goal_forecasts FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own goal forecasts"
  ON public.wt_goal_forecasts FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own goal forecasts"
  ON public.wt_goal_forecasts FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER handle_updated_at_goal_forecasts
  BEFORE UPDATE ON public.wt_goal_forecasts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Cross-migration dependency: Link supplement protocols to goal forecasts
-- ============================================================================
-- Add FK from wt_supplement_protocols to wt_goal_forecasts (cross-migration dependency)
ALTER TABLE public.wt_supplement_protocols
  ADD CONSTRAINT fk_supplement_protocol_goal
  FOREIGN KEY (linked_goal_id) REFERENCES public.wt_goal_forecasts(id) ON DELETE SET NULL;
