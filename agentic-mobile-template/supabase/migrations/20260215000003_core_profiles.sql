-- Migration: Core User and Profile Tables
-- WellTrack Phase 1
-- Creates: wt_users, wt_profiles, wt_profile_modules
-- Also creates auth trigger for auto-provisioning on signup

-- ============================================================================
-- wt_users: App-specific user data (extends auth.users)
-- ============================================================================
CREATE TABLE public.wt_users (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  text,
  avatar_url    text,
  onboarding_completed boolean NOT NULL DEFAULT false,
  plan_tier     wt_plan_tier NOT NULL DEFAULT 'free',
  timezone      text DEFAULT 'UTC',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.wt_users ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_wt_users_updated_at
  BEFORE UPDATE ON public.wt_users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- wt_profiles: Parent + dependent profiles under a user
-- ============================================================================
CREATE TABLE public.wt_profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_type  wt_profile_type NOT NULL DEFAULT 'parent',
  display_name  text NOT NULL,
  date_of_birth date,
  gender        text,
  height_cm     numeric(5,1),
  weight_kg     numeric(5,1),
  activity_level text,
  fitness_goals  text,
  dietary_restrictions text,
  allergies     text,
  is_primary    boolean NOT NULL DEFAULT false,
  avatar_url    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.wt_profiles ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_wt_profiles_user_id ON public.wt_profiles(user_id);

CREATE TRIGGER set_wt_profiles_updated_at
  BEFORE UPDATE ON public.wt_profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- wt_profile_modules: Module toggle system per profile
-- ============================================================================
CREATE TABLE public.wt_profile_modules (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id    uuid NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  module_name   text NOT NULL,
  enabled       boolean NOT NULL DEFAULT true,
  tile_order    integer NOT NULL DEFAULT 0,
  tile_config   jsonb DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(profile_id, module_name)
);

ALTER TABLE public.wt_profile_modules ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_wt_profile_modules_updated_at
  BEFORE UPDATE ON public.wt_profile_modules
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- Auto-create user + primary profile on auth signup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wt_users (id, display_name, plan_tier, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    'free',
    now(),
    now()
  );
  INSERT INTO public.wt_profiles (user_id, profile_type, display_name, is_primary, created_at, updated_at)
  VALUES (
    NEW.id,
    'parent',
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    true,
    now(),
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
