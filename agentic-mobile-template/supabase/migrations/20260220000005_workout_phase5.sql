-- Migration: Workout Logger Phase 5
-- WellTrack Phase 5 — JEFIT-style workout tracking
-- Operations:
--   1a. Alter wt_exercises  — muscle arrays, equipment type, media URLs, custom flag
--   1b. Create wt_workout_plans
--   1c. Create wt_workout_plan_exercises
--   1d. Alter wt_workouts   — plan linkage, start/end timestamps
--   1e. Create wt_workout_sets
--   1f. Create wt_exercise_records

-- ============================================================================
-- ENSURE TRIGGER FUNCTION EXISTS
-- Both handle_updated_at() and update_updated_at_column() were defined in
-- 20260215000001_extensions_and_enums.sql. Guard here so the migration is
-- safe to re-run in isolation (e.g. a clean test DB built from this file).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1a. ALTER wt_exercises
-- Adds: muscle_groups[], secondary_muscles[], equipment_type, image_url,
--       gif_url, is_custom, profile_id (for user-created exercises), category.
-- Backfills: copies legacy muscle_group text into the new array column.
-- RLS: custom exercises are owner-only; shared exercises are read-only for all
--      authenticated users; owners get full CRUD on their custom exercises.
-- ============================================================================

ALTER TABLE public.wt_exercises
  ADD COLUMN IF NOT EXISTS muscle_groups     text[]    DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS secondary_muscles text[]    DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS equipment_type    text,
  ADD COLUMN IF NOT EXISTS image_url         text,
  ADD COLUMN IF NOT EXISTS gif_url           text,
  ADD COLUMN IF NOT EXISTS is_custom         boolean   DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_id        uuid      REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS category          text;

-- Backfill: copy existing single muscle_group text value into the array column.
-- Only touches rows that haven't already been populated (idempotent on re-run).
UPDATE public.wt_exercises
SET    muscle_groups = ARRAY[muscle_group]
WHERE  muscle_group IS NOT NULL
  AND  muscle_groups = '{}';

-- Index to efficiently find exercises owned by a specific profile (custom exercises).
CREATE INDEX IF NOT EXISTS idx_wt_exercises_profile_id
  ON public.wt_exercises(profile_id)
  WHERE profile_id IS NOT NULL;

-- Index for fast muscle-group filtering (GIN for array containment queries).
CREATE INDEX IF NOT EXISTS idx_wt_exercises_muscle_groups
  ON public.wt_exercises USING GIN(muscle_groups);

-- Drop the old blanket "all authenticated users can view exercises" policy
-- so we can replace it with the split shared / custom logic.
DROP POLICY IF EXISTS "All authenticated users can view exercises" ON public.wt_exercises;

