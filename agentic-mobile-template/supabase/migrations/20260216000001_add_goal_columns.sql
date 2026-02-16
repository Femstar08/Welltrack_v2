ALTER TABLE public.wt_profiles
  ADD COLUMN IF NOT EXISTS primary_goal text,
  ADD COLUMN IF NOT EXISTS goal_intensity text;
