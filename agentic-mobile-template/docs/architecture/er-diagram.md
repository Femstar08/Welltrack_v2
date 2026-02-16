# WellTrack Database ER Diagram

**Last Updated**: 2026-02-15
**Total Tables**: 34 (29 existing + 5 new Phase 1b)
**Table Prefix**: `wt_` (all tables)

---

## ASCII ER Diagram Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  AUTHENTICATION                                  │
│                              auth.users (Supabase)                               │
└────────┬────────────────────────────────────────┬───────────────────────────────┘
         │                                        │
         │                                        │
┌────────▼─────────┐                    ┌─────────▼──────────┐
│   CORE TABLES    │                    │   AI TABLES (3)    │
│       (3)        │                    ├────────────────────┤
├──────────────────┤                    │ wt_ai_usage        │
│ wt_users         │◄───────┐           │ wt_ai_audit_log    │
│ wt_profiles      │◄─┐     │           │ wt_ai_memory       │
│ wt_profile_      │  │     │           └────────────────────┘
│   modules        │  │     │
└──────┬───────────┘  │     │
       │              │     │
       │              │     │
   ┌───▼──────────────┴─────┴───────────────────────────────────────────────┐
   │                                                                         │
   │                          PROFILE-SCOPED MODULES                         │
   │                                                                         │
   ├─────────────────┬──────────────────┬──────────────────┬────────────────┤
   │                 │                  │                  │                │
┌──▼────────────┐ ┌──▼────────────┐ ┌──▼────────────┐ ┌──▼────────────┐ ┌──▼────────────┐
│ MEALS &       │ │ SUPPLEMENTS   │ │ WORKOUTS      │ │ HEALTH        │ │ PLANS &       │
│ RECIPES (9)   │ │     (3)       │ │     (3)       │ │ METRICS (2)   │ │ GOALS (3)     │
├───────────────┤ ├───────────────┤ ├───────────────┤ ├───────────────┤ ├───────────────┤
│ wt_recipes    │ │ wt_supplements│ │ wt_exercises  │ │ wt_health_    │ │ wt_plans      │
│ wt_recipe_    │ │ wt_supplement_│ │ wt_workouts   │ │   metrics     │ │ wt_plan_items │
│   steps       │ │   logs        │ │ wt_workout_   │ │ wt_health_    │ │ wt_goal_      │
│ wt_recipe_    │ │ wt_supplement_│ │   logs        │ │   connections │ │   forecasts   │
│   ingredients │ │   protocols   │ └───────────────┘ └───────────────┘ └───────┬───────┘
│ wt_meals      │ └───────────────┘                                             │
│ wt_pantry_    │                                                                │
│   items       │                                                                │
│ wt_leftovers  │                                                                │
│ wt_nutrients  │                                                                │
│ wt_nutrient_  │                                                                │
│   targets     │                                                                │
│ wt_meal_      │                                                                │
│   nutrient_   │                                                                │
│   breakdown   │                                                                │
└───────────────┘                                                                │
                                                                                 │
   ┌─────────────────────────────────────────────────────────────────────────────┤
   │                                                                             │
┌──▼────────────────┐ ┌──────────────────────────────────────────────────────┐  │
│ DAILY & INSIGHTS  │ │      PERFORMANCE ENGINE (Phase 1b) - NEW (5)        │  │
│       (3)         │ │                                                      │  │
├───────────────────┤ ├──────────────────────────────────────────────────────┤  │
│ wt_daily_logs     │ │ wt_baselines          ◄────┐                        │  │
│ wt_insights       │ │ wt_training_loads     ◄──┐ │                        │  │
│ wt_reminders      │ │ wt_recovery_scores    ◄┐ │ │                        │  │
└───────────────────┘ │ wt_forecasts ◄────────┼─┼─┼────────────────────────┼──┘
                      │ wt_webhook_events      │ │ │                        │
                      │                        │ │ │                        │
                      │ Links to:              │ │ │                        │
                      │   wt_profiles ─────────┘ │ │                        │
                      │   wt_workouts ────────────┘ │                        │
                      │   wt_goal_forecasts ─────────┘                       │
                      └──────────────────────────────────────────────────────┘
