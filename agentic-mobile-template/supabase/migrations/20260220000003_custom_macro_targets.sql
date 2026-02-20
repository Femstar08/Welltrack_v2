-- Custom macro targets per day type
CREATE TABLE IF NOT EXISTS wt_custom_macro_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  day_type TEXT NOT NULL CHECK (day_type IN ('strength', 'cardio', 'rest')),
  calories INT NOT NULL CHECK (calories BETWEEN 800 AND 8000),
  protein_g INT NOT NULL CHECK (protein_g >= 0),
  carbs_g INT NOT NULL CHECK (carbs_g >= 0),
  fat_g INT NOT NULL CHECK (fat_g >= 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(profile_id, day_type)
);

-- RLS
ALTER TABLE wt_custom_macro_targets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own custom targets"
  ON wt_custom_macro_targets FOR SELECT
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own custom targets"
  ON wt_custom_macro_targets FOR INSERT
  WITH CHECK (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own custom targets"
  ON wt_custom_macro_targets FOR UPDATE
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete their own custom targets"
  ON wt_custom_macro_targets FOR DELETE
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));

-- Index
CREATE INDEX idx_custom_macro_targets_profile ON wt_custom_macro_targets(profile_id);
