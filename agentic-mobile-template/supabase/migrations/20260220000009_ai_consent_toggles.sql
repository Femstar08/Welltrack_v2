-- Migration: Add AI consent toggles to wt_profiles
-- Controls whether sensitive vitality/bloodwork data is shared with AI

ALTER TABLE public.wt_profiles
  ADD COLUMN IF NOT EXISTS ai_consent_vitality boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS ai_consent_bloodwork boolean DEFAULT false NOT NULL;
