import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { refreshGarminToken, refreshStravaToken } from '../_shared/token-refresh.ts'
import {
  type HealthMetric,
  normalizeStravaActivityPayload,
} from '../_shared/webhook-processor.ts'

/**
 * Backfill Health Data
 *
 * Fetches the last 14 days of health data from Garmin or Strava on demand.
 * Designed to be called immediately after a successful OAuth connect so that
 * users see populated charts without waiting for the next scheduled webhook.
 *
 * POST body (JSON):
 *   { provider: 'garmin' | 'strava', profile_id: string }
 *
 * Rate-limit guard: rejects requests where last_sync_at on the connection
 * row is less than 24 hours ago (HTTP 429). This prevents duplicate heavy
 * backfills if the function is called multiple times in quick succession.
 * On a fresh connect last_sync_at is NULL so the guard is always bypassed.
 *
 * On success returns:
 *   { status: 'complete', metrics_count: number }
 *
 * On rate-limit:
 *   { status: 'rate_limited', last_sync_at: string, next_allowed_at: string }
 *
 * Required Supabase secrets (same as oauth-garmin / oauth-strava):
 *   GARMIN_CLIENT_ID, GARMIN_CLIENT_SECRET
 *   STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders })
  }

  try {
    // -----------------------------------------------------------------------
    // Parse and validate request body
    // -----------------------------------------------------------------------
    let body: { provider?: string; profile_id?: string }

    try {
      body = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { provider, profile_id } = body

    if (!provider || !profile_id) {
      return new Response(
        JSON.stringify({ error: 'provider and profile_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (provider !== 'garmin' && provider !== 'strava') {
      return new Response(
        JSON.stringify({ error: 'provider must be "garmin" or "strava"' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { adminClient } = createSupabaseClient(req)

    // -----------------------------------------------------------------------
    // Load connection row — includes rate-limit check and token retrieval
    // -----------------------------------------------------------------------
    const { data: connection, error: connError } = await adminClient
      .from('wt_health_connections')
      .select('access_token_encrypted, refresh_token_encrypted, token_expires_at, last_sync_at, connection_metadata')
      .eq('profile_id', profile_id)
      .eq('provider', provider)
      .eq('is_connected', true)
      .single()

    if (connError || !connection) {
      console.error('[Backfill] No active connection found:', connError)
      return new Response(
        JSON.stringify({ error: 'No active connection found for this profile and provider' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // -----------------------------------------------------------------------
    // Rate-limit guard: skip if synced within the last 24 hours
    // -----------------------------------------------------------------------
    if (connection.last_sync_at) {
      const lastSync = new Date(connection.last_sync_at)
      const hoursSinceSync = (Date.now() - lastSync.getTime()) / (1000 * 60 * 60)

      if (hoursSinceSync < 24) {
        const nextAllowedAt = new Date(lastSync.getTime() + 24 * 60 * 60 * 1000).toISOString()
        console.log(
          `[Backfill] Rate limited — last sync was ${hoursSinceSync.toFixed(1)}h ago. Next allowed: ${nextAllowedAt}`
        )
        return new Response(
          JSON.stringify({
            status: 'rate_limited',
            last_sync_at: connection.last_sync_at,
            next_allowed_at: nextAllowedAt,
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // -----------------------------------------------------------------------
    // Resolve user_id from profile
    // -----------------------------------------------------------------------
    const { data: profileRow, error: profileError } = await adminClient
      .from('wt_profiles')
      .select('user_id')
      .eq('id', profile_id)
      .single()

    if (profileError || !profileRow?.user_id) {
      console.error('[Backfill] Failed to resolve user_id from profile:', profileError)
      return new Response(
        JSON.stringify({ error: 'Failed to resolve user_id for profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId: string = profileRow.user_id

    // -----------------------------------------------------------------------
    // Run provider-specific backfill
    // -----------------------------------------------------------------------
    let metricsCount = 0

    if (provider === 'garmin') {
      metricsCount = await backfillGarmin(adminClient, connection, userId, profile_id)
    } else {
      metricsCount = await backfillStrava(adminClient, connection, userId, profile_id)
    }

    // -----------------------------------------------------------------------
    // Update last_sync_at on the connection row
    // -----------------------------------------------------------------------
    const { error: syncUpdateError } = await adminClient
      .from('wt_health_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('profile_id', profile_id)
      .eq('provider', provider)

    if (syncUpdateError) {
      // Non-fatal — the metrics were already written; just log the failure
      console.warn('[Backfill] Failed to update last_sync_at:', syncUpdateError)
    }

    console.log(`[Backfill] Completed. provider=${provider} profile=${profile_id} metrics=${metricsCount}`)

    return new Response(
      JSON.stringify({ status: 'complete', metrics_count: metricsCount }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('[Backfill] Unhandled error:', err)
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ---------------------------------------------------------------------------
// Garmin backfill — 14-day dailies, sleep, stress, userMetrics
// ---------------------------------------------------------------------------

async function backfillGarmin(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  // deno-lint-ignore no-explicit-any
  connection: any,
  userId: string,
  profileId: string
): Promise<number> {
  // Refresh token if within 600-second expiry window (per Garmin recommendation)
  let accessToken: string = connection.access_token_encrypted

  if (!accessToken) {
    throw new Error('[Backfill Garmin] No access token available')
  }

  const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
  const nowPlusBuffer = new Date(Date.now() + 600_000) // 10 min buffer per Garmin docs

  if (expiresAt && expiresAt <= nowPlusBuffer) {
    if (!connection.refresh_token_encrypted) {
      await markConnectionNeedsReauth(adminClient, profileId, 'garmin')
      throw new Error('[Backfill Garmin] Token expired and no refresh token available')
    }
    try {
      console.log('[Backfill Garmin] Access token expired — refreshing')
      const refreshed = await refreshGarminToken(connection.refresh_token_encrypted)
      accessToken = refreshed.accessToken

      // Persist refreshed tokens
      await adminClient
        .from('wt_health_connections')
        .update({
          access_token_encrypted: refreshed.accessToken,
          refresh_token_encrypted: refreshed.refreshToken,
          token_expires_at: refreshed.expiresAt,
        })
        .eq('profile_id', profileId)
        .eq('provider', 'garmin')

      console.log('[Backfill Garmin] Tokens refreshed and persisted')
    } catch (refreshErr) {
      console.error('[Backfill Garmin] Token refresh failed:', refreshErr)
      await markConnectionNeedsReauth(adminClient, profileId, 'garmin')
      throw refreshErr
    }
  }

  // Build time range: 14 days back from now (Unix timestamps in seconds)
  const nowEpoch = Math.floor(Date.now() / 1000)
  const startEpoch = nowEpoch - (14 * 24 * 60 * 60)

  console.log(`[Backfill Garmin] Requesting async backfill from ${startEpoch} to ${nowEpoch}`)

  // Garmin Health API base URL (per official docs)
  const garminBase = 'https://apis.garmin.com/wellness-api/rest'
  const authHeader = { 'Authorization': `Bearer ${accessToken}` }

  // Use Garmin's official Backfill API endpoints (per Health API v1.2.0, Section 8).
  // These return HTTP 202 immediately and process asynchronously — actual data
  // arrives via Push/Ping webhooks to our webhook-garmin endpoint.
  const backfillEndpoints = [
    'backfill/dailies',
    'backfill/sleeps',
    'backfill/stressDetails',
    'backfill/userMetrics',
  ]

  const queryParams = `summaryStartTimeInSeconds=${startEpoch}&summaryEndTimeInSeconds=${nowEpoch}`

  const results = await Promise.allSettled(
    backfillEndpoints.map((endpoint) =>
      requestGarminBackfill(`${garminBase}/${endpoint}?${queryParams}`, authHeader, endpoint)
    )
  )

  // Count successful backfill requests (HTTP 202 = accepted)
  let acceptedCount = 0
  for (const [i, result] of results.entries()) {
    const endpoint = backfillEndpoints[i]
    if (result.status === 'fulfilled') {
      acceptedCount++
      console.log(`[Backfill Garmin] ${endpoint}: accepted (202)`)
    } else {
      console.warn(`[Backfill Garmin] ${endpoint} request failed:`, result.reason)
    }
  }

  console.log(`[Backfill Garmin] ${acceptedCount}/${backfillEndpoints.length} backfill requests accepted`)

  // Return the count of accepted requests. Actual data will arrive via webhooks.
  // The webhook handler (webhook-garmin) queues events to wt_webhook_events,
  // and process-webhooks normalizes and upserts to wt_health_metrics.
  return acceptedCount
}

/**
 * Request an async backfill from Garmin's Backfill API.
 *
 * Per Garmin Health API v1.2.0 Section 8:
 * - Returns HTTP 202 (accepted) on success — data arrives via Push/Ping webhooks
 * - Returns HTTP 409 if a duplicate backfill request is already in progress
 * - Returns HTTP 429 if rate-limited (100 days/min for eval keys)
 *
 * Throws on unexpected errors.
 */
