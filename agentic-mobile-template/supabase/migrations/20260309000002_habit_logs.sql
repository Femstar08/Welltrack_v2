-- Migration: Habit Logs for Phase 12 Habits + Bloodwork
-- Adds daily completion records that feed streak calculations on wt_habit_streaks.

-- ============================================================================
-- Table: wt_habit_logs
-- Purpose: One row per (profile, habit_type, day) recording completion status
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_habit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,

  habit_type text NOT NULL,
  log_date date NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  notes text,

  created_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT unique_habit_log_per_day UNIQUE (profile_id, habit_type, log_date)
);

-- Index for fast calendar-range queries and streak calculation look-ups
CREATE INDEX idx_habit_logs_profile_type_date
  ON public.wt_habit_logs(profile_id, habit_type, log_date DESC);

-- RLS — matching pattern used across all wt_* tables
ALTER TABLE public.wt_habit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own habit logs"
  ON public.wt_habit_logs FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own habit logs"
  ON public.wt_habit_logs FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own habit logs"
  ON public.wt_habit_logs FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own habit logs"
  ON public.wt_habit_logs FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_habit_logs TO authenticated;
