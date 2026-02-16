# Priority: Onboarding UI Redesign

Before proceeding with pantry/recipes integration, the onboarding flow must be redesigned.
See: `/PRPs/onboarding-ui-redesign.md`

**Status**: In Progress
**Phase**: 2b

---

# Next Steps: Integrating Pantry → Recipes → Prep Feature

## Immediate Actions Required

### 1. Database Schema Deployment

Run this SQL migration in Supabase to create the required tables:

```sql
-- Pantry Items Table
CREATE TABLE wt_pantry_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('fridge', 'cupboard', 'freezer')),
  quantity NUMERIC,
  unit TEXT,
  expiry_date TIMESTAMPTZ,
  is_available BOOLEAN DEFAULT true,
  barcode TEXT,
  cost NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Recipes Table
CREATE TABLE wt_recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  servings INTEGER NOT NULL,
  prep_time_min INTEGER,
  cook_time_min INTEGER,
  source_type TEXT NOT NULL CHECK (source_type IN ('url', 'ocr', 'ai', 'manual')),
  source_url TEXT,
  nutrition_score TEXT CHECK (nutrition_score IN ('A', 'B', 'C', 'D')),
  tags TEXT[] DEFAULT '{}',
  image_url TEXT,
  rating NUMERIC CHECK (rating >= 0 AND rating <= 5),
  is_favorite BOOLEAN DEFAULT false,
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Recipe Steps Table
CREATE TABLE wt_recipe_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES wt_recipes(id) ON DELETE CASCADE,
  step_number INTEGER NOT NULL,
  instruction TEXT NOT NULL,
  duration_minutes INTEGER,
  UNIQUE(recipe_id, step_number)
);

-- Recipe Ingredients Table
CREATE TABLE wt_recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES wt_recipes(id) ON DELETE CASCADE,
  ingredient_name TEXT NOT NULL,
  quantity NUMERIC,
  unit TEXT,
  notes TEXT,
  sort_order INTEGER NOT NULL,
  UNIQUE(recipe_id, sort_order)
);

-- Meals Table
CREATE TABLE wt_meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES wt_recipes(id) ON DELETE SET NULL,
  meal_date TIMESTAMPTZ NOT NULL,
  meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  name TEXT NOT NULL,
  servings_consumed NUMERIC NOT NULL DEFAULT 1,
  nutrition_info JSONB,
  score TEXT CHECK (score IN ('A', 'B', 'C', 'D')),
  rating NUMERIC CHECK (rating >= 0 AND rating <= 5),
  notes TEXT,
  photo_url TEXT,
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Row Level Security Policies

-- Pantry Items RLS
ALTER TABLE wt_pantry_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own pantry items"
  ON wt_pantry_items FOR SELECT
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert their own pantry items"
  ON wt_pantry_items FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own pantry items"
  ON wt_pantry_items FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own pantry items"
  ON wt_pantry_items FOR DELETE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

-- Recipes RLS
ALTER TABLE wt_recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recipes and public recipes"
  ON wt_recipes FOR SELECT
  USING (
    profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
    OR is_public = true
  );

CREATE POLICY "Users can insert their own recipes"
  ON wt_recipes FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own recipes"
  ON wt_recipes FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own recipes"
  ON wt_recipes FOR DELETE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

-- Recipe Steps RLS (inherited from recipe)
ALTER TABLE wt_recipe_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view steps for accessible recipes"
  ON wt_recipe_steps FOR SELECT
  USING (recipe_id IN (
    SELECT id FROM wt_recipes WHERE
      profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
      OR is_public = true
  ));

CREATE POLICY "Users can manage steps for their own recipes"
  ON wt_recipe_steps FOR ALL
  USING (recipe_id IN (
    SELECT id FROM wt_recipes WHERE
      profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
  ));

-- Recipe Ingredients RLS (inherited from recipe)
ALTER TABLE wt_recipe_ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ingredients for accessible recipes"
  ON wt_recipe_ingredients FOR SELECT
  USING (recipe_id IN (
    SELECT id FROM wt_recipes WHERE
      profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
      OR is_public = true
  ));

CREATE POLICY "Users can manage ingredients for their own recipes"
  ON wt_recipe_ingredients FOR ALL
  USING (recipe_id IN (
    SELECT id FROM wt_recipes WHERE
      profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid())
  ));

-- Meals RLS
ALTER TABLE wt_meals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own meals"
  ON wt_meals FOR SELECT
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert their own meals"
  ON wt_meals FOR INSERT
  WITH CHECK (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update their own meals"
  ON wt_meals FOR UPDATE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their own meals"
  ON wt_meals FOR DELETE
  USING (profile_id IN (
    SELECT id FROM wt_profiles WHERE user_id = auth.uid()
  ));

-- Indexes for performance
CREATE INDEX idx_pantry_items_profile_category ON wt_pantry_items(profile_id, category);
CREATE INDEX idx_pantry_items_expiry ON wt_pantry_items(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_recipes_profile ON wt_recipes(profile_id);
CREATE INDEX idx_recipes_public ON wt_recipes(is_public) WHERE is_public = true;
CREATE INDEX idx_recipe_steps_recipe ON wt_recipe_steps(recipe_id, step_number);
CREATE INDEX idx_recipe_ingredients_recipe ON wt_recipe_ingredients(recipe_id, sort_order);
CREATE INDEX idx_meals_profile_date ON wt_meals(profile_id, meal_date);
```