```

---

## Table Groups and Relationships

### 1. CORE TABLES (3)

#### wt_users
**Purpose**: User account information (1:1 with auth.users)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, FK→auth.users | User ID from Supabase Auth |
| display_name | text | | User's display name |
| avatar_url | text | | URL to user avatar |
| onboarding_completed | boolean | DEFAULT false | Onboarding status |
| plan_tier | text | DEFAULT 'free' | Subscription tier: free/pro |
| timezone | text | DEFAULT 'UTC' | User timezone |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Relationships**:
- → `wt_profiles` (1:many) via `user_id`
- → `wt_health_metrics` (1:many) via `user_id`
- → `wt_ai_usage` (1:many) via `user_id`
- → `wt_ai_audit_log` (1:many) via `user_id`
- → `wt_ai_memory` (1:many) via `user_id`
- → `wt_webhook_events` (1:many) via `user_id` [NEW]

---

#### wt_profiles
**Purpose**: Multiple profiles per user (parent + dependents)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | Profile ID |
| user_id | uuid | FK→auth.users ON DELETE CASCADE, NOT NULL | Owner user |
| profile_type | text | NOT NULL | parent/dependent |
| display_name | text | NOT NULL | Profile display name |
| date_of_birth | date | | DOB for age calculations |
| gender | text | | Gender |
| height_cm | numeric | | Height in cm |
| weight_kg | numeric | | Weight in kg |
| activity_level | text | | Activity level |
| fitness_goals | text[] | | Array of fitness goals |
| dietary_restrictions | text[] | | Dietary restrictions |
| allergies | text[] | | Known allergies |
| is_primary | boolean | DEFAULT false | Primary profile flag |
| avatar_url | text | | Profile avatar URL |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_profiles_user_id` on `user_id`

**Relationships**:
- ← `auth.users` via `user_id`
- → `wt_profile_modules` (1:many) via `profile_id`
- → `wt_recipes` (1:many) via `profile_id`
- → `wt_meals` (1:many) via `profile_id`
- → `wt_pantry_items` (1:many) via `profile_id`
- → `wt_leftovers` (1:many) via `profile_id`
- → `wt_nutrient_targets` (1:many) via `profile_id`
- → `wt_supplements` (1:many) via `profile_id`
- → `wt_supplement_logs` (1:many) via `profile_id`
- → `wt_supplement_protocols` (1:many) via `profile_id`
- → `wt_workouts` (1:many) via `profile_id`
- → `wt_workout_logs` (1:many) via `profile_id`
- → `wt_health_metrics` (1:many) via `profile_id`
- → `wt_health_connections` (1:many) via `profile_id`
- → `wt_plans` (1:many) via `profile_id`
- → `wt_goal_forecasts` (1:many) via `profile_id`
- → `wt_daily_logs` (1:many) via `profile_id`
- → `wt_insights` (1:many) via `profile_id`
- → `wt_reminders` (1:many) via `profile_id`
- → `wt_ai_usage` (1:many) via `profile_id`
- → `wt_ai_audit_log` (1:many) via `profile_id`
- → `wt_ai_memory` (1:many) via `profile_id`
- → `wt_baselines` (1:many) via `profile_id` [NEW]
- → `wt_training_loads` (1:many) via `profile_id` [NEW]
- → `wt_recovery_scores` (1:many) via `profile_id` [NEW]
- → `wt_forecasts` (1:many) via `profile_id` [NEW]

---

#### wt_profile_modules
**Purpose**: Per-profile module toggles and dashboard layout

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| module_name | text | NOT NULL | meals/supplements/workouts/activity/etc. |
| enabled | boolean | DEFAULT true | Module enabled flag |
| tile_order | int | | Dashboard tile sort order |
| tile_config | jsonb | | Tile-specific config (color, size, etc.) |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(profile_id, module_name)

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

### 2. MEALS & RECIPES TABLES (9)

#### wt_recipes
**Purpose**: Recipe library (user-created and imported)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE SET NULL | Creator profile |
| title | text | NOT NULL | Recipe title |
| description | text | | Recipe description |
| servings | int | | Number of servings |
| prep_time_min | int | | Prep time in minutes |
| cook_time_min | int | | Cook time in minutes |
| source_type | text | NOT NULL | url/ocr/ai/manual |
| source_url | text | | Source URL if applicable |
| instructions | text | | Overall instructions |
| nutrition_score | text | | A/B/C/D score |
| tags | text[] | | Recipe tags (vegetarian, quick, etc.) |
| image_url | text | | Recipe image |
| rating | numeric | | User rating (1-5) |
| is_favorite | boolean | DEFAULT false | Favorite flag |
| is_public | boolean | DEFAULT false | Shareable flag |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_recipes_profile_id` on `profile_id`
- `idx_recipes_tags` on `tags` (GIN)

**Relationships**:
- ← `wt_profiles` via `profile_id`
- → `wt_recipe_steps` (1:many) via `recipe_id`
- → `wt_recipe_ingredients` (1:many) via `recipe_id`
- → `wt_meals` (1:many) via `recipe_id`
- → `wt_leftovers` (1:many) via `source_recipe_id`

---

#### wt_recipe_steps
**Purpose**: Step-by-step recipe instructions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| recipe_id | uuid | FK→wt_recipes ON DELETE CASCADE, NOT NULL | |
| step_number | int | NOT NULL | Step order |
| instruction | text | NOT NULL | Step instruction text |
| duration_minutes | int | | Timer duration for this step |
| created_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(recipe_id, step_number)

**Relationships**:
- ← `wt_recipes` via `recipe_id`

---

#### wt_recipe_ingredients
**Purpose**: Recipe ingredient list

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| recipe_id | uuid | FK→wt_recipes ON DELETE CASCADE, NOT NULL | |
| ingredient_name | text | NOT NULL | Ingredient name |
| quantity | numeric | | Amount |
| unit | text | | Unit (cup, tsp, g, etc.) |
| notes | text | | Optional notes (e.g., "chopped") |
| sort_order | int | | Display order |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_recipe_ingredients_recipe_id` on `recipe_id`

