-- Migration: RLS Policies for Core Profiles and Meals/Recipes/Nutrition tables
-- WellTrack Phase 1
-- Covers tables from migrations 3 and 4 that don't have inline policies.
-- Migrations 5, 6, 7 already have their own inline policies.

-- ============================================================================
-- wt_users (user-scoped: id = auth.uid())
-- ============================================================================
CREATE POLICY "Users can view their own user record"
  ON public.wt_users FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users can insert their own user record"
  ON public.wt_users FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own user record"
  ON public.wt_users FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Users can delete their own user record"
  ON public.wt_users FOR DELETE
  USING (id = auth.uid());

-- ============================================================================
-- wt_profiles (profile-scoped: user_id = auth.uid())
-- ============================================================================
CREATE POLICY "Users can view their own profiles"
  ON public.wt_profiles FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own profiles"
  ON public.wt_profiles FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own profiles"
  ON public.wt_profiles FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own profiles"
  ON public.wt_profiles FOR DELETE
  USING (user_id = auth.uid());

-- ============================================================================
-- wt_profile_modules (via profile_id -> wt_profiles)
-- ============================================================================
CREATE POLICY "Users can view their own profile modules"
  ON public.wt_profile_modules FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own profile modules"
  ON public.wt_profile_modules FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own profile modules"
  ON public.wt_profile_modules FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own profile modules"
  ON public.wt_profile_modules FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_recipes (profile-scoped, nullable profile_id for shared recipes)
-- ============================================================================
CREATE POLICY "Users can view their own or shared recipes"
  ON public.wt_recipes FOR SELECT
  USING (
    profile_id IN (SELECT public.get_profile_ids_for_user())
    OR profile_id IS NULL
  );

CREATE POLICY "Users can insert their own recipes"
  ON public.wt_recipes FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own recipes"
  ON public.wt_recipes FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own recipes"
  ON public.wt_recipes FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_recipe_steps (child table via recipe_id -> wt_recipes)
-- ============================================================================
CREATE POLICY "Users can view recipe steps for accessible recipes"
  ON public.wt_recipe_steps FOR SELECT
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
        OR profile_id IS NULL
    )
  );

CREATE POLICY "Users can insert recipe steps for their recipes"
  ON public.wt_recipe_steps FOR INSERT
  WITH CHECK (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can update recipe steps for their recipes"
  ON public.wt_recipe_steps FOR UPDATE
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can delete recipe steps for their recipes"
  ON public.wt_recipe_steps FOR DELETE
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

-- ============================================================================
-- wt_recipe_ingredients (child table via recipe_id -> wt_recipes)
-- ============================================================================
CREATE POLICY "Users can view recipe ingredients for accessible recipes"
  ON public.wt_recipe_ingredients FOR SELECT
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
        OR profile_id IS NULL
    )
  );

CREATE POLICY "Users can insert recipe ingredients for their recipes"
  ON public.wt_recipe_ingredients FOR INSERT
  WITH CHECK (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can update recipe ingredients for their recipes"
  ON public.wt_recipe_ingredients FOR UPDATE
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can delete recipe ingredients for their recipes"
  ON public.wt_recipe_ingredients FOR DELETE
  USING (
    recipe_id IN (
      SELECT id FROM public.wt_recipes
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

-- ============================================================================
-- wt_meals (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own meals"
  ON public.wt_meals FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own meals"
  ON public.wt_meals FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own meals"
  ON public.wt_meals FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own meals"
  ON public.wt_meals FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_pantry_items (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own pantry items"
  ON public.wt_pantry_items FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own pantry items"
  ON public.wt_pantry_items FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own pantry items"
  ON public.wt_pantry_items FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own pantry items"
  ON public.wt_pantry_items FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_leftovers (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own leftovers"
  ON public.wt_leftovers FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own leftovers"
  ON public.wt_leftovers FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own leftovers"
  ON public.wt_leftovers FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own leftovers"
  ON public.wt_leftovers FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_nutrients (reference table: SELECT only for all authenticated users)
-- ============================================================================
CREATE POLICY "All authenticated users can view nutrients"
  ON public.wt_nutrients FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- wt_nutrient_targets (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own nutrient targets"
  ON public.wt_nutrient_targets FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own nutrient targets"
  ON public.wt_nutrient_targets FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own nutrient targets"
  ON public.wt_nutrient_targets FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own nutrient targets"
  ON public.wt_nutrient_targets FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- wt_meal_nutrient_breakdown (child table via meal_id -> wt_meals)
-- ============================================================================
CREATE POLICY "Users can view their own meal nutrient breakdowns"
  ON public.wt_meal_nutrient_breakdown FOR SELECT
  USING (
    meal_id IN (
      SELECT id FROM public.wt_meals
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can insert their own meal nutrient breakdowns"
  ON public.wt_meal_nutrient_breakdown FOR INSERT
  WITH CHECK (
    meal_id IN (
      SELECT id FROM public.wt_meals
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can update their own meal nutrient breakdowns"
  ON public.wt_meal_nutrient_breakdown FOR UPDATE
  USING (
    meal_id IN (
      SELECT id FROM public.wt_meals
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can delete their own meal nutrient breakdowns"
  ON public.wt_meal_nutrient_breakdown FOR DELETE
  USING (
    meal_id IN (
      SELECT id FROM public.wt_meals
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );
