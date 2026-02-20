import { WorkflowType } from './types.ts'

export interface ToolConfig {
  name: string
  description: string
  max_tokens: number
  temperature: number
  system_prompt_additions: string
}

export const TOOL_REGISTRY: Record<WorkflowType, ToolConfig> = {
  generate_weekly_plan: {
    name: 'generate_weekly_plan',
    description: 'Generate a personalized weekly wellness plan with meals, workouts, supplements, and activities',
    max_tokens: 2000,
    temperature: 0.7,
    system_prompt_additions: `
You are generating a weekly wellness plan. Based on the user's context:
- Create 7 days of structured plans
- Include meal suggestions (breakfast, lunch, dinner, snacks) aligned with dietary restrictions and goals
- Recommend workouts based on fitness level and recovery score
- Suggest supplement timing (AM/PM protocols)
- Set realistic daily activity targets
- Calculate expected goal achievement date based on current trajectory

Return your response in this JSON structure:
{
  "plan_title": "Week of [date]",
  "days": [
    {
      "day": "Monday",
      "meals": [{"meal_type": "breakfast", "name": "...", "notes": "..."}],
      "workouts": [{"type": "...", "duration_min": 30, "intensity": "..."}],
      "supplements": [{"name": "...", "time": "AM"}],
      "activity_goal_steps": 8000
    }
  ],
  "expected_goal_date": "2026-03-15",
  "confidence": 0.75,
  "rationale": "Based on your stress levels trending down and consistent sleep..."
}

NEVER prescribe specific dosages or make medical claims. Use suggestive language only.
`,
  },

  generate_pantry_recipes: {
    name: 'generate_pantry_recipes',
    description: 'Generate recipe suggestions from available pantry items',
    max_tokens: 1500,
    temperature: 0.8,
    system_prompt_additions: `
You are generating recipe ideas from pantry items. The user will provide:
- Fridge items
- Cupboard/pantry items
- Freezer items
- Dietary restrictions and allergies from profile

Generate 5-10 recipe options with:
- Recipe name
- Prep time (minutes)
- Cook time (minutes)
- Difficulty (easy/medium/hard)
- Ingredients from pantry (list what's used)
- High-level steps (2-3 sentences)
- Nutrition score estimate (A/B/C/D based on balance and quality)
- Tags (e.g., "high-protein", "vegetarian", "quick")

Return JSON array:
[
  {
    "name": "Chicken Stir-Fry",
    "prep_time": 15,
    "cook_time": 20,
    "difficulty": "easy",
    "ingredients_used": ["chicken breast", "bell peppers", "soy sauce"],
    "steps_summary": "Dice chicken and vegetables. Stir-fry in hot pan with sauce.",
    "nutrition_score": "A",
    "tags": ["high-protein", "quick"]
  }
]

Prioritize recipes that use the most pantry items and match dietary needs.
`,
  },

  generate_recipe_steps: {
    name: 'generate_recipe_steps',
    description: 'Generate detailed step-by-step cooking instructions for a selected recipe',
    max_tokens: 1200,
    temperature: 0.6,
    system_prompt_additions: `
You are creating detailed cooking steps for a recipe. The user has selected a recipe and needs:
- Step-by-step instructions
- Timing guidance for each step
- Tips and techniques
- Leftover suggestions

Return JSON:
{
  "recipe_id": "...",
  "steps": [
    {
      "step_number": 1,
      "instruction": "Preheat oven to 375°F and line baking sheet with parchment.",
      "duration_min": 5,
      "tips": "Use convection mode if available for even heating."
    }
  ],
  "total_time": 45,
  "leftover_suggestions": [
    {"item": "cooked chicken", "storage": "fridge", "duration_days": 3, "reuse_ideas": "Add to salads or wraps"}
  ]
}

Be precise with temperatures, times, and techniques. Safety first.
`,
  },

  summarize_insights: {
    name: 'summarize_insights',
    description: 'Summarize wellness insights from recent data and generate actionable recommendations',
    max_tokens: 1000,
    temperature: 0.6,
    system_prompt_additions: `
You are summarizing the user's wellness insights. Based on recent metrics, meals, workouts, and sleep:
- Identify patterns (positive and areas for improvement)
- Highlight correlations (e.g., "Sleep improved on days with morning workouts")
- Suggest 2-3 actionable next steps
- Note any concerning trends (but never diagnose)

Return JSON:
{
  "summary": "Your stress levels decreased 15% this week, correlating with 3 morning workouts...",
  "key_patterns": [
    {"pattern": "Better sleep on workout days", "confidence": "high"}
  ],
  "recommendations": [
    {"action": "Schedule 2 more morning workouts next week", "rationale": "..."}
  ],
  "flags": ["Consider consulting a professional if headaches persist"]
}

Use suggestive, supportive language. Never make medical diagnoses.
`,
  },

  recommend_supplements: {
    name: 'recommend_supplements',
    description: 'Recommend supplement protocol based on goals and deficiencies',
    max_tokens: 800,
    temperature: 0.5,
    system_prompt_additions: `
You are suggesting a supplement protocol. Based on user's goals, dietary restrictions, and any noted deficiencies:
- Suggest common supplements (Vitamin D, Omega-3, Magnesium, etc.)
- Recommend AM/PM timing
- Link to specific goals (e.g., "Magnesium for sleep quality")

Return JSON:
{
  "suggestions": [
    {
      "supplement_name": "Vitamin D3",
      "timing": "AM",
      "goal_link": "Support immune health and mood",
      "rationale": "Your location and indoor work suggest potential low sun exposure"
    }
  ],
  "disclaimer": "These are general suggestions. Consult a healthcare provider before starting any supplement."
}

NEVER prescribe dosages. Always include disclaimer.
`,
  },

  recommend_workouts: {
    name: 'recommend_workouts',
    description: 'Recommend workouts based on fitness level, goals, and recovery status',
    max_tokens: 1000,
    temperature: 0.7,
    system_prompt_additions: `
You are recommending workouts. Based on:
- Fitness goals (strength, endurance, weight loss, etc.)
- Activity level
- Recovery score
- Recent workout history

Suggest 3-5 workouts for the week with:
- Type (cardio, strength, HIIT, yoga, etc.)
- Duration
- Intensity
- Specific exercises or focus areas

Return JSON:
{
  "workouts": [
    {
      "day": "Monday",
      "type": "strength",
      "duration_min": 45,
      "intensity": "moderate",
      "focus": "Upper body",
      "exercises": ["Push-ups", "Dumbbell rows", "Shoulder press"],
      "rationale": "Recovery score is high; good day for strength work"
    }
  ]
}

Adjust intensity based on recovery score. If recovery is low, suggest active recovery or rest.
`,
  },

  update_goals: {
    name: 'update_goals',
    description: 'Update or create new wellness goals based on conversation',
    max_tokens: 600,
    temperature: 0.6,
    system_prompt_additions: `
You are helping the user set or update wellness goals. Goals should be:
- Specific and measurable
- Time-bound
- Realistic based on current baselines

Return JSON:
{
  "goals": [
    {
      "goal_type": "weight_loss",
      "target_value": 75,
      "target_unit": "kg",
      "target_date": "2026-06-01",
      "rationale": "Based on your current weight and activity level, 0.5kg/week is sustainable"
    }
  ]
}

Use SMART goal framework. Be encouraging but realistic.
`,
  },

  recalc_goal_forecast: {
    name: 'recalc_goal_forecast',
    description: 'Recalculate expected goal achievement date based on recent progress',
    max_tokens: 500,
    temperature: 0.5,
    system_prompt_additions: `
You are recalculating when a goal will be achieved based on recent data trends.

Return JSON:
{
  "goal_id": "...",
  "original_target_date": "2026-06-01",
  "new_expected_date": "2026-06-15",
  "confidence": 0.7,
  "explanation": "Progress is 10% slower than target rate; adjusting timeline by 2 weeks",
  "suggestions": ["Increase workout frequency by 1 day/week to stay on track"]
}

Be honest about progress. Adjust expectations realistically.
`,
  },

  log_event_suggestion: {
    name: 'log_event_suggestion',
    description: 'Suggest logging a wellness event based on conversation',
    max_tokens: 400,
    temperature: 0.6,
    system_prompt_additions: `
You are suggesting a manual log entry based on user's message.

Return JSON:
{
  "log_type": "meal|workout|symptom|note",
  "suggested_data": {
    "name": "...",
    "notes": "...",
    "time": "..."
  },
  "confirmation_prompt": "I can log this meal for you. Does this look correct?"
}
`,
  },

  extract_recipe_from_url: {
    name: 'extract_recipe_from_url',
    description: 'Extract recipe details from a provided URL',
    max_tokens: 1200,
    temperature: 0.4,
    system_prompt_additions: `
You are extracting recipe information from a webpage. Parse the HTML/text for:
- Recipe title
- Servings
- Prep time / Cook time
- Ingredients list
- Instructions/steps

Return JSON:
{
  "title": "...",
  "servings": 4,
  "prep_time": 15,
  "cook_time": 30,
  "ingredients": [
    {"item": "chicken breast", "quantity": "500g"}
  ],
  "steps": [
    {"step_number": 1, "instruction": "..."}
  ],
  "source_url": "...",
  "confidence": 0.9
}

If critical fields are missing, set confidence < 0.7 and flag for user review.
`,
  },

  extract_recipe_from_image: {
    name: 'extract_recipe_from_image',
    description: 'Extract recipe details from an image using OCR',
    max_tokens: 1200,
    temperature: 0.4,
    system_prompt_additions: `
You are extracting recipe information from OCR text of a photographed recipe. Parse for:
- Recipe title
- Servings
- Prep/cook time
- Ingredients
- Instructions

Return same JSON structure as extract_recipe_from_url.

OCR text may have errors. Use context clues and common recipe patterns to interpret. Flag low confidence if text is unclear.
`,
  },

  generate_daily_meal_plan: {
    name: 'generate_daily_meal_plan',
    description: 'Generate a personalized daily meal plan with macro targets',
    max_tokens: 1500,
    temperature: 0.7,
    system_prompt_additions: `
You are generating a daily meal plan. Create 3 meals (breakfast, lunch, dinner) plus 1-2 snacks.

For each meal, provide:
- meal_type: "breakfast", "lunch", "dinner", or "snack"
- name: Short meal name
- description: Brief description (1-2 sentences)
- calories: Estimated calories (integer)
- protein_g: Protein in grams (integer)
- carbs_g: Carbs in grams (integer)
- fat_g: Fat in grams (integer)

Consider the user's:
- Dietary restrictions and allergies
- Activity level and fitness goals
- Day type (strength/cardio/rest) — adjust carbs and calories accordingly
- Target macro totals provided in context
- Cuisine preferences if available

Return a JSON code block with this structure:
\`\`\`json
{
  "meals": [
    {
      "meal_type": "breakfast",
      "name": "Greek Yogurt Power Bowl",
      "description": "Protein-rich yogurt with berries, granola, and honey.",
      "calories": 450,
      "protein_g": 30,
      "carbs_g": 55,
      "fat_g": 12
    }
  ],
  "rationale": "This plan prioritizes protein for your strength training day while keeping carbs moderate for energy."
}
\`\`\`

Ensure total macros across all meals approximate the target values. Be creative with meal variety.
NEVER suggest meals that conflict with stated allergies or dietary restrictions.
`,
  },

  generate_shopping_list: {
    name: 'generate_shopping_list',
    description: 'Consolidate meal plan ingredients into a shopping list with quantities and aisle assignments',
    max_tokens: 1500,
    temperature: 0.5,
    system_prompt_additions: `
You are consolidating ingredients from multiple meal plans into a unified shopping list.

You will receive meal plan data for multiple days. For each day, there are meals with names and descriptions.

Your job:
1. Extract all ingredients needed for all meals across all days
2. Consolidate duplicate ingredients (sum quantities)
3. Assign each ingredient to a supermarket aisle category
4. Estimate reasonable quantities based on serving sizes

Return a JSON code block:
\`\`\`json
{
  "items": [
    {
      "ingredient_name": "Chicken Breast",
      "quantity": 1.5,
      "unit": "kg",
      "aisle": "Meat & Poultry",
      "notes": "For grilled chicken salad (Mon) and chicken stir-fry (Wed)"
    }
  ],
  "summary": "Shopping list for 3 days of meal plans covering 12 meals"
}
\`\`\`

Aisle categories to use: Produce, Meat & Poultry, Seafood, Dairy & Eggs, Bakery, Frozen, Canned & Jarred, Pasta & Grains, Snacks, Beverages, Condiments & Sauces, Spices & Seasonings, Baking, Health & Wellness, Other.

Be thorough — include cooking oils, seasonings, and garnishes that recipes would need.
`,
  },

  generate_meal_swap: {
    name: 'generate_meal_swap',
    description: 'Generate a replacement meal matching similar macro targets',
    max_tokens: 600,
    temperature: 0.7,
    system_prompt_additions: `
You are replacing a single meal in a daily meal plan. The user wants to swap out the current meal for something different while hitting similar macro targets.

You will receive the current meal's details and macro targets in the context.

Return a JSON code block with a single replacement meal:
\`\`\`json
{
  "meal_type": "lunch",
  "name": "Grilled Chicken Caesar Salad",
  "description": "Crispy romaine with grilled chicken, parmesan, and light caesar dressing.",
  "calories": 520,
  "protein_g": 42,
  "carbs_g": 25,
  "fat_g": 28
}
\`\`\`

The replacement must:
- Match the same meal_type as the original
- Be within 10% of the original calorie count
- Be a meaningfully different meal (not just a minor variation)
- Respect dietary restrictions and allergies
`,
  },
}

export function getToolConfig(workflowType?: WorkflowType): ToolConfig {
  if (!workflowType) {
    // Default general chat config
    return {
      name: 'general_chat',
      description: 'General wellness assistant conversation',
      max_tokens: 800,
      temperature: 0.7,
      system_prompt_additions: '',
    }
  }

  return TOOL_REGISTRY[workflowType]
}
