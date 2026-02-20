-- Migration: Meal Plans and Meal Plan Items
-- WellTrack Phase 8: AI Meal Planning
-- Creates: wt_meal_plans, wt_meal_plan_items

-- ============================================================================
-- MEAL PLANS TABLE
-- ============================================================================
CREATE TABLE wt_meal_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    plan_date date NOT NULL,
    day_type text DEFAULT 'rest',
    total_calories int,
    total_protein_g int,
    total_carbs_g int,
    total_fat_g int,
    status text DEFAULT 'active' NOT NULL,
    ai_rationale text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    UNIQUE(profile_id, plan_date)
);

-- Indexes for wt_meal_plans
CREATE INDEX idx_wt_meal_plans_profile_id ON wt_meal_plans(profile_id);
CREATE INDEX idx_wt_meal_plans_profile_id_date ON wt_meal_plans(profile_id, plan_date);

-- Enable RLS
ALTER TABLE wt_meal_plans ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_meal_plans
    BEFORE UPDATE ON wt_meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MEAL PLAN ITEMS TABLE
-- ============================================================================
CREATE TABLE wt_meal_plan_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_plan_id uuid REFERENCES wt_meal_plans(id) ON DELETE CASCADE NOT NULL,
    meal_type text NOT NULL,
    name text NOT NULL,
    description text,
    calories int,
    protein_g int,
    carbs_g int,
    fat_g int,
    recipe_id uuid REFERENCES wt_recipes(id) ON DELETE SET NULL,
    sort_order int DEFAULT 0,
    is_logged boolean DEFAULT false,
    swap_count int DEFAULT 0,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_meal_plan_items
CREATE INDEX idx_wt_meal_plan_items_meal_plan_id ON wt_meal_plan_items(meal_plan_id);
CREATE INDEX idx_wt_meal_plan_items_meal_plan_id_type ON wt_meal_plan_items(meal_plan_id, meal_type);

-- Enable RLS
ALTER TABLE wt_meal_plan_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES — wt_meal_plans (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own meal plans"
  ON public.wt_meal_plans FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own meal plans"
  ON public.wt_meal_plans FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own meal plans"
  ON public.wt_meal_plans FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own meal plans"
  ON public.wt_meal_plans FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- RLS POLICIES — wt_meal_plan_items (child table via meal_plan_id)
-- ============================================================================
CREATE POLICY "Users can view their own meal plan items"
  ON public.wt_meal_plan_items FOR SELECT
  USING (
    meal_plan_id IN (
      SELECT id FROM public.wt_meal_plans
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can insert their own meal plan items"
  ON public.wt_meal_plan_items FOR INSERT
  WITH CHECK (
    meal_plan_id IN (
      SELECT id FROM public.wt_meal_plans
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can update their own meal plan items"
  ON public.wt_meal_plan_items FOR UPDATE
  USING (
    meal_plan_id IN (
      SELECT id FROM public.wt_meal_plans
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can delete their own meal plan items"
  ON public.wt_meal_plan_items FOR DELETE
  USING (
    meal_plan_id IN (
      SELECT id FROM public.wt_meal_plans
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );
