-- Migration: Daily Logs, Insights, Reminders, and AI Tables
-- WellTrack Phase 1
-- Creates: wt_daily_logs, wt_insights, wt_reminders,
--          wt_ai_usage, wt_ai_audit_log, wt_ai_memory

-- Note: Enum types wt_insight_period, wt_plan_tier, and wt_memory_type
-- are created in migration 001 (extensions_and_enums.sql)

-- ============================================================================
-- TABLE: wt_daily_logs
-- ============================================================================

CREATE TABLE public.wt_daily_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  log_date date NOT NULL DEFAULT CURRENT_DATE,
  log_type text NOT NULL,
  value_num numeric(10,2),
  value_text text,
  unit text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Comments
COMMENT ON TABLE public.wt_daily_logs IS 'Daily health and wellness logs (mood, energy, water, weight, custom metrics)';
COMMENT ON COLUMN public.wt_daily_logs.log_type IS 'Type of log entry: mood, energy, water, weight, custom, etc.';
COMMENT ON COLUMN public.wt_daily_logs.value_num IS 'Numeric value for quantifiable metrics';
COMMENT ON COLUMN public.wt_daily_logs.value_text IS 'Text value for qualitative entries';
COMMENT ON COLUMN public.wt_daily_logs.unit IS 'Unit of measurement (e.g., lbs, oz, glasses)';

-- Indexes
CREATE INDEX idx_wt_daily_logs_profile_date ON public.wt_daily_logs(profile_id, log_date);
CREATE INDEX idx_wt_daily_logs_log_type ON public.wt_daily_logs(log_type);
CREATE INDEX idx_wt_daily_logs_created_at ON public.wt_daily_logs(created_at);

-- Enable RLS
ALTER TABLE public.wt_daily_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own daily logs"
  ON public.wt_daily_logs
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own daily logs"
  ON public.wt_daily_logs
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own daily logs"
  ON public.wt_daily_logs
  FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own daily logs"
  ON public.wt_daily_logs
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_daily_logs
  BEFORE UPDATE ON public.wt_daily_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- TABLE: wt_insights
-- ============================================================================

CREATE TABLE public.wt_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  period_type public.wt_insight_period NOT NULL,
  period_start date NOT NULL,
  summary_text text NOT NULL,
  ai_model text,
  metrics_snapshot jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_profile_period_insights UNIQUE (profile_id, period_type, period_start)
);

-- Comments
COMMENT ON TABLE public.wt_insights IS 'AI-generated insights and summaries for various time periods';
COMMENT ON COLUMN public.wt_insights.period_type IS 'Type of period: daily, weekly, monthly, quarterly, yearly';
COMMENT ON COLUMN public.wt_insights.period_start IS 'Start date of the insight period';
COMMENT ON COLUMN public.wt_insights.summary_text IS 'AI-generated summary text';
COMMENT ON COLUMN public.wt_insights.ai_model IS 'AI model used to generate insight';
COMMENT ON COLUMN public.wt_insights.metrics_snapshot IS 'JSON snapshot of key metrics for this period';

-- Indexes
CREATE INDEX idx_wt_insights_profile_period ON public.wt_insights(profile_id, period_type, period_start);
CREATE INDEX idx_wt_insights_period_start ON public.wt_insights(period_start);

-- Enable RLS
ALTER TABLE public.wt_insights ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own insights"
  ON public.wt_insights
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own insights"
  ON public.wt_insights
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own insights"
  ON public.wt_insights
  FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own insights"
  ON public.wt_insights
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_insights
  BEFORE UPDATE ON public.wt_insights
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- TABLE: wt_reminders
-- ============================================================================

CREATE TABLE public.wt_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  module text,
  title text NOT NULL,
  body text,
  remind_at timestamptz NOT NULL,
  repeat_rule text,
  is_active boolean NOT NULL DEFAULT true,
  last_triggered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Comments
COMMENT ON TABLE public.wt_reminders IS 'User reminders for medications, exercises, appointments, etc.';
COMMENT ON COLUMN public.wt_reminders.module IS 'Module associated with reminder (e.g., medications, exercises)';
COMMENT ON COLUMN public.wt_reminders.repeat_rule IS 'Recurrence rule (e.g., RRULE format or custom)';
COMMENT ON COLUMN public.wt_reminders.is_active IS 'Whether the reminder is active';
COMMENT ON COLUMN public.wt_reminders.last_triggered_at IS 'Last time the reminder was triggered';

-- Indexes
CREATE INDEX idx_wt_reminders_profile_remind_at ON public.wt_reminders(profile_id, remind_at)
  WHERE is_active = true;
CREATE INDEX idx_wt_reminders_remind_at_active ON public.wt_reminders(remind_at)
  WHERE is_active = true;
CREATE INDEX idx_wt_reminders_module ON public.wt_reminders(module);

-- Enable RLS
ALTER TABLE public.wt_reminders ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own reminders"
  ON public.wt_reminders
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own reminders"
  ON public.wt_reminders
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own reminders"
  ON public.wt_reminders
  FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own reminders"
  ON public.wt_reminders
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_reminders
  BEFORE UPDATE ON public.wt_reminders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- TABLE: wt_ai_usage
-- ============================================================================

CREATE TABLE public.wt_ai_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.wt_profiles(id) ON DELETE SET NULL,
  usage_date date NOT NULL DEFAULT CURRENT_DATE,
  calls_used int NOT NULL DEFAULT 0,
  tokens_used int NOT NULL DEFAULT 0,
  calls_limit int NOT NULL DEFAULT 10,
  tokens_limit int NOT NULL DEFAULT 50000,
  plan_tier public.wt_plan_tier NOT NULL DEFAULT 'free',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_user_usage_date UNIQUE (user_id, usage_date)
);

-- Comments
COMMENT ON TABLE public.wt_ai_usage IS 'Daily AI usage metering per user';
COMMENT ON COLUMN public.wt_ai_usage.calls_used IS 'Number of AI calls used today';
COMMENT ON COLUMN public.wt_ai_usage.tokens_used IS 'Number of tokens used today';
COMMENT ON COLUMN public.wt_ai_usage.calls_limit IS 'Daily limit for AI calls';
COMMENT ON COLUMN public.wt_ai_usage.tokens_limit IS 'Daily limit for tokens';
COMMENT ON COLUMN public.wt_ai_usage.plan_tier IS 'User plan tier (free, premium, enterprise)';

-- Indexes
CREATE INDEX idx_wt_ai_usage_user_date ON public.wt_ai_usage(user_id, usage_date);
CREATE INDEX idx_wt_ai_usage_plan_tier ON public.wt_ai_usage(plan_tier);

-- Enable RLS
ALTER TABLE public.wt_ai_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own AI usage"
  ON public.wt_ai_usage
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own AI usage"
  ON public.wt_ai_usage
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own AI usage"
  ON public.wt_ai_usage
  FOR UPDATE
  USING (user_id = auth.uid());

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_ai_usage
  BEFORE UPDATE ON public.wt_ai_usage
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- TABLE: wt_ai_audit_log
-- ============================================================================

CREATE TABLE public.wt_ai_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.wt_profiles(id) ON DELETE SET NULL,
  tool_called text NOT NULL,
  input_summary text,
  output_summary text,
  tokens_consumed int NOT NULL DEFAULT 0,
  duration_ms int,
  safety_flags jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Comments
COMMENT ON TABLE public.wt_ai_audit_log IS 'Audit log of all AI tool calls for compliance and debugging';
COMMENT ON COLUMN public.wt_ai_audit_log.tool_called IS 'Name of the AI tool or function called';
COMMENT ON COLUMN public.wt_ai_audit_log.input_summary IS 'Summary of input parameters';
COMMENT ON COLUMN public.wt_ai_audit_log.output_summary IS 'Summary of output response';
COMMENT ON COLUMN public.wt_ai_audit_log.tokens_consumed IS 'Number of tokens consumed by this call';
COMMENT ON COLUMN public.wt_ai_audit_log.duration_ms IS 'Duration of the call in milliseconds';
COMMENT ON COLUMN public.wt_ai_audit_log.safety_flags IS 'JSON object containing any safety or content flags';

-- Indexes
CREATE INDEX idx_wt_ai_audit_log_user_created ON public.wt_ai_audit_log(user_id, created_at);
CREATE INDEX idx_wt_ai_audit_log_tool ON public.wt_ai_audit_log(tool_called);
CREATE INDEX idx_wt_ai_audit_log_created_at ON public.wt_ai_audit_log(created_at);

-- Enable RLS
ALTER TABLE public.wt_ai_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own AI audit logs"
  ON public.wt_ai_audit_log
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own AI audit logs"
  ON public.wt_ai_audit_log
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- TABLE: wt_ai_memory
-- ============================================================================

CREATE TABLE public.wt_ai_memory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.wt_profiles(id) ON DELETE SET NULL,
  memory_type public.wt_memory_type NOT NULL,
  memory_key text NOT NULL,
  memory_value jsonb NOT NULL DEFAULT '{}',
  source_tool text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Comments
