-- Add ingredient preference columns to wt_profiles
-- Used by AI meal planning to prioritize/exclude ingredients
ALTER TABLE wt_profiles ADD COLUMN IF NOT EXISTS preferred_ingredients text[] DEFAULT '{}';
ALTER TABLE wt_profiles ADD COLUMN IF NOT EXISTS excluded_ingredients text[] DEFAULT '{}';
