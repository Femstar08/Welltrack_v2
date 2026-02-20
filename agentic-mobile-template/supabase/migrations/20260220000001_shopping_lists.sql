-- Migration: Shopping Lists and Shopping List Items
-- WellTrack Phase 7a
-- Creates: wt_shopping_lists, wt_shopping_list_items

-- ============================================================================
-- SHOPPING LISTS TABLE
-- ============================================================================
CREATE TABLE wt_shopping_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES wt_profiles(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    recipe_ids uuid[] DEFAULT '{}',
    status text DEFAULT 'active' NOT NULL,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_shopping_lists
CREATE INDEX idx_wt_shopping_lists_profile_id ON wt_shopping_lists(profile_id);
CREATE INDEX idx_wt_shopping_lists_profile_id_status ON wt_shopping_lists(profile_id, status);

-- Enable RLS
ALTER TABLE wt_shopping_lists ENABLE ROW LEVEL SECURITY;

-- Trigger for updated_at
CREATE TRIGGER set_updated_at_wt_shopping_lists
    BEFORE UPDATE ON wt_shopping_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SHOPPING LIST ITEMS TABLE
-- ============================================================================
CREATE TABLE wt_shopping_list_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shopping_list_id uuid REFERENCES wt_shopping_lists(id) ON DELETE CASCADE NOT NULL,
    ingredient_name text NOT NULL,
    quantity numeric(10,2),
    unit text,
    aisle text DEFAULT 'Other',
    is_checked boolean DEFAULT false NOT NULL,
    notes text,
    source_recipe_id uuid REFERENCES wt_recipes(id) ON DELETE SET NULL,
    sort_order int DEFAULT 0,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for wt_shopping_list_items
CREATE INDEX idx_wt_shopping_list_items_shopping_list_id ON wt_shopping_list_items(shopping_list_id);
CREATE INDEX idx_wt_shopping_list_items_shopping_list_id_checked ON wt_shopping_list_items(shopping_list_id, is_checked);

-- Enable RLS
ALTER TABLE wt_shopping_list_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES — wt_shopping_lists (profile-scoped)
-- ============================================================================
CREATE POLICY "Users can view their own shopping lists"
  ON public.wt_shopping_lists FOR SELECT
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can insert their own shopping lists"
  ON public.wt_shopping_lists FOR INSERT
  WITH CHECK (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can update their own shopping lists"
  ON public.wt_shopping_lists FOR UPDATE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

CREATE POLICY "Users can delete their own shopping lists"
  ON public.wt_shopping_lists FOR DELETE
  USING (profile_id IN (SELECT public.get_profile_ids_for_user()));

-- ============================================================================
-- RLS POLICIES — wt_shopping_list_items (child table via shopping_list_id)
-- ============================================================================
CREATE POLICY "Users can view their own shopping list items"
  ON public.wt_shopping_list_items FOR SELECT
  USING (
    shopping_list_id IN (
      SELECT id FROM public.wt_shopping_lists
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can insert their own shopping list items"
  ON public.wt_shopping_list_items FOR INSERT
  WITH CHECK (
    shopping_list_id IN (
      SELECT id FROM public.wt_shopping_lists
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can update their own shopping list items"
  ON public.wt_shopping_list_items FOR UPDATE
  USING (
    shopping_list_id IN (
      SELECT id FROM public.wt_shopping_lists
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );

CREATE POLICY "Users can delete their own shopping list items"
  ON public.wt_shopping_list_items FOR DELETE
  USING (
    shopping_list_id IN (
      SELECT id FROM public.wt_shopping_lists
      WHERE profile_id IN (SELECT public.get_profile_ids_for_user())
    )
  );
