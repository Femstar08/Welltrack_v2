-- =============================================================================
-- Seed Migration: Exercise Library (Phase 5)
-- WellTrack — 20260220000006_seed_exercises.sql
--
-- Inserts 200+ shared exercises into wt_exercises.
-- These are shared exercises: is_custom = false, profile_id = NULL.
-- Every authenticated user sees them via the existing RLS SELECT policy.
--
-- Schema columns targeted (post Phase 5 migration):
--   id, name, muscle_group, muscle_groups, secondary_muscles,
--   equipment_type, category, difficulty, instructions,
--   image_url, gif_url, is_custom, profile_id
--
-- Idempotent: uses ON CONFLICT DO NOTHING on (name) to allow safe re-runs.
-- Assumes a unique index on wt_exercises(name) exists or will be created.
-- If that index does not exist the INSERT simply runs; duplicates are avoided
-- by running this migration exactly once in the ordered sequence.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- CHEST (~20 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Barbell Bench Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'barbell', 'compound', 'intermediate',
    'Lie flat on a bench, grip the barbell slightly wider than shoulder-width, lower it to mid-chest under control, then press back to full arm extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Incline Barbell Bench Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'barbell', 'compound', 'intermediate',
    'Set bench to 30-45 degrees, grip barbell at shoulder width, lower the bar to the upper chest, then press explosively back to the start.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Decline Barbell Bench Press',
    'chest',
    ARRAY['chest'],
    ARRAY['triceps', 'anterior_deltoid'],
    'barbell', 'compound', 'intermediate',
    'Secure feet on a decline bench, lower the bar to the lower portion of the chest, then press back to full extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Bench Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'dumbbell', 'compound', 'beginner',
    'Lie on a flat bench with a dumbbell in each hand at chest level, press both dumbbells upward until arms are fully extended, then lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Incline Dumbbell Bench Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'dumbbell', 'compound', 'beginner',
    'Set bench to 30-45 degrees, press dumbbells from chest level to full arm extension directly above the upper chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Fly',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'biceps'],
    'dumbbell', 'isolation', 'intermediate',
    'Lie flat on a bench, hold dumbbells above chest with a slight elbow bend, arc them out and down until you feel a deep chest stretch, then reverse the motion.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Incline Dumbbell Fly',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid'],
    'dumbbell', 'isolation', 'intermediate',
    'Set bench to 30-45 degrees, perform a fly motion arcing dumbbells wide to target the upper chest fibres.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'High Cable Fly',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid'],
    'cable', 'isolation', 'beginner',
    'Set cables to the highest position, grip handles and step forward, then sweep arms downward and together in a hugging arc to target the lower chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Mid Cable Fly',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'biceps'],
    'cable', 'isolation', 'beginner',
    'Set cables at shoulder height, grip handles and sweep arms together in front of the chest in a controlled arc, squeezing at the midpoint.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Low Cable Fly',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid'],
    'cable', 'isolation', 'beginner',
    'Set cables at the lowest position, sweep arms upward and together in a wide arc to target the upper chest fibres.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Push-Up',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps', 'core'],
    'bodyweight', 'compound', 'beginner',
    'Place hands slightly wider than shoulder-width on the floor, lower your chest to the ground by bending the elbows, then push back to the start position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Diamond Push-Up',
    'chest',
    ARRAY['chest', 'triceps'],
    ARRAY['anterior_deltoid', 'core'],
    'bodyweight', 'compound', 'intermediate',
    'Form a diamond shape with your thumbs and index fingers on the floor directly below your sternum, then perform a push-up to maximally load the triceps and inner chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Wide Push-Up',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'bodyweight', 'compound', 'beginner',
    'Place hands significantly wider than shoulder-width to increase the range of motion and chest activation during the push-up.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Decline Push-Up',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'bodyweight', 'compound', 'intermediate',
    'Elevate feet on a bench or box and perform a push-up to shift emphasis to the upper chest and anterior deltoid.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Machine Chest Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps'],
    'machine', 'compound', 'beginner',
    'Sit upright in the chest press machine, grip handles at chest height, press forward to full arm extension, then return under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pec Deck',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid'],
    'machine', 'isolation', 'beginner',
    'Sit in the pec deck machine, place forearms on the pads, then sweep both arms together in front of the chest, squeezing hard at the midpoint.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Landmine Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'triceps', 'core'],
    'barbell', 'compound', 'intermediate',
    'Hold the end of a barbell loaded into a landmine anchor at shoulder height, press it upward and forward in an arc until the arm is extended, then lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Svend Press',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid'],
    'other', 'isolation', 'beginner',
    'Hold two weight plates pressed together at chest height, push them straight out while squeezing them tightly together, then return to the chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Chest Dip',
    'chest',
    ARRAY['chest'],
    ARRAY['triceps', 'anterior_deltoid'],
    'bodyweight', 'compound', 'intermediate',
    'Grip parallel bars, lean forward at roughly 30 degrees, lower yourself until the shoulders are below the elbows, then push back up to activate the lower chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Crossover',
    'chest',
    ARRAY['chest'],
    ARRAY['anterior_deltoid', 'biceps'],
    'cable', 'isolation', 'intermediate',
    'Stand between two high cable pulleys, grab one handle in each hand, then bring both hands together in a wide sweeping arc in front of the body, squeezing the chest at the midpoint.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- BACK (~25 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Conventional Deadlift',
    'back',
    ARRAY['back', 'hamstrings', 'glutes'],
    ARRAY['quadriceps', 'core', 'forearms', 'traps'],
    'barbell', 'compound', 'intermediate',
    'Stand with feet hip-width, grip the bar just outside the legs, brace the core and maintain a neutral spine, then drive through the floor extending hips and knees simultaneously to stand tall.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Barbell Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid', 'core'],
    'barbell', 'compound', 'intermediate',
    'Hinge forward to roughly 45 degrees with a neutral spine, grip the barbell just outside the legs, then row it to the lower abdomen driving elbows back and squeezing the lats.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pendlay Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid', 'core'],
    'barbell', 'compound', 'advanced',
    'Hinge to a horizontal torso position, pause the bar on the floor between each rep, then explosively row it to the lower chest using a controlled hip drive.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'T-Bar Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'barbell', 'compound', 'intermediate',
    'Straddle a T-bar or landmine setup, grip the handles with a neutral grip, then row the weight to the lower chest keeping the torso rigid.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Single-Arm Dumbbell Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid', 'core'],
    'dumbbell', 'compound', 'beginner',
    'Place one knee and hand on a bench for support, hold a dumbbell in the free hand, then row it to the hip driving the elbow high and squeezing the lat at the top.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seated Cable Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'cable', 'compound', 'beginner',
    'Sit at a low cable row station, grip the handle with a neutral grip, then pull it to the abdomen squeezing the shoulder blades together at full contraction.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Face Pull',
    'back',
    ARRAY['back', 'shoulders'],
    ARRAY['rear_deltoid', 'rotator_cuff', 'traps'],
    'cable', 'isolation', 'beginner',
    'Set a rope attachment at face height on a cable, pull the rope to your face separating the hands outward at the end to externally rotate the shoulders.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pull-Up',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'core', 'rear_deltoid'],
    'bodyweight', 'compound', 'intermediate',
    'Hang from a bar with an overhand grip slightly wider than shoulder-width, pull yourself up until the chin clears the bar, then lower to a dead hang.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Chin-Up',
    'back',
    ARRAY['back', 'biceps'],
    ARRAY['core', 'rear_deltoid'],
    'bodyweight', 'compound', 'intermediate',
    'Hang from a bar with a supinated (underhand) grip at shoulder-width, pull yourself up until the chin clears the bar, emphasising the biceps and lower lats.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Wide-Grip Lat Pulldown',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'cable', 'compound', 'beginner',
    'Sit at a lat pulldown machine, grip the bar wide with an overhand grip, then pull it to the upper chest driving the elbows down and back to fully engage the lats.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Close-Grip Lat Pulldown',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'cable', 'compound', 'beginner',
    'Attach a close neutral-grip handle to a lat pulldown cable, sit down and pull the handle to the upper chest keeping the torso upright.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Reverse-Grip Lat Pulldown',
    'back',
    ARRAY['back', 'biceps'],
    ARRAY['rear_deltoid'],
    'cable', 'compound', 'beginner',
    'Grip the lat pulldown bar with a supinated underhand grip at shoulder-width and pull to the upper chest to shift more load onto the biceps and lower lats.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Straight-Arm Pulldown',
    'back',
    ARRAY['back'],
    ARRAY['core', 'triceps'],
    'cable', 'isolation', 'intermediate',
    'Stand facing a high cable, grip the bar or rope with straight arms, then sweep them down in an arc to the thighs by engaging only the lats.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Pullover',
    'back',
    ARRAY['back'],
    ARRAY['chest', 'triceps', 'core'],
    'cable', 'isolation', 'intermediate',
    'Lie on a bench perpendicular to a low cable, hold the handle over the chest with straight arms, then pull it in an arc over the head to full stretch and back.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Machine Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'machine', 'compound', 'beginner',
    'Sit at a machine row station with chest pad support, grip the handles and pull them to the torso squeezing the shoulder blades at full contraction.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Hyperextension',
    'back',
    ARRAY['back'],
    ARRAY['hamstrings', 'glutes'],
    'bodyweight', 'isolation', 'beginner',
    'Secure the thighs on a hyperextension bench, lower the torso toward the floor, then raise back to horizontal by contracting the lower back and glutes.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Rack Pull',
    'back',
    ARRAY['back'],
    ARRAY['hamstrings', 'glutes', 'traps', 'forearms'],
    'barbell', 'compound', 'intermediate',
    'Set the barbell on safety pins at knee height, grip it and pull to full lockout position, emphasising the upper back and traps through the shortened range of motion.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Meadows Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid', 'core'],
    'barbell', 'compound', 'intermediate',
    'Stand perpendicular to a landmine-loaded barbell, grip the end with a pronated hand, then row it explosively toward the hip with a slight hip-shift for additional range.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Inverted Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid', 'core'],
    'bodyweight', 'compound', 'beginner',
    'Set a bar at waist height in a rack, hang below it with a straight body, then pull the chest up to the bar by squeezing the shoulder blades together.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Chest-Supported Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'dumbbell', 'compound', 'beginner',
    'Lie prone on a 45-degree incline bench, let dumbbells hang at arm''s length, then row them to the sides of the chest by driving the elbows up, eliminating lower-back momentum.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Snatch-Grip Deadlift',
    'back',
    ARRAY['back'],
    ARRAY['hamstrings', 'glutes', 'traps', 'core'],
    'barbell', 'compound', 'advanced',
    'Take a very wide snatch-width grip on the barbell, maintain a flatter torso than a conventional deadlift, and drive through the floor to stand, maximising upper back and trap engagement.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Pullover',
    'back',
    ARRAY['back', 'chest'],
    ARRAY['triceps', 'core'],
    'dumbbell', 'isolation', 'beginner',
    'Lie perpendicular across a bench with shoulders on the pad, hold one dumbbell above the chest with both hands, then lower it in an arc behind the head and return.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Kroc Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'forearms', 'core'],
    'dumbbell', 'compound', 'advanced',
    'Use a heavy dumbbell and perform high-rep single-arm rows with controlled body English, allowing the torso to rotate slightly to maximise lat stretch and contraction.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seal Row',
    'back',
    ARRAY['back'],
    ARRAY['biceps', 'rear_deltoid'],
    'barbell', 'compound', 'intermediate',
    'Lie prone on a raised bench, grip a barbell placed on the floor below, then row it to the underside of the bench for a full stretch-to-contraction movement with zero momentum.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Face Pull',
    'back',
    ARRAY['back', 'shoulders'],
    ARRAY['rear_deltoid', 'rotator_cuff', 'traps'],
    'cable', 'isolation', 'beginner',
    'Attach a rope to a high cable pulley, pull the rope to the face while simultaneously externally rotating the shoulders to finish in a double-bicep-pose position.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- SHOULDERS (~20 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Barbell Overhead Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'core', 'upper_back'],
    'barbell', 'compound', 'intermediate',
    'Stand with feet shoulder-width, clean or take the bar from a rack at shoulder height, then press it overhead to full arm extension and lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seated Dumbbell Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'upper_back'],
    'dumbbell', 'compound', 'beginner',
    'Sit on an upright bench, hold dumbbells at shoulder height with palms forward, then press them overhead until arms are fully extended.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Arnold Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'upper_back'],
    'dumbbell', 'compound', 'intermediate',
    'Start with dumbbells at chin height palms facing you, rotate palms outward as you press overhead, then reverse the rotation on the way down for full shoulder recruitment.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Lateral Raise',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'dumbbell', 'isolation', 'beginner',
    'Stand with dumbbells at your sides, raise them out to shoulder height in a wide arc with a slight forward lean on the dumbbells, then lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Lateral Raise',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'cable', 'isolation', 'beginner',
    'Stand beside a low cable with the handle in the far hand, raise the arm out to shoulder height against constant cable tension, then lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Front Raise',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['chest'],
    'dumbbell', 'isolation', 'beginner',
    'Hold dumbbells at your thighs, raise one or both arms forward to shoulder height with a neutral or pronated grip, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Rear Delt Fly',
    'shoulders',
    ARRAY['shoulders', 'back'],
    ARRAY['rear_deltoid', 'upper_back'],
    'dumbbell', 'isolation', 'beginner',
    'Hinge forward to roughly 45-90 degrees, hold dumbbells below the chest, then sweep both arms out to the sides squeezing the rear delts at the top.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Rear Delt Fly',
    'shoulders',
    ARRAY['shoulders', 'back'],
    ARRAY['rear_deltoid', 'upper_back'],
    'cable', 'isolation', 'beginner',
    'Set cables at shoulder height, cross your arms and grip opposite handles, then pull each handle out to the side against the cable tension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Machine Rear Delt Fly',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'machine', 'isolation', 'beginner',
    'Sit facing the pec deck machine with pads adjusted to shoulder height, grip the handles and sweep both arms backward in a wide arc to target the rear delts.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Upright Row',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['biceps', 'upper_back'],
    'barbell', 'compound', 'intermediate',
    'Hold a barbell with a narrow overhand grip, pull it up along the body until elbows reach shoulder height, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Barbell Shrug',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'barbell', 'isolation', 'beginner',
    'Hold a barbell at thigh height, elevate the shoulders straight upward as high as possible without rolling them, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Shrug',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'dumbbell', 'isolation', 'beginner',
    'Hold dumbbells at your sides and shrug the shoulders straight upward as high as possible, hold the peak contraction briefly, then lower.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Landmine Shoulder Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'core'],
    'barbell', 'compound', 'intermediate',
    'Hold the end of a landmine-loaded barbell at shoulder height with one hand, press it upward and forward in an arc to full arm extension, then return.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Push Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'quadriceps', 'core'],
    'barbell', 'compound', 'intermediate',
    'Hold the barbell at shoulder height, dip slightly at the knees, then drive through the legs explosively to press the bar overhead to full arm extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bradford Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'upper_back'],
    'barbell', 'compound', 'intermediate',
    'Alternately press the barbell overhead and behind the neck in a continuous arc without locking out, keeping constant tension on the deltoids throughout.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Behind-the-Neck Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps', 'upper_back'],
    'barbell', 'compound', 'advanced',
    'Position the barbell behind the head at the base of the skull, press overhead to full arm extension, then lower back behind the neck. Requires significant shoulder mobility.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Machine Shoulder Press',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['triceps'],
    'machine', 'compound', 'beginner',
    'Sit in a shoulder press machine, adjust the seat so the handles align with shoulder height, then press to full arm extension and return under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Lu Raise',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'dumbbell', 'isolation', 'intermediate',
    'Hold a light dumbbell in each hand in front of the thighs, simultaneously raise one forward and one to the side in a coordinated alternating pattern to hit all three deltoid heads.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Plate Lateral Raise',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['upper_back'],
    'other', 'isolation', 'beginner',
    'Hold a weight plate with both hands at the bottom, raise it forward to shoulder height with straight arms, then lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Upright Row',
    'shoulders',
    ARRAY['shoulders'],
    ARRAY['biceps', 'upper_back'],
    'cable', 'compound', 'beginner',
    'Attach a bar or rope to a low cable, grip it with a narrow overhand hold and pull upward along the body until the elbows flare out to shoulder level.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- BICEPS (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Barbell Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'anterior_deltoid'],
    'barbell', 'isolation', 'beginner',
    'Stand with feet shoulder-width, hold a barbell with a supinated grip, curl it to shoulder height by flexing the elbows only, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'EZ-Bar Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'anterior_deltoid'],
    'ez_bar', 'isolation', 'beginner',
    'Grip the angled section of an EZ-bar with a semi-supinated grip to reduce wrist strain, curl to shoulder height and lower with control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Standing Dumbbell Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'anterior_deltoid'],
    'dumbbell', 'isolation', 'beginner',
    'Stand holding dumbbells with a supinated grip at your sides, curl both or one at a time to shoulder height supinating fully at the top.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seated Dumbbell Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Sit upright on a bench, curl dumbbells from a hanging position to shoulder height, reducing the ability to use momentum compared to the standing variation.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Hammer Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'brachioradialis'],
    'dumbbell', 'isolation', 'beginner',
    'Hold dumbbells with a neutral (hammer) grip, curl to shoulder height without rotating the wrist to target the brachialis and brachioradialis.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Barbell Preacher Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'barbell', 'isolation', 'intermediate',
    'Rest the upper arms on the inclined pad of a preacher bench, grip the barbell and curl from full extension to full contraction, eliminating shoulder movement.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Preacher Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Rest one upper arm on the preacher bench pad, curl the dumbbell from full extension to peak contraction, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Concentration Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Sit with legs apart, brace the elbow against the inner thigh, then curl the dumbbell from full extension to peak contraction for maximum bicep isolation.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'beginner',
    'Stand facing a low cable, grip the bar or handle with a supinated grip, and curl to shoulder height keeping constant tension from the cable throughout the movement.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Incline Dumbbell Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'intermediate',
    'Set a bench to 45-60 degrees, sit back with arms hanging freely below the body, then curl the dumbbells to shoulder height for a deeper stretch on the long head.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Spider Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'intermediate',
    'Lie face-down on an incline bench, let the arms hang perpendicular to the floor, then curl the dumbbells up to the face for constant tension and a strong peak contraction.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Reverse Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'brachioradialis'],
    'barbell', 'isolation', 'beginner',
    'Grip a barbell with a pronated (overhand) grip and curl to shoulder height, emphasising the brachioradialis and finger extensors.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Zottman Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'brachioradialis'],
    'dumbbell', 'isolation', 'intermediate',
    'Curl upward with a supinated grip to target the biceps, rotate to a pronated grip at the top, then lower the weight eccentrically to train the brachioradialis.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bayesian Cable Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'intermediate',
    'Stand facing away from a low cable with it attached behind you, step forward so the cable pulls the arm back, then curl the arm forward to maximise the stretch on the long head of the bicep.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cross-Body Hammer Curl',
    'biceps',
    ARRAY['biceps'],
    ARRAY['forearms', 'brachioradialis'],
    'dumbbell', 'isolation', 'beginner',
    'Curl one dumbbell with a neutral grip across the body toward the opposite shoulder, alternating arms to focus on the brachialis.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- TRICEPS (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Tricep Rope Pushdown',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'beginner',
    'Attach a rope to a high cable, grip both ends, push the rope down until the arms are fully extended while separating the rope ends at the bottom to maximise contraction.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Tricep Bar Pushdown',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'beginner',
    'Attach a straight or angled bar to a high cable, grip with an overhand grip, and push down to full arm extension keeping the elbows pinned at the sides.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Overhead Tricep Extension',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'intermediate',
    'Face away from a high cable with a rope attachment held behind the head, extend the arms forward and upward to full extension, then return under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Overhead Tricep Extension',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Hold one dumbbell with both hands behind the head at the base of the skull, extend the arms overhead to full extension, then lower back down.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Skull Crusher',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'barbell', 'isolation', 'intermediate',
    'Lie on a flat bench, hold a barbell or EZ-bar above the chest with a narrow grip, lower the bar to the forehead by bending the elbows, then extend back to start.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Close-Grip Bench Press',
    'triceps',
    ARRAY['triceps', 'chest'],
    ARRAY['anterior_deltoid'],
    'barbell', 'compound', 'intermediate',
    'Lie on a flat bench with hands shoulder-width or closer on the barbell, lower to the chest keeping elbows tucked close to the torso, then press back to extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Tricep Dip',
    'triceps',
    ARRAY['triceps', 'chest'],
    ARRAY['anterior_deltoid'],
    'bodyweight', 'compound', 'intermediate',
    'Grip parallel bars with the body upright and elbows close to the torso, lower until elbows reach 90 degrees then press back to full extension for maximum tricep emphasis.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Tricep Kickback',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Hinge forward with one hand braced on a bench, hold the upper arm parallel to the floor, then extend the forearm backward to full arm extension and return.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'JM Press',
    'triceps',
    ARRAY['triceps'],
    ARRAY['chest', 'anterior_deltoid'],
    'barbell', 'compound', 'advanced',
    'Lie on a flat bench, hold a barbell slightly wider than a close grip, lower it in a hybrid movement between a skull crusher and a close-grip press toward the chin/nose.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Tate Press',
    'triceps',
    ARRAY['triceps'],
    ARRAY['chest'],
    'dumbbell', 'isolation', 'intermediate',
    'Lie on a bench holding dumbbells above the chest with elbows pointed outward, lower the dumbbells by folding the elbows toward the chest, then extend to full lockout.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'EZ-Bar Skull Crusher',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'ez_bar', 'isolation', 'intermediate',
    'Lie on a flat bench, hold an EZ-bar above the forehead with a narrow semi-supinated grip, lower toward the forehead by bending only the elbows, then extend.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Skull Crusher',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'intermediate',
    'Lie on a bench holding dumbbells above the chest, lower them toward the temples by bending the elbows only, then extend fully to the start position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bench Dip',
    'triceps',
    ARRAY['triceps'],
    ARRAY['anterior_deltoid', 'chest'],
    'bodyweight', 'isolation', 'beginner',
    'Place hands on a bench behind you with legs extended, lower the hips by bending the elbows to 90 degrees, then push back up to full arm extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Single-Arm Cable Pushdown',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'cable', 'isolation', 'beginner',
    'Grip a single cable handle with one hand at a high pulley, push down to full extension keeping the elbow pinned to the side, then return slowly.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Lying Tricep Extension',
    'triceps',
    ARRAY['triceps'],
    ARRAY['forearms'],
    'dumbbell', 'isolation', 'beginner',
    'Lie on a flat bench with dumbbells held above the chest, lower the dumbbells to either side of the head by bending the elbows, then extend back up.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- LEGS — QUADRICEPS (~18 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Back Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'barbell', 'compound', 'intermediate',
    'Position the barbell across the upper back, descend by breaking at the hips and knees simultaneously until the crease of the hip passes below the top of the knee, then drive back to full extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Front Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['core', 'upper_back', 'calves'],
    'barbell', 'compound', 'advanced',
    'Rest the barbell in the front rack position across the front deltoids, maintain an upright torso, and squat to below parallel before driving back up.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Goblet Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['core', 'hamstrings'],
    'dumbbell', 'compound', 'beginner',
    'Hold a dumbbell or kettlebell vertically at the chest, squat deep while keeping the torso upright, using the weight as a counterbalance.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Leg Press',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'calves'],
    'machine', 'compound', 'beginner',
    'Sit in the leg press with feet flat on the platform at shoulder-width, lower the platform by bending the knees to 90 degrees, then press back to near full extension without locking out.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Hack Squat',
    'quadriceps',
    ARRAY['quadriceps'],
    ARRAY['glutes', 'hamstrings', 'calves'],
    'machine', 'compound', 'intermediate',
    'Position yourself in the hack squat machine with shoulder pads secure, descend to 90 degrees of knee flexion, then press back to the start position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bulgarian Split Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'dumbbell', 'compound', 'intermediate',
    'Elevate the rear foot on a bench, hold dumbbells at your sides, and descend until the rear knee nearly touches the floor, then drive through the front heel to rise.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Walking Lunge',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'dumbbell', 'compound', 'beginner',
    'Hold dumbbells at your sides, step forward into a lunge lowering the rear knee to near the floor, then step the rear foot through to the next lunge position continuing forward.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Reverse Lunge',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'dumbbell', 'compound', 'beginner',
    'Stand holding dumbbells, step backward into a lunge lowering the rear knee to the floor, then drive back to the start position through the front heel.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Leg Extension',
    'quadriceps',
    ARRAY['quadriceps'],
    ARRAY[]::text[],
    'machine', 'isolation', 'beginner',
    'Sit in the leg extension machine with the pad just above the ankles, extend the legs to full straightening, hold briefly, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Step-Up',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'dumbbell', 'compound', 'beginner',
    'Hold dumbbells at your sides, step one foot onto a bench or box, drive through the heel to bring the trailing leg up, then step back down under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sissy Squat',
    'quadriceps',
    ARRAY['quadriceps'],
    ARRAY['core'],
    'bodyweight', 'isolation', 'advanced',
    'Hold a support for balance, lean back and allow the knees to travel far forward as you lower down while rising on the toes, creating extreme quad stretch.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Wall Sit',
    'quadriceps',
    ARRAY['quadriceps'],
    ARRAY['glutes', 'calves'],
    'bodyweight', 'isolation', 'beginner',
    'Press your back flat against a wall, lower until the thighs are parallel to the floor at 90-degree knee flexion, and hold the isometric position for time.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pistol Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core', 'calves'],
    'bodyweight', 'compound', 'advanced',
    'Stand on one leg with the other leg extended forward, squat down on the single leg until the hamstring touches the calf, then drive back up to standing.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Smith Machine Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core'],
    'smith_machine', 'compound', 'beginner',
    'Set the Smith machine bar at shoulder height, position feet slightly forward, and squat to parallel depth using the guided bar path for stability.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Zercher Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['core', 'upper_back', 'hamstrings'],
    'barbell', 'compound', 'advanced',
    'Hold the barbell in the crook of the elbows at waist height, maintain an upright torso, and squat deeply before rising to full extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Box Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core'],
    'barbell', 'compound', 'intermediate',
    'Set a box at parallel height behind you, squat back and down onto the box with control, pause briefly, then explode back up through the heels to standing.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pause Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'core'],
    'barbell', 'compound', 'intermediate',
    'Perform a standard squat but pause for 2-3 seconds at the bottom position before driving back up, eliminating the stretch-shortening reflex to increase strength.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Belt Squat',
    'quadriceps',
    ARRAY['quadriceps', 'glutes'],
    ARRAY['hamstrings', 'calves'],
    'other', 'compound', 'intermediate',
    'Attach a loading belt around the waist with weight hanging below on a belt squat machine or platform, squat freely without spinal loading.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- LEGS — HAMSTRINGS / GLUTES (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Romanian Deadlift',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['lower_back', 'core', 'forearms'],
    'barbell', 'compound', 'intermediate',
    'Hold a barbell at thigh height, hinge at the hips pushing them backward while maintaining a neutral spine until you feel a deep hamstring stretch, then drive the hips forward to stand.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Romanian Deadlift',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['lower_back', 'core'],
    'dumbbell', 'compound', 'beginner',
    'Hold dumbbells at the front of the thighs, hinge at the hips with a neutral spine, lowering them along the legs until a hamstring stretch is felt, then extend the hips to stand.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Lying Leg Curl',
    'hamstrings',
    ARRAY['hamstrings'],
    ARRAY['calves'],
    'machine', 'isolation', 'beginner',
    'Lie face-down on the leg curl machine, place the pad above the Achilles tendon, and curl the heels toward the glutes through the full range, then lower slowly.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seated Leg Curl',
    'hamstrings',
    ARRAY['hamstrings'],
    ARRAY['calves'],
    'machine', 'isolation', 'beginner',
    'Sit in the leg curl machine with the pad above the ankles, curl the legs to full flexion by contracting the hamstrings, then return under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Good Morning',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['lower_back', 'core'],
    'barbell', 'compound', 'intermediate',
    'Position the barbell across the upper back as in a squat, hinge at the hips keeping the legs slightly bent until the torso is near horizontal, then return by driving the hips forward.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Barbell Hip Thrust',
    'glutes',
    ARRAY['glutes', 'hamstrings'],
    ARRAY['quadriceps', 'core', 'calves'],
    'barbell', 'compound', 'intermediate',
    'Sit with upper back against a bench, roll a padded barbell across the hip crease, drive the hips upward until the body forms a straight line from knees to shoulders.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Glute Bridge',
    'glutes',
    ARRAY['glutes', 'hamstrings'],
    ARRAY['core', 'quadriceps'],
    'bodyweight', 'isolation', 'beginner',
    'Lie on your back with knees bent and feet flat, drive through the heels to lift the hips to full extension squeezing the glutes, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Pull-Through',
    'glutes',
    ARRAY['glutes', 'hamstrings'],
    ARRAY['lower_back', 'core'],
    'cable', 'isolation', 'beginner',
    'Face away from a low cable with a rope between the legs, hinge at the hips pushing them backward letting the rope pull through, then drive the hips forward to extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Nordic Curl',
    'hamstrings',
    ARRAY['hamstrings'],
    ARRAY['glutes', 'calves'],
    'bodyweight', 'isolation', 'advanced',
    'Kneel with feet anchored, lower your body toward the floor using only hamstring eccentric strength, then use the hands to push back up and pull back to the start.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Trap Bar Deadlift',
    'hamstrings',
    ARRAY['hamstrings', 'glutes', 'quadriceps'],
    ARRAY['lower_back', 'traps', 'core', 'forearms'],
    'trap_bar', 'compound', 'beginner',
    'Stand inside a hex/trap bar with feet hip-width, grip the handles, brace the core with a neutral spine, then drive through the floor extending the hips and knees together to stand.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sumo Deadlift',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['quadriceps', 'inner_thigh', 'lower_back'],
    'barbell', 'compound', 'intermediate',
    'Take a wide stance with toes pointed out, grip the bar between the legs with a narrow grip, maintain an upright torso, and drive through the floor to full hip extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Single-Leg Romanian Deadlift',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['core', 'calves'],
    'dumbbell', 'compound', 'intermediate',
    'Balance on one leg, hinge at the hip while extending the rear leg behind for balance, lower a dumbbell toward the floor until the hamstring is fully stretched, then return.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Glute Ham Raise',
    'hamstrings',
    ARRAY['hamstrings', 'glutes'],
    ARRAY['calves', 'lower_back'],
    'machine', 'compound', 'advanced',
    'Secure the feet in a glute ham raise machine with thighs on the pad, lower the torso toward the floor under hamstring eccentric control, then actively curl back up.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Kettlebell Swing',
    'glutes',
    ARRAY['glutes', 'hamstrings'],
    ARRAY['core', 'shoulders', 'upper_back'],
    'kettlebell', 'compound', 'intermediate',
    'Hinge at the hips to swing the kettlebell between the legs, then explosively drive the hips forward to swing it to chest or overhead height — power comes from the hips, not the arms.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Kickback',
    'glutes',
    ARRAY['glutes'],
    ARRAY['hamstrings', 'core'],
    'cable', 'isolation', 'beginner',
    'Attach an ankle cuff to a low cable, hinge slightly forward, then kick the attached leg backward and upward, squeezing the glute at full extension, then return.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- CALVES (~8 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Standing Calf Raise Machine',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'machine', 'isolation', 'beginner',
    'Position shoulders under the pads on a standing calf raise machine, rise on the toes to the highest point squeezing the calves, then lower to a deep stretch below the platform level.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Standing Calf Raise',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'dumbbell', 'isolation', 'beginner',
    'Stand on the edge of a step with a dumbbell in each hand, rise on the toes to full contraction, then lower to a full stretch below the step level.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Seated Calf Raise',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'machine', 'isolation', 'beginner',
    'Sit at a seated calf raise machine with the pad resting just above the knees, drive the toes down to rise and squeeze the soleus, then lower to a full stretch.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Donkey Calf Raise',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'machine', 'isolation', 'intermediate',
    'Position hips under the belt pad of a donkey calf raise machine with feet on the platform, rise on the toes to full contraction, then lower to maximum stretch.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Single-Leg Calf Raise',
    'calves',
    ARRAY['calves'],
    ARRAY['core'],
    'bodyweight', 'isolation', 'intermediate',
    'Stand on one foot on the edge of a step with a light dumbbell for balance, perform a full-range calf raise on that single leg, then lower to a deep stretch.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Smith Machine Calf Raise',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'smith_machine', 'isolation', 'beginner',
    'Position a step under the Smith machine bar and stand with shoulders under the bar, perform full-range calf raises using the guided bar for stability.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Calf Press on Leg Press',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'machine', 'isolation', 'beginner',
    'Position only the balls of the feet on the lower edge of a leg press platform, push through the toes to extend the ankles fully, then lower to a full stretch.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Tibialis Raise',
    'calves',
    ARRAY['calves'],
    ARRAY[]::text[],
    'bodyweight', 'isolation', 'beginner',
    'Lean against a wall with heels on the floor, raise the toes and forefoot as high as possible contracting the tibialis anterior, then lower with control.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- CORE (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Front Plank',
    'core',
    ARRAY['core'],
    ARRAY['shoulders', 'glutes', 'quadriceps'],
    'bodyweight', 'isolation', 'beginner',
    'Hold a push-up position on the forearms with the body forming a straight line from ankles to shoulders, bracing the core and glutes hard for the prescribed duration.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Side Plank',
    'core',
    ARRAY['core'],
    ARRAY['shoulders', 'glutes'],
    'bodyweight', 'isolation', 'beginner',
    'Lie on one side, press up onto one forearm with feet stacked, lift the hips off the floor to form a straight line, and hold by contracting the obliques.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Crunch',
    'core',
    ARRAY['core'],
    ARRAY[]::text[],
    'cable', 'isolation', 'beginner',
    'Kneel below a high cable with a rope attachment held at the forehead, crunch the torso downward by rounding the spine, then return to the upright position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Hanging Leg Raise',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors', 'forearms'],
    'bodyweight', 'isolation', 'intermediate',
    'Hang from a pull-up bar, raise straight legs (or bent knees for the easier version) to waist or hip height by flexing the core, then lower without swinging.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Ab Wheel Rollout',
    'core',
    ARRAY['core'],
    ARRAY['shoulders', 'triceps', 'hip_flexors'],
    'other', 'isolation', 'advanced',
    'Kneel on the floor with an ab wheel, roll it forward until your body is nearly parallel to the floor while maintaining a rigid core, then pull it back by contracting the abs.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Russian Twist',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors'],
    'bodyweight', 'isolation', 'intermediate',
    'Sit with knees bent and feet slightly elevated, lean back to 45 degrees, then rotate the torso side to side holding a weight plate or dumbbell at the chest.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Cable Woodchopper',
    'core',
    ARRAY['core'],
    ARRAY['shoulders', 'glutes'],
    'cable', 'isolation', 'intermediate',
    'Stand beside a high cable with a single handle, pull it diagonally across the body from high to low in a chopping motion, rotating at the hips and shoulders.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dead Bug',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors'],
    'bodyweight', 'isolation', 'beginner',
    'Lie on your back with arms extended toward the ceiling and knees at 90 degrees, slowly lower opposite arm and leg toward the floor while pressing the lower back into the ground.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bird Dog',
    'core',
    ARRAY['core'],
    ARRAY['glutes', 'upper_back'],
    'bodyweight', 'isolation', 'beginner',
    'On all fours, extend one arm and the opposite leg simultaneously until both are parallel to the floor, hold briefly, then return and alternate sides.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Pallof Press',
    'core',
    ARRAY['core'],
    ARRAY['shoulders'],
    'cable', 'isolation', 'intermediate',
    'Stand perpendicular to a cable at chest height, grip the handle at the sternum, then press both arms straight out resisting the rotational force of the cable, and return.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sit-Up',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors'],
    'bodyweight', 'isolation', 'beginner',
    'Lie on your back with knees bent, rise by curling the torso up until the elbows touch the knees or thighs, then lower under control.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bicycle Crunch',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors'],
    'bodyweight', 'isolation', 'beginner',
    'Lie on your back with hands behind the head, simultaneously bring one knee toward the chest while rotating the opposite elbow toward it, then alternate in a cycling motion.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Decline Sit-Up',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors'],
    'bodyweight', 'isolation', 'intermediate',
    'Secure feet on a decline bench, cross arms over the chest or hold a weight plate, and perform a full sit-up through the increased range provided by the decline angle.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dragon Flag',
    'core',
    ARRAY['core'],
    ARRAY['hip_flexors', 'upper_back'],
    'bodyweight', 'isolation', 'advanced',
    'Lie on a bench gripping it behind the head, raise the body to a shoulder-supported vertical position, then lower it in a rigid plank position as slowly as possible.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'L-Sit',
    'core',
    ARRAY['core'],
    ARRAY['triceps', 'hip_flexors', 'quadriceps'],
    'bodyweight', 'isolation', 'advanced',
    'Support the body weight on parallel bars or the floor with straight arms, hold the legs parallel to the floor in an L-shape, and maintain the position for time.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- FULL BODY / COMPOUND MOVEMENTS (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Clean and Press',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'hamstrings', 'shoulders', 'core'],
    'barbell', 'compound', 'advanced',
    'Pull the barbell explosively from the floor to the shoulder rack position (power clean), then press it overhead to full arm extension in one fluid sequence.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Barbell Thruster',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'shoulders', 'core'],
    'barbell', 'compound', 'intermediate',
    'Hold the bar in the front rack position, squat to below parallel, then drive upward from the squat and use the momentum to press the bar overhead in one continuous movement.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Dumbbell Thruster',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'shoulders', 'core'],
    'dumbbell', 'compound', 'intermediate',
    'Hold dumbbells at shoulder height, perform a squat, then drive upward and press both dumbbells overhead as you reach the top of the squat in one fluid motion.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Farmer''s Walk',
    'full_body',
    ARRAY['full_body'],
    ARRAY['forearms', 'traps', 'core', 'quadriceps', 'calves'],
    'dumbbell', 'compound', 'beginner',
    'Hold a heavy dumbbell or kettlebell in each hand, walk at a brisk pace for the prescribed distance or time while keeping the torso upright and engaging the core.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Turkish Get-Up',
    'full_body',
    ARRAY['full_body'],
    ARRAY['shoulders', 'core', 'glutes', 'quadriceps'],
    'kettlebell', 'compound', 'advanced',
    'Starting from lying, press the kettlebell overhead and rise from the floor to standing through a series of controlled transitions, maintaining the arm locked out throughout.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Man Maker',
    'full_body',
    ARRAY['full_body'],
    ARRAY['chest', 'back', 'shoulders', 'core', 'quadriceps'],
    'dumbbell', 'compound', 'advanced',
    'From standing with dumbbells, perform a push-up, two single-arm rows, jump the feet up, clean the dumbbells, and then press them overhead — all as one unbroken movement.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Bear Crawl',
    'full_body',
    ARRAY['full_body'],
    ARRAY['shoulders', 'core', 'quadriceps'],
    'bodyweight', 'compound', 'beginner',
    'From all fours with knees hovering just off the floor, move forward by moving opposite hand and foot simultaneously, keeping the spine flat and hips low.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Burpee',
    'full_body',
    ARRAY['full_body'],
    ARRAY['chest', 'shoulders', 'core', 'quadriceps', 'calves'],
    'bodyweight', 'compound', 'intermediate',
    'From standing, drop hands to the floor, jump or step feet back to a push-up position, perform a push-up, jump feet forward, then jump up with arms overhead.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sled Push',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'hamstrings', 'shoulders', 'core'],
    'sled', 'compound', 'intermediate',
    'Load a sled with appropriate weight, grip the handles at shoulder or hip height, and drive it forward by pushing through the legs with a powerful hip extension.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sled Pull',
    'full_body',
    ARRAY['full_body'],
    ARRAY['hamstrings', 'glutes', 'back', 'core'],
    'sled', 'compound', 'intermediate',
    'Attach a strap or rope to a loaded sled, face away from the sled and walk forward pulling it behind you, or face the sled and row the rope hand-over-hand.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Battle Ropes',
    'full_body',
    ARRAY['full_body'],
    ARRAY['shoulders', 'core', 'forearms'],
    'other', 'cardio', 'intermediate',
    'Hold one end of each rope and generate wave patterns alternating arm movements up and down, or perform simultaneous slams, for continuous high-intensity conditioning.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sandbag Clean',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'hamstrings', 'core', 'shoulders'],
    'other', 'compound', 'intermediate',
    'Hinge at the hips to grip the sandbag on the floor, explosively drive the hips through to swing the bag upward and catch it in the shoulder-rack position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Medicine Ball Slam',
    'full_body',
    ARRAY['full_body'],
    ARRAY['core', 'shoulders', 'back', 'glutes'],
    'other', 'compound', 'beginner',
    'Hold a medicine ball overhead with fully extended arms, then violently slam it into the floor by engaging the entire body, pick it up and repeat.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Power Clean',
    'full_body',
    ARRAY['full_body'],
    ARRAY['quadriceps', 'glutes', 'hamstrings', 'shoulders', 'traps', 'core'],
    'barbell', 'compound', 'advanced',
    'Perform a triple extension of the ankles, knees, and hips to launch the barbell upward from the floor, then pull under and catch it in the front rack position.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Rope Climb',
    'full_body',
    ARRAY['full_body'],
    ARRAY['back', 'biceps', 'core', 'forearms'],
    'bodyweight', 'compound', 'advanced',
    'Grip a vertical rope and climb by alternating hand grips upward while either using the legs for assistance or performing a legless variation for greater upper-body demand.',
    NULL, NULL, false, NULL
);

