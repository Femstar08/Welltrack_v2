import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { encode as base64UrlEncode } from 'https://deno.land/std@0.208.0/encoding/base64url.ts'

/**
 * Garmin OAuth 2.0 PKCE Token Exchange + Disconnect
 *
 * POST action: 'initiate'
 *   Generates a PKCE code_verifier + code_challenge, stores the verifier
 *   server-side keyed by profile_id, and returns the full authorization URL
 *   (including code_challenge) for the client to open in a browser.
 *
 * POST (default) — Authorization code exchange
 *   Body: { authorization_code, redirect_uri, profile_id }
 *   Retrieves the stored code_verifier, exchanges the code at Garmin's
 *   token endpoint with PKCE, upserts tokens to wt_health_connections,
 *   and fires a non-blocking backfill.
 *   Returns: { status: 'connected', garmin_user_id: string }
 *
 * GET — OAuth callback redirect
 *   Garmin redirects the user here after consent. We forward the code
 *   and state to the app's custom scheme via 302 redirect.
 *
 * DELETE — Disconnect / revoke
 *   Body: { profile_id }
 *   Returns: { status: 'disconnected' }
 *
 * Required Supabase secrets:
 *   GARMIN_CLIENT_ID
 *   GARMIN_CLIENT_SECRET
 *
 * Garmin OAuth 2.0 PKCE endpoints (per official docs):
 *   Authorize: https://connect.garmin.com/oauth2Confirm
 *   Token:     https://diauth.garmin.com/di-oauth2-service/oauth/token
 */

// ---------------------------------------------------------------------------
// PKCE helpers
// ---------------------------------------------------------------------------

/** Generates a cryptographically random code_verifier (43–128 chars, A-Z a-z 0-9 -._~) */
function generateCodeVerifier(): string {
  const array = new Uint8Array(48) // 48 bytes → 64 base64url chars
  crypto.getRandomValues(array)
  return base64UrlEncode(array)
}

