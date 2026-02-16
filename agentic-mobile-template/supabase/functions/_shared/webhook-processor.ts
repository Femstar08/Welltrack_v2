import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { encodeHex } from 'https://deno.land/std@0.224.0/encoding/hex.ts'

/**
 * Webhook Event Processor
 *
 * Processes pending webhook events from wt_webhook_events table.
 * Called by scheduled Edge Function (process-webhooks).
 *
 * Processing flow:
 * 1. Pick up events WHERE status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= now())
 * 2. Process by event_type and source
 * 3. Normalize data and upsert to wt_health_metrics with deduplication
 * 4. Update event status: 'completed', 'failed', or 'dead_letter'
 * 5. On failure: exponential backoff retry
 */

interface WebhookEvent {
  id: string
  source: 'garmin' | 'strava'
  event_type: string
  payload: any
  user_id: string | null
  profile_id?: string | null
  garmin_user_id?: string | null
  strava_athlete_id?: string | null
  strava_object_id?: string | null
  attempts: number
  max_attempts: number
}

interface HealthMetric {
  user_id: string
  profile_id: string
  source: string
  metric_type: string
  value_num: number | null
  value_text: string | null
  unit: string | null
  start_time: string | null
  end_time: string | null
  recorded_at: string
  raw_payload_json: any
  dedupe_hash: string
}

/**
 * Process a batch of pending webhook events
 */
export async function processPendingEvents(
  adminClient: SupabaseClient,
  batchSize: number = 10
): Promise<{ processed: number; failed: number }> {
  // Fetch pending events
  const { data: events, error: fetchError } = await adminClient
    .from('wt_webhook_events')
    .select('*')
    .eq('status', 'pending')
    .or('next_retry_at.is.null,next_retry_at.lte.' + new Date().toISOString())
    .limit(batchSize)

  if (fetchError) {
    console.error('[Webhook Processor] Failed to fetch events:', fetchError)
    return { processed: 0, failed: 0 }
  }

  if (!events || events.length === 0) {
    console.log('[Webhook Processor] No pending events')
    return { processed: 0, failed: 0 }
  }

  console.log(`[Webhook Processor] Processing ${events.length} events`)

  let processed = 0
  let failed = 0

  for (const event of events) {
    try {
      await processEvent(adminClient, event as WebhookEvent)
      processed++
    } catch (err) {
      console.error(`[Webhook Processor] Failed to process event ${event.id}:`, err)
      failed++
    }
  }

  return { processed, failed }
}

/**
 * Process a single webhook event
 */
async function processEvent(
  adminClient: SupabaseClient,
  event: WebhookEvent
): Promise<void> {
  console.log(`[Webhook Processor] Processing ${event.source}/${event.event_type} (ID: ${event.id})`)

  try {
    // Resolve profile_id if not present
    let profileId = event.profile_id
    if (!profileId && event.user_id) {
      const { data: profile } = await adminClient
        .from('wt_profiles')
        .select('id')
        .eq('user_id', event.user_id)
        .eq('is_parent', true)
        .single()

      profileId = profile?.id || null
    }

    if (!event.user_id || !profileId) {
      console.warn(`[Webhook Processor] Event ${event.id} has no user_id or profile_id, skipping`)
      await markEventCompleted(adminClient, event.id)
      return
    }

    // Process by source and event type
    let metrics: HealthMetric[] = []

    if (event.source === 'garmin') {
      metrics = await processGarminEvent(event, profileId)
    } else if (event.source === 'strava') {
      metrics = await processStravaEvent(adminClient, event, profileId)
    }

    // Upsert metrics to wt_health_metrics
    if (metrics.length > 0) {
      for (const metric of metrics) {
        const { error: upsertError } = await adminClient
          .from('wt_health_metrics')
          .upsert(metric, { onConflict: 'dedupe_hash' })

        if (upsertError) {
          console.error(`[Webhook Processor] Failed to upsert metric:`, upsertError)
        }
      }
      console.log(`[Webhook Processor] Upserted ${metrics.length} metrics`)
    }

    // Handle special event types
    if (event.event_type === 'deregistration' && event.source === 'garmin') {
      await handleGarminDeregistration(adminClient, event.garmin_user_id)
    }

    // Mark event as completed
    await markEventCompleted(adminClient, event.id)
  } catch (err) {
    // Mark event as failed and schedule retry
    await markEventFailed(adminClient, event)
    throw err
  }
}

