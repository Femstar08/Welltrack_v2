import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  ContextSnapshot,
  ProfileContext,
  MetricSummary,
  MealSummary,
  MemoryItem,
  BaselineSummary,
  PlanSummary,
} from './types.ts'

export async function buildContextSnapshot(
  adminClient: SupabaseClient,
  userId: string,
  profileId: string,
  contextOverride?: Record<string, unknown>
): Promise<ContextSnapshot> {
  const sevenDaysAgo = new Date()
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
  const threeDaysAgo = new Date()
  threeDaysAgo.setDate(threeDaysAgo.getDate() - 3)

  // Fetch profile data
  const { data: profileData, error: profileError } = await adminClient
    .from('wt_profiles')
    .select('display_name, date_of_birth, gender, height_cm, weight_kg, activity_level, fitness_goals, dietary_restrictions, allergies, preferred_ingredients, excluded_ingredients')
    .eq('id', profileId)
    .eq('user_id', userId)
    .single()

  if (profileError || !profileData) {
    throw new Error(`Profile not found: ${profileError?.message || 'Unknown error'}`)
  }

  // Fetch plan_tier from wt_users (it lives there, not on wt_profiles)
  const { data: userData } = await adminClient
    .from('wt_users')
    .select('plan_tier')
    .eq('id', userId)
    .single()

  // Compute age from date_of_birth
  let computedAge: number | null = null
  if (profileData.date_of_birth) {
    const dob = new Date(profileData.date_of_birth)
    computedAge = Math.floor(
      (Date.now() - dob.getTime()) / (365.25 * 24 * 60 * 60 * 1000)
    )
  }

  const profile: ProfileContext = {
    display_name: profileData.display_name || 'User',
    age: computedAge,
    gender: profileData.gender,
    height_cm: profileData.height_cm,
    weight_kg: profileData.weight_kg,
    activity_level: profileData.activity_level,
    fitness_goals: profileData.fitness_goals,
    dietary_restrictions: profileData.dietary_restrictions,
    allergies: profileData.allergies,
    preferred_ingredients: profileData.preferred_ingredients || null,
    excluded_ingredients: profileData.excluded_ingredients || null,
    plan_tier: userData?.plan_tier || 'free',
  }

  // Fetch recent health metrics (last 7 days, aggregated)
  const { data: metricsData } = await adminClient
    .from('wt_health_metrics')
    .select('metric_type, value_num, unit, recorded_at')
    .eq('profile_id', profileId)
    .gte('recorded_at', sevenDaysAgo.toISOString())
    .order('recorded_at', { ascending: false })

  const recent_metrics = aggregateMetrics(metricsData || [])

  // Fetch active plan
  const { data: planData } = await adminClient
    .from('wt_plans')
    .select('id, title, status, completion_pct')
    .eq('profile_id', profileId)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(1)
    .single()

  const active_plan: PlanSummary | null = planData
    ? {
        id: planData.id,
        title: planData.title,
        status: planData.status,
        completion_pct: planData.completion_pct || 0,
      }
    : null

  // Fetch recent meals (last 3 days)
  const { data: mealsData } = await adminClient
    .from('wt_meals')
    .select('date, meal_type, name, calories')
    .eq('profile_id', profileId)
    .gte('date', threeDaysAgo.toISOString().split('T')[0])
    .order('date', { ascending: false })
    .limit(20)

  const recent_meals: MealSummary[] =
    mealsData?.map((m) => ({
      date: m.date,
      meal_type: m.meal_type,
      name: m.name,
      calories: m.calories,
    })) || []

  // Fetch supplement adherence (last 7 days)
  const { data: supplementData } = await adminClient
    .from('wt_supplement_logs')
    .select('id, taken')
    .eq('profile_id', profileId)
    .gte('log_date', sevenDaysAgo.toISOString().split('T')[0])

  const supplement_adherence = supplementData && supplementData.length > 0
    ? supplementData.filter((s) => s.taken).length / supplementData.length
    : 0

  // Fetch AI memory
  const { data: memoryData } = await adminClient
    .from('wt_ai_memory')
    .select('memory_type, memory_key, memory_value')
    .eq('profile_id', profileId)
    .order('updated_at', { ascending: false })
    .limit(50)

  const ai_memory: MemoryItem[] =
    memoryData?.map((m) => ({
      memory_type: m.memory_type,
      memory_key: m.memory_key,
      memory_value: m.memory_value as Record<string, unknown>,
    })) || []

  // Fetch baselines status
  const { data: baselinesData } = await adminClient
    .from('wt_baselines')
    .select('metric_type, baseline_value, is_complete')
    .eq('profile_id', profileId)

  const baselines: BaselineSummary[] =
    baselinesData?.map((b) => ({
      metric_type: b.metric_type,
      baseline_value: b.baseline_value,
      is_complete: b.is_complete,
    })) || []

  // Fetch latest recovery score (if exists)
  const { data: recoveryData } = await adminClient
    .from('wt_recovery_scores')
    .select('score')
    .eq('profile_id', profileId)
    .order('date', { ascending: false })
    .limit(1)
    .single()

  const recovery_score = recoveryData?.score || null

  // Apply context override if provided
  const context: ContextSnapshot = {
    profile,
    recent_metrics,
    active_plan,
    recent_meals,
    supplement_adherence,
    ai_memory,
    baselines,
    recovery_score,
  }

  if (contextOverride) {
    return { ...context, ...contextOverride }
  }

  return context
}

function aggregateMetrics(metricsData: any[]): MetricSummary[] {
  const metricGroups = new Map<string, any[]>()

  for (const m of metricsData) {
    if (!metricGroups.has(m.metric_type)) {
      metricGroups.set(m.metric_type, [])
    }
    metricGroups.get(m.metric_type)!.push(m)
  }

  const summaries: MetricSummary[] = []

  for (const [metric_type, values] of metricGroups.entries()) {
    const numericValues = values
      .map((v) => v.value_num)
      .filter((v) => v !== null && v !== undefined)

    if (numericValues.length === 0) {
      summaries.push({
        metric_type,
        avg_value: null,
        latest_value: null,
        unit: values[0]?.unit || '',
        trend: 'insufficient_data',
      })
      continue
    }

    const avg_value =
      numericValues.reduce((sum, val) => sum + val, 0) / numericValues.length
    const latest_value = numericValues[0]

    // Simple trend calculation: compare first half vs second half
    const halfPoint = Math.floor(numericValues.length / 2)
    const firstHalfAvg =
      numericValues.slice(0, halfPoint).reduce((sum, val) => sum + val, 0) /
      halfPoint
    const secondHalfAvg =
      numericValues.slice(halfPoint).reduce((sum, val) => sum + val, 0) /
      (numericValues.length - halfPoint)

    let trend: 'improving' | 'stable' | 'declining' | 'insufficient_data' =
      'stable'
    if (numericValues.length >= 4) {
      const diff = secondHalfAvg - firstHalfAvg
      const threshold = avg_value * 0.05 // 5% threshold
      if (diff > threshold) {
        trend = 'improving'
      } else if (diff < -threshold) {
        trend = 'declining'
      }
    } else {
      trend = 'insufficient_data'
    }

    summaries.push({
      metric_type,
      avg_value,
      latest_value,
      unit: values[0]?.unit || '',
      trend,
    })
  }

  return summaries
}
