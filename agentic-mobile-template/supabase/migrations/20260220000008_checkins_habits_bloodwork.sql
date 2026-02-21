-- Migration: Daily Check-ins, Habit Streaks, Bloodwork Results
-- Fills Phase 1 schema gaps for Phases 9, 12

-- ============================================================================
-- Table: wt_daily_checkins
-- Purpose: Morning check-in responses (mood, sleep override, vitality, schedule)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_daily_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  checkin_date date NOT NULL DEFAULT CURRENT_DATE,

  -- Morning questions (daily)
  feeling_level text CHECK (feeling_level IN ('great', 'good', 'tired', 'sore', 'unwell')),
  sleep_quality numeric(3,1) CHECK (sleep_quality BETWEEN 1 AND 10),
  sleep_quality_override boolean DEFAULT false NOT NULL,
  morning_erection boolean,
  injuries_notes text,
  schedule_type text CHECK (schedule_type IN ('busy', 'normal', 'flexible')),

  -- Weekly questions (Sunday)
  is_weekly boolean DEFAULT false NOT NULL,
  erection_quality_weekly smallint CHECK (erection_quality_weekly BETWEEN 1 AND 10),

  -- Privacy flags
  is_sensitive boolean DEFAULT true NOT NULL,

  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT unique_checkin_per_day UNIQUE (profile_id, checkin_date)
);

-- Indexes
CREATE INDEX idx_daily_checkins_profile_date
  ON public.wt_daily_checkins(profile_id, checkin_date DESC);

-- RLS
ALTER TABLE public.wt_daily_checkins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own check-ins"
  ON public.wt_daily_checkins FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own check-ins"
  ON public.wt_daily_checkins FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own check-ins"
  ON public.wt_daily_checkins FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own check-ins"
  ON public.wt_daily_checkins FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- updated_at trigger
CREATE TRIGGER handle_updated_at_daily_checkins
  BEFORE UPDATE ON public.wt_daily_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Table: wt_habit_streaks
-- Purpose: Generic streak tracker (porn_free, kegels, sleep_target, custom)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_habit_streaks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,

  habit_type text NOT NULL,
  habit_label text,
  current_streak_days int NOT NULL DEFAULT 0,
  longest_streak_days int NOT NULL DEFAULT 0,
  last_logged_date date,
  is_active boolean NOT NULL DEFAULT true,

  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT unique_habit_per_profile UNIQUE (profile_id, habit_type)
);

-- Indexes
CREATE INDEX idx_habit_streaks_profile_active
  ON public.wt_habit_streaks(profile_id) WHERE is_active = true;

-- RLS
ALTER TABLE public.wt_habit_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own habit streaks"
  ON public.wt_habit_streaks FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own habit streaks"
  ON public.wt_habit_streaks FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own habit streaks"
  ON public.wt_habit_streaks FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own habit streaks"
  ON public.wt_habit_streaks FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- updated_at trigger
CREATE TRIGGER handle_updated_at_habit_streaks
  BEFORE UPDATE ON public.wt_habit_streaks
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Table: wt_bloodwork_results
-- Purpose: Lab result history with reference ranges and out-of-range flags
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_bloodwork_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,

  test_name text NOT NULL,
  value_num numeric(12,4) NOT NULL,
  unit text NOT NULL,
  reference_range_low numeric(12,4),
  reference_range_high numeric(12,4),
  is_out_of_range boolean GENERATED ALWAYS AS (
    (reference_range_low IS NOT NULL AND value_num < reference_range_low)
    OR
    (reference_range_high IS NOT NULL AND value_num > reference_range_high)
  ) STORED,

  test_date date NOT NULL,
  notes text,

  is_sensitive boolean DEFAULT true NOT NULL,

  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX idx_bloodwork_profile_test_date
  ON public.wt_bloodwork_results(profile_id, test_name, test_date DESC);

CREATE INDEX idx_bloodwork_out_of_range
  ON public.wt_bloodwork_results(profile_id, is_out_of_range)
  WHERE is_out_of_range = true;

-- RLS
ALTER TABLE public.wt_bloodwork_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bloodwork"
  ON public.wt_bloodwork_results FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own bloodwork"
  ON public.wt_bloodwork_results FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own bloodwork"
  ON public.wt_bloodwork_results FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own bloodwork"
  ON public.wt_bloodwork_results FOR DELETE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

-- updated_at trigger
CREATE TRIGGER handle_updated_at_bloodwork
  BEFORE UPDATE ON public.wt_bloodwork_results
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