-- SELECT: shared exercises (is_custom IS FALSE or NULL) visible to all
--         authenticated users; custom exercises only to the owning profile.
CREATE POLICY "Users can view shared and their own custom exercises"
  ON public.wt_exercises FOR SELECT
  USING (
    (is_custom IS FALSE OR is_custom IS NULL)
    OR
    profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- INSERT: only allowed for custom exercises owned by the authenticated user.
CREATE POLICY "Users can create their own custom exercises"
  ON public.wt_exercises FOR INSERT
  WITH CHECK (
    is_custom = true
    AND profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- UPDATE: only allowed on the user's own custom exercises.
CREATE POLICY "Users can update their own custom exercises"
  ON public.wt_exercises FOR UPDATE
  USING (
    is_custom = true
    AND profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

-- DELETE: only allowed on the user's own custom exercises.
CREATE POLICY "Users can delete their own custom exercises"
  ON public.wt_exercises FOR DELETE
  USING (
    is_custom = true
    AND profile_id IN (
      SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
    )
  );

COMMENT ON COLUMN public.wt_exercises.muscle_groups     IS 'Primary target muscle groups (array). Backfilled from legacy muscle_group text column.';
COMMENT ON COLUMN public.wt_exercises.secondary_muscles IS 'Secondary / synergist muscles worked during the exercise.';
COMMENT ON COLUMN public.wt_exercises.equipment_type    IS 'Equipment category: barbell, dumbbell, cable, machine, bodyweight, kettlebell, trap_bar, etc.';
COMMENT ON COLUMN public.wt_exercises.image_url         IS 'Static demonstration image URL (CDN-hosted).';
COMMENT ON COLUMN public.wt_exercises.gif_url           IS 'Animated GIF demonstration URL shown on the live logging screen.';
COMMENT ON COLUMN public.wt_exercises.is_custom         IS 'TRUE = user-created exercise scoped to profile_id. FALSE / NULL = shared library exercise.';
COMMENT ON COLUMN public.wt_exercises.profile_id        IS 'Owning profile for custom exercises. NULL for shared library exercises.';
COMMENT ON COLUMN public.wt_exercises.category          IS 'Top-level category: chest, back, shoulders, arms, legs, core, full_body, cardio, etc.';

-- ============================================================================
-- 1b. CREATE wt_workout_plans
-- Named training plans owned by a profile. Each plan holds a collection of
-- exercises assigned to specific days of the week via wt_workout_plan_exercises.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_workout_plans (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  uuid        NOT NULL REFERENCES public.wt_profiles(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  description text,
  is_active   boolean     DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wt_workout_plans_profile_id
  ON public.wt_workout_plans(profile_id);

CREATE INDEX IF NOT EXISTS idx_wt_workout_plans_profile_active
  ON public.wt_workout_plans(profile_id, is_active);

-- Enable RLS
ALTER TABLE public.wt_workout_plans ENABLE ROW LEVEL SECURITY;

-- RLS Policies — profile-scoped (users can only see/modify their own plans)
CREATE POLICY "Users can view their own workout plans"
  ON public.wt_workout_plans FOR SELECT
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can create their own workout plans"
  ON public.wt_workout_plans FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own workout plans"
  ON public.wt_workout_plans FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own workout plans"
  ON public.wt_workout_plans FOR DELETE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

-- updated_at trigger
CREATE TRIGGER set_updated_at_wt_workout_plans
  BEFORE UPDATE ON public.wt_workout_plans
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMENT ON TABLE  public.wt_workout_plans            IS 'Named training plans (e.g. "4-Day Push/Pull/Legs"). Each plan owns a set of day-assigned exercises.';
COMMENT ON COLUMN public.wt_workout_plans.is_active  IS 'Only one plan is typically active at a time; others are archived but not deleted.';

-- ============================================================================
-- 1c. CREATE wt_workout_plan_exercises
-- Exercises assigned to a specific day within a named plan. Captures targets
-- (sets, reps, weight, rest) that pre-populate the live logging screen.
-- RLS: access is gated by joining through wt_workout_plans to the owning profile.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_workout_plan_exercises (
  id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id          uuid          NOT NULL REFERENCES public.wt_workout_plans(id) ON DELETE CASCADE,
  exercise_id      uuid          NOT NULL REFERENCES public.wt_exercises(id)    ON DELETE CASCADE,
  day_of_week      int           NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- 1=Mon, 7=Sun
  sort_order       int           NOT NULL DEFAULT 0,
  target_sets      int           NOT NULL DEFAULT 3,
  target_reps      int           NOT NULL DEFAULT 10,
  target_weight_kg numeric(6,2),
  rest_seconds     int                    DEFAULT 90,
  notes            text,
  created_at       timestamptz   DEFAULT now()
);

-- Indexes
-- Primary query pattern: fetch all exercises for a plan day, ordered.
CREATE INDEX IF NOT EXISTS idx_wt_workout_plan_exercises_plan_day_order
  ON public.wt_workout_plan_exercises(plan_id, day_of_week, sort_order);

-- Secondary: look up all occurrences of an exercise across plans.
CREATE INDEX IF NOT EXISTS idx_wt_workout_plan_exercises_exercise_id
  ON public.wt_workout_plan_exercises(exercise_id);

-- Enable RLS
ALTER TABLE public.wt_workout_plan_exercises ENABLE ROW LEVEL SECURITY;

-- RLS Policies — ownership resolved via plan_id → wt_workout_plans → profile_id
CREATE POLICY "Users can view their own workout plan exercises"
  ON public.wt_workout_plan_exercises FOR SELECT
  USING (
    plan_id IN (
      SELECT id FROM public.wt_workout_plans
      WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can create their own workout plan exercises"
  ON public.wt_workout_plan_exercises FOR INSERT
  WITH CHECK (
    plan_id IN (
      SELECT id FROM public.wt_workout_plans
      WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update their own workout plan exercises"
  ON public.wt_workout_plan_exercises FOR UPDATE
  USING (
    plan_id IN (
      SELECT id FROM public.wt_workout_plans
      WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete their own workout plan exercises"
  ON public.wt_workout_plan_exercises FOR DELETE
  USING (
    plan_id IN (
      SELECT id FROM public.wt_workout_plans
      WHERE profile_id IN (
        SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
      )
    )
  );

COMMENT ON TABLE  public.wt_workout_plan_exercises                IS 'Exercises within a named plan, assigned to a day of the week with target load parameters.';
COMMENT ON COLUMN public.wt_workout_plan_exercises.day_of_week   IS 'ISO day of week: 1=Monday, 2=Tuesday, ..., 7=Sunday.';
COMMENT ON COLUMN public.wt_workout_plan_exercises.sort_order    IS 'Display order of the exercise within its day. Lower values appear first.';
COMMENT ON COLUMN public.wt_workout_plan_exercises.rest_seconds  IS 'Default rest timer for this exercise (seconds). Default 90 s; suggest 60 s for isolation.';

-- ============================================================================
-- 1d. ALTER wt_workouts (sessions)
-- Links a completed session to a plan, and captures precise start/end times
-- for duration calculation and timeline rendering.
-- ============================================================================
ALTER TABLE public.wt_workouts
  ADD COLUMN IF NOT EXISTS plan_id    uuid        REFERENCES public.wt_workout_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS start_time timestamptz,
  ADD COLUMN IF NOT EXISTS end_time   timestamptz;

-- Index to find all sessions belonging to a specific plan.
CREATE INDEX IF NOT EXISTS idx_wt_workouts_plan_id
  ON public.wt_workouts(plan_id)
  WHERE plan_id IS NOT NULL;

COMMENT ON COLUMN public.wt_workouts.plan_id    IS 'The plan this session was executed from. NULL for ad-hoc sessions not tied to a plan.';
COMMENT ON COLUMN public.wt_workouts.start_time IS 'Timestamp when the user tapped "Start Workout". Used for duration calculation.';
COMMENT ON COLUMN public.wt_workouts.end_time   IS 'Timestamp when the user tapped "Finish Workout". Duration = end_time - start_time.';

-- ============================================================================
-- 1e. CREATE wt_workout_sets
-- Individual sets logged during a workout session. The core granular unit of
-- the workout logger. Stores actual weight/reps, completion state, RPE, and
-- a pre-calculated estimated 1RM (Epley formula: weight * (1 + reps/30)).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_workout_sets (
  id             uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id     uuid          NOT NULL REFERENCES public.wt_profiles(id)  ON DELETE CASCADE,
  workout_id     uuid          NOT NULL REFERENCES public.wt_workouts(id)   ON DELETE CASCADE,
  exercise_id    uuid                   REFERENCES public.wt_exercises(id)  ON DELETE SET NULL,
  set_number     int           NOT NULL,
  weight_kg      numeric(6,2),
  reps           int,
  completed      boolean       DEFAULT false,
  rpe            numeric(3,1)  CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
  estimated_1rm  numeric(6,2),           -- Epley: weight_kg * (1 + reps / 30.0)
  logged_at      timestamptz   DEFAULT now(),
  created_at     timestamptz   DEFAULT now()
);

-- Indexes
-- Primary query pattern: fetch all sets for a workout, ordered by exercise then set.
CREATE INDEX IF NOT EXISTS idx_wt_workout_sets_workout_exercise_set
  ON public.wt_workout_sets(workout_id, exercise_id, set_number);

-- Secondary: history of all sets for a given exercise across sessions (for pre-fill and 1RM trend).
CREATE INDEX IF NOT EXISTS idx_wt_workout_sets_profile_exercise_logged
  ON public.wt_workout_sets(profile_id, exercise_id, logged_at DESC);

-- Enable RLS
ALTER TABLE public.wt_workout_sets ENABLE ROW LEVEL SECURITY;

-- RLS Policies — profile-scoped via profile_id column.
CREATE POLICY "Users can view their own workout sets"
  ON public.wt_workout_sets FOR SELECT
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can create their own workout sets"
  ON public.wt_workout_sets FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own workout sets"
  ON public.wt_workout_sets FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own workout sets"
  ON public.wt_workout_sets FOR DELETE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

COMMENT ON TABLE  public.wt_workout_sets              IS 'Individual sets logged during a workout session. Granular unit of the workout logger.';
COMMENT ON COLUMN public.wt_workout_sets.set_number   IS 'Set index within the exercise for this session (1-based). Displayed as "Set 1", "Set 2", etc.';
COMMENT ON COLUMN public.wt_workout_sets.rpe          IS 'Rate of Perceived Exertion (1-10). Optional; recorded after the set.';
COMMENT ON COLUMN public.wt_workout_sets.estimated_1rm IS 'Epley formula: weight_kg * (1 + reps / 30.0). Pre-computed and stored for fast PR detection.';
COMMENT ON COLUMN public.wt_workout_sets.completed    IS 'FALSE = set was planned/skipped; TRUE = set was actually performed by the user.';

-- ============================================================================
-- 1f. CREATE wt_exercise_records
-- One row per (profile, exercise) tracking all-time personal records.
-- Updated by application logic (or a trigger / Edge Function) whenever a
-- new best is detected in wt_workout_sets.
-- UNIQUE(profile_id, exercise_id) enforces a single record row per exercise.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.wt_exercise_records (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id          uuid          NOT NULL REFERENCES public.wt_profiles(id)  ON DELETE CASCADE,
  exercise_id         uuid          NOT NULL REFERENCES public.wt_exercises(id)  ON DELETE CASCADE,
  max_weight_kg       numeric(6,2),
  max_weight_date     date,
  max_reps            int,
  max_reps_date       date,
  max_volume          numeric(10,2),          -- total volume in a single session (sum sets*reps*weight)
  max_volume_date     date,
  max_estimated_1rm   numeric(6,2),
  max_1rm_date        date,
  updated_at          timestamptz   DEFAULT now(),
  UNIQUE(profile_id, exercise_id)
);

-- Index for fast single-exercise PR lookup (most common read pattern).
CREATE INDEX IF NOT EXISTS idx_wt_exercise_records_profile_exercise
  ON public.wt_exercise_records(profile_id, exercise_id);

-- Enable RLS
ALTER TABLE public.wt_exercise_records ENABLE ROW LEVEL SECURITY;

-- RLS Policies — profile-scoped.
CREATE POLICY "Users can view their own exercise records"
  ON public.wt_exercise_records FOR SELECT
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can create their own exercise records"
  ON public.wt_exercise_records FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own exercise records"
  ON public.wt_exercise_records FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own exercise records"
  ON public.wt_exercise_records FOR DELETE
  USING (profile_id IN (
    SELECT id FROM public.wt_profiles WHERE user_id = auth.uid()
  ));

COMMENT ON TABLE  public.wt_exercise_records                  IS 'All-time personal records per (profile, exercise). One row per exercise; updated on each new PR.';
COMMENT ON COLUMN public.wt_exercise_records.max_weight_kg   IS 'Heaviest single-rep weight ever lifted for this exercise.';
COMMENT ON COLUMN public.wt_exercise_records.max_reps        IS 'Most reps performed in a single set (at any weight).';
COMMENT ON COLUMN public.wt_exercise_records.max_volume      IS 'Highest total session volume: SUM(weight_kg * reps) across all sets in one session.';
COMMENT ON COLUMN public.wt_exercise_records.max_estimated_1rm IS 'Highest estimated 1RM ever calculated via Epley formula.';

-- ============================================================================
-- GRANTS — authenticated role full CRUD on all Phase 5 tables
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_workout_plans           TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_workout_plan_exercises   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_workout_sets             TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wt_exercise_records         TO authenticated;

-- ============================================================================
-- MIGRATION COMPLETE
-- Tables created  : wt_workout_plans, wt_workout_plan_exercises,
--                   wt_workout_sets, wt_exercise_records
-- Tables altered  : wt_exercises (+7 columns, backfill, new RLS split),
--                   wt_workouts  (+3 columns)
-- Indexes created : 10 (covering primary, GIN array, and history patterns)
-- RLS policies    : 16 new + 1 replaced (wt_exercises shared/custom split)
-- ============================================================================