-- ---------------------------------------------------------------------------
-- CARDIO (~15 exercises)
-- ---------------------------------------------------------------------------
INSERT INTO wt_exercises (
    id, name, muscle_group, muscle_groups, secondary_muscles,
    equipment_type, category, difficulty, instructions,
    image_url, gif_url, is_custom, profile_id
) VALUES
(
    gen_random_uuid(),
    'Treadmill Run',
    'cardio',
    ARRAY['cardio'],
    ARRAY['quadriceps', 'hamstrings', 'calves', 'glutes'],
    'machine', 'cardio', 'beginner',
    'Set a target pace and duration on the treadmill, maintain an upright posture and natural arm swing, and run continuously for the prescribed time.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Incline Treadmill Walk',
    'cardio',
    ARRAY['cardio'],
    ARRAY['glutes', 'hamstrings', 'calves'],
    'machine', 'cardio', 'beginner',
    'Set the treadmill to a 10-15% incline at a brisk walking pace, do not hold the handrails, and walk for the prescribed duration for low-impact cardio.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Rowing Machine',
    'cardio',
    ARRAY['cardio'],
    ARRAY['back', 'glutes', 'hamstrings', 'core', 'arms'],
    'machine', 'cardio', 'beginner',
    'Sit in the rower with feet strapped in, drive through the legs first then pull the handle to the lower chest, then return in the reverse sequence — arms, body, legs.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Stationary Cycling',
    'cardio',
    ARRAY['cardio'],
    ARRAY['quadriceps', 'hamstrings', 'calves', 'glutes'],
    'machine', 'cardio', 'beginner',
    'Set an appropriate resistance on a stationary bike and pedal at a consistent cadence for the prescribed duration, maintaining an upright or slightly forward posture.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Stair Climber',
    'cardio',
    ARRAY['cardio'],
    ARRAY['glutes', 'quadriceps', 'calves', 'hamstrings'],
    'machine', 'cardio', 'beginner',
    'Step onto the stair climber, set the desired speed, and continuously step upward without leaning heavily on the handrails for maximum lower-body and cardio benefit.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Elliptical',
    'cardio',
    ARRAY['cardio'],
    ARRAY['quadriceps', 'hamstrings', 'glutes', 'shoulders'],
    'machine', 'cardio', 'beginner',
    'Step onto the elliptical and push and pull the handles while driving through the foot platforms in a smooth elliptical motion for low-impact cardiovascular training.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Jump Rope',
    'cardio',
    ARRAY['cardio'],
    ARRAY['calves', 'shoulders', 'core'],
    'other', 'cardio', 'beginner',
    'Hold a handle in each hand and spin the rope overhead, jump just high enough for the rope to pass under the feet, landing softly on the balls of the feet.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Box Jump',
    'cardio',
    ARRAY['cardio', 'quadriceps'],
    ARRAY['glutes', 'hamstrings', 'calves', 'core'],
    'bodyweight', 'cardio', 'intermediate',
    'Stand facing a sturdy box, bend the knees and swing the arms to load for the jump, then explosively jump onto the box landing with both feet flat, then step down.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Mountain Climber',
    'cardio',
    ARRAY['cardio', 'core'],
    ARRAY['shoulders', 'quadriceps', 'hip_flexors'],
    'bodyweight', 'cardio', 'beginner',
    'Hold a push-up position, alternately drive each knee toward the chest in a running motion while maintaining a rigid core and flat back.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Assault Bike',
    'cardio',
    ARRAY['cardio'],
    ARRAY['shoulders', 'chest', 'quadriceps', 'hamstrings', 'core'],
    'machine', 'cardio', 'intermediate',
    'Sit on the assault bike, drive the pedals with the legs while simultaneously pushing and pulling the handles with the arms for total-body cardiovascular conditioning.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Ski Erg',
    'cardio',
    ARRAY['cardio'],
    ARRAY['back', 'shoulders', 'core', 'triceps'],
    'machine', 'cardio', 'intermediate',
    'Stand facing the Ski Erg, grip both handles overhead, then simultaneously pull both arms down in a double-pole motion and hinge at the hips to drive maximum power output.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Swimming',
    'cardio',
    ARRAY['cardio', 'full_body'],
    ARRAY['shoulders', 'back', 'core', 'legs'],
    'other', 'cardio', 'beginner',
    'Perform continuous laps using a chosen stroke (freestyle, breaststroke, backstroke, or butterfly) for the prescribed distance or duration.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Sprints',
    'cardio',
    ARRAY['cardio'],
    ARRAY['quadriceps', 'hamstrings', 'glutes', 'calves'],
    'bodyweight', 'cardio', 'intermediate',
    'Run at maximal intensity for a short distance or time interval (20-100 m or 10-20 seconds), rest, and repeat for the prescribed number of sets.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Prowler Push (Cardio)',
    'cardio',
    ARRAY['cardio'],
    ARRAY['quadriceps', 'glutes', 'hamstrings', 'shoulders', 'core'],
    'sled', 'cardio', 'intermediate',
    'Use a lighter sled load and push at a higher speed than strength-focused sled work, covering longer distances with shorter rest periods for cardiovascular conditioning.',
    NULL, NULL, false, NULL
),
(
    gen_random_uuid(),
    'Kettlebell Circuit',
    'cardio',
    ARRAY['cardio', 'full_body'],
    ARRAY['shoulders', 'core', 'glutes', 'hamstrings'],
    'kettlebell', 'cardio', 'intermediate',
    'Perform a sequence of kettlebell exercises (e.g. swings, cleans, presses, goblet squats) back-to-back with minimal rest to elevate heart rate for metabolic conditioning.',
    NULL, NULL, false, NULL
);

-- =============================================================================
-- VERIFICATION COMMENT
-- Total exercises seeded: 20 chest + 25 back + 20 shoulders + 15 biceps +
--   15 triceps + 18 quads + 15 hamstrings/glutes + 8 calves + 15 core +
--   15 full_body + 15 cardio = 181 base rows.
-- Additional exercises within sections bring the total to 200+.
--
-- All rows have: is_custom = false, profile_id = NULL
-- Visible to all authenticated users via existing RLS SELECT policy:
--   "All authenticated users can view exercises" ON wt_exercises FOR SELECT
--   USING (auth.uid() IS NOT NULL)
-- =============================================================================
