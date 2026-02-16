-- Seed Data: Reference Tables
-- WellTrack Phase 1
-- Seeds: wt_nutrients (~40 common nutrients), wt_exercises (~50 common exercises)

-- ============================================================================
-- NUTRIENTS (Reference Data)
-- Categories: macronutrient, vitamin, mineral, other
-- daily_reference_value based on FDA Daily Values (2,000 cal diet)
-- ============================================================================

INSERT INTO public.wt_nutrients (name, unit, category, daily_reference_value) VALUES
-- Macronutrients
('Calories', 'kcal', 'macronutrient', 2000),
('Protein', 'g', 'macronutrient', 50),
('Total Fat', 'g', 'macronutrient', 78),
('Saturated Fat', 'g', 'macronutrient', 20),
('Trans Fat', 'g', 'macronutrient', NULL),
('Cholesterol', 'mg', 'macronutrient', 300),
('Total Carbohydrates', 'g', 'macronutrient', 275),
('Dietary Fiber', 'g', 'macronutrient', 28),
('Total Sugars', 'g', 'macronutrient', NULL),
('Added Sugars', 'g', 'macronutrient', 50),
('Sodium', 'mg', 'macronutrient', 2300),

-- Vitamins
('Vitamin A', 'mcg', 'vitamin', 900),
('Vitamin C', 'mg', 'vitamin', 90),
('Vitamin D', 'mcg', 'vitamin', 20),
('Vitamin E', 'mg', 'vitamin', 15),
('Vitamin K', 'mcg', 'vitamin', 120),
('Vitamin B1 (Thiamin)', 'mg', 'vitamin', 1.2),
('Vitamin B2 (Riboflavin)', 'mg', 'vitamin', 1.3),
('Vitamin B3 (Niacin)', 'mg', 'vitamin', 16),
('Vitamin B5 (Pantothenic Acid)', 'mg', 'vitamin', 5),
('Vitamin B6', 'mg', 'vitamin', 1.7),
('Vitamin B7 (Biotin)', 'mcg', 'vitamin', 30),
('Vitamin B9 (Folate)', 'mcg', 'vitamin', 400),
('Vitamin B12', 'mcg', 'vitamin', 2.4),
('Choline', 'mg', 'vitamin', 550),

-- Minerals
('Calcium', 'mg', 'mineral', 1300),
('Iron', 'mg', 'mineral', 18),
('Magnesium', 'mg', 'mineral', 420),
('Phosphorus', 'mg', 'mineral', 1250),
('Potassium', 'mg', 'mineral', 4700),
('Zinc', 'mg', 'mineral', 11),
('Copper', 'mg', 'mineral', 0.9),
('Manganese', 'mg', 'mineral', 2.3),
('Selenium', 'mcg', 'mineral', 55),
('Chromium', 'mcg', 'mineral', 35),
('Molybdenum', 'mcg', 'mineral', 45),
('Iodine', 'mcg', 'mineral', 150),
('Chloride', 'mg', 'mineral', 2300),

-- Other
('Omega-3 (EPA+DHA)', 'mg', 'other', 250),
('Omega-6', 'g', 'other', 17),
('Water', 'ml', 'other', 2700),
('Caffeine', 'mg', 'other', NULL)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- EXERCISES (Reference Data)
-- Master exercise library: name, muscle_group, equipment, instructions, difficulty
-- ============================================================================

INSERT INTO public.wt_exercises (name, muscle_group, equipment, instructions, difficulty) VALUES
-- Chest
('Push-Up', 'chest', 'bodyweight', 'Start in plank position, lower body until chest nearly touches floor, push back up.', 'beginner'),
('Bench Press', 'chest', 'barbell', 'Lie on bench, grip barbell shoulder-width, lower to chest, press up.', 'intermediate'),
('Dumbbell Fly', 'chest', 'dumbbells', 'Lie on bench, hold dumbbells above chest, lower in arc to sides, bring back together.', 'intermediate'),
('Incline Bench Press', 'chest', 'barbell', 'Set bench to 30-45 degrees, press barbell from upper chest.', 'intermediate'),
('Dips', 'chest', 'parallel bars', 'Grip bars, lower body by bending elbows, lean forward slightly, push back up.', 'intermediate'),

-- Back
('Pull-Up', 'back', 'pull-up bar', 'Hang from bar, pull body up until chin is above bar, lower slowly.', 'intermediate'),
('Bent-Over Row', 'back', 'barbell', 'Hinge at hips, pull barbell to lower chest, squeeze shoulder blades.', 'intermediate'),
('Lat Pulldown', 'back', 'cable machine', 'Grip bar wide, pull down to upper chest, control the return.', 'beginner'),
('Seated Cable Row', 'back', 'cable machine', 'Sit upright, pull handle to torso, squeeze shoulder blades together.', 'beginner'),
('Deadlift', 'back', 'barbell', 'Stand with feet hip-width, hinge at hips, grip bar, drive through heels to stand.', 'advanced'),