**Relationships**:
- ← `wt_recipes` via `recipe_id`

---

#### wt_meals
**Purpose**: Logged meals (linked to recipes or standalone)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| recipe_id | uuid | FK→wt_recipes ON DELETE SET NULL | Optional recipe link |
| meal_date | date | NOT NULL | Date of meal |
| meal_type | text | NOT NULL | breakfast/lunch/dinner/snack |
| name | text | NOT NULL | Meal name |
| servings_consumed | numeric | | Servings eaten |
| nutrition_info | jsonb | | Nutrition breakdown JSON |
| score | text | | A/B/C/D nutrition score |
| rating | numeric | | User rating (1-5) |
| notes | text | | Meal notes |
| photo_url | text | | Meal photo |
| is_favorite | boolean | DEFAULT false | Favorite flag |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_meals_profile_id` on `profile_id`
- `idx_meals_meal_date` on `meal_date`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_recipes` via `recipe_id`
- → `wt_meal_nutrient_breakdown` (1:many) via `meal_id`

---

#### wt_pantry_items
**Purpose**: Current pantry inventory

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| name | text | NOT NULL | Item name |
| category | text | NOT NULL | fridge/cupboard/freezer |
| quantity | numeric | | Amount available |
| unit | text | | Unit |
| expiry_date | date | | Expiration date |
| is_available | boolean | DEFAULT true | In stock flag |
| barcode | text | | Barcode for scanning |
| cost | numeric | | Item cost |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_pantry_profile_id` on `profile_id`
- `idx_pantry_category` on `category`

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

#### wt_leftovers
**Purpose**: Leftover tracking for meal planning

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| name | text | NOT NULL | Leftover name |
| quantity | numeric | | Amount |
| unit | text | | Unit |
| source_recipe_id | uuid | FK→wt_recipes ON DELETE SET NULL | Source recipe if applicable |
| stored_date | date | NOT NULL | Date stored |
| expiry_date | date | | Estimated expiry |
| is_consumed | boolean | DEFAULT false | Consumed flag |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_leftovers_profile_id` on `profile_id`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_recipes` via `source_recipe_id`

---

#### wt_nutrients
**Purpose**: Reference table of all tracked nutrients

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| name | text | UNIQUE, NOT NULL | Nutrient name (e.g., "Protein") |
| unit | text | NOT NULL | Unit (g, mg, mcg, etc.) |
| category | text | | macronutrient/vitamin/mineral |
| daily_reference_value | numeric | | RDA if applicable |
| created_at | timestamptz | DEFAULT now() | |

**Relationships**:
- → `wt_nutrient_targets` (1:many) via `nutrient_id`
- → `wt_meal_nutrient_breakdown` (1:many) via `nutrient_id`

---

#### wt_nutrient_targets
**Purpose**: Per-profile nutrient goals

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| nutrient_id | uuid | FK→wt_nutrients ON DELETE CASCADE, NOT NULL | |
| target_value | numeric | NOT NULL | Target amount |
| period | text | NOT NULL | daily/weekly/monthly |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(profile_id, nutrient_id, period)

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_nutrients` via `nutrient_id`

---

#### wt_meal_nutrient_breakdown
**Purpose**: Detailed nutrient breakdown per meal

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| meal_id | uuid | FK→wt_meals ON DELETE CASCADE, NOT NULL | |
| nutrient_id | uuid | FK→wt_nutrients ON DELETE CASCADE, NOT NULL | |
| amount | numeric | NOT NULL | Amount of nutrient |
| unit | text | NOT NULL | Unit |
| created_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(meal_id, nutrient_id)

**Relationships**:
- ← `wt_meals` via `meal_id`
- ← `wt_nutrients` via `nutrient_id`

---

### 3. SUPPLEMENTS TABLES (3)

