-- Migration: Meals, Recipes, and Nutrition Tables
-- WellTrack Phase 1
-- Creates: wt_recipes, wt_recipe_steps, wt_recipe_ingredients, wt_meals,
--          wt_pantry_items, wt_leftovers, wt_nutrients, wt_nutrient_targets,
--          wt_meal_nutrient_breakdown

-- ============================================================================
-- RECIPES TABLE
-- ============================================================================
CREATE TABLE wt_recipes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    servings int DEFAULT 1,
    prep_time_min int,
    cook_time_min int,
    source_type wt_recipe_source DEFAULT 'manual',
    source_url text,
    instructions text,
    nutrition_score text,
    tags text[] DEFAULT '{}',
    image_url text,
    rating numeric(2,1),
    is_favorite boolean DEFAULT false,
    is_public boolean DEFAULT false,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_recipes
CREATE INDEX idx_wt_recipes_profile_id ON wt_recipes(profile_id);
CREATE INDEX idx_wt_recipes_created_at ON wt_recipes(created_at);

-- Enable RLS
ALTER TABLE wt_recipes ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_recipes
    BEFORE UPDATE ON wt_recipes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- RECIPE STEPS TABLE
-- ============================================================================
CREATE TABLE wt_recipe_steps (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id uuid REFERENCES wt_recipes(id) ON DELETE CASCADE NOT NULL,
    step_number int NOT NULL,
    instruction text NOT NULL,
    duration_minutes int,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_recipe_steps
CREATE INDEX idx_wt_recipe_steps_recipe_id_step_number ON wt_recipe_steps(recipe_id, step_number);

-- Enable RLS
ALTER TABLE wt_recipe_steps ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RECIPE INGREDIENTS TABLE
-- ============================================================================
CREATE TABLE wt_recipe_ingredients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id uuid REFERENCES wt_recipes(id) ON DELETE CASCADE NOT NULL,
    ingredient_name text NOT NULL,
    quantity numeric(10,2),
    unit text,
    notes text,
    sort_order int DEFAULT 0,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_recipe_ingredients
CREATE INDEX idx_wt_recipe_ingredients_recipe_id ON wt_recipe_ingredients(recipe_id);

-- Enable RLS
ALTER TABLE wt_recipe_ingredients ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- MEALS TABLE
-- ============================================================================
CREATE TABLE wt_meals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    recipe_id uuid REFERENCES wt_recipes(id) ON DELETE SET NULL,
    meal_date date DEFAULT CURRENT_DATE NOT NULL,
    meal_type wt_meal_type DEFAULT 'other' NOT NULL,
    name text,
    servings_consumed numeric(4,2) DEFAULT 1.0,
    nutrition_info jsonb,
    score text,
    rating numeric(2,1),
    notes text,
    photo_url text,
    is_favorite boolean DEFAULT false,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_meals
CREATE INDEX idx_wt_meals_profile_id_meal_date ON wt_meals(profile_id, meal_date);
CREATE INDEX idx_wt_meals_recipe_id ON wt_meals(recipe_id);

-- Enable RLS
ALTER TABLE wt_meals ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_meals
    BEFORE UPDATE ON wt_meals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PANTRY ITEMS TABLE
-- ============================================================================
CREATE TABLE wt_pantry_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    category wt_pantry_category DEFAULT 'fridge' NOT NULL,
    quantity numeric(10,2),
    unit text,
    expiry_date date,
    is_available boolean DEFAULT true NOT NULL,
    barcode text,
    cost numeric(8,2),
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_pantry_items
CREATE INDEX idx_wt_pantry_items_profile_id_category ON wt_pantry_items(profile_id, category);
CREATE INDEX idx_wt_pantry_items_profile_id_expiry_date ON wt_pantry_items(profile_id, expiry_date);

-- Enable RLS
ALTER TABLE wt_pantry_items ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_pantry_items
    BEFORE UPDATE ON wt_pantry_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- LEFTOVERS TABLE
-- ============================================================================
CREATE TABLE wt_leftovers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    quantity numeric(10,2),
    unit text,
    source_recipe_id uuid REFERENCES wt_recipes(id) ON DELETE SET NULL,
    stored_date date DEFAULT CURRENT_DATE NOT NULL,
    expiry_date date,
    is_consumed boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Index for wt_leftovers
CREATE INDEX idx_wt_leftovers_profile_id_expiry_date ON wt_leftovers(profile_id, expiry_date);

-- Enable RLS
ALTER TABLE wt_leftovers ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_leftovers
    BEFORE UPDATE ON wt_leftovers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- NUTRIENTS TABLE (Reference Table)
-- ============================================================================
CREATE TABLE wt_nutrients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    unit text NOT NULL,
    category text NOT NULL,
    daily_reference_value numeric(10,2),
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE wt_nutrients ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- NUTRIENT TARGETS TABLE
-- ============================================================================
CREATE TABLE wt_nutrient_targets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    nutrient_id uuid REFERENCES wt_nutrients(id) ON DELETE CASCADE NOT NULL,
    target_value numeric(10,2) NOT NULL,
    period wt_period_type DEFAULT 'daily' NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE(profile_id, nutrient_id, period)
);

-- Enable RLS
ALTER TABLE wt_nutrient_targets ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_nutrient_targets
    BEFORE UPDATE ON wt_nutrient_targets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MEAL NUTRIENT BREAKDOWN TABLE
-- ============================================================================
CREATE TABLE wt_meal_nutrient_breakdown (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id uuid REFERENCES wt_meals(id) ON DELETE CASCADE NOT NULL,
    nutrient_id uuid REFERENCES wt_nutrients(id) ON DELETE CASCADE NOT NULL,
    amount numeric(10,2) NOT NULL,
    unit text NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE(meal_id, nutrient_id)
);

-- Index for wt_meal_nutrient_breakdown
CREATE INDEX idx_wt_meal_nutrient_breakdown_meal_id ON wt_meal_nutrient_breakdown(meal_id);

-- Enable RLS
ALTER TABLE wt_meal_nutrient_breakdown ENABLE ROW LEVEL SECURITY;