/**
 * Process Garmin webhook event
 */
async function processGarminEvent(
  event: WebhookEvent,
  profileId: string
): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []

  switch (event.event_type) {
    case 'sleeps':
      metrics.push(...await normalizeGarminSleep(event, profileId))
      break
    case 'stressDetails':
      metrics.push(...await normalizeGarminStress(event, profileId))
      break
    case 'userMetrics':
      metrics.push(...await normalizeGarminUserMetrics(event, profileId))
      break
    case 'dailies':
      metrics.push(...await normalizeGarminDailies(event, profileId))
      break
    case 'activities':
      metrics.push(...await normalizeGarminActivities(event, profileId))
      break
    default:
      console.log(`[Webhook Processor] Unhandled Garmin event type: ${event.event_type}`)
  }

  return metrics
}

/**
 * Process Strava webhook event
 */
async function processStravaEvent(
  adminClient: SupabaseClient,
  event: WebhookEvent,
  profileId: string
): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []

  if (event.event_type === 'activity_create' || event.event_type === 'activity_update') {
    // Fetch full activity details from Strava API
    const activityId = event.strava_object_id
    if (!activityId) {
      console.warn('[Webhook Processor] Strava event missing object_id')
      return metrics
    }

    // Get access token from wt_health_connections
    const { data: connection } = await adminClient
      .from('wt_health_connections')
      .select('access_token')
      .eq('provider', 'strava')
      .eq('connection_metadata->>athlete_id', event.strava_athlete_id)
      .single()

    if (!connection?.access_token) {
      console.warn('[Webhook Processor] No Strava access token found')
      return metrics
    }

    // Fetch activity from Strava API
    const activityData = await fetchStravaActivity(activityId, connection.access_token)
    if (activityData) {
      metrics.push(...await normalizeStravaActivity(event, profileId, activityData))
    }
  } else if (event.event_type === 'athlete_deauthorization') {
    await handleStravaDeauthorization(adminClient, event.strava_athlete_id)
  }

  return metrics
}

/**
 * Normalize Garmin sleep data
 */
async function normalizeGarminSleep(event: WebhookEvent, profileId: string): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []
  const payload = event.payload

  if (!Array.isArray(payload)) return metrics

  for (const sleep of payload) {
    const startTime = sleep.calendarDate + 'T' + (sleep.sleepStartTimestampGMT || '00:00:00')
    const endTime = sleep.calendarDate + 'T' + (sleep.sleepEndTimestampGMT || '00:00:00')
    const durationSeconds = sleep.sleepTimeSeconds || 0

    metrics.push({
      user_id: event.user_id!,
      profile_id: profileId,
      source: 'garmin',
      metric_type: 'sleep',
      value_num: durationSeconds / 60, // Convert to minutes
      value_text: null,
      unit: 'minutes',
      start_time: startTime,
      end_time: endTime,
      recorded_at: new Date().toISOString(),
      raw_payload_json: sleep,
      dedupe_hash: await generateDedupeHash('garmin', 'sleep', startTime, endTime),
    })

    // Extract sleep stages if available
    if (sleep.deepSleepSeconds) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'sleep_deep',
        value_num: sleep.deepSleepSeconds / 60,
        value_text: null,
        unit: 'minutes',
        start_time: startTime,
        end_time: endTime,
        recorded_at: new Date().toISOString(),
        raw_payload_json: sleep,
        dedupe_hash: await generateDedupeHash('garmin', 'sleep_deep', startTime, endTime),
      })
    }

    if (sleep.lightSleepSeconds) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'sleep_light',
        value_num: sleep.lightSleepSeconds / 60,
        value_text: null,
        unit: 'minutes',
        start_time: startTime,
        end_time: endTime,
        recorded_at: new Date().toISOString(),
        raw_payload_json: sleep,
        dedupe_hash: await generateDedupeHash('garmin', 'sleep_light', startTime, endTime),
      })
    }

    if (sleep.remSleepSeconds) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'sleep_rem',
        value_num: sleep.remSleepSeconds / 60,
        value_text: null,
        unit: 'minutes',
        start_time: startTime,
        end_time: endTime,
        recorded_at: new Date().toISOString(),
        raw_payload_json: sleep,
        dedupe_hash: await generateDedupeHash('garmin', 'sleep_rem', startTime, endTime),
      })
    }
  }

  return metrics
}