#### wt_supplements
**Purpose**: Supplement library

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE SET NULL | Creator profile |
| name | text | NOT NULL | Supplement name |
| brand | text | | Brand name |
| description | text | | Description |
| dosage | numeric | | Standard dosage |
| unit | text | | Unit (mg, IU, etc.) |
| serving_size | text | | Serving size description |
| barcode | text | | Barcode for scanning |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_supplements_profile_id` on `profile_id`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- → `wt_supplement_logs` (1:many) via `supplement_id`
- → `wt_supplement_protocols` (1:many) via `supplement_id`

---

#### wt_supplement_logs
**Purpose**: Daily supplement intake logs

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| supplement_id | uuid | FK→wt_supplements ON DELETE CASCADE, NOT NULL | |
| taken_at | timestamptz | NOT NULL | When taken |
| protocol_time | text | | am/pm/with_meal/bedtime |
| dosage_taken | numeric | | Actual dosage taken |
| status | text | NOT NULL | taken/skipped/planned |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_supplement_logs_profile_id` on `profile_id`
- `idx_supplement_logs_taken_at` on `taken_at`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_supplements` via `supplement_id`

---

#### wt_supplement_protocols
**Purpose**: Supplement schedules/protocols

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| supplement_id | uuid | FK→wt_supplements ON DELETE CASCADE, NOT NULL | |
| time_of_day | text | NOT NULL | am/pm/with_meal/bedtime |
| dosage | numeric | NOT NULL | Dosage amount |
| unit | text | NOT NULL | Unit |
| linked_goal_id | uuid | FK→wt_goal_forecasts ON DELETE SET NULL | Linked goal |
| is_active | boolean | DEFAULT true | Active protocol flag |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(profile_id, supplement_id, time_of_day)

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_supplements` via `supplement_id`
- ← `wt_goal_forecasts` via `linked_goal_id`

---

### 4. WORKOUTS TABLES (3)

#### wt_exercises
**Purpose**: Exercise reference library

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| name | text | UNIQUE, NOT NULL | Exercise name |
| muscle_group | text | | Primary muscle group |
| equipment | text | | Required equipment |
| instructions | text | | How to perform |
| difficulty | text | | beginner/intermediate/advanced |
| created_at | timestamptz | DEFAULT now() | |

**Relationships**:
- → `wt_workout_logs` (1:many) via `exercise_id`

---

#### wt_workouts
**Purpose**: Planned or completed workouts

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| name | text | NOT NULL | Workout name |
| workout_type | text | | strength/cardio/flexibility/mixed |
| scheduled_date | date | | Scheduled date |
| completed | boolean | DEFAULT false | Completion flag |
| completed_at | timestamptz | | Actual completion time |
| duration_minutes | int | | Total duration |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_workouts_profile_id` on `profile_id`
- `idx_workouts_scheduled_date` on `scheduled_date`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- → `wt_workout_logs` (1:many) via `workout_id`
- → `wt_training_loads` (1:many) via `workout_id` [NEW]

---

#### wt_workout_logs
**Purpose**: Per-exercise logs within a workout

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| workout_id | uuid | FK→wt_workouts ON DELETE SET NULL | Parent workout |
| exercise_id | uuid | FK→wt_exercises ON DELETE SET NULL | Exercise performed |
| sets | int | | Number of sets |
| reps | int | | Reps per set |
| weight_kg | numeric | | Weight used |
| duration_seconds | int | | Duration for cardio/timed exercises |
| distance_m | numeric | | Distance for cardio |
| notes | text | | Notes |
| logged_at | timestamptz | DEFAULT now() | |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_workout_logs_profile_id` on `profile_id`
- `idx_workout_logs_workout_id` on `workout_id`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_workouts` via `workout_id`
- ← `wt_exercises` via `exercise_id`

---

### 5. HEALTH METRICS TABLES (2)

#### wt_health_metrics
**Purpose**: Normalized health data from all sources

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK→auth.users ON DELETE CASCADE, NOT NULL | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| source | text | NOT NULL | healthconnect/healthkit/garmin/strava/manual |
| metric_type | text | NOT NULL | sleep/stress/vo2max/steps/hr/hrv/calories/distance/active_minutes/weight/body_fat/blood_pressure/spo2 |
| value_num | numeric | | Numeric value |
| value_text | text | | Text value if applicable |
| unit | text | | Unit |
| start_time | timestamptz | | Start of measurement period |
| end_time | timestamptz | | End of measurement period |
| recorded_at | timestamptz | NOT NULL | When recorded |
| raw_payload_json | jsonb | | Original payload from source |
| dedupe_hash | text | UNIQUE | Hash for deduplication |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_health_metrics_profile_id` on `profile_id`
- `idx_health_metrics_metric_type` on `metric_type`
- `idx_health_metrics_recorded_at` on `recorded_at`
- `idx_health_metrics_dedupe` on `dedupe_hash`

**Relationships**:
- ← `auth.users` via `user_id`
- ← `wt_profiles` via `profile_id`

---

#### wt_health_connections
**Purpose**: OAuth connection status for health providers

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| provider | text | NOT NULL | healthconnect/healthkit/garmin/strava |
| access_token_encrypted | text | | Encrypted access token |
| refresh_token_encrypted | text | | Encrypted refresh token |
| token_expires_at | timestamptz | | Token expiry |
| is_connected | boolean | DEFAULT false | Connection status |
| last_sync_at | timestamptz | | Last successful sync |
| connection_metadata | jsonb | | Provider-specific metadata |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(profile_id, provider)

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

### 6. PLANS & GOALS TABLES (3)

