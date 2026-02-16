-- Migration: Extensions, Enum Types, and Utility Functions
-- WellTrack Phase 1
-- Creates foundation layer: extensions, enum types, trigger functions, RLS helper

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- UUID generation and cryptographic functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- pgvector for AI embeddings - will not fail if unavailable
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS "vector";
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pgvector extension not available, skipping';
END $$;

-- ============================================================================
-- ENUM TYPES
-- ============================================================================

-- Subscription plan tiers
CREATE TYPE wt_plan_tier AS ENUM (
  'free',
  'pro'
);

-- Health data source platforms
CREATE TYPE wt_health_source AS ENUM (
  'healthconnect',
  'healthkit',
  'garmin',
  'strava',
  'manual'
);

-- Health metric categories
CREATE TYPE wt_metric_type AS ENUM (
  'sleep',
  'stress',
  'vo2max',
  'steps',
  'hr',
  'hrv',
  'calories',
  'distance',
  'active_minutes',
  'weight',
  'body_fat',
  'blood_pressure',
  'spo2'
);

-- Meal categorization
CREATE TYPE wt_meal_type AS ENUM (
  'breakfast',
  'lunch',
  'dinner',
  'snack',
  'other'
);

-- Recipe input source
CREATE TYPE wt_recipe_source AS ENUM (
  'url',
  'ocr',
  'ai',
  'manual'
);

-- Pantry storage location
CREATE TYPE wt_pantry_category AS ENUM (
  'fridge',
  'cupboard',
  'freezer'
);

-- Supplement intake timing
CREATE TYPE wt_supplement_time AS ENUM (
  'am',
  'pm',
  'with_meal',
  'bedtime'
);

-- Time period granularity
CREATE TYPE wt_period_type AS ENUM (
  'daily',
  'weekly',
  'monthly'
);

-- Insight analysis timeframe
CREATE TYPE wt_insight_period AS ENUM (
  'day',
  'week',
  'month'
);

-- Meal plan duration type
CREATE TYPE wt_plan_type AS ENUM (
  'weekly',
  'monthly'
);

-- Meal plan lifecycle status
CREATE TYPE wt_plan_status AS ENUM (
  'draft',
  'active',
  'completed',
  'archived'
);

-- AI memory categorization
CREATE TYPE wt_memory_type AS ENUM (
  'preference',
  'embedding',
  'pattern'
);

-- User profile type (parent account or dependent)
CREATE TYPE wt_profile_type AS ENUM (
  'parent',
  'dependent'
);

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Auto-update updated_at timestamp on row changes
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auto-generate deduplication hash for health metrics
CREATE OR REPLACE FUNCTION public.generate_health_metric_dedupe_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.dedupe_hash = md5(
    COALESCE(NEW.profile_id::text, '') ||
    COALESCE(NEW.source::text, '') ||
    COALESCE(NEW.metric_type::text, '') ||
    COALESCE(NEW.start_time::text, '') ||
    COALESCE(NEW.end_time::text, '') ||
    COALESCE(NEW.value_num::text, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- RLS helper: Get all profile IDs accessible by current user
-- Uses plpgsql to defer table reference validation (wt_profiles created later)
CREATE OR REPLACE FUNCTION public.get_profile_ids_for_user()
RETURNS SETOF uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT id FROM public.wt_profiles
  WHERE user_id = auth.uid();
END;
$$;

-- Alias for backward-compatible trigger references
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
