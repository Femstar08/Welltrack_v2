-- Table for per-profile module configuration (toggle on/off, tile ordering)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.wt_profile_modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  module_name TEXT NOT NULL,
  enabled BOOLEAN DEFAULT true,
  tile_order INT DEFAULT 0,
  tile_config JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, module_name)
);

ALTER TABLE public.wt_profile_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile modules"
  ON public.wt_profile_modules FOR SELECT
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert their own profile modules"
  ON public.wt_profile_modules FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own profile modules"
  ON public.wt_profile_modules FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own profile modules"
  ON public.wt_profile_modules FOR DELETE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE INDEX IF NOT EXISTS idx_profile_modules_profile
  ON public.wt_profile_modules(profile_id);