#### wt_plans
**Purpose**: Weekly/monthly plans

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| plan_type | text | NOT NULL | weekly/monthly |
| title | text | NOT NULL | Plan title |
| start_date | date | NOT NULL | Plan start |
| end_date | date | NOT NULL | Plan end |
| status | text | NOT NULL | draft/active/completed/archived |
| ai_generated | boolean | DEFAULT false | AI-generated flag |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_plans_profile_id` on `profile_id`
- `idx_plans_start_date` on `start_date`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- → `wt_plan_items` (1:many) via `plan_id`

---

#### wt_plan_items
**Purpose**: Individual tasks/items within a plan

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| plan_id | uuid | FK→wt_plans ON DELETE CASCADE, NOT NULL | |
| module | text | NOT NULL | meals/workouts/supplements/activity |
| item_type | text | NOT NULL | meal/workout/supplement/activity/custom |
| item_data | jsonb | NOT NULL | Item-specific data (recipe_id, workout_id, etc.) |
| scheduled_date | date | | Scheduled date |
| scheduled_time | time | | Scheduled time |
| completed | boolean | DEFAULT false | Completion flag |
| completed_at | timestamptz | | Completion timestamp |
| user_override | boolean | DEFAULT false | User modified flag |
| sort_order | int | | Display order |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_plan_items_plan_id` on `plan_id`
- `idx_plan_items_scheduled_date` on `scheduled_date`

**Relationships**:
- ← `wt_plans` via `plan_id`

---

#### wt_goal_forecasts
**Purpose**: Goal tracking with forecasted achievement dates

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| goal_description | text | NOT NULL | Goal description |
| target_value | numeric | NOT NULL | Target value |
| current_value | numeric | | Current progress value |
| unit | text | NOT NULL | Unit |
| expected_date | date | | Forecasted achievement date |
| confidence_score | numeric | | Confidence (0-1) |
| last_recalculated_at | timestamptz | | Last forecast update |
| is_active | boolean | DEFAULT true | Active goal flag |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_goal_forecasts_profile_id` on `profile_id`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- → `wt_supplement_protocols` (1:many) via `linked_goal_id`
- → `wt_forecasts` (1:many) via `goal_forecast_id` [NEW]

---

### 7. DAILY & INSIGHTS TABLES (3)

#### wt_daily_logs
**Purpose**: Generic daily logging for any module

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| log_date | date | NOT NULL | Log date |
| log_type | text | NOT NULL | Type of log entry |
| value_num | numeric | | Numeric value |
| value_text | text | | Text value |
| unit | text | | Unit |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_daily_logs_profile_id` on `profile_id`
- `idx_daily_logs_log_date` on `log_date`

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

#### wt_insights
**Purpose**: AI-generated insights (daily/weekly/monthly)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| period_type | text | NOT NULL | day/week/month |
| period_start | date | NOT NULL | Period start date |
| summary_text | text | NOT NULL | AI-generated summary |
| ai_model | text | | Model used |
| metrics_snapshot | jsonb | | Snapshot of metrics for period |
| created_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(profile_id, period_type, period_start)

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

#### wt_reminders
**Purpose**: Module-specific reminders

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| module | text | NOT NULL | Module name |
| title | text | NOT NULL | Reminder title |
| body | text | | Reminder body text |
| remind_at | timestamptz | NOT NULL | When to remind |
| repeat_rule | text | | Repeat rule (RRULE format) |
| is_active | boolean | DEFAULT true | Active flag |
| last_triggered_at | timestamptz | | Last trigger time |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_reminders_profile_id` on `profile_id`
- `idx_reminders_remind_at` on `remind_at`

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

### 8. AI TABLES (3)

#### wt_ai_usage
**Purpose**: AI usage tracking and metering (freemium limits)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK→auth.users ON DELETE CASCADE, NOT NULL | |
| profile_id | uuid | FK→wt_profiles ON DELETE SET NULL | |
| usage_date | date | NOT NULL | Usage date |
| calls_used | int | DEFAULT 0 | AI calls made |
| tokens_used | int | DEFAULT 0 | Tokens consumed |
| calls_limit | int | NOT NULL | Daily call limit |
| tokens_limit | int | NOT NULL | Daily token limit |
| plan_tier | text | NOT NULL | free/pro |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Constraints**:
- UNIQUE(user_id, usage_date)

**Relationships**:
- ← `auth.users` via `user_id`
- ← `wt_profiles` via `profile_id`

---

#### wt_ai_audit_log
**Purpose**: Audit trail for all AI interactions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK→auth.users ON DELETE CASCADE, NOT NULL | |
| profile_id | uuid | FK→wt_profiles ON DELETE SET NULL | |
| tool_called | text | NOT NULL | Tool/function name |
| input_summary | text | | Input summary (truncated) |
| output_summary | text | | Output summary (truncated) |
| tokens_consumed | int | | Tokens used |
| duration_ms | int | | Request duration |
| safety_flags | jsonb | | Safety/moderation flags |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_ai_audit_user_id` on `user_id`
- `idx_ai_audit_created_at` on `created_at`

