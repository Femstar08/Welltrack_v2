import { createSupabaseClient } from '../_shared/supabase-client.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { refreshGarminToken, refreshStravaToken } from '../_shared/token-refresh.ts'
import {
  type HealthMetric,
  normalizeGarminDailiesPayload,
  normalizeGarminSleepPayload,
  normalizeGarminStressPayload,
  normalizeGarminUserMetricsPayload,
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
  // Refresh token if within 60-second expiry window
  let accessToken: string = connection.access_token_encrypted

  if (!accessToken) {
    throw new Error('[Backfill Garmin] No access token available')
  }

  const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
  const nowPlusBuffer = new Date(Date.now() + 60_000)

  if (expiresAt && expiresAt <= nowPlusBuffer) {
    if (!connection.refresh_token_encrypted) {
      throw new Error('[Backfill Garmin] Token expired and no refresh token available')
    }
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
  }

  // Build date range: today going back 14 days (inclusive)
  const today = new Date()
  const startDate = new Date(today)
  startDate.setDate(today.getDate() - 13) // 14 days including today

  const startDateStr = formatDate(startDate) // YYYY-MM-DD
  const endDateStr = formatDate(today)

  console.log(`[Backfill Garmin] Fetching data from ${startDateStr} to ${endDateStr}`)

  const allMetrics: HealthMetric[] = []

  // Garmin Health API base URL
  const garminBase = 'https://healthapi.garmin.com/wellness-api/rest'
  const authHeader = { 'Authorization': `Bearer ${accessToken}` }

  // Fetch each data type in parallel — Garmin's API supports date-range queries
  const [dailiesResult, sleepResult, stressResult, metricsResult] = await Promise.allSettled([
    fetchGarminEndpoint(`${garminBase}/dailies?startDate=${startDateStr}&endDate=${endDateStr}`, authHeader, 'dailies'),
    fetchGarminEndpoint(`${garminBase}/sleeps?startDate=${startDateStr}&endDate=${endDateStr}`, authHeader, 'sleeps'),
    fetchGarminEndpoint(`${garminBase}/stressDetails?startDate=${startDateStr}&endDate=${endDateStr}`, authHeader, 'stressDetails'),
    fetchGarminEndpoint(`${garminBase}/userMetrics?startDate=${startDateStr}&endDate=${endDateStr}`, authHeader, 'userMetrics'),
  ])

  // Normalize each result using the shared normalizer exports
  if (dailiesResult.status === 'fulfilled' && dailiesResult.value.length > 0) {
    const metrics = await normalizeGarminDailiesPayload(userId, profileId, dailiesResult.value)
    allMetrics.push(...metrics)
    console.log(`[Backfill Garmin] Normalized ${metrics.length} dailies metrics`)
  }

  if (sleepResult.status === 'fulfilled' && sleepResult.value.length > 0) {
    const metrics = await normalizeGarminSleepPayload(userId, profileId, sleepResult.value)
    allMetrics.push(...metrics)
    console.log(`[Backfill Garmin] Normalized ${metrics.length} sleep metrics`)
  }

  if (stressResult.status === 'fulfilled' && stressResult.value.length > 0) {
    const metrics = await normalizeGarminStressPayload(userId, profileId, stressResult.value)
    allMetrics.push(...metrics)
    console.log(`[Backfill Garmin] Normalized ${metrics.length} stress metrics`)
  }

  if (metricsResult.status === 'fulfilled' && metricsResult.value.length > 0) {
    const metrics = await normalizeGarminUserMetricsPayload(userId, profileId, metricsResult.value)
    allMetrics.push(...metrics)
    console.log(`[Backfill Garmin] Normalized ${metrics.length} userMetrics`)
  }

  // Log any failures from the parallel fetches (non-fatal — partial backfill is better than none)
  for (const [name, result] of [
    ['dailies', dailiesResult],
    ['sleeps', sleepResult],
    ['stressDetails', stressResult],
    ['userMetrics', metricsResult],
  ] as [string, PromiseSettledResult<any>][]) {
    if (result.status === 'rejected') {
      console.warn(`[Backfill Garmin] ${name} fetch failed (continuing):`, result.reason)
    }
  }

  // Upsert all metrics to wt_health_metrics with dedupe_hash conflict handling
  return upsertMetrics(adminClient, allMetrics)
}

/**
 * Fetch a single Garmin Health API endpoint.
 * Returns the parsed JSON array or throws on HTTP error.
 */
async function fetchGarminEndpoint(
  url: string,
  headers: Record<string, string>,
  label: string
): Promise<any[]> {
  const response = await fetch(url, { headers })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(`[Backfill Garmin] ${label} HTTP ${response.status}: ${text}`)
  }

  const data = await response.json()

  // Garmin wraps array responses in a top-level key that varies by endpoint.
  // Try common wrapper keys; fall back to treating the response as the array.
  const wrapperKeys: Record<string, string> = {
    dailies: 'dailies',
    sleeps: 'sleeps',
    stressDetails: 'stressDetails',
    userMetrics: 'userMetrics',
  }

  const key = wrapperKeys[label]
  if (key && Array.isArray(data[key])) {
    return data[key]
  }

  // Some endpoints return the array at the top level
  return Array.isArray(data) ? data : []
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
  // Refresh token if within 60-second expiry window
  let accessToken: string = connection.access_token_encrypted

  if (!accessToken) {
    throw new Error('[Backfill Strava] No access token available')
  }

  const expiresAt = connection.token_expires_at ? new Date(connection.token_expires_at) : null
  const nowPlusBuffer = new Date(Date.now() + 60_000)

  if (expiresAt && expiresAt <= nowPlusBuffer) {
    if (!connection.refresh_token_encrypted) {
      throw new Error('[Backfill Strava] Token expired and no refresh token available')
    }
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
 * Format a Date as YYYY-MM-DD (Garmin API date format).
 */
function formatDate(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