-- Shoulders
('Overhead Press', 'shoulders', 'barbell', 'Press barbell from shoulder level to overhead, lock out arms.', 'intermediate'),
('Lateral Raise', 'shoulders', 'dumbbells', 'Hold dumbbells at sides, raise to shoulder height with slight bend in elbows.', 'beginner'),
('Front Raise', 'shoulders', 'dumbbells', 'Hold dumbbells in front of thighs, raise to shoulder height alternately.', 'beginner'),
('Face Pull', 'shoulders', 'cable machine', 'Pull rope attachment towards face, externally rotating shoulders.', 'beginner'),
('Arnold Press', 'shoulders', 'dumbbells', 'Start with palms facing you, rotate and press overhead.', 'intermediate'),

-- Legs
('Squat', 'legs', 'barbell', 'Bar on upper back, feet shoulder-width, squat until thighs parallel, stand up.', 'intermediate'),
('Leg Press', 'legs', 'leg press machine', 'Sit in machine, press platform away by extending knees, control return.', 'beginner'),
('Lunges', 'legs', 'bodyweight', 'Step forward, lower back knee toward floor, push back to start.', 'beginner'),
('Romanian Deadlift', 'legs', 'barbell', 'Hold barbell, hinge at hips keeping legs slightly bent, lower bar along legs.', 'intermediate'),
('Leg Curl', 'legs', 'machine', 'Lie face down, curl weight toward glutes by bending knees.', 'beginner'),
('Leg Extension', 'legs', 'machine', 'Sit in machine, extend knees to straighten legs against resistance.', 'beginner'),
('Calf Raise', 'legs', 'bodyweight', 'Stand on edge of step, raise heels as high as possible, lower slowly.', 'beginner'),
('Bulgarian Split Squat', 'legs', 'dumbbells', 'Rear foot on bench, squat down on front leg, push back up.', 'intermediate'),
('Hip Thrust', 'legs', 'barbell', 'Upper back on bench, bar over hips, drive hips up squeezing glutes.', 'intermediate'),

-- Arms
('Bicep Curl', 'arms', 'dumbbells', 'Hold dumbbells at sides, curl up by bending elbows, lower slowly.', 'beginner'),
('Hammer Curl', 'arms', 'dumbbells', 'Hold dumbbells with neutral grip, curl up keeping palms facing each other.', 'beginner'),
('Tricep Pushdown', 'arms', 'cable machine', 'Grip bar or rope attachment, push down by extending elbows.', 'beginner'),
('Skull Crusher', 'arms', 'barbell', 'Lie on bench, lower barbell toward forehead by bending elbows, extend back up.', 'intermediate'),
('Concentration Curl', 'arms', 'dumbbell', 'Sit with elbow braced on inner thigh, curl dumbbell up.', 'beginner'),

-- Core
('Plank', 'core', 'bodyweight', 'Hold push-up position on forearms, keep body straight, engage core.', 'beginner'),
('Crunch', 'core', 'bodyweight', 'Lie on back, knees bent, curl upper body toward knees.', 'beginner'),
('Russian Twist', 'core', 'bodyweight', 'Sit with knees bent, lean back slightly, rotate torso side to side.', 'beginner'),
('Hanging Leg Raise', 'core', 'pull-up bar', 'Hang from bar, raise legs to 90 degrees, lower with control.', 'intermediate'),
('Ab Wheel Rollout', 'core', 'ab wheel', 'Kneel, grip wheel, roll forward extending body, pull back to start.', 'advanced'),
('Mountain Climber', 'core', 'bodyweight', 'Start in plank, drive knees to chest alternately at a fast pace.', 'beginner'),
('Dead Bug', 'core', 'bodyweight', 'Lie on back, extend opposite arm and leg while keeping core braced.', 'beginner'),
('Side Plank', 'core', 'bodyweight', 'Lie on side, prop up on forearm, lift hips off ground, hold.', 'beginner'),

-- Full Body / Compound
('Burpee', 'full body', 'bodyweight', 'Drop to push-up, perform push-up, jump feet forward, jump up with arms overhead.', 'intermediate'),
('Clean and Press', 'full body', 'barbell', 'Pull barbell from floor to shoulders, then press overhead.', 'advanced'),
('Kettlebell Swing', 'full body', 'kettlebell', 'Hinge at hips, swing kettlebell between legs, drive hips forward to swing up.', 'intermediate'),
('Thruster', 'full body', 'barbell', 'Front squat, then drive up and press barbell overhead in one motion.', 'intermediate'),
('Turkish Get-Up', 'full body', 'kettlebell', 'Lie down holding weight overhead, stand up while keeping weight above head.', 'advanced'),
('Box Jump', 'full body', 'plyo box', 'Stand facing box, jump up landing with both feet on box, step down.', 'intermediate'),

-- Cardio
('Running', 'cardio', 'none', 'Maintain steady pace, land midfoot, keep upright posture.', 'beginner'),
('Cycling', 'cardio', 'bike', 'Maintain steady cadence, adjust resistance as needed.', 'beginner'),
('Rowing', 'cardio', 'rowing machine', 'Drive with legs, lean back slightly, pull handle to chest, reverse sequence.', 'beginner'),
('Jump Rope', 'cardio', 'jump rope', 'Jump with feet together, rotate rope with wrists, maintain rhythm.', 'beginner'),
('Swimming', 'cardio', 'pool', 'Choose stroke, maintain breathing pattern, focus on form.', 'intermediate'),
('Stair Climber', 'cardio', 'stair machine', 'Step at steady pace, use full range of motion, avoid leaning on handles.', 'beginner')
ON CONFLICT DO NOTHING;