**Relationships**:
- ← `auth.users` via `user_id`
- ← `wt_profiles` via `profile_id`

---

#### wt_ai_memory
**Purpose**: Persistent AI memory (Level 3)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK→auth.users ON DELETE CASCADE, NOT NULL | |
| profile_id | uuid | FK→wt_profiles ON DELETE SET NULL | |
| memory_type | text | NOT NULL | preference/embedding/pattern |
| memory_key | text | NOT NULL | Memory key |
| memory_value | jsonb | NOT NULL | Memory value (structured) |
| source_tool | text | | Tool that created this memory |
| expires_at | timestamptz | | Expiry date (optional) |
| embedding | vector(1536) | | Vector embedding (pgvector) |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_ai_memory_user_id` on `user_id`
- `idx_ai_memory_type` on `memory_type`
- Vector index on `embedding` (if pgvector enabled)

**Relationships**:
- ← `auth.users` via `user_id`
- ← `wt_profiles` via `profile_id`

---

### 9. PERFORMANCE ENGINE TABLES (Phase 1b) - NEW (5)

#### wt_baselines [NEW]
**Purpose**: Capture baseline metrics for performance tracking

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| metric_type | text | NOT NULL | vo2max/resting_hr/hrv/stress/sleep_quality |
| baseline_value | numeric | NOT NULL | Calculated baseline |
| data_points_count | int | NOT NULL | Number of data points used |
| capture_start | date | NOT NULL | Baseline period start |
| capture_end | date | NOT NULL | Baseline period end |
| is_complete | boolean | DEFAULT false | Baseline capture complete |
| calibration_status | text | DEFAULT 'pending' | pending/in_progress/complete |
| notes | text | | Notes |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_baselines_profile_id` on `profile_id`
- `idx_baselines_metric_type` on `metric_type`

**Constraints**:
- UNIQUE(profile_id, metric_type, capture_start)

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

#### wt_training_loads [NEW]
**Purpose**: Calculate and track training load per workout

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| workout_id | uuid | FK→wt_workouts ON DELETE CASCADE, NOT NULL | |
| load_date | date | NOT NULL | Date of training load |
| duration_minutes | int | NOT NULL | Workout duration |
| intensity_factor | numeric | NOT NULL | Intensity (0.0-1.0 or RPE-based) |
| training_load | numeric | GENERATED ALWAYS AS (duration_minutes * intensity_factor) STORED | Computed load |
| load_type | text | NOT NULL | cardio/strength/mixed |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_training_loads_profile_id` on `profile_id`
- `idx_training_loads_load_date` on `load_date`

**Constraints**:
- UNIQUE(profile_id, workout_id)

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_workouts` via `workout_id`

---

#### wt_recovery_scores [NEW]
**Purpose**: Daily recovery score calculation

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| score_date | date | NOT NULL | Date of recovery score |
| stress_component | numeric | | Stress contribution (0-100) |
| sleep_component | numeric | | Sleep contribution (0-100) |
| hr_component | numeric | | Heart rate contribution (0-100) |
| load_component | numeric | | Training load contribution (0-100) |
| recovery_score | numeric | NOT NULL | Composite recovery score (0-100) |
| raw_data | jsonb | | Raw data used for calculation |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_recovery_scores_profile_id` on `profile_id`
- `idx_recovery_scores_score_date` on `score_date`

**Constraints**:
- UNIQUE(profile_id, score_date)

**Relationships**:
- ← `wt_profiles` via `profile_id`

---

#### wt_forecasts [NEW]
**Purpose**: Regression-based goal forecasts

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| profile_id | uuid | FK→wt_profiles ON DELETE CASCADE, NOT NULL | |
| goal_forecast_id | uuid | FK→wt_goal_forecasts ON DELETE CASCADE, NOT NULL | Linked goal |
| metric_type | text | NOT NULL | Metric being forecasted |
| current_value | numeric | NOT NULL | Current metric value |
| target_value | numeric | NOT NULL | Goal target value |
| slope | numeric | NOT NULL | Regression slope |
| projected_date | date | | Projected achievement date |
| confidence | numeric | | Forecast confidence (0-1) |
| data_points | int | NOT NULL | Number of data points used |
| model_type | text | DEFAULT 'linear_regression' | Model type |
| calculated_at | timestamptz | DEFAULT now() | When forecast was calculated |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_forecasts_profile_id` on `profile_id`
- `idx_forecasts_goal_forecast_id` on `goal_forecast_id`

**Relationships**:
- ← `wt_profiles` via `profile_id`
- ← `wt_goal_forecasts` via `goal_forecast_id`

---

