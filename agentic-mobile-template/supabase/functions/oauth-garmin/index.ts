import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'

/**
 * Garmin OAuth 2.0 Token Exchange + Disconnect
 *
 * POST — Authorization code exchange
 *   Body: { authorization_code: string, redirect_uri: string, profile_id: string }
 *   1. Exchanges the code at Garmin's token endpoint
 *   2. Upserts a row in wt_health_connections with encrypted tokens
 *   3. Fires a non-blocking backfill for the last 14 days of Garmin data
 *   Returns: { status: 'connected', garmin_user_id: string }
 *
 * DELETE — Disconnect / revoke
 *   Body: { profile_id: string }
 *   1. Best-effort token revocation with Garmin API (never fails the request)
 *   2. Sets is_connected = false, clears token columns, records disconnected_at
 *   Returns: { status: 'disconnected' }
 *
 * Required Supabase secrets:
 *   GARMIN_CLIENT_ID
 *   GARMIN_CLIENT_SECRET
 *
 * NOTE: Tokens are stored in the columns `access_token_encrypted` and
 * `refresh_token_encrypted`. Encryption at rest is the responsibility of
 * the database-level security policy; the "encrypted" suffix signals intent
 * to ops so the columns are never exposed through RLS to the Flutter client.
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ---------------------------------------------------------------------------
  // POST — Initiate (get auth URL) or Authorization code exchange
  // ---------------------------------------------------------------------------
  if (req.method === 'POST') {
    try {
      // --- Parse and validate request body ---
      let body: { action?: string; authorization_code?: string; redirect_uri?: string; profile_id?: string }

      try {
        body = await req.json()
      } catch {
        return new Response(
          JSON.stringify({ error: 'Invalid JSON body' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { action, authorization_code, redirect_uri, profile_id } = body

      // --- Initiate action: return OAuth 2.0 authorization URL ---
      if (action === 'initiate') {
        if (!profile_id) {
          return new Response(
            JSON.stringify({ error: 'profile_id is required' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        const garminClientId = Deno.env.get('GARMIN_CLIENT_ID')
        if (!garminClientId) {
          console.error('[OAuth Garmin] GARMIN_CLIENT_ID not configured')
          return new Response(
            JSON.stringify({ error: 'Server configuration error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        // Build OAuth 2.0 authorization URL — client_id stays server-side
        const garminRedirectUri = 'welltrack://oauth/garmin/callback'
        const params = new URLSearchParams({
          client_id: garminClientId,
          redirect_uri: garminRedirectUri,
          response_type: 'code',
          scope: 'ACTIVITY_IMPORT DAILY HEALTH_SNAPSHOT',
        })

        const authUrl = `https://connect.garmin.com/oauthConfirm?${params.toString()}`
        console.log('[OAuth Garmin] Initiate: returning auth URL for profile:', profile_id)

        return new Response(
          JSON.stringify({ oauth_token: authUrl }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Connect action (default POST): exchange authorization code for tokens ---
      if (!authorization_code || !redirect_uri || !profile_id) {
        return new Response(
          JSON.stringify({ error: 'authorization_code, redirect_uri, and profile_id are required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Read Garmin credentials from environment ---
      const garminClientId = Deno.env.get('GARMIN_CLIENT_ID')
      const garminClientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')

      if (!garminClientId || !garminClientSecret) {
        console.error('[OAuth Garmin] GARMIN_CLIENT_ID or GARMIN_CLIENT_SECRET not configured')
        return new Response(
          JSON.stringify({ error: 'Server configuration error' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Exchange authorization_code for tokens at Garmin's token endpoint ---
      console.log('[OAuth Garmin] Exchanging authorization code for tokens')

      const tokenRequestBody = new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorization_code,
        redirect_uri: redirect_uri,
        client_id: garminClientId,
        client_secret: garminClientSecret,
      })

      const tokenResponse = await fetch('https://connectapi.garmin.com/oauth-service/oauth/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: tokenRequestBody.toString(),
      })

      if (!tokenResponse.ok) {
        const errorText = await tokenResponse.text()
        console.error('[OAuth Garmin] Token exchange failed:', tokenResponse.status, errorText)
        return new Response(
          JSON.stringify({ error: 'Garmin token exchange failed', detail: errorText }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const tokenData = await tokenResponse.json()

      const accessToken: string = tokenData.access_token
      const refreshToken: string = tokenData.refresh_token
      const expiresIn: number = tokenData.expires_in ?? 3600
      // Garmin embeds the user's Garmin ID in the token response
      const garminUserId: string = tokenData.user_id?.toString() ?? tokenData.userId?.toString() ?? ''
      const tokenExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()

      if (!accessToken || !refreshToken) {
        console.error('[OAuth Garmin] Token response missing access_token or refresh_token')
        return new Response(
          JSON.stringify({ error: 'Incomplete token response from Garmin' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Garmin] Tokens received. Garmin user ID:', garminUserId)

      // --- Persist tokens to wt_health_connections ---
      const { adminClient } = createSupabaseClient(req)

      const connectionRecord = {
        profile_id: profile_id,
        provider: 'garmin',
        is_connected: true,
        access_token_encrypted: accessToken,
        refresh_token_encrypted: refreshToken,
        token_expires_at: tokenExpiresAt,
        connection_metadata: {
          garmin_user_id: garminUserId,
          connected_at: new Date().toISOString(),
        },
      }

      // Use upsert on (profile_id, provider) to handle reconnects gracefully
      const { error: upsertError } = await adminClient
        .from('wt_health_connections')
        .upsert(connectionRecord, { onConflict: 'profile_id,provider' })

      if (upsertError) {
        console.error('[OAuth Garmin] Failed to persist connection:', upsertError)
        return new Response(
          JSON.stringify({ error: 'Failed to save connection', detail: upsertError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Garmin] Connection saved for profile:', profile_id)

      // --- Fire-and-forget backfill for the last 14 days ---
      // We deliberately do NOT await this — the connect response must return
      // immediately. The backfill function handles its own rate-limit guard so
      // it is safe to call on every (re-)connect.
      triggerBackfill(profile_id, 'garmin').catch((err) => {
        console.warn('[OAuth Garmin] Backfill trigger failed (non-fatal):', err)
      })

      return new Response(
        JSON.stringify({ status: 'connected', garmin_user_id: garminUserId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (err) {
      console.error('[OAuth Garmin] Unhandled error:', err)
      return new Response(
        JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE — Disconnect and best-effort token revocation
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

      // --- Fetch the current access token so we can attempt revocation ---
      const { data: connection, error: fetchError } = await adminClient
        .from('wt_health_connections')
        .select('access_token_encrypted, connection_metadata')
        .eq('profile_id', profile_id)
        .eq('provider', 'garmin')
        .single()

      if (fetchError && fetchError.code !== 'PGRST116') {
        // PGRST116 = row not found — that is fine, nothing to disconnect
        console.error('[OAuth Garmin] Failed to fetch connection for disconnect:', fetchError)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch connection', detail: fetchError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Best-effort token revocation with Garmin ---
      // Garmin does not publish a public token revocation endpoint at this time.
      // The de-facto approach is to call Garmin Health API user deregistration.
      // We attempt this but treat any failure as non-fatal so the user is always
      // disconnected locally regardless of what Garmin's API returns.
      if (connection?.access_token_encrypted) {
        try {
          const revokeResponse = await fetch(
            'https://healthapi.garmin.com/wellness-api/rest/user/registration',
            {
              method: 'DELETE',
              headers: {
                'Authorization': `Bearer ${connection.access_token_encrypted}`,
                'Content-Type': 'application/json',
              },
            }
          )
          if (revokeResponse.ok) {
            console.log('[OAuth Garmin] Token revocation succeeded')
          } else {
            const revokeText = await revokeResponse.text()
            console.warn(
              '[OAuth Garmin] Token revocation returned non-OK (best-effort, continuing):',
              revokeResponse.status,
              revokeText
            )
          }
        } catch (revokeErr) {
          // Non-fatal — always complete the local disconnect below
          console.warn('[OAuth Garmin] Token revocation threw (best-effort, continuing):', revokeErr)
        }
      }

      // --- Mark connection as disconnected and clear tokens ---
      // Preserve existing metadata fields while adding disconnected_at so we
      // retain the garmin_user_id for audit / analytics purposes.
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
        .eq('provider', 'garmin')

      if (updateError) {
        console.error('[OAuth Garmin] Failed to update connection on disconnect:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to disconnect', detail: updateError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('[OAuth Garmin] Disconnected profile:', profile_id)

      return new Response(
        JSON.stringify({ status: 'disconnected' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } catch (err) {
      console.error('[OAuth Garmin] Unhandled error in DELETE handler:', err)
      return new Response(
        JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }

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
    console.warn('[OAuth Garmin] Cannot trigger backfill — SUPABASE_URL or SERVICE_ROLE_KEY not set')
    return
  }

  const backfillUrl = `${supabaseUrl}/functions/v1/backfill-health-data`

  console.log(`[OAuth Garmin] Triggering backfill for profile=${profileId} provider=${provider}`)

  const response = await fetch(backfillUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      // Use the service-role key so the backfill function can authenticate
      'Authorization': `Bearer ${serviceRoleKey}`,
      'apikey': serviceRoleKey,
    },
    body: JSON.stringify({ profile_id: profileId, provider }),
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(`Backfill HTTP ${response.status}: ${text}`)
  }

  console.log(`[OAuth Garmin] Backfill triggered successfully for profile=${profileId}`)
}
