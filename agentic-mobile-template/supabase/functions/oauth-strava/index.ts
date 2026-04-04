import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'

/**
 * Strava OAuth 2.0 Token Exchange + Disconnect
 *
 * GET — Strava webhook subscription verification.
 *   Strava sends hub.mode, hub.verify_token and hub.challenge to confirm
 *   the endpoint is live when registering or renewing a push subscription.
 *   The webhook-strava function already handles this, but this endpoint
 *   supports it as well so a single registered callback URL can cover both
 *   use-cases (subscription verification + token exchange).
 *
 * POST — Authorization code exchange.
 *   Body: { authorization_code: string, profile_id: string }
 *   The Flutter client sends the short-lived code obtained after the user
 *   completes Strava's consent screen. This function exchanges it for
 *   access + refresh tokens, extracts the athlete ID from Strava's response,
 *   persists tokens to wt_health_connections, and fires a non-blocking
 *   backfill for the last 14 days of Strava activity data.
 *   Returns: { status: 'connected', athlete_id: number }
 *
 * DELETE — Disconnect / revoke.
 *   Body: { profile_id: string }
 *   Calls Strava's deauthorize endpoint with the stored access token, then
 *   sets is_connected = false, clears token columns, and records
 *   disconnected_at in connection_metadata.
 *   Returns: { status: 'disconnected' }
 *
 * Required Supabase secrets:
 *   STRAVA_CLIENT_ID
 *   STRAVA_CLIENT_SECRET
 *   STRAVA_VERIFY_TOKEN   (for GET verification — same value as webhook-strava)
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ---------------------------------------------------------------------------
  // GET — Strava OAuth callback redirect OR webhook subscription verification
  // ---------------------------------------------------------------------------
  if (req.method === 'GET') {
    const url = new URL(req.url)

    // --- OAuth callback redirect ---
    // Strava redirects the user here after consent. We forward the code and
    // state to the app's custom scheme so the deep link handler picks it up.
    const code = url.searchParams.get('code')
    if (code) {
      const state = url.searchParams.get('state') ?? ''
      const scope = url.searchParams.get('scope') ?? ''
      const appRedirect = `welltrack://oauth/strava/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}&scope=${encodeURIComponent(scope)}`
      console.log('[OAuth Strava] Redirecting to app deep link:', appRedirect)
      return new Response(null, {
        status: 302,
        headers: { ...corsHeaders, 'Location': appRedirect },
      })
    }

    // --- Webhook subscription verification ---
    const mode = url.searchParams.get('hub.mode')
    const token = url.searchParams.get('hub.verify_token')
    const challenge = url.searchParams.get('hub.challenge')

    console.log('[OAuth Strava] Webhook verification request:', { mode, token })

    const expectedToken = Deno.env.get('STRAVA_VERIFY_TOKEN')
    if (!expectedToken) {
      console.error('[OAuth Strava] STRAVA_VERIFY_TOKEN not configured')
      return new Response('Server misconfigured', { status: 500 })
    }

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      console.log('[OAuth Strava] Webhook verification successful')
      return new Response(
        JSON.stringify({ 'hub.challenge': challenge }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.error('[OAuth Strava] Webhook verification failed — token mismatch or missing params')
    return new Response('Forbidden', { status: 403, headers: corsHeaders })
  }

  // ---------------------------------------------------------------------------
  // POST — Authorization code exchange
  // ---------------------------------------------------------------------------
  if (req.method === 'POST') {
    try {
      // --- Parse and validate request body ---
      let body: { authorization_code?: string; profile_id?: string }

      try {
        body = await req.json()
      } catch {
        return new Response(
          JSON.stringify({ error: 'Invalid JSON body' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { authorization_code, profile_id } = body

      if (!authorization_code || !profile_id) {
        return new Response(
          JSON.stringify({ error: 'authorization_code and profile_id are required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Read Strava credentials from environment ---
      const stravaClientId = Deno.env.get('STRAVA_CLIENT_ID')
      const stravaClientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')

      if (!stravaClientId || !stravaClientSecret) {
        console.error('[OAuth Strava] STRAVA_CLIENT_ID or STRAVA_CLIENT_SECRET not configured')
        return new Response(
          JSON.stringify({ error: 'Server configuration error' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Exchange authorization_code for tokens at Strava's token endpoint ---
      console.log('[OAuth Strava] Exchanging authorization code for tokens')

      const tokenRequestBody = new URLSearchParams({
        client_id: stravaClientId,
        client_secret: stravaClientSecret,
        code: authorization_code,
        grant_type: 'authorization_code',
      })

      const tokenResponse = await fetch('https://www.strava.com/oauth/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: tokenRequestBody.toString(),
      })

      if (!tokenResponse.ok) {
        const errorText = await tokenResponse.text()
        console.error('[OAuth Strava] Token exchange failed:', tokenResponse.status, errorText)
        return new Response(
          JSON.stringify({ error: 'Strava token exchange failed', detail: errorText }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const tokenData = await tokenResponse.json()

      const accessToken: string = tokenData.access_token
      const refreshToken: string = tokenData.refresh_token
      // Strava returns expires_at as UNIX timestamp (seconds)
      const tokenExpiresAt = new Date((tokenData.expires_at ?? Math.floor(Date.now() / 1000) + 3600) * 1000).toISOString()
      // The athlete object is included in the authorization_code exchange response
      const athleteId: number = tokenData.athlete?.id

      if (!accessToken || !refreshToken) {
        console.error('[OAuth Strava] Token response missing access_token or refresh_token')
        return new Response(
          JSON.stringify({ error: 'Incomplete token response from Strava' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      if (!athleteId) {
        console.error('[OAuth Strava] Token response missing athlete.id')
        return new Response(
          JSON.stringify({ error: 'Strava response did not include athlete ID' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Strava] Tokens received. Strava athlete ID:', athleteId)

      // --- Persist tokens to wt_health_connections ---
      const { adminClient } = createSupabaseClient(req)

      const connectionRecord = {
        profile_id: profile_id,
        provider: 'strava',
        is_connected: true,
        access_token_encrypted: accessToken,
        refresh_token_encrypted: refreshToken,
        token_expires_at: tokenExpiresAt,
        connection_metadata: {
          athlete_id: athleteId.toString(),
          athlete_firstname: tokenData.athlete?.firstname ?? null,
          athlete_lastname: tokenData.athlete?.lastname ?? null,
          connected_at: new Date().toISOString(),
        },
      }

      // Use upsert on (profile_id, provider) to handle reconnects gracefully
      const { error: upsertError } = await adminClient
        .from('wt_health_connections')
        .upsert(connectionRecord, { onConflict: 'profile_id,provider' })

      if (upsertError) {
        console.error('[OAuth Strava] Failed to persist connection:', upsertError)
        return new Response(
          JSON.stringify({ error: 'Failed to save connection', detail: upsertError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Strava] Connection saved for profile:', profile_id)

      // --- Fire-and-forget backfill for the last 14 days ---
      // We deliberately do NOT await this — the connect response must return
      // immediately. The backfill function handles its own rate-limit guard so
      // it is safe to call on every (re-)connect.
      triggerBackfill(profile_id, 'strava').catch((err) => {
        console.warn('[OAuth Strava] Backfill trigger failed (non-fatal):', err)
      })

      return new Response(
        JSON.stringify({ status: 'connected', athlete_id: athleteId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (err) {
      console.error('[OAuth Strava] Unhandled error:', err)
      return new Response(
        JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE — Disconnect and Strava deauthorize
  // ---------------------------------------------------------------------------
  if (req.method === 'DELETE') {
    try {
      // --- Parse and validate request body ---
      let body: { profile_id?: string }

      try {
        body = await req.json()
      } catch {
        return new Response(
          JSON.stringify({ error: 'Invalid JSON body' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { profile_id } = body

      if (!profile_id) {
        return new Response(
          JSON.stringify({ error: 'profile_id is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { adminClient } = createSupabaseClient(req)

      // --- Fetch the current access token so we can call Strava's deauthorize ---
      const { data: connection, error: fetchError } = await adminClient
        .from('wt_health_connections')
        .select('access_token_encrypted, connection_metadata')
        .eq('profile_id', profile_id)
        .eq('provider', 'strava')
        .single()

      if (fetchError && fetchError.code !== 'PGRST116') {
        // PGRST116 = row not found — that is fine, nothing to disconnect
        console.error('[OAuth Strava] Failed to fetch connection for disconnect:', fetchError)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch connection', detail: fetchError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Call Strava deauthorize endpoint ---
      // Per Strava API docs: POST https://www.strava.com/oauth/deauthorize
      // with access_token in the body. We treat failure as non-fatal so the
      // local disconnect always completes regardless of Strava's response.
      if (connection?.access_token_encrypted) {
        try {
          const deauthBody = new URLSearchParams({
            access_token: connection.access_token_encrypted,
          })

          const deauthResponse = await fetch('https://www.strava.com/oauth/deauthorize', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: deauthBody.toString(),
          })

          if (deauthResponse.ok) {
            console.log('[OAuth Strava] Strava deauthorize succeeded')
          } else {
            const deauthText = await deauthResponse.text()
            console.warn(
              '[OAuth Strava] Strava deauthorize returned non-OK (best-effort, continuing):',
              deauthResponse.status,
              deauthText
            )
          }
        } catch (deauthErr) {
          // Non-fatal — always complete the local disconnect below
          console.warn('[OAuth Strava] Strava deauthorize threw (best-effort, continuing):', deauthErr)
        }
      } else {
        console.log('[OAuth Strava] No access token stored — skipping Strava deauthorize call')
      }

      // --- Mark connection as disconnected and clear tokens ---
      // Preserve existing metadata fields while adding disconnected_at.
      const existingMeta: Record<string, unknown> =
        typeof connection?.connection_metadata === 'object' && connection?.connection_metadata !== null
          ? (connection.connection_metadata as Record<string, unknown>)
          : {}

      const { error: updateError } = await adminClient
        .from('wt_health_connections')
        .update({
          is_connected: false,
          access_token_encrypted: null,
          refresh_token_encrypted: null,
          connection_metadata: {
            ...existingMeta,
            disconnected_at: new Date().toISOString(),
          },
        })
        .eq('profile_id', profile_id)
        .eq('provider', 'strava')

      if (updateError) {
        console.error('[OAuth Strava] Failed to update connection on disconnect:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to disconnect', detail: updateError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Strava] Disconnected profile:', profile_id)

      return new Response(
        JSON.stringify({ status: 'disconnected' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (err) {
      console.error('[OAuth Strava] Unhandled error in DELETE handler:', err)
      return new Response(
        JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }

  // Unknown method
  return new Response('Method Not Allowed', { status: 405, headers: corsHeaders })
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Invoke the backfill-health-data Edge Function in a fire-and-forget manner.
 * The function URL is derived from the same SUPABASE_URL env var already
 * available to all Edge Functions.
 */
async function triggerBackfill(profileId: string, provider: 'garmin' | 'strava'): Promise<void> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !serviceRoleKey) {
    console.warn('[OAuth Strava] Cannot trigger backfill — SUPABASE_URL or SERVICE_ROLE_KEY not set')
    return
  }

  const backfillUrl = `${supabaseUrl}/functions/v1/backfill-health-data`

  console.log(`[OAuth Strava] Triggering backfill for profile=${profileId} provider=${provider}`)

  const response = await fetch(backfillUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${serviceRoleKey}`,
      'apikey': serviceRoleKey,
    },
    body: JSON.stringify({ profile_id: profileId, provider }),
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(`Backfill HTTP ${response.status}: ${text}`)
  }

  console.log(`[OAuth Strava] Backfill triggered successfully for profile=${profileId}`)
}
