-- Migration: Add plan_type, recovery_score, calorie_adjustment_percent to wt_daily_prescriptions
ALTER TABLE public.wt_daily_prescriptions
  ADD COLUMN IF NOT EXISTS plan_type text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS recovery_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS calorie_adjustment_percent numeric(4,2) NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN public.wt_daily_prescriptions.plan_type IS 'Score-based plan type: push | normal | easy | rest';
COMMENT ON COLUMN public.wt_daily_prescriptions.recovery_score IS 'Recovery score 0-100 used to determine plan type';
COMMENT ON COLUMN public.wt_daily_prescriptions.calorie_adjustment_percent IS 'Percentage calorie adjustment (e.g. -0.10 = -10%)';
