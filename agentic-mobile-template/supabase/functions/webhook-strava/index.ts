import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'

/**
 * Strava Webhook Handler
 *
 * Handles two types of requests:
 * 1. GET: Subscription verification (echo back hub.challenge)
 * 2. POST: Event notifications (queue to wt_webhook_events)
 *
 * CRITICAL: POST requests NEVER process data inline.
 * Queue events and return 200 immediately.
 *
 * Event types:
 * - create: New activity created
 * - update: Activity updated
 * - delete: Activity deleted
 * - deauthorization: User revoked access
 *
 * For activity events, POST only contains object_id.
 * Full activity details must be fetched via Strava API during processing.
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const url = new URL(req.url)

  // GET: Subscription verification
  if (req.method === 'GET') {
    const mode = url.searchParams.get('hub.mode')
    const token = url.searchParams.get('hub.verify_token')
    const challenge = url.searchParams.get('hub.challenge')

    console.log('[Strava Webhook] Verification request:', { mode, token })

    // Verify the verify_token matches our configured token
    const expectedToken = Deno.env.get('STRAVA_VERIFY_TOKEN') || 'WELLTRACK_STRAVA_2026'

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      console.log('[Strava Webhook] Verification successful')
      return new Response(
        JSON.stringify({ 'hub.challenge': challenge }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      console.error('[Strava Webhook] Verification failed')
      return new Response('Forbidden', { status: 403 })
    }
  }

  // POST: Event notification
  if (req.method === 'POST') {
    try {
      const { adminClient } = createSupabaseClient(req)

      const payload = await req.json()

      console.log('[Strava Webhook] Received event:', {
        objectType: payload?.object_type,
        aspectType: payload?.aspect_type,
        objectId: payload?.object_id,
        ownerId: payload?.owner_id,
      })

      const eventType = payload?.aspect_type || 'unknown' // create, update, delete
      const objectType = payload?.object_type || 'unknown' // activity, athlete
      const objectId = payload?.object_id?.toString() || null
      const ownerId = payload?.owner_id?.toString() || null // Strava athlete ID

      let userId: string | null = null

      // Resolve Strava athlete ID to auth user via wt_health_connections
      if (ownerId) {
        const { data: connection } = await adminClient
          .from('wt_health_connections')
          .select('profile_id, wt_profiles!inner(user_id)')
          .eq('provider', 'strava')
          .eq('connection_metadata->>athlete_id', ownerId)
          .single()

        if (connection) {
          userId = (connection as any).wt_profiles?.user_id || null
          console.log(`[Strava Webhook] Resolved to WellTrack userId: ${userId}`)
        } else {
          console.warn(`[Strava Webhook] No connection found for Strava athlete ID: ${ownerId}`)
        }
      }

      // Queue the event — NEVER process inline
      // For activity events, we'll need to fetch full details during processing
      const { error } = await adminClient
        .from('wt_webhook_events')
        .insert({
          source: 'strava',
          event_type: `${objectType}_${eventType}`, // e.g., activity_create
          payload: payload,
          user_id: userId,
          strava_athlete_id: ownerId,
          strava_object_id: objectId,
          status: 'pending',
          attempts: 0,
          max_attempts: 5,
          received_at: new Date().toISOString(),
        })

      if (error) {
        console.error('[Strava Webhook] Failed to queue webhook event:', error)
        // Still return 200 to prevent Strava from retrying
      } else {
        console.log(`[Strava Webhook] Successfully queued ${objectType}_${eventType} event`)
      }

      // CRITICAL: Return 200 immediately
      return new Response(
        JSON.stringify({ status: 'received' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (err) {
      console.error('[Strava Webhook] Webhook error:', err)
      // Return 200 even on error — Strava may disable endpoint on repeated failures
      return new Response(
        JSON.stringify({ status: 'received' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }

  // Unknown method
  return new Response('Method Not Allowed', { status: 405 })
})
