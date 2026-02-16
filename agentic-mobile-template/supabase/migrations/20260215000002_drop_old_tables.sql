-- Migration: Drop Legacy wt_ Tables
-- WellTrack Phase 1
-- Created: 2026-02-15
--
-- Purpose: Drops all 21 existing wt_ tables to recreate with proper structure
-- Changes:
--   - Removes tables that need profile_id support
--   - Removes tables that need enum types
--   - Removes tables that need normalized schema
--
-- Note: No data needs to be preserved - tables were empty/test-only
-- CASCADE handles all foreign key dependencies automatically

-- Drop old helper functions that may conflict
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;

-- Drop tables in order: child tables first (those with FKs), then parent tables
-- CASCADE ensures any remaining dependencies are handled

-- Level 5: Deepest child tables (logs and usage records)
DROP TABLE IF EXISTS public.wt_pantry_usage_logs CASCADE;
DROP TABLE IF EXISTS public.wt_supplement_logs CASCADE;
DROP TABLE IF EXISTS public.wt_habit_logs CASCADE;
DROP TABLE IF EXISTS public.wt_biomarkers CASCADE;

-- Level 4: Relationship/junction tables and tracking tables
DROP TABLE IF EXISTS public.wt_meal_ingredients CASCADE;
DROP TABLE IF EXISTS public.wt_recipe_ingredients CASCADE;
DROP TABLE IF EXISTS public.wt_meal_plan_items CASCADE;
DROP TABLE IF EXISTS public.wt_shopping_list_items CASCADE;
DROP TABLE IF EXISTS public.wt_cost_tracking CASCADE;
DROP TABLE IF EXISTS public.wt_budget_tracking CASCADE;

-- Level 3: Tables with dependencies on Level 2
DROP TABLE IF EXISTS public.wt_user_supplements CASCADE;
DROP TABLE IF EXISTS public.wt_pantry_items CASCADE;
DROP TABLE IF EXISTS public.wt_meals CASCADE;

-- Level 2: Core entity tables with user dependencies
DROP TABLE IF EXISTS public.wt_meal_plans CASCADE;
DROP TABLE IF EXISTS public.wt_shopping_lists CASCADE;
DROP TABLE IF EXISTS public.wt_recipes CASCADE;
DROP TABLE IF EXISTS public.wt_custom_habits CASCADE;
DROP TABLE IF EXISTS public.wt_health_metrics CASCADE;

-- Level 1: Reference/lookup tables (no user dependencies)
DROP TABLE IF EXISTS public.wt_ingredients CASCADE;
DROP TABLE IF EXISTS public.wt_supplements CASCADE;

-- Level 0: Root table (user profiles)
DROP TABLE IF EXISTS public.wt_user_profiles CASCADE;
