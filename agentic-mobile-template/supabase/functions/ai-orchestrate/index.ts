import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'
import {
  OrchestrateRequest,
  OrchestrateResponse,
  SafetyFlag,
  DBWrite,
  UsageInfo,
} from '../_shared/types.ts'
import { buildContextSnapshot } from '../_shared/context-builder.ts'
import { getToolConfig } from '../_shared/tool-registry.ts'
import { validateSafety, hasBlockingFlags } from '../_shared/safety-validator.ts'

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')
const DRY_RUN_MODE = Deno.env.get('WT_AI_DRY_RUN') === 'true'

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    // Step 1: Parse and validate request
    const body = await req.json()
    const request = body as OrchestrateRequest

    if (!request.user_id || !request.profile_id) {
      return new Response(
        JSON.stringify({ error: 'user_id and profile_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 2: Create Supabase clients
    const { adminClient, userClient } = createSupabaseClient(req)

    // Verify JWT and user authorization
    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser()

    if (authError || !user || user.id !== request.user_id) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 3: Check rate limits
    // check_ai_limit(p_user_id, p_calls, p_tokens) returns boolean
    const { data: limitAllowed, error: limitError } = await adminClient.rpc(
      'check_ai_limit',
      {
        p_user_id: request.user_id,
        p_calls: 1,
        p_tokens: 0,
      }
    )

    if (limitError) {
      console.error('Rate limit check error:', limitError)
    }

    if (limitAllowed === false) {
      return new Response(
        JSON.stringify({
          error: 'AI usage limit exceeded',
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 4: Build context snapshot
    const context = await buildContextSnapshot(
      adminClient,
      request.user_id,
      request.profile_id,
      request.context_override
    )

    // Step 5: Get tool configuration
    const toolConfig = getToolConfig(request.workflow_type)

    // Step 6: Build system prompt
    const systemPrompt = buildSystemPrompt(context, toolConfig.system_prompt_additions)

    // Step 7: Call OpenAI API with timeout
    if (!OPENAI_API_KEY) {
      throw new Error('OPENAI_API_KEY environment variable is not set')
    }

    const abortController = new AbortController()
    const timeoutId = setTimeout(() => abortController.abort(), 45_000)

    let openaiResponse: Response
    try {
      openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: request.message || 'Generate response based on workflow type' },
          ],
          max_tokens: toolConfig.max_tokens,
          temperature: toolConfig.temperature,
        }),
        signal: abortController.signal,
      })
    } catch (fetchError) {
      clearTimeout(timeoutId)
      if (fetchError.name === 'AbortError') {
        return new Response(
          JSON.stringify({ error: 'OpenAI request timed out', fallback: true }),
          { status: 504, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      throw fetchError
    } finally {
      clearTimeout(timeoutId)
    }

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text()
      console.error('OpenAI API error:', errorText)
      throw new Error(`OpenAI API error: ${openaiResponse.statusText}`)
    }

    const openaiData = await openaiResponse.json()

    // Validate OpenAI response structure
    if (
      !openaiData.choices ||
      openaiData.choices.length === 0 ||
      !openaiData.choices[0]?.message?.content
    ) {
      return new Response(
        JSON.stringify({
          error: 'OpenAI returned empty or malformed response',
          fallback: true,
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const assistantMessage = openaiData.choices[0].message.content
    const tokensUsed = openaiData.usage?.total_tokens || 0

    // Step 8: Parse response
    const { dbWrites, suggestedActions, updatedForecast } = parseAssistantResponse(
      assistantMessage,
      request.workflow_type
    )

    // Step 9: Safety validation
    const safetyFlags = validateSafety(assistantMessage, dbWrites)

    if (hasBlockingFlags(safetyFlags)) {
      return new Response(
        JSON.stringify({
          error: 'Response blocked due to safety concerns',
          safety_flags: safetyFlags,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 10: Execute DB writes (if not dry run and no blocking flags)
    if (!DRY_RUN_MODE && dbWrites.length > 0) {
      for (const write of dbWrites) {
        write.dry_run = false
        try {
          if (write.operation === 'insert') {
            await adminClient.from(write.table).insert(write.data)
          } else if (write.operation === 'update') {
            const { id, ...updateData } = write.data
            await adminClient.from(write.table).update(updateData).eq('id', id)
          } else if (write.operation === 'upsert') {
            await adminClient.from(write.table).upsert(write.data)
          }
        } catch (error) {
          console.error(`DB write error for ${write.table}:`, error)
          safetyFlags.push({
            type: 'unsafe_value',
            message: `Failed to execute DB write to ${write.table}: ${error.message}`,
            blocked: false,
          })
        }
      }
    } else {
      dbWrites.forEach((w) => (w.dry_run = true))
    }

    const durationMs = Date.now() - startTime

    // Step 11: Increment usage tracking (fault-tolerant)
    try {
      await adminClient.rpc('increment_ai_usage', {
        p_user_id: request.user_id,
        p_profile_id: request.profile_id,
        p_tokens: tokensUsed,
      })
    } catch (usageError) {
      console.error('Usage tracking failed (non-fatal):', usageError)
    }

    // Step 12: Audit logging (fault-tolerant)
    try {
      await adminClient.from('wt_ai_audit_log').insert({
        user_id: request.user_id,
        profile_id: request.profile_id,
        tool_called: request.workflow_type || 'general_chat',
        input_summary: request.message?.substring(0, 500) || null,
        output_summary: assistantMessage.substring(0, 500),
        tokens_consumed: tokensUsed,
        duration_ms: durationMs,
        safety_flags: safetyFlags.length > 0 ? safetyFlags : [],
      })
    } catch (auditError) {
      console.error('Audit logging failed (non-fatal):', auditError)
    }

    // Step 13: Build usage info
    const usage: UsageInfo = {
      calls_used: 1,
      calls_limit: 0,
      tokens_used: tokensUsed,
      tokens_limit: 0,
    }

    // Step 14: Return response
    const response: OrchestrateResponse = {
      assistant_message: assistantMessage,
      suggested_actions: suggestedActions,
      db_writes: dbWrites,
      updated_forecast: updatedForecast,
      safety_flags: safetyFlags,
      usage,
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('AI Orchestrator error:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error.message,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

function buildSystemPrompt(context: any, toolSpecificAdditions: string): string {
  // Build vitality context only if consent was given and data exists
  let vitalityBlock = ''
  if (context.vitality_data) {
    const v = context.vitality_data
    vitalityBlock = `
Vitality Indicators (consent granted):
- Morning erection: ${v.days_with_morning_erection}/${v.total_days_tracked} days tracked
- Weekly quality score: ${v.latest_erection_quality_weekly ?? 'Not reported'}
- Feeling trend: ${v.feeling_trend ?? 'Insufficient data'}
Note: Treat these as physiological recovery indicators. Never sexualise.`
  }

  // Build bloodwork context only if consent was given and data exists
  let bloodworkBlock = ''
  if (context.bloodwork_results && context.bloodwork_results.length > 0) {
    const outOfRange = context.bloodwork_results.filter((b: any) => b.is_out_of_range)
    bloodworkBlock = `
Bloodwork Results (consent granted, ${context.bloodwork_results.length} tests on file):
${outOfRange.length > 0 ? `- Out of range: ${outOfRange.map((b: any) => `${b.test_name}: ${b.value_num} ${b.unit}`).join(', ')}` : '- All results within reference ranges'}
Note: Always recommend consulting a healthcare professional for out-of-range values.`
  }

  return `SYSTEM ROLE

You are the WellTrack Intelligence Engine.

Your role is to analyse wellness, fitness, and lifestyle data and generate supportive insights that help users train consistently and improve their overall performance.

Your responses must always follow these principles:
1. Suggestive, never prescriptive — use "you might consider", "based on your data", "this suggests"
2. Wellness guidance only, never medical diagnosis
3. Evidence-informed but conservative
4. Data-driven when possible — reference the user's actual numbers
5. Simple and actionable for everyday users

---

SAFETY RULES

- NEVER diagnose medical conditions.
- NEVER prescribe medication, hormone therapy, or specific supplement dosages.
- NEVER claim to treat, cure, or prevent diseases.
- When interpreting biomarkers or bloodwork, always say:
  "This value is outside the typical reference range. Consider discussing this with a qualified healthcare professional."
- NEVER provide explicit sexual content.
- Morning vitality metrics are physiological indicators of recovery and hormonal health — treat them clinically.
- If the user describes acute symptoms (chest pain, dizziness, breathing difficulty), respond:
  "This sounds like it needs immediate attention. Please contact a healthcare professional or emergency services."

---

DATA CONTEXT

Profile: ${context.profile.display_name}, ${context.profile.age || 'age unknown'}, ${context.profile.gender || 'gender unspecified'}
Height: ${context.profile.height_cm ? context.profile.height_cm + ' cm' : 'Unknown'} | Weight: ${context.profile.weight_kg ? context.profile.weight_kg + ' kg' : 'Unknown'}
Activity Level: ${context.profile.activity_level || 'Not specified'}
Plan Tier: ${context.profile.plan_tier}
Fitness Goals: ${context.profile.fitness_goals || 'Not specified'}
Dietary Restrictions: ${context.profile.dietary_restrictions || 'None'}
Allergies: ${context.profile.allergies || 'None'}
Preferred Ingredients: ${context.profile.preferred_ingredients?.join(', ') || 'None'}
Excluded Ingredients: ${context.profile.excluded_ingredients?.join(', ') || 'None'}

Recent Metrics (7 days):
${context.recent_metrics.length > 0 ? context.recent_metrics.map((m: any) => `- ${m.metric_type}: avg ${m.avg_value?.toFixed(1) ?? '?'} ${m.unit}, latest ${m.latest_value ?? '?'}, trend: ${m.trend}`).join('\n') : 'No metrics available'}

Active Plan: ${context.active_plan ? `${context.active_plan.title} (${context.active_plan.completion_pct}% complete)` : 'None'}

Recent Meals (3 days):
${context.recent_meals.length > 0 ? context.recent_meals.slice(0, 5).map((m: any) => `- ${m.date} ${m.meal_type}: ${m.name} (${m.calories || '?'} cal)`).join('\n') : 'No meals logged'}

Supplement Adherence: ${(context.supplement_adherence * 100).toFixed(0)}%
Recovery Score: ${context.recovery_score ?? 'Not available'}
Baselines: ${context.baselines?.filter((b: any) => b.is_complete).length ?? 0} calibrated metrics
${vitalityBlock}${bloodworkBlock}

User Preferences (AI Memory):
${context.ai_memory.filter((m: any) => m.memory_type === 'preference').slice(0, 5).map((m: any) => `- ${m.memory_key}: ${JSON.stringify(m.memory_value)}`).join('\n') || 'No stored preferences'}

---

INGREDIENT RULES

- ALWAYS prioritise preferred ingredients when generating meal plans, recipes, or shopping lists.
- NEVER use excluded ingredients under any circumstance.
- NEVER include foods that match stated allergies.

---

RESPONSE STYLE

Tone: Friendly, motivating, calm, professional. Never alarmist.
Language: Use "you might consider", "based on your signals", "many athletes find that".
NEVER use: "you should", "you must", "you need to", "you have to".

---

OUTPUT FORMAT

Return structured JSON following the schema defined by the calling workflow.
Do NOT wrap JSON in markdown code fences unless the workflow explicitly requests it.
All numeric values must be integers or floats — never strings.
All date values must be ISO 8601 format (YYYY-MM-DD).

---

${toolSpecificAdditions}
`
}

function parseAssistantResponse(
  message: string,
  workflowType?: string
): {
  dbWrites: DBWrite[]
  suggestedActions: any[]
  updatedForecast: any
} {
  const dbWrites: DBWrite[] = []
  const suggestedActions: any[] = []
  let updatedForecast = undefined

  // --- generate_daily_plan: expects bare JSON { focus_tip, narrative } ---
  if (workflowType === 'generate_daily_plan') {
    try {
      // Try parsing entire message as JSON first
      const parsed = JSON.parse(message.trim())
      if (
        typeof parsed.focus_tip === 'string' &&
        typeof parsed.narrative === 'string'
      ) {
        // Valid — no DB writes needed; the Flutter client reads assistant_message directly
        return { dbWrites, suggestedActions, updatedForecast }
      }
    } catch (_) {
      // Fall through to code block extraction
    }

    // Try extracting from a JSON code block
    const blockMatch = /```json\n([\s\S]*?)\n```/.exec(message)
    if (blockMatch) {
      try {
        const parsed = JSON.parse(blockMatch[1])
        if (
          typeof parsed.focus_tip === 'string' &&
          typeof parsed.narrative === 'string'
        ) {
          return { dbWrites, suggestedActions, updatedForecast }
        }
      } catch (_) {
        // ignore — fallback handled by Flutter client (isFallback = true)
      }
    }

    return { dbWrites, suggestedActions, updatedForecast }
  }

  // Try parsing entire message as bare JSON first (preferred format)
  let parsedBareJson: any = null
  try {
    parsedBareJson = JSON.parse(message.trim())
  } catch (_) {
    // Not bare JSON — fall through to code block extraction
  }

  // Extract JSON from response — either bare JSON or code-fenced blocks
  const jsonCandidates: any[] = []
  if (parsedBareJson) {
    jsonCandidates.push(parsedBareJson)
  }

  // Also check for code-fenced JSON blocks (backward compatibility)
  const jsonBlockRegex = /```json\n([\s\S]*?)\n```/g
  let match
  while ((match = jsonBlockRegex.exec(message)) !== null) {
    try {
      jsonCandidates.push(JSON.parse(match[1]))
    } catch (_) {
      // Skip malformed blocks
    }
  }

  for (const jsonData of jsonCandidates) {
    try {
      // Parse based on workflow type
      // Support both new and legacy schemas for each workflow

      if (workflowType === 'generate_weekly_plan') {
        // New schema: { week_plan: [...], weekly_summary: {...} }
        // Legacy: { days: [...], plan_title, ... }
        const planData = jsonData.week_plan || jsonData.days
        if (planData) {
          const title = jsonData.weekly_summary?.primary_focus || jsonData.plan_title || 'Weekly Plan'
          dbWrites.push({
            table: 'wt_plans',
            operation: 'insert',
            data: {
              title,
              status: 'recommended',
              plan_data: jsonData,
            },
            dry_run: true,
          })
        }
      } else if (workflowType === 'generate_pantry_recipes') {
        // New schema: { recipes: [...] }
        // Legacy: top-level array
        const recipes = jsonData.recipes || (Array.isArray(jsonData) ? jsonData : null)
        if (recipes) {
          recipes.forEach((recipe: any) => {
            suggestedActions.push({
              action_type: 'view_recipe',
              label: recipe.name,
              payload: recipe,
            })
          })
        }
      } else if (workflowType === 'summarize_insights') {
        // New schema: { insights: [{title, explanation, suggestion}] }
        // Legacy: { summary, recommendations: [{action, rationale}] }
        if (jsonData.insights && Array.isArray(jsonData.insights)) {
          jsonData.insights.forEach((insight: any) => {
            if (insight.suggestion) {
              suggestedActions.push({
                action_type: 'apply_recommendation',
                label: insight.suggestion,
                payload: insight,
              })
            }
          })
        } else if (jsonData.recommendations) {
          jsonData.recommendations.forEach((rec: any) => {
            suggestedActions.push({
              action_type: 'apply_recommendation',
              label: rec.action,
              payload: rec,
            })
          })
        }
      } else if (workflowType === 'generate_shopping_list') {
        // New schema: { shopping_list: { produce: [], protein: [], ... } }
        // Legacy: { items: [{ingredient_name, ...}] }
        if (jsonData.shopping_list && typeof jsonData.shopping_list === 'object') {
          for (const [aisle, items] of Object.entries(jsonData.shopping_list)) {
            if (Array.isArray(items)) {
              (items as string[]).forEach((item: string) => {
                suggestedActions.push({
                  action_type: 'add_shopping_item',
                  label: item,
                  payload: { ingredient_name: item, aisle },
                })
              })
            }
          }
        } else if (jsonData.items) {
          jsonData.items.forEach((item: any) => {
            suggestedActions.push({
              action_type: 'add_shopping_item',
              label: item.ingredient_name,
              payload: item,
            })
          })
        }
      }
      // Add more workflow-specific parsing as needed
    } catch (e) {
      console.error('Failed to parse JSON data:', e)
    }
  }

  return { dbWrites, suggestedActions, updatedForecast }
}
