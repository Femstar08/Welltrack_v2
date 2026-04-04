-- Migration: Extend wt_recipes schema for full recipe data
-- Adds: cuisine_type, meal_type, serving_size_description, ingredients (jsonb),
--        nutrition macros, and 'photo' source type

-- Add 'photo' to wt_recipe_source enum
ALTER TYPE wt_recipe_source ADD VALUE IF NOT EXISTS 'photo';

-- Add new columns to wt_recipes
ALTER TABLE wt_recipes
  ADD COLUMN IF NOT EXISTS cuisine_type text,
  ADD COLUMN IF NOT EXISTS meal_type wt_meal_type,
  ADD COLUMN IF NOT EXISTS serving_size_description text,
  ADD COLUMN IF NOT EXISTS ingredients jsonb,
  ADD COLUMN IF NOT EXISTS calories_per_serving int,
  ADD COLUMN IF NOT EXISTS protein_per_serving numeric(6,1),
  ADD COLUMN IF NOT EXISTS carbs_per_serving numeric(6,1),
  ADD COLUMN IF NOT EXISTS fat_per_serving numeric(6,1),
  ADD COLUMN IF NOT EXISTS fibre_per_serving numeric(6,1);

-- Change instructions from text to jsonb for structured step data
ALTER TABLE wt_recipes
  ALTER COLUMN instructions TYPE jsonb USING
    CASE
      WHEN instructions IS NULL THEN NULL
      WHEN instructions::text ~ '^\[' THEN instructions::jsonb
      ELSE jsonb_build_array(jsonb_build_object('step', 1, 'instruction', instructions))
    END;

-- Index for meal_type filtering
CREATE INDEX IF NOT EXISTS idx_wt_recipes_meal_type ON wt_recipes(meal_type);

-- Index for cuisine filtering
CREATE INDEX IF NOT EXISTS idx_wt_recipes_cuisine_type ON wt_recipes(cuisine_type);

-- Index for public recipe browsing
CREATE INDEX IF NOT EXISTS idx_wt_recipes_is_public ON wt_recipes(is_public) WHERE is_public = true;

-- RLS policy: allow anyone to read public recipes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'wt_recipes' AND policyname = 'Public recipes are readable by all authenticated users'
  ) THEN
    CREATE POLICY "Public recipes are readable by all authenticated users"
      ON wt_recipes FOR SELECT
      TO authenticated
      USING (is_public = true OR profile_id = auth.uid());
  END IF;
END $$;
