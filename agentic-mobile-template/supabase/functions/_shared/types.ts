export interface OrchestrateRequest {
  user_id: string
  profile_id: string
  message?: string
  workflow_type?: WorkflowType
  context_override?: Record<string, unknown>
}

export type WorkflowType =
  | 'generate_weekly_plan'
  | 'generate_pantry_recipes'
  | 'generate_recipe_steps'
  | 'summarize_insights'
  | 'recommend_supplements'
  | 'recommend_workouts'
  | 'update_goals'
  | 'recalc_goal_forecast'
  | 'log_event_suggestion'
  | 'extract_recipe_from_url'
  | 'extract_recipe_from_image'

export interface OrchestrateResponse {
  assistant_message: string
  suggested_actions: SuggestedAction[]
  db_writes: DBWrite[]
  updated_forecast?: ForecastUpdate
  safety_flags: SafetyFlag[]
  usage: UsageInfo
}

export interface SuggestedAction {
  action_type: string
  label: string
  payload: Record<string, unknown>
}

export interface DBWrite {
  table: string
  operation: 'insert' | 'update' | 'upsert'
  data: Record<string, unknown>
  dry_run: boolean
}

export interface ForecastUpdate {
  goal_id: string
  new_expected_date: string
  confidence: number
  explanation: string
}

export interface SafetyFlag {
  type: 'medical_claim' | 'unsafe_value' | 'rate_limit' | 'content_filter'
  message: string
  blocked: boolean
}

export interface UsageInfo {
  calls_used: number
  calls_limit: number
  tokens_used: number
  tokens_limit: number
}

export interface ContextSnapshot {
  profile: ProfileContext
  recent_metrics: MetricSummary[]
  active_plan: PlanSummary | null
  recent_meals: MealSummary[]
  supplement_adherence: number
  ai_memory: MemoryItem[]
  baselines: BaselineSummary[]
  recovery_score: number | null
}

export interface ProfileContext {
  display_name: string
  age: number | null
  gender: string | null
  height_cm: number | null
  weight_kg: number | null
  activity_level: string | null
  fitness_goals: string | null
  dietary_restrictions: string | null
  allergies: string | null
  plan_tier: string
}

export interface MetricSummary {
  metric_type: string
  avg_value: number | null
  latest_value: number | null
  unit: string
  trend: 'improving' | 'stable' | 'declining' | 'insufficient_data'
}

export interface MealSummary {
  date: string
  meal_type: string
  name: string
  calories: number | null
}

export interface MemoryItem {
  memory_type: string
  memory_key: string
  memory_value: Record<string, unknown>
}

export interface BaselineSummary {
  metric_type: string
  baseline_value: number
  is_complete: boolean
}

export interface PlanSummary {
  id: string
  title: string
  status: string
  completion_pct: number
}
