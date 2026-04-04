-- Migration: Add baseline tracking columns to wt_profiles
-- Phase 10: US-003 — 14-day baseline calibration gate
-- Tracks how many distinct days of health data have been collected per profile,
-- and records when the baseline calibration window is complete.

ALTER TABLE public.wt_profiles
  ADD COLUMN IF NOT EXISTS baseline_days_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS baseline_complete BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS baseline_completed_at TIMESTAMPTZ;