/**
 * Normalize Garmin stress data
 * CRITICAL: Stress values 0-100 are valid. Negative values are null.
 */
async function normalizeGarminStress(event: WebhookEvent, profileId: string): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []
  const payload = event.payload

  if (!Array.isArray(payload)) return metrics

  for (const stress of payload) {
    const startTime = stress.calendarDate + 'T' + (stress.startTimestampGMT || '00:00:00')
    const avgStress = stress.avgStressLevel

    // Only store valid stress values (0-100). Negative = unavailable.
    if (avgStress !== null && avgStress !== undefined && avgStress >= 0 && avgStress <= 100) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'stress',
        value_num: avgStress,
        value_text: null,
        unit: 'score',
        start_time: startTime,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: stress,
        dedupe_hash: await generateDedupeHash('garmin', 'stress', startTime, startTime),
      })
    }
  }

  return metrics
}

/**
 * Normalize Garmin user metrics (VO2 max, fitness age, etc.)
 */
async function normalizeGarminUserMetrics(event: WebhookEvent, profileId: string): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []
  const payload = event.payload

  if (!Array.isArray(payload)) return metrics

  for (const metric of payload) {
    const timestamp = metric.calendarDate + 'T12:00:00' // Use noon for daily metrics

    // VO2 Max (running)
    if (metric.vo2Max !== null && metric.vo2Max !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'vo2max',
        value_num: metric.vo2Max,
        value_text: null,
        unit: 'ml/kg/min',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: metric,
        dedupe_hash: await generateDedupeHash('garmin', 'vo2max', timestamp, timestamp),
      })
    }

    // VO2 Max (cycling)
    if (metric.vo2MaxCycling !== null && metric.vo2MaxCycling !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'vo2max_cycling',
        value_num: metric.vo2MaxCycling,
        value_text: null,
        unit: 'ml/kg/min',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: metric,
        dedupe_hash: await generateDedupeHash('garmin', 'vo2max_cycling', timestamp, timestamp),
      })
    }

    // Fitness age
    if (metric.fitnessAge !== null && metric.fitnessAge !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'fitness_age',
        value_num: metric.fitnessAge,
        value_text: null,
        unit: 'years',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: metric,
        dedupe_hash: await generateDedupeHash('garmin', 'fitness_age', timestamp, timestamp),
      })
    }
  }

  return metrics
}

/**
 * Normalize Garmin daily summaries (steps, HR, calories)
 */