#### wt_webhook_events [NEW]
**Purpose**: Webhook event queue for Garmin/Strava push notifications

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| source | text | NOT NULL | garmin/strava |
| event_type | text | NOT NULL | Event type from webhook |
| payload | jsonb | NOT NULL | Full webhook payload |
| user_id | uuid | FK→auth.users ON DELETE CASCADE | User ID if identified |
| status | text | DEFAULT 'pending' | pending/processing/completed/failed/dead_letter |
| attempts | int | DEFAULT 0 | Processing attempts |
| max_attempts | int | DEFAULT 3 | Max retry attempts |
| last_error | text | | Last error message |
| received_at | timestamptz | DEFAULT now() | When webhook received |
| processed_at | timestamptz | | When processing completed |
| next_retry_at | timestamptz | | Next retry time |
| created_at | timestamptz | DEFAULT now() | |

**Indexes**:
- `idx_webhook_events_status` on `status`
- `idx_webhook_events_next_retry` on `next_retry_at` WHERE status = 'failed'
- `idx_webhook_events_user_id` on `user_id`

**Relationships**:
- ← `auth.users` via `user_id`

---

## Cross-Table Relationship Summary

### Core Profile Hierarchy
```
auth.users (1)
    ├── wt_users (1:1)
    └── wt_profiles (1:many)
            ├── wt_profile_modules (1:many)
            ├── All meal/recipe tables (1:many each)
            ├── All supplement tables (1:many each)
            ├── All workout tables (1:many each)
            ├── All health tables (1:many each)
            ├── All plan/goal tables (1:many each)
            ├── All daily/insight tables (1:many each)
            ├── All AI tables (1:many each)
            └── All performance engine tables (1:many each) [NEW]
```

### Key Many-to-Many Relationships (via Junction Tables)
- **Meals ↔ Nutrients**: via `wt_meal_nutrient_breakdown`
- **Profiles ↔ Nutrients**: via `wt_nutrient_targets`

### Optional/Nullable Foreign Keys
- `wt_recipes.profile_id` → Can be NULL (system recipes)
- `wt_supplements.profile_id` → Can be NULL (system supplements)
- `wt_meals.recipe_id` → Can be NULL (standalone meals)
- `wt_leftovers.source_recipe_id` → Can be NULL
- `wt_workout_logs.workout_id` → Can be NULL (standalone exercise logs)
- `wt_workout_logs.exercise_id` → Can be NULL (custom exercises)
- `wt_supplement_protocols.linked_goal_id` → Can be NULL
- All AI tables' `profile_id` → Can be NULL (user-level AI interactions)

---

## RLS (Row Level Security) Policies

**All tables MUST have RLS enabled.**

### Standard Policy Pattern
```sql
-- Enable RLS
ALTER TABLE wt_<table_name> ENABLE ROW LEVEL SECURITY;

-- SELECT policy: user can read their own data
CREATE POLICY "Users can view own data"
    ON wt_<table_name>
    FOR SELECT
    USING (
        auth.uid() = user_id  -- for user-scoped tables
        OR
        profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())  -- for profile-scoped
    );

-- INSERT/UPDATE/DELETE policies: user can modify their own data
CREATE POLICY "Users can insert own data"
    ON wt_<table_name>
    FOR INSERT
    WITH CHECK (
        profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can update own data"
    ON wt_<table_name>
    FOR UPDATE
    USING (
        profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can delete own data"
    ON wt_<table_name>
    FOR DELETE
    USING (
        profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
    );
```

### Reference Tables (Public Read)
For tables like `wt_nutrients` and `wt_exercises`:
```sql
CREATE POLICY "Public read access"
    ON wt_nutrients
    FOR SELECT
    USING (true);
```

---

## Database Indexes Summary

**Performance-critical indexes** (already listed per table above):

### High-frequency query patterns:
1. **Profile-scoped queries**: `idx_<table>_profile_id` on all profile-scoped tables
2. **Date-range queries**:
   - `idx_meals_meal_date`
   - `idx_workouts_scheduled_date`
   - `idx_plan_items_scheduled_date`
   - `idx_daily_logs_log_date`
   - `idx_recovery_scores_score_date` [NEW]
   - `idx_training_loads_load_date` [NEW]
3. **Health metrics lookups**:
   - `idx_health_metrics_metric_type`
   - `idx_health_metrics_recorded_at`
   - `idx_health_metrics_dedupe` (UNIQUE)
4. **Webhook processing**:
   - `idx_webhook_events_status` [NEW]
   - `idx_webhook_events_next_retry` (partial) [NEW]
5. **AI audit trail**:
   - `idx_ai_audit_created_at`
6. **Vector search** (if pgvector enabled):
   - Vector index on `wt_ai_memory.embedding`

---

## Data Integrity Constraints

### Cascading Deletes
- **Profile deletion** → Cascades to all profile-scoped data
- **Recipe deletion** → Cascades to recipe_steps, recipe_ingredients, meal_nutrient_breakdown
- **Workout deletion** → Cascades to workout_logs, training_loads [NEW]
- **Plan deletion** → Cascades to plan_items
- **Goal deletion** → Cascades to forecasts [NEW]