Save as: `/supabase/migrations/YYYYMMDDHHMMSS_pantry_recipes_meals.sql`

### 2. Add Routes to App Router

Edit `/lib/shared/core/router/app_router.dart`:

```dart
import 'package:welltrack/features/pantry/presentation/pantry_screen.dart';
import 'package:welltrack/features/recipes/presentation/recipe_suggestions_screen.dart';
import 'package:welltrack/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:welltrack/features/recipes/presentation/prep_walkthrough_screen.dart';
import 'package:welltrack/features/meals/presentation/log_meal_screen.dart';

// Add to routes:
GoRoute(
  path: '/pantry',
  builder: (context, state) => const PantryScreen(),
),
GoRoute(
  path: '/recipes/suggestions',
  builder: (context, state) => const RecipeSuggestionsScreen(),
),
GoRoute(
  path: '/recipes/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return RecipeDetailScreen(recipeId: id);
  },
),
GoRoute(
  path: '/meals/log',
  builder: (context, state) => const LogMealScreen(),
),
```

### 3. Register Modules in Dashboard

Edit `/lib/shared/core/modules/module_registry.dart`:

```dart
ModuleMetadata(
  id: 'pantry',
  name: 'Pantry',
  description: 'Manage your pantry inventory',
  icon: Icons.kitchen,
  route: '/pantry',
  color: Colors.brown,
  order: 5,
),
ModuleMetadata(
  id: 'recipes',
  name: 'Recipes',
  description: 'AI-generated and saved recipes',
  icon: Icons.restaurant,
  route: '/recipes',
  color: Colors.orange,
  order: 6,
),
ModuleMetadata(
  id: 'meals',
  name: 'Meals',
  description: 'Log your meals and track nutrition',
  icon: Icons.fastfood,
  route: '/meals',
  color: Colors.deepOrange,
  order: 7,
),
```

### 4. Create AI Orchestrator Edge Function

Create `/supabase/functions/ai-orchestrate/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const openAiKey = Deno.env.get('OPENAI_API_KEY')

serve(async (req) => {
  try {
    const { profileId, workflowType, context, userMessage } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Route to appropriate handler
    if (workflowType === 'generate_pantry_recipes') {
      return await generatePantryRecipes(supabase, profileId, context)
    }

    if (workflowType === 'generate_recipe_steps') {
      return await generateRecipeSteps(supabase, context)
    }

    return new Response(
      JSON.stringify({ error: 'Unknown workflow type' }),
      { status: 400 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})

async function generatePantryRecipes(supabase, profileId, context) {
  // context.pantryItems = array of { name, quantity, unit, category }

  const prompt = `You are a creative chef. Generate 5-10 recipe suggestions using these pantry items:
${context.pantryItems.map(item => `- ${item.name} (${item.quantity} ${item.unit})`).join('\n')}

Return JSON array of recipes with:
- title (string)
- description (string)
- estimated_time_min (number)
- difficulty (Easy/Medium/Hard)
- nutrition_score (A/B/C/D based on healthiness)
- tags (array of strings)
- servings (number)