async function normalizeGarminDailies(event: WebhookEvent, profileId: string): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []
  const payload = event.payload

  if (!Array.isArray(payload)) return metrics

  for (const daily of payload) {
    const timestamp = daily.calendarDate + 'T12:00:00'

    // Steps
    if (daily.totalSteps !== null && daily.totalSteps !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'steps',
        value_num: daily.totalSteps,
        value_text: null,
        unit: 'steps',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: daily,
        dedupe_hash: await generateDedupeHash('garmin', 'steps', timestamp, timestamp),
      })
    }

    // Resting heart rate
    if (daily.restingHeartRate !== null && daily.restingHeartRate !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'resting_hr',
        value_num: daily.restingHeartRate,
        value_text: null,
        unit: 'bpm',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: daily,
        dedupe_hash: await generateDedupeHash('garmin', 'resting_hr', timestamp, timestamp),
      })
    }

    // Calories
    if (daily.totalKilocalories !== null && daily.totalKilocalories !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'calories',
        value_num: daily.totalKilocalories,
        value_text: null,
        unit: 'kcal',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: daily,
        dedupe_hash: await generateDedupeHash('garmin', 'calories', timestamp, timestamp),
      })
    }

    // Distance
    if (daily.totalDistanceMeters !== null && daily.totalDistanceMeters !== undefined) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'distance',
        value_num: daily.totalDistanceMeters / 1000, // Convert to km
        value_text: null,
        unit: 'km',
        start_time: timestamp,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: daily,
        dedupe_hash: await generateDedupeHash('garmin', 'distance', timestamp, timestamp),
      })
    }
  }

  return metrics
}

/**
 * Normalize Garmin activities
 */
async function normalizeGarminActivities(event: WebhookEvent, profileId: string): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []
  const payload = event.payload

  if (!Array.isArray(payload)) return metrics

  for (const activity of payload) {
    const startTime = activity.startTimeGMT || activity.startTimeLocal
    const duration = activity.durationSeconds || 0

    if (activity.activityType && startTime) {
      metrics.push({
        user_id: event.user_id!,
        profile_id: profileId,
        source: 'garmin',
        metric_type: 'activity',
        value_num: duration / 60, // Duration in minutes
        value_text: activity.activityType,
        unit: 'minutes',
        start_time: startTime,
        end_time: null,
        recorded_at: new Date().toISOString(),
        raw_payload_json: activity,
        dedupe_hash: await generateDedupeHash('garmin', 'activity', startTime, startTime),
      })
    }
  }

  return metrics
}

/**
 * Fetch Strava activity details from API
 */
async function fetchStravaActivity(activityId: string, accessToken: string): Promise<any> {
  try {
    const response = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    })

    if (!response.ok) {
      console.error(`[Webhook Processor] Failed to fetch Strava activity ${activityId}:`, response.status)
      return null
    }

    return await response.json()
  } catch (err) {
    console.error('[Webhook Processor] Error fetching Strava activity:', err)
    return null
  }
}

/**
 * Normalize Strava activity data
 */
async function normalizeStravaActivity(
  event: WebhookEvent,
  profileId: string,
  activity: any
): Promise<HealthMetric[]> {
  const metrics: HealthMetric[] = []

  const startTime = activity.start_date
  const duration = activity.moving_time // seconds

  // Activity duration
  metrics.push({
    user_id: event.user_id!,
    profile_id: profileId,
    source: 'strava',
    metric_type: 'activity',
    value_num: duration / 60, // minutes
    value_text: activity.type || 'Unknown',
    unit: 'minutes',
    start_time: startTime,
    end_time: null,
    recorded_at: new Date().toISOString(),
    raw_payload_json: activity,
    dedupe_hash: await generateDedupeHash('strava', 'activity', startTime, startTime),
  })

  // Distance
  if (activity.distance) {
    metrics.push({
      user_id: event.user_id!,
      profile_id: profileId,
      source: 'strava',
      metric_type: 'distance',
      value_num: activity.distance / 1000, // Convert to km
      value_text: null,
      unit: 'km',
      start_time: startTime,
      end_time: null,
      recorded_at: new Date().toISOString(),
      raw_payload_json: activity,
      dedupe_hash: await generateDedupeHash('strava', 'distance', startTime, startTime),
    })
  }

  // Average heart rate
  if (activity.average_heartrate) {
    metrics.push({
      user_id: event.user_id!,
      profile_id: profileId,
      source: 'strava',
      metric_type: 'avg_hr',
      value_num: activity.average_heartrate,
      value_text: null,
      unit: 'bpm',
      start_time: startTime,
      end_time: null,
      recorded_at: new Date().toISOString(),
      raw_payload_json: activity,
      dedupe_hash: await generateDedupeHash('strava', 'avg_hr', startTime, startTime),
    })
  }

  // Calories
  if (activity.calories) {
    metrics.push({
      user_id: event.user_id!,
      profile_id: profileId,
      source: 'strava',
      metric_type: 'calories',
      value_num: activity.calories,
      value_text: null,
      unit: 'kcal',
      start_time: startTime,
      end_time: null,
      recorded_at: new Date().toISOString(),
      raw_payload_json: activity,
      dedupe_hash: await generateDedupeHash('strava', 'calories', startTime, startTime),
    })
  }

  return metrics
}

