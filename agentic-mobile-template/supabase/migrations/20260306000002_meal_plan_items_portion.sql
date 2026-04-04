-- Migration: Add portion_multiplier and source columns to wt_meal_plan_items
-- Phase 9b: Meal module user interactions (portion adjustment, food log source)

ALTER TABLE wt_meal_plan_items
  ADD COLUMN IF NOT EXISTS portion_multiplier numeric DEFAULT 1.0 NOT NULL,
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'plan' NOT NULL;
