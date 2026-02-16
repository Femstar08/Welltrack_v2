-- Migration: Supplements and Workouts Tables
-- WellTrack Phase 1
-- Creates: wt_supplements, wt_supplement_logs, wt_supplement_protocols,
--          wt_exercises, wt_workouts, wt_workout_logs

-- =====================================================
-- 1. SUPPLEMENTS TABLE
-- =====================================================
-- Core supplement definitions (can be profile-specific or shared)
CREATE TABLE wt_supplements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE SET NULL,
    name text NOT NULL,
    brand text,
    description text,
    dosage numeric(10,2),
    unit text,
    serving_size text,
    barcode text,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for profile-specific supplements lookup
CREATE INDEX idx_supplements_profile ON wt_supplements(profile_id);

-- Enable RLS
ALTER TABLE wt_supplements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for supplements
CREATE POLICY "Users can view their own supplements"
    ON wt_supplements FOR SELECT
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ) OR profile_id IS NULL);

CREATE POLICY "Users can create their own supplements"
    ON wt_supplements FOR INSERT
    WITH CHECK (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own supplements"
    ON wt_supplements FOR UPDATE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own supplements"
    ON wt_supplements FOR DELETE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_supplements
    BEFORE UPDATE ON wt_supplements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =====================================================
-- 2. SUPPLEMENT LOGS TABLE
-- =====================================================
-- Tracks actual supplement intake
CREATE TABLE wt_supplement_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    supplement_id uuid REFERENCES wt_supplements(id) ON DELETE CASCADE NOT NULL,
    taken_at timestamptz DEFAULT now() NOT NULL,
    protocol_time wt_supplement_time,
    dosage_taken numeric(10,2),
    status text DEFAULT 'taken' NOT NULL,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT valid_supplement_log_status CHECK (status IN ('taken', 'skipped', 'planned'))
);

-- Index for profile and time-based queries
CREATE INDEX idx_supplement_logs_profile_taken ON wt_supplement_logs(profile_id, taken_at);

-- Enable RLS
ALTER TABLE wt_supplement_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for supplement logs
CREATE POLICY "Users can view their own supplement logs"
    ON wt_supplement_logs FOR SELECT
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can create their own supplement logs"
    ON wt_supplement_logs FOR INSERT
    WITH CHECK (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own supplement logs"
    ON wt_supplement_logs FOR UPDATE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own supplement logs"
    ON wt_supplement_logs FOR DELETE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));


-- =====================================================
-- 3. SUPPLEMENT PROTOCOLS TABLE
-- =====================================================
-- Defines supplement schedules and protocols
CREATE TABLE wt_supplement_protocols (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    supplement_id uuid REFERENCES wt_supplements(id) ON DELETE CASCADE NOT NULL,
    time_of_day wt_supplement_time NOT NULL,
    dosage numeric(10,2) NOT NULL,
    unit text,
    linked_goal_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE(profile_id, supplement_id, time_of_day)
);

-- Enable RLS
ALTER TABLE wt_supplement_protocols ENABLE ROW LEVEL SECURITY;

-- RLS Policies for supplement protocols
CREATE POLICY "Users can view their own supplement protocols"
    ON wt_supplement_protocols FOR SELECT
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can create their own supplement protocols"
    ON wt_supplement_protocols FOR INSERT
    WITH CHECK (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own supplement protocols"
    ON wt_supplement_protocols FOR UPDATE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own supplement protocols"
    ON wt_supplement_protocols FOR DELETE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_supplement_protocols
    BEFORE UPDATE ON wt_supplement_protocols
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =====================================================
-- 4. EXERCISES TABLE (Reference)
-- =====================================================
-- Master exercise library
CREATE TABLE wt_exercises (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    muscle_group text,
    equipment text,
    instructions text,
    difficulty text,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE wt_exercises ENABLE ROW LEVEL SECURITY;

-- RLS Policies for exercises (read-only for all authenticated users)
CREATE POLICY "All authenticated users can view exercises"
    ON wt_exercises FOR SELECT
    USING (auth.uid() IS NOT NULL);


-- =====================================================
-- 5. WORKOUTS TABLE
-- =====================================================
-- Planned or completed workout sessions
CREATE TABLE wt_workouts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    workout_type text,
    scheduled_date date,
    completed boolean DEFAULT false NOT NULL,
    completed_at timestamptz,
    duration_minutes int,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for profile and scheduled date queries
CREATE INDEX idx_workouts_profile_scheduled ON wt_workouts(profile_id, scheduled_date);

-- Enable RLS
ALTER TABLE wt_workouts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for workouts
CREATE POLICY "Users can view their own workouts"
    ON wt_workouts FOR SELECT
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can create their own workouts"
    ON wt_workouts FOR INSERT
    WITH CHECK (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own workouts"
    ON wt_workouts FOR UPDATE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own workouts"
    ON wt_workouts FOR DELETE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_workouts
    BEFORE UPDATE ON wt_workouts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =====================================================
-- 6. WORKOUT LOGS TABLE
-- =====================================================
-- Individual exercise performance records
CREATE TABLE wt_workout_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    workout_id uuid REFERENCES wt_workouts(id) ON DELETE SET NULL,
    exercise_id uuid REFERENCES wt_exercises(id) ON DELETE SET NULL,
    sets int,
    reps int,
    weight_kg numeric(6,2),
    duration_seconds int,
    distance_m numeric(10,2),
    notes text,
    logged_at timestamptz DEFAULT now() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for efficient querying
CREATE INDEX idx_workout_logs_profile_logged ON wt_workout_logs(profile_id, logged_at);
CREATE INDEX idx_workout_logs_workout ON wt_workout_logs(workout_id);

-- Enable RLS
ALTER TABLE wt_workout_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for workout logs
CREATE POLICY "Users can view their own workout logs"
    ON wt_workout_logs FOR SELECT
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can create their own workout logs"
    ON wt_workout_logs FOR INSERT
    WITH CHECK (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update their own workout logs"
    ON wt_workout_logs FOR UPDATE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete their own workout logs"
    ON wt_workout_logs FOR DELETE
    USING (profile_id IN (
        SELECT id FROM wt_profiles WHERE user_id = auth.uid()
    ));


-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE wt_supplements IS 'Supplement definitions - can be profile-specific or shared (profile_id NULL)';
COMMENT ON TABLE wt_supplement_logs IS 'Tracks actual supplement intake with status (taken/skipped/planned)';
COMMENT ON TABLE wt_supplement_protocols IS 'Defines supplement schedules and protocols per profile';
COMMENT ON TABLE wt_exercises IS 'Master exercise library - reference data for all users';
COMMENT ON TABLE wt_workouts IS 'Planned or completed workout sessions';
COMMENT ON TABLE wt_workout_logs IS 'Individual exercise performance records within workouts';

COMMENT ON COLUMN wt_supplements.profile_id IS 'NULL for shared supplements, set for profile-specific';
COMMENT ON COLUMN wt_supplement_logs.protocol_time IS 'Links to protocol time_of_day if from scheduled protocol';
COMMENT ON COLUMN wt_supplement_protocols.linked_goal_id IS 'FK to wt_goals - will be added in migration 6';
COMMENT ON COLUMN wt_workout_logs.workout_id IS 'NULL if standalone exercise log, set if part of workout';
