-- Phase 8: Add nutrition_profiles and cuisine_preference to wt_profiles
ALTER TABLE wt_profiles ADD COLUMN IF NOT EXISTS nutrition_profiles text[] DEFAULT '{}'::text[];
ALTER TABLE wt_profiles ADD COLUMN IF NOT EXISTS cuisine_preference text DEFAULT 'balanced';
