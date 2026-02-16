import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { processPendingEvents } from '../_shared/webhook-processor.ts'

/**
 * Scheduled Webhook Event Processor
 *
 * This Edge Function is invoked on a schedule (e.g., every 60 seconds via pg_cron
 * or Supabase scheduled invocations).
 *
 * It picks up pending events from wt_webhook_events and processes them in batches.
 *
 * Flow:
 * 1. Fetch batch of pending events (status = 'pending', next_retry_at <= now)
 * 2. Process each event (normalize data, upsert to wt_health_metrics)
 * 3. Update event status (completed/failed/dead_letter)
 * 4. Return summary
 *
 * IMPORTANT: This function should be idempotent. If processing fails mid-batch,
 * the next invocation will retry pending events.
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  console.log('[Process Webhooks] Starting webhook processing batch')

  try {
    const { adminClient } = createSupabaseClient(req)

    // Get batch size from query param or use default
    const url = new URL(req.url)
    const batchSize = parseInt(url.searchParams.get('batch_size') || '10')

    // Process pending events
    const result = await processPendingEvents(adminClient, batchSize)

    const duration = Date.now() - startTime
    console.log(`[Process Webhooks] Completed in ${duration}ms:`, result)

    return new Response(
      JSON.stringify({
        success: true,
        processed: result.processed,
        failed: result.failed,
        duration_ms: duration,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err) {
    console.error('[Process Webhooks] Fatal error:', err)

    return new Response(
      JSON.stringify({
        success: false,
        error: err instanceof Error ? err.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