COMMENT ON TABLE public.wt_ai_memory IS 'Persistent AI memory for user preferences, context, and learned patterns';
COMMENT ON COLUMN public.wt_ai_memory.memory_type IS 'Type of memory: user_preference, health_context, conversation_summary, etc.';
COMMENT ON COLUMN public.wt_ai_memory.memory_key IS 'Unique key for this memory item';
COMMENT ON COLUMN public.wt_ai_memory.memory_value IS 'JSON value containing the memory data';
COMMENT ON COLUMN public.wt_ai_memory.source_tool IS 'AI tool that created this memory';
COMMENT ON COLUMN public.wt_ai_memory.expires_at IS 'Optional expiration timestamp for temporary memories';

-- Add embedding column with error handling for pgvector
DO $$ BEGIN
  ALTER TABLE public.wt_ai_memory ADD COLUMN embedding vector(1536);
  RAISE NOTICE 'Successfully added embedding column';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pgvector not available, skipping embedding column';
END $$;

-- Indexes
CREATE INDEX idx_wt_ai_memory_user_profile_type_key ON public.wt_ai_memory(user_id, profile_id, memory_type, memory_key);
CREATE INDEX idx_wt_ai_memory_user_type ON public.wt_ai_memory(user_id, memory_type);
CREATE INDEX idx_wt_ai_memory_expires_at ON public.wt_ai_memory(expires_at) WHERE expires_at IS NOT NULL;

-- Vector index with error handling
DO $$ BEGIN
  CREATE INDEX idx_wt_ai_memory_embedding ON public.wt_ai_memory
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
  RAISE NOTICE 'Successfully created vector index';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not create vector index, skipping';
END $$;

-- Enable RLS
ALTER TABLE public.wt_ai_memory ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own AI memory"
  ON public.wt_ai_memory
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own AI memory"
  ON public.wt_ai_memory
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own AI memory"
  ON public.wt_ai_memory
  FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own AI memory"
  ON public.wt_ai_memory
  FOR DELETE
  USING (user_id = auth.uid());

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_ai_memory
  BEFORE UPDATE ON public.wt_ai_memory
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to increment AI usage for a user
CREATE OR REPLACE FUNCTION public.increment_ai_usage(
  p_user_id uuid,
  p_profile_id uuid DEFAULT NULL,
  p_calls int DEFAULT 1,
  p_tokens int DEFAULT 0
)
RETURNS public.wt_ai_usage
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usage public.wt_ai_usage;
BEGIN
  -- Insert or update usage for today
  INSERT INTO public.wt_ai_usage (user_id, profile_id, usage_date, calls_used, tokens_used)
  VALUES (p_user_id, p_profile_id, CURRENT_DATE, p_calls, p_tokens)
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET
    calls_used = public.wt_ai_usage.calls_used + EXCLUDED.calls_used,
    tokens_used = public.wt_ai_usage.tokens_used + EXCLUDED.tokens_used,
    updated_at = now()
  RETURNING * INTO v_usage;

  RETURN v_usage;
END;
$$;

COMMENT ON FUNCTION public.increment_ai_usage IS 'Increment AI usage counters for a user';

-- Function to check if user has exceeded AI limits
CREATE OR REPLACE FUNCTION public.check_ai_limit(
  p_user_id uuid,
  p_calls int DEFAULT 0,
  p_tokens int DEFAULT 0
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usage public.wt_ai_usage;
BEGIN
  -- Get or create today's usage record
  SELECT * INTO v_usage
  FROM public.wt_ai_usage
  WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;

  -- If no record exists, create one with defaults
  IF NOT FOUND THEN
    INSERT INTO public.wt_ai_usage (user_id, usage_date)
    VALUES (p_user_id, CURRENT_DATE)
    RETURNING * INTO v_usage;
  END IF;

  -- Check if adding the requested usage would exceed limits
  IF (v_usage.calls_used + p_calls) > v_usage.calls_limit THEN
    RETURN false;
  END IF;

  IF (v_usage.tokens_used + p_tokens) > v_usage.tokens_limit THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

COMMENT ON FUNCTION public.check_ai_limit IS 'Check if user has remaining AI quota for calls/tokens';

-- Function to clean up expired AI memories
CREATE OR REPLACE FUNCTION public.cleanup_expired_ai_memories()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count int;
BEGIN
  DELETE FROM public.wt_ai_memory
  WHERE expires_at IS NOT NULL AND expires_at < now();

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_ai_memories IS 'Delete expired AI memory records';

-- ============================================================================
-- GRANTS
-- ============================================================================

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_daily_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_insights TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_reminders TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wt_ai_usage TO authenticated;
GRANT SELECT, INSERT ON public.wt_ai_audit_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_ai_memory TO authenticated;

-- Grant function permissions
GRANT EXECUTE ON FUNCTION public.increment_ai_usage TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_ai_limit TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_ai_memories TO authenticated;