/** Creates a SHA-256 code_challenge from the code_verifier */
async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return base64UrlEncode(new Uint8Array(digest))
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ---------------------------------------------------------------------------
  // GET — Garmin OAuth callback redirect (browser → app deep link)
  // ---------------------------------------------------------------------------
  if (req.method === 'GET') {
    const url = new URL(req.url)
    const code = url.searchParams.get('code')
    if (code) {
      const state = url.searchParams.get('state') ?? ''
      const appRedirect = `welltrack://oauth/garmin/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`
      console.log('[OAuth Garmin] Redirecting to app deep link:', appRedirect)
      return new Response(null, {
        status: 302,
        headers: { ...corsHeaders, 'Location': appRedirect },
      })
    }
    return new Response('Bad Request — missing code parameter', { status: 400, headers: corsHeaders })
  }

  // ---------------------------------------------------------------------------
  // POST — Initiate (get auth URL with PKCE) or Authorization code exchange
  // ---------------------------------------------------------------------------
  if (req.method === 'POST') {
    try {
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

      // --- Initiate action: generate PKCE and return OAuth 2.0 authorization URL ---
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

        // Generate PKCE code_verifier and code_challenge
        const codeVerifier = generateCodeVerifier()
        const codeChallenge = await generateCodeChallenge(codeVerifier)

        // Store code_verifier server-side for later token exchange
        const { adminClient } = createSupabaseClient(req)
        const { error: storeError } = await adminClient
          .from('wt_health_connections')
          .upsert({
            profile_id: profile_id,
            provider: 'garmin',
            is_connected: false,
            connection_metadata: {
              pkce_code_verifier: codeVerifier,
              initiated_at: new Date().toISOString(),
            },
          }, { onConflict: 'profile_id,provider' })

        if (storeError) {
          console.error('[OAuth Garmin] Failed to store PKCE verifier:', storeError)
          return new Response(
            JSON.stringify({ error: 'Failed to initiate OAuth' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        // Use the Edge Function URL as redirect so Garmin can redirect via HTTPS,
        // then we 302 to the app's custom scheme (same pattern as Strava)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const garminRedirectUri = `${supabaseUrl}/functions/v1/oauth-garmin`

        // Build OAuth 2.0 PKCE authorization URL per Garmin docs
        const params = new URLSearchParams({
          client_id: garminClientId,
          response_type: 'code',
          code_challenge: codeChallenge,
          code_challenge_method: 'S256',
          redirect_uri: garminRedirectUri,
        })

        const authUrl = `https://connect.garmin.com/oauth2Confirm?${params.toString()}`
        console.log('[OAuth Garmin] Initiate: returning auth URL for profile:', profile_id)

        return new Response(
          JSON.stringify({ oauth_token: authUrl }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Connect action (default POST): exchange authorization code for tokens ---
      if (!authorization_code || !profile_id) {
        return new Response(
          JSON.stringify({ error: 'authorization_code and profile_id are required' }),
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

      // --- Retrieve stored PKCE code_verifier ---
      const { adminClient } = createSupabaseClient(req)
      const { data: storedConn, error: fetchVerifierErr } = await adminClient
        .from('wt_health_connections')
        .select('connection_metadata')
        .eq('profile_id', profile_id)
        .eq('provider', 'garmin')
        .single()

      if (fetchVerifierErr || !storedConn?.connection_metadata?.pkce_code_verifier) {
        console.error('[OAuth Garmin] No PKCE code_verifier found for profile:', profile_id)
        return new Response(
          JSON.stringify({ error: 'OAuth session expired — please try connecting again' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const codeVerifier = storedConn.connection_metadata.pkce_code_verifier as string

      // --- Use the same redirect_uri that was sent during initiation ---
      const supabaseUrl = Deno.env.get('SUPABASE_URL')
      const garminRedirectUri = redirect_uri || `${supabaseUrl}/functions/v1/oauth-garmin`

      // --- Exchange authorization_code for tokens at Garmin's token endpoint ---
      console.log('[OAuth Garmin] Exchanging authorization code for tokens (PKCE)')

      const tokenRequestBody = new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorization_code,
        code_verifier: codeVerifier,
        client_id: garminClientId,
        client_secret: garminClientSecret,
        redirect_uri: garminRedirectUri,
      })

      const tokenResponse = await fetch('https://diauth.garmin.com/di-oauth2-service/oauth/token', {
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
      const expiresIn: number = tokenData.expires_in ?? 86400
      const tokenExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()

      if (!accessToken || !refreshToken) {
        console.error('[OAuth Garmin] Token response missing access_token or refresh_token')
        return new Response(
          JSON.stringify({ error: 'Incomplete token response from Garmin' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // --- Fetch Garmin User ID via the permissions/user ID endpoint ---
      let garminUserId = ''
      try {
        const userIdResponse = await fetch('https://apis.garmin.com/wellness-api/rest/user/id', {
          headers: { 'Authorization': `Bearer ${accessToken}` },
        })
        if (userIdResponse.ok) {
          const userIdData = await userIdResponse.json()
          garminUserId = userIdData.userId?.toString() ?? ''
        }
      } catch (e) {
        console.warn('[OAuth Garmin] Failed to fetch Garmin user ID (non-fatal):', e)
      }

      console.log('[OAuth Garmin] Tokens received. Garmin user ID:', garminUserId)

      // --- Persist tokens to wt_health_connections ---
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

      const { data: connection, error: fetchError } = await adminClient
        .from('wt_health_connections')
        .select('access_token_encrypted, connection_metadata')
        .eq('profile_id', profile_id)
        .eq('provider', 'garmin')
        .single()

      if (fetchError && fetchError.code !== 'PGRST116') {
        console.error('[OAuth Garmin] Failed to fetch connection for disconnect:', fetchError)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch connection', detail: fetchError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Best-effort deregistration per Garmin docs (required for compliance)
      if (connection?.access_token_encrypted) {
        try {
          const revokeResponse = await fetch(
            'https://apis.garmin.com/wellness-api/rest/user/registration',
            {
              method: 'DELETE',
              headers: {
                'Authorization': `Bearer ${connection.access_token_encrypted}`,
              },
            }
          )
          if (revokeResponse.ok) {
            console.log('[OAuth Garmin] User deregistration succeeded')
          } else {
            const revokeText = await revokeResponse.text()
            console.warn('[OAuth Garmin] Deregistration returned non-OK (best-effort):', revokeResponse.status, revokeText)
          }
        } catch (revokeErr) {
          console.warn('[OAuth Garmin] Deregistration threw (best-effort):', revokeErr)
        }
      }

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
            pkce_code_verifier: undefined, // Clean up PKCE state
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
