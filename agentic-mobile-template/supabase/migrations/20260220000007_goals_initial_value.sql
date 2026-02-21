-- Add initial_value column to wt_goal_forecasts
-- This stores the starting value when a goal is created,
-- enabling accurate progress percentage calculation.

ALTER TABLE wt_goal_forecasts
  ADD COLUMN IF NOT EXISTS initial_value numeric;

-- Backfill: set initial_value = current_value for existing goals
UPDATE wt_goal_forecasts
  SET initial_value = current_value
  WHERE initial_value IS NULL;
