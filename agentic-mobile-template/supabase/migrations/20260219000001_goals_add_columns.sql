-- Add columns to wt_goal_forecasts required by the goals feature module
ALTER TABLE public.wt_goal_forecasts
  ADD COLUMN IF NOT EXISTS metric_type text,
  ADD COLUMN IF NOT EXISTS deadline date,
  ADD COLUMN IF NOT EXISTS priority int DEFAULT 0;
