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
  return `You are WellTrack AI, a performance optimization assistant.

CORE IDENTITY:
- You help users optimize their wellness through data-driven insights
- You are suggestive, never prescriptive
- You use phrases like "You might consider...", "Based on your data...", "This suggests..."
- You are encouraging, supportive, and realistic

MEDICAL DISCLAIMER:
- NEVER make medical diagnoses, treatment recommendations, or health claims
- NEVER prescribe specific dosages or medications
- If user describes concerning symptoms, suggest consulting a healthcare professional
- You provide general wellness suggestions only

USER CONTEXT:
Profile: ${context.profile.display_name}, ${context.profile.age || 'age unknown'}, ${context.profile.gender || 'gender unspecified'}
Plan Tier: ${context.profile.plan_tier}
Fitness Goals: ${context.profile.fitness_goals || 'Not specified'}
Dietary Restrictions: ${context.profile.dietary_restrictions || 'None'}
Allergies: ${context.profile.allergies || 'None'}
Preferred Ingredients: ${context.profile.preferred_ingredients?.join(', ') || 'None'}
Excluded Ingredients: ${context.profile.excluded_ingredients?.join(', ') || 'None'}

INGREDIENT RULES:
- ALWAYS prioritize preferred ingredients when generating meal plans, recipes, or shopping lists.
- NEVER use excluded ingredients in any meal plan, recipe, or shopping list.

RECENT METRICS (Last 7 days):
${context.recent_metrics.map((m: any) => `- ${m.metric_type}: avg ${m.avg_value} ${m.unit}, trend: ${m.trend}`).join('\n') || 'No metrics available'}

ACTIVE PLAN:
${context.active_plan ? `${context.active_plan.title} (${context.active_plan.completion_pct}% complete)` : 'No active plan'}

RECENT MEALS (Last 3 days):
${context.recent_meals.slice(0, 5).map((m: any) => `- ${m.date} ${m.meal_type}: ${m.name} (${m.calories || '?'} cal)`).join('\n') || 'No meals logged'}

SUPPLEMENT ADHERENCE: ${(context.supplement_adherence * 100).toFixed(0)}%

RECOVERY SCORE: ${context.recovery_score || 'Not available'}

AI MEMORY (User Preferences):
${context.ai_memory.filter((m: any) => m.memory_type === 'preference').slice(0, 3).map((m: any) => `- ${m.memory_key}: ${JSON.stringify(m.memory_value)}`).join('\n') || 'No stored preferences'}

${toolSpecificAdditions}

RESPONSE FORMAT:
Your response should be conversational and helpful. If you are generating structured data (plans, recipes, recommendations), include a JSON code block in your response with the appropriate structure as specified in the tool instructions.

Always be encouraging and focus on small, achievable steps.
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

  // Extract JSON blocks from response
  const jsonBlockRegex = /```json\n([\s\S]*?)\n```/g
  let match

  while ((match = jsonBlockRegex.exec(message)) !== null) {
    try {
      const jsonData = JSON.parse(match[1])

      // Parse based on workflow type
      if (workflowType === 'generate_weekly_plan' && jsonData.days) {
        // Convert plan to DB writes
        dbWrites.push({
          table: 'wt_plans',
          operation: 'insert',
          data: {
            title: jsonData.plan_title,
            status: 'recommended',
            plan_data: jsonData,
          },
          dry_run: true,
        })

        if (jsonData.expected_goal_date) {
          updatedForecast = {
            goal_id: '', // Will be set by app
            new_expected_date: jsonData.expected_goal_date,
            confidence: jsonData.confidence || 0.5,
            explanation: jsonData.rationale || '',
          }
        }
      } else if (workflowType === 'generate_pantry_recipes' && Array.isArray(jsonData)) {
        // Recipes array - convert to suggested actions
        jsonData.forEach((recipe: any) => {
          suggestedActions.push({
            action_type: 'view_recipe',
            label: recipe.name,
            payload: recipe,
          })
        })
      } else if (workflowType === 'summarize_insights' && jsonData.recommendations) {
        jsonData.recommendations.forEach((rec: any) => {
          suggestedActions.push({
            action_type: 'apply_recommendation',
            label: rec.action,
            payload: rec,
          })
        })
      } else if (workflowType === 'generate_shopping_list' && jsonData.items) {
        // Shopping list items - convert to suggested actions
        jsonData.items.forEach((item: any) => {
          suggestedActions.push({
            action_type: 'add_shopping_item',
            label: item.ingredient_name,
            payload: item,
          })
        })
      }
      // Add more workflow-specific parsing as needed
    } catch (e) {
      console.error('Failed to parse JSON block:', e)
    }
  }

  return { dbWrites, suggestedActions, updatedForecast }
}