Format: JSON array only, no other text.`

  const openAiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openAiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.8,
    }),
  })

  const data = await openAiResponse.json()
  const suggestions = JSON.parse(data.choices[0].message.content)

  // Log AI usage
  await supabase.from('wt_ai_usage').insert({
    profile_id: profileId,
    workflow_type: 'generate_pantry_recipes',
    tokens_used: data.usage.total_tokens,
    cost_usd: data.usage.total_tokens * 0.00003, // GPT-4 pricing
  })

  return new Response(
    JSON.stringify({ suggestions }),
    { headers: { 'Content-Type': 'application/json' } }
  )
}

async function generateRecipeSteps(supabase, context) {
  // context.recipe = { title, description, ingredients, servings }

  const prompt = `Generate detailed cooking steps for this recipe:
Title: ${context.recipe.title}
Description: ${context.recipe.description}

Return JSON with:
- steps: array of { step_number, instruction, duration_minutes (optional) }
- ingredients: array of { ingredient_name, quantity, unit, notes (optional), sort_order }

Format: JSON object only, no other text.`

  const openAiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openAiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.7,
    }),
  })

  const data = await openAiResponse.json()
  const recipeDetails = JSON.parse(data.choices[0].message.content)

  return new Response(
    JSON.stringify(recipeDetails),
    { headers: { 'Content-Type': 'application/json' } }
  )
}
```

Deploy:
```bash
supabase functions deploy ai-orchestrate --no-verify-jwt
```

### 5. Update Recipe Generation Provider

Replace mock functions in `/lib/features/recipes/presentation/recipe_generation_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:welltrack/shared/core/network/dio_client.dart';

Future<void> generateRecipeSuggestions(
  String profileId,
  List<PantryItemEntity> pantryItems,
) async {
  state = state.copyWith(state: RecipeGenerationState.generating);

  try {
    final dio = ref.read(dioClientProvider);

    final response = await dio.post(
      'https://YOUR_PROJECT_REF.supabase.co/functions/v1/ai-orchestrate',
      data: {
        'profileId': profileId,
        'workflowType': 'generate_pantry_recipes',
        'context': {
          'pantryItems': pantryItems.map((item) => {
            'name': item.name,
            'quantity': item.quantity,
            'unit': item.unit,
            'category': item.category,
          }).toList(),
        },
      },
    );

    final suggestions = (response.data['suggestions'] as List)
        .map((json) => RecipeSuggestion.fromJson(json))
        .toList();

    state = state.copyWith(
      state: RecipeGenerationState.suggestions,
      suggestions: suggestions,
    );
  } catch (e) {
    state = state.copyWith(
      state: RecipeGenerationState.error,
      errorMessage: 'Failed to generate recipes: $e',
    );
  }
}
```

### 6. Testing Checklist

- [ ] Run `flutter analyze` (should pass with no errors)
- [ ] Deploy database schema to Supabase
- [ ] Add test data to wt_profiles
- [ ] Test pantry CRUD operations
- [ ] Test recipe generation flow (with mock data first)
- [ ] Test prep walkthrough timers
- [ ] Test meal logging
- [ ] Verify RLS policies work
- [ ] Test offline behavior (airplane mode)
- [ ] Test on both iOS and Android

### 7. Environment Variables Needed

Add to `.env`:
```
OPENAI_API_KEY=sk-...
```

Add to Supabase Edge Function secrets:
```bash
supabase secrets set OPENAI_API_KEY=sk-...
```

## Optional Enhancements

1. **Photo Capture**
   - Use `image_picker` package
   - Upload to Supabase Storage
   - Display in meal history

2. **Recipe Sharing**
   - Toggle `is_public` on recipes
   - Browse public recipes from other users
   - Community recipe library

3. **Leftover Tracking**
   - After meal logging, prompt to capture leftovers
   - Add back to pantry with expiry date

4. **Shopping List**
   - Generate shopping list from missing ingredients
   - Track which items to buy

5. **Nutrition Dashboard**
   - Daily/weekly nutrition charts
   - Track macros and micros
   - Progress vs goals

## Support

If you encounter issues:
1. Check database schema is deployed correctly
2. Verify RLS policies allow access
3. Check Supabase logs for errors
4. Ensure profile_id is passed correctly
5. Test with mock data before AI integration

## Documentation

- PRP: `/PRPs/pantry-recipes-prep-feature.md`
- Implementation: `/PRPs/pantry-recipes-prep-IMPLEMENTATION.md`
- This guide: `/PRPs/NEXT_STEPS.md`