async function requestGarminBackfill(
  url: string,
  headers: Record<string, string>,
  label: string
): Promise<void> {
  const response = await fetch(url, { method: 'GET', headers })

  if (response.status === 202) {
    // Success — backfill accepted, data will arrive via webhooks
    return
  }

  if (response.status === 409) {
    // Duplicate request — a backfill for this range is already in progress
    console.log(`[Backfill Garmin] ${label}: duplicate request (409) — already in progress`)
    return
  }

  if (response.status === 429) {
    const text = await response.text()
    console.warn(`[Backfill Garmin] ${label}: rate-limited (429) — ${text}`)
    throw new Error(`Rate limited by Garmin for ${label}`)
  }

  const text = await response.text()
  throw new Error(`[Backfill Garmin] ${label} HTTP ${response.status}: ${text}`)
}

// ---------------------------------------------------------------------------
// Strava backfill — 14-day activities
// ---------------------------------------------------------------------------

async function backfillStrava(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  // deno-lint-ignore no-explicit-any
  connection: any,
  userId: string,
  profileId: string
): Promise<number> {
  // Refresh token if within 600-second expiry window
  let accessToken: string = connection.access_token_encrypted

  if (!accessToken) {
    throw new Error('[Backfill Strava] No access token available')
  }

  const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
  const nowPlusBuffer = new Date(Date.now() + 600_000) // 10 min buffer

  if (expiresAt && expiresAt <= nowPlusBuffer) {
    if (!connection.refresh_token_encrypted) {
      await markConnectionNeedsReauth(adminClient, profileId, 'strava')
      throw new Error('[Backfill Strava] Token expired and no refresh token available')
    }
    try {
      console.log('[Backfill Strava] Access token expired — refreshing')
      const refreshed = await refreshStravaToken(connection.refresh_token_encrypted)
      accessToken = refreshed.accessToken

      // Persist refreshed tokens — Strava ALWAYS rotates on refresh
      await adminClient
        .from('wt_health_connections')
        .update({
          access_token_encrypted: refreshed.accessToken,
          refresh_token_encrypted: refreshed.refreshToken,
          token_expires_at: refreshed.expiresAt,
        })
        .eq('profile_id', profileId)
        .eq('provider', 'strava')

      console.log('[Backfill Strava] Tokens refreshed and persisted')
    } catch (refreshErr) {
      console.error('[Backfill Strava] Token refresh failed:', refreshErr)
      await markConnectionNeedsReauth(adminClient, profileId, 'strava')
      throw refreshErr
    }
  }

  // Epoch timestamp 14 days ago (Strava uses UNIX seconds for the after param)
  const fourteenDaysAgoEpoch = Math.floor((Date.now() - 14 * 24 * 60 * 60 * 1000) / 1000)

  console.log(`[Backfill Strava] Fetching activities after epoch ${fourteenDaysAgoEpoch}`)

  // Strava paginates at 200 items max per page — we fetch pages until empty
  const allActivities: any[] = []
  let page = 1
  const perPage = 100 // conservative page size to stay within rate limits

  while (true) {
    const url =
      `https://www.strava.com/api/v3/athlete/activities?after=${fourteenDaysAgoEpoch}&page=${page}&per_page=${perPage}`

    const response = await fetch(url, {
      headers: { 'Authorization': `Bearer ${accessToken}` },
    })

    if (!response.ok) {
      const text = await response.text()
      // Non-fatal for pagination errors after the first page — partial is fine
      if (page > 1) {
        console.warn(`[Backfill Strava] Page ${page} fetch failed (using partial result):`, response.status, text)
        break
      }
      throw new Error(`[Backfill Strava] Activities fetch HTTP ${response.status}: ${text}`)
    }

    const activities = await response.json()

    if (!Array.isArray(activities) || activities.length === 0) {
      // No more pages
      break
    }

    allActivities.push(...activities)
    console.log(`[Backfill Strava] Page ${page}: fetched ${activities.length} activities`)

    if (activities.length < perPage) {
      // Last page
      break
    }

    page++
  }

  console.log(`[Backfill Strava] Total activities fetched: ${allActivities.length}`)

  const allMetrics: HealthMetric[] = []

  for (const activity of allActivities) {
    const metrics = await normalizeStravaActivityPayload(userId, profileId, activity)
    allMetrics.push(...metrics)
  }

  console.log(`[Backfill Strava] Normalized ${allMetrics.length} metrics from ${allActivities.length} activities`)

  return upsertMetrics(adminClient, allMetrics)
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/**
 * Upsert a batch of HealthMetric rows to wt_health_metrics.
 * Uses dedupe_hash as the conflict target — safe for re-runs.
 * Returns the count of metrics processed (not the count actually inserted,
 * since upserts on existing rows are no-ops for dedup purposes).
 */
// deno-lint-ignore no-explicit-any
async function upsertMetrics(adminClient: any, metrics: HealthMetric[]): Promise<number> {
  if (metrics.length === 0) return 0

  let successCount = 0
  let errorCount = 0

  // Batch in groups of 50 to avoid oversized request payloads
  const batchSize = 50

  for (let i = 0; i < metrics.length; i += batchSize) {
    const batch = metrics.slice(i, i + batchSize)

    const { error } = await adminClient
      .from('wt_health_metrics')
      .upsert(batch, { onConflict: 'dedupe_hash' })

    if (error) {
      console.error(`[Backfill] Batch upsert error (rows ${i}–${i + batch.length - 1}):`, error)
      errorCount += batch.length
    } else {
      successCount += batch.length
    }
  }

  if (errorCount > 0) {
    console.warn(`[Backfill] ${errorCount} metrics failed to upsert, ${successCount} succeeded`)
  }

  return successCount
}

/**
 * Mark a connection as needing re-authorization after a token refresh failure.
 * Sets is_connected = false so the UI prompts the user to reconnect.
 */
async function markConnectionNeedsReauth(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  profileId: string,
  provider: 'garmin' | 'strava'
): Promise<void> {
  console.warn(`[Backfill] Marking ${provider} connection as needing re-auth for profile ${profileId}`)

  const { error } = await adminClient
    .from('wt_health_connections')
    .update({
      is_connected: false,
      connection_metadata: {
        needs_reauth: true,
        reauth_reason: 'token_refresh_failed',
        reauth_at: new Date().toISOString(),
      },
    })
    .eq('profile_id', profileId)
    .eq('provider', provider)

  if (error) {
    console.error(`[Backfill] Failed to mark ${provider} connection for re-auth:`, error)
  }
}

