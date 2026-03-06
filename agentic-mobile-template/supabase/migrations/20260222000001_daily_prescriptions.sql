-- Migration: Daily Prescriptions for Phase 9 AI Daily Coach
CREATE TABLE IF NOT EXISTS public.wt_daily_prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  checkin_id uuid REFERENCES public.wt_daily_checkins(id) ON DELETE SET NULL,
  prescription_date date NOT NULL DEFAULT CURRENT_DATE,

  -- Prescription scenario resolved by the rule engine
  scenario text NOT NULL,
  -- Values: 'well_rested' | 'tired_not_sore' | 'very_sore' | 'behind_steps'
  --        | 'weight_stalling' | 'busy_day' | 'unwell' | 'default'

  -- Workout directive
  workout_directive text NOT NULL,
  -- Values: 'full_session' | 'reduced_volume' | 'active_recovery' | 'rest' | 'quick_session'
  workout_volume_modifier numeric(4,2) DEFAULT 1.0,
  -- 1.0 = full, 0.8 = reduce 20%, 0.0 = no workout
  workout_note text,

  -- Meal directive
  meal_directive text NOT NULL,
  -- Values: 'standard' | 'extra_carbs' | 'high_protein' | 'light' | 'grab_and_go' | 'hydration_focus'
  calorie_modifier numeric(5,0) DEFAULT 0,
  -- Signed integer offset from normal target (e.g. -150 for stalling weight)

  -- Steps / activity directive
  steps_nudge text,

  -- AI-generated narrative (narrates the rule-based output only)
  ai_focus_tip text,
  ai_narrative text,

  -- Bedtime recommendation
  bedtime_hour smallint,       -- 22 = 10 PM
  bedtime_minute smallint,     -- 45 = :45

  -- Generation metadata
  generated_at timestamptz NOT NULL DEFAULT now(),
  ai_model text,
  is_fallback boolean NOT NULL DEFAULT false,
  -- true when AI narration failed; deterministic plan still shown

  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT unique_prescription_per_day UNIQUE (profile_id, prescription_date)
);

CREATE INDEX idx_daily_prescriptions_profile_date
  ON public.wt_daily_prescriptions(profile_id, prescription_date DESC);

ALTER TABLE public.wt_daily_prescriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own prescriptions"
  ON public.wt_daily_prescriptions FOR SELECT
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own prescriptions"
  ON public.wt_daily_prescriptions FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own prescriptions"
  ON public.wt_daily_prescriptions FOR UPDATE
  USING (profile_id IN (SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()));

CREATE TRIGGER handle_updated_at_daily_prescriptions
  BEFORE UPDATE ON public.wt_daily_prescriptions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

GRANT SELECT, INSERT, UPDATE ON public.wt_daily_prescriptions TO authenticated;
