import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'

/**
 * Garmin Push Webhook Handler
 *
 * CRITICAL: This function NEVER processes data inline.
 * It queues events to wt_webhook_events and returns 200 immediately.
 *
 * Garmin will disable webhooks if we don't respond within 30 seconds
 * or return non-200 status codes repeatedly.
 *
 * Supported event types:
 * - sleeps: Sleep summary data
 * - stressDetails: Stress scores (0-100)
 * - userMetrics: VO2 max, fitness age, etc.
 * - dailies: Steps, resting HR, calories, distance
 * - activities: Activity summaries
 * - epochs: Detailed epoch data
 * - moveIQ: Auto-detected activities
 * - deregistration: User revoked access
 * - user-permission: Permission changes
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { adminClient } = createSupabaseClient(req)

    // Extract event type from URL path or header
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/')
    const eventType = pathParts[pathParts.length - 1] || 'unknown'

    // Parse payload
    const payload = await req.json()

    console.log(`[Garmin Webhook] Received ${eventType} event`, {
      payloadType: Array.isArray(payload) ? 'array' : typeof payload,
      payloadLength: Array.isArray(payload) ? payload.length : 'n/a',
    })

    // Extract Garmin userId from payload (varies by event type)
    // Garmin sends arrays of summaries, each with a userId
    let garminUserId: string | null = null
    let userId: string | null = null

    // Most Garmin payloads are arrays with userId field
    if (Array.isArray(payload) && payload.length > 0) {
      garminUserId = payload[0]?.userId?.toString() || null
    } else if (payload?.userId) {
      garminUserId = payload.userId.toString()
    }

    // For deregistration events, userId is at top level
    if (eventType === 'deregistration' && payload?.userId) {
      garminUserId = payload.userId.toString()
    }

    console.log(`[Garmin Webhook] Extracted Garmin userId: ${garminUserId}`)

    // Resolve garmin userId to auth user via wt_health_connections
    if (garminUserId) {
      const { data: connection } = await adminClient
        .from('wt_health_connections')
        .select('profile_id, wt_profiles!inner(user_id)')
        .eq('provider', 'garmin')
        .eq('connection_metadata->>garmin_user_id', garminUserId)
        .single()

      if (connection) {
        userId = (connection as any).wt_profiles?.user_id || null
        console.log(`[Garmin Webhook] Resolved to WellTrack userId: ${userId}`)
      } else {
        console.warn(`[Garmin Webhook] No connection found for Garmin userId: ${garminUserId}`)
      }
    }

    // Queue the event — NEVER process inline
    const { error } = await adminClient
      .from('wt_webhook_events')
      .insert({
        source: 'garmin',
        event_type: eventType,
        payload: payload,
        user_id: userId,
        garmin_user_id: garminUserId,
        status: 'pending',
        attempts: 0,
        max_attempts: 5,
        received_at: new Date().toISOString(),
      })

    if (error) {
      console.error('[Garmin Webhook] Failed to queue webhook event:', error)
      // Still return 200 to prevent Garmin from retrying
    } else {
      console.log(`[Garmin Webhook] Successfully queued ${eventType} event`)
    }

    // CRITICAL: Return 200 within 30 seconds
    return new Response(
      JSON.stringify({ status: 'received' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('[Garmin Webhook] Webhook error:', err)
    // Return 200 even on error — Garmin will disable endpoint on repeated failures
    return new Response(
      JSON.stringify({ status: 'received' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