### SET NULL Deletes
- **Profile deletion from recipes/supplements** → Sets to NULL (preserves library items)
- **Recipe deletion from meals/leftovers** → Sets to NULL (preserves meal logs)
- **Exercise/workout deletion from logs** → Sets to NULL (preserves historical data)

### Unique Constraints
- `wt_nutrients.name` (UNIQUE)
- `wt_exercises.name` (UNIQUE)
- `wt_nutrient_targets(profile_id, nutrient_id, period)` (UNIQUE)
- `wt_supplement_protocols(profile_id, supplement_id, time_of_day)` (UNIQUE)
- `wt_health_connections(profile_id, provider)` (UNIQUE)
- `wt_health_metrics.dedupe_hash` (UNIQUE)
- `wt_insights(profile_id, period_type, period_start)` (UNIQUE)
- `wt_ai_usage(user_id, usage_date)` (UNIQUE)
- `wt_recovery_scores(profile_id, score_date)` (UNIQUE) [NEW]
- `wt_baselines(profile_id, metric_type, capture_start)` (UNIQUE) [NEW]
- `wt_training_loads(profile_id, workout_id)` (UNIQUE) [NEW]

---

## Enum Types

### Recommended PostgreSQL ENUMs
```sql
CREATE TYPE wt_plan_tier AS ENUM ('free', 'pro');
CREATE TYPE wt_profile_type AS ENUM ('parent', 'dependent');
CREATE TYPE wt_meal_type AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');
CREATE TYPE wt_source_type AS ENUM ('url', 'ocr', 'ai', 'manual');
CREATE TYPE wt_pantry_category AS ENUM ('fridge', 'cupboard', 'freezer');
CREATE TYPE wt_period AS ENUM ('daily', 'weekly', 'monthly');
CREATE TYPE wt_protocol_time AS ENUM ('am', 'pm', 'with_meal', 'bedtime');
CREATE TYPE wt_supplement_status AS ENUM ('taken', 'skipped', 'planned');
CREATE TYPE wt_workout_type AS ENUM ('strength', 'cardio', 'flexibility', 'mixed');
CREATE TYPE wt_difficulty AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE wt_health_source AS ENUM ('healthconnect', 'healthkit', 'garmin', 'strava', 'manual');
CREATE TYPE wt_metric_type AS ENUM ('sleep', 'stress', 'vo2max', 'steps', 'hr', 'hrv', 'calories', 'distance', 'active_minutes', 'weight', 'body_fat', 'blood_pressure', 'spo2');
CREATE TYPE wt_plan_type AS ENUM ('weekly', 'monthly');
CREATE TYPE wt_plan_status AS ENUM ('draft', 'active', 'completed', 'archived');
CREATE TYPE wt_item_type AS ENUM ('meal', 'workout', 'supplement', 'activity', 'custom');
CREATE TYPE wt_period_type AS ENUM ('day', 'week', 'month');
CREATE TYPE wt_memory_type AS ENUM ('preference', 'embedding', 'pattern');
CREATE TYPE wt_calibration_status AS ENUM ('pending', 'in_progress', 'complete'); -- NEW
CREATE TYPE wt_load_type AS ENUM ('cardio', 'strength', 'mixed'); -- NEW
CREATE TYPE wt_webhook_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'dead_letter'); -- NEW
CREATE TYPE wt_webhook_source AS ENUM ('garmin', 'strava'); -- NEW
CREATE TYPE wt_forecast_model AS ENUM ('linear_regression', 'polynomial', 'exponential'); -- NEW
```

---

## Migration Order

### Phase 1 (Complete)
1. Core tables (wt_users, wt_profiles, wt_profile_modules)
2. Reference tables (wt_nutrients, wt_exercises)
3. Meals & Recipes (9 tables)
4. Supplements (3 tables)
5. Workouts (3 tables)
6. Health (2 tables)
7. Plans & Goals (3 tables)
8. Daily & Insights (3 tables)
9. AI (3 tables)
10. RLS policies for all tables

### Phase 1b (NEW - In Progress)
11. Performance engine tables (5 tables):
    - wt_baselines
    - wt_training_loads
    - wt_recovery_scores
    - wt_forecasts
    - wt_webhook_events
12. RLS policies for new tables
13. Indexes for new tables
14. ENUMs for new types

---

## Notes

- **All timestamps**: Use `timestamptz` (timezone-aware)
- **All UUIDs**: Use `gen_random_uuid()` for defaults
- **All tables**: Include `created_at` and `updated_at` (except reference tables)
- **Deduplication**: Use `dedupe_hash` on `wt_health_metrics` to prevent duplicate ingestion
- **Offline sync**: Client generates UUIDs; server validates and stores
- **Conflict resolution**: Last-write-wins with `updated_at` timestamp
- **Encryption**: Sensitive tokens encrypted at application layer before storage
- **pgvector**: Optional; gracefully degrade to text-based search if not available
- **Performance Engine**: New Phase 1b tables enable advanced analytics, recovery tracking, and goal forecasting

---

**End of ER Diagram Document**