/**
 * Generate deduplication hash using Web Crypto API (SHA-256)
 */
async function generateDedupeHash(
  source: string,
  metricType: string,
  startTime: string | null,
  endTime: string | null
): Promise<string> {
  const input = `${source}:${metricType}:${startTime || ''}:${endTime || ''}`
  const data = new TextEncoder().encode(input)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  return encodeHex(new Uint8Array(hashBuffer))
}

/**
 * Handle Garmin deregistration
 */
async function handleGarminDeregistration(
  adminClient: SupabaseClient,
  garminUserId: string | null | undefined
): Promise<void> {
  if (!garminUserId) return

  console.log(`[Webhook Processor] Handling Garmin deregistration for user ${garminUserId}`)

  const { error } = await adminClient
    .from('wt_health_connections')
    .update({
      is_connected: false,
      connection_metadata: {
        disconnected_at: new Date().toISOString(),
      },
    })
    .eq('provider', 'garmin')
    .eq('connection_metadata->>garmin_user_id', garminUserId)

  if (error) {
    console.error('[Webhook Processor] Failed to update Garmin connection:', error)
  }
}

/**
 * Handle Strava deauthorization
 */
async function handleStravaDeauthorization(
  adminClient: SupabaseClient,
  athleteId: string | null | undefined
): Promise<void> {
  if (!athleteId) return

  console.log(`[Webhook Processor] Handling Strava deauthorization for athlete ${athleteId}`)

  const { error } = await adminClient
    .from('wt_health_connections')
    .update({
      is_connected: false,
      connection_metadata: {
        disconnected_at: new Date().toISOString(),
      },
    })
    .eq('provider', 'strava')
    .eq('connection_metadata->>athlete_id', athleteId)

  if (error) {
    console.error('[Webhook Processor] Failed to update Strava connection:', error)
  }
}

/**
 * Mark event as completed
 */
async function markEventCompleted(
  adminClient: SupabaseClient,
  eventId: string
): Promise<void> {
  const { error } = await adminClient
    .from('wt_webhook_events')
    .update({
      status: 'completed',
      processed_at: new Date().toISOString(),
    })
    .eq('id', eventId)

  if (error) {
    console.error(`[Webhook Processor] Failed to mark event ${eventId} as completed:`, error)
  }
}

/**
 * Mark event as failed and schedule retry
 */
async function markEventFailed(
  adminClient: SupabaseClient,
  event: WebhookEvent
): Promise<void> {
  const attempts = event.attempts + 1
  const isDeadLetter = attempts >= event.max_attempts

  // Exponential backoff: 60s * 2^(attempts-1)
  const retryDelaySeconds = 60 * Math.pow(2, attempts - 1)
  const nextRetryAt = new Date(Date.now() + retryDelaySeconds * 1000).toISOString()

  const { error } = await adminClient
    .from('wt_webhook_events')
    .update({
      status: isDeadLetter ? 'dead_letter' : 'pending',
      attempts: attempts,
      next_retry_at: isDeadLetter ? null : nextRetryAt,
      last_error: 'Processing failed',
    })
    .eq('id', event.id)

  if (error) {
    console.error(`[Webhook Processor] Failed to mark event ${event.id} as failed:`, error)
  }
}
