-- Migration: Verify health_metrics columns exist
-- Phase 3: Health Connect / HealthKit
--
-- NOTE: The columns validation_status, processing_status, is_primary,
-- and ingestion_source_version were already added in migration
-- 20260215000009_performance_engine.sql via ALTER TABLE.
--
-- This migration is a no-op safety check to ensure the columns exist.
-- If they already exist (expected), the IF NOT EXISTS prevents errors.

-- Verify columns exist (idempotent)
DO $$
BEGIN
  -- validation_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'wt_health_metrics'
    AND column_name = 'validation_status'
  ) THEN
    ALTER TABLE public.wt_health_metrics
      ADD COLUMN validation_status wt_validation_status NOT NULL DEFAULT 'raw';
  END IF;

  -- processing_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'wt_health_metrics'
    AND column_name = 'processing_status'
  ) THEN
    ALTER TABLE public.wt_health_metrics
      ADD COLUMN processing_status wt_processing_status NOT NULL DEFAULT 'pending';
  END IF;

  -- is_primary
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'wt_health_metrics'
    AND column_name = 'is_primary'
  ) THEN
    ALTER TABLE public.wt_health_metrics
      ADD COLUMN is_primary boolean NOT NULL DEFAULT false;
  END IF;

  -- ingestion_source_version
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'wt_health_metrics'
    AND column_name = 'ingestion_source_version'
  ) THEN
    ALTER TABLE public.wt_health_metrics
      ADD COLUMN ingestion_source_version text;
  END IF;
END $$;
