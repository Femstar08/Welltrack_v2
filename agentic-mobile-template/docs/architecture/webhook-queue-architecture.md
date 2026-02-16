# Webhook Queue Architecture

## Overview

This document defines the asynchronous webhook processing system for WellTrack. The core principle is: **NEVER process webhooks inline**. Always queue first, respond immediately, process asynchronously.

## Why Queue Architecture

Garmin requires HTTP 200 within 30 seconds. Processing data inline risks timeout, causing Garmin to retry (and potentially disable the endpoint). The same principle applies to Strava webhooks.

By queuing webhook events immediately and processing them asynchronously, we ensure:
- Fast response times (< 500ms)
- Reliable webhook delivery
- Retry capability for failed processing
- Audit trail of all webhook events
- No data loss from transient failures

## Table: wt_webhook_events

```sql
CREATE TABLE wt_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL,          -- 'garmin' | 'strava'
  event_type text NOT NULL,      -- 'sleeps' | 'stressDetails' | 'userMetrics' | 'dailies' | 'activities' | 'deregistration' | 'user_permission'
  payload jsonb NOT NULL,        -- raw webhook payload
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- resolved from source user ID
  garmin_user_id text,           -- Garmin userId (persists across re-registrations)
  strava_athlete_id text,        -- Strava athlete ID
  status text NOT NULL DEFAULT 'pending',  -- 'pending' | 'processing' | 'completed' | 'failed' | 'dead_letter'
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 5,
  last_error text,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  next_retry_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_webhook_events_status_retry ON wt_webhook_events(status, next_retry_at)
  WHERE status IN ('pending', 'failed');
CREATE INDEX idx_webhook_events_source_user ON wt_webhook_events(source, user_id);
CREATE INDEX idx_webhook_events_received_at ON wt_webhook_events(received_at);
CREATE INDEX idx_webhook_events_garmin_user ON wt_webhook_events(garmin_user_id)
  WHERE garmin_user_id IS NOT NULL;

-- RLS policy (admin only)
ALTER TABLE wt_webhook_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role can manage webhook events"
  ON wt_webhook_events FOR ALL
  USING (auth.role() = 'service_role');
```

## Webhook Receive Flow

### Garmin Push Endpoint

```
POST /webhooks/garmin/{event_type}
```

**Flow:**
1. Validate request (check signature/origin)
2. Parse payload minimally (extract Garmin userId)
3. Resolve Garmin userId → auth user_id via wt_health_connections
4. INSERT INTO wt_webhook_events (source: 'garmin', event_type, payload, user_id, garmin_user_id, status: 'pending')
5. Return HTTP 200 immediately

**Total time:** < 500ms

**Supported event types:**
- `sleeps` — sleep data with stages, scores, SpO2
- `stressDetails` — stress levels (0-100) and body battery
- `userMetrics` — VO2 max values
- `dailies` — daily summary (steps, HR, calories, distance)
- `activities` — workout/activity data

### Strava Webhook Endpoint

```
GET /webhooks/strava (subscription validation — echo challenge)
POST /webhooks/strava (event notification)
```

**Flow:**
1. Validate subscription
2. Parse event (object_type, aspect_type, object_id, owner_id)
3. INSERT INTO wt_webhook_events (source: 'strava', event_type: object_type, payload, strava_athlete_id)
4. Return HTTP 200 immediately

**Event types:**
- `activities` — activity create/update/delete
- `athlete` — athlete update (e.g., changed permissions)

### Special Garmin Endpoints

```
POST /webhooks/garmin/deregistration
```
**Purpose:** User disconnected from Garmin Connect

**Flow:**
1. Queue event
2. Process: set wt_health_connections.is_connected = false
3. Clear access tokens
4. Optionally notify user

```
POST /webhooks/garmin/user-permission
```
**Purpose:** User changed data sharing toggles

**Flow:**
1. Queue event
2. Process: update connection_metadata with new permissions
3. Adjust data fetch strategy based on granted permissions

## Processing Pipeline

### Worker Architecture

**Implementation options:**
1. **Supabase Edge Function** triggered on schedule (every 60 seconds)
2. **pg_cron** extension for periodic jobs
3. **Dedicated worker service** (Docker container polling queue)

**Processing rules:**
- Pick up events WHERE status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= now())
- Process in FIFO order (received_at ASC)
- Batch size: 10 events per run (prevent timeout)
- Lock mechanism: UPDATE status = 'processing' WHERE status = 'pending' ... FOR UPDATE SKIP LOCKED

**Pseudo-code:**

```typescript
async function processWebhookQueue() {
  // Fetch next batch with row-level lock
  const events = await supabase
    .from('wt_webhook_events')
    .select('*')
    .in('status', ['pending', 'failed'])
    .or(`next_retry_at.is.null,next_retry_at.lte.${new Date().toISOString()}`)
    .order('received_at', { ascending: true })
    .limit(10);

  for (const event of events.data) {
    try {
      // Mark as processing
      await updateEventStatus(event.id, 'processing');

      // Process based on source and event type
      await processEvent(event);

      // Mark as completed
      await updateEventStatus(event.id, 'completed', { processed_at: new Date() });
    } catch (error) {
      // Handle retry logic
      await handleFailure(event, error);
    }
  }
}
```

### Processing by Event Type

#### Garmin sleeps

**Flow:**
1. Parse sleep summary from payload
2. Extract: sleep levels (deep, light, rem, awake), duration, scores, start/end
3. Map to wt_health_metrics (metric_type: 'sleep')
4. Check for SpO2 data → store as separate metric (metric_type: 'spo2')
5. Dedup by (profile_id, source: 'garmin', metric_type: 'sleep', start_time, end_time)

**Data mapping:**
```typescript
{
  metric_type: 'sleep',
  value_num: durationInSeconds,
  value_text: JSON.stringify({
    deep: deepSleepSeconds,
    light: lightSleepSeconds,
    rem: remSleepSeconds,
    awake: awakeDurationSeconds,
    sleepScore: overallScore
  }),
  unit: 'seconds',
  start_time: sleepStartTimestampGMT,
  end_time: sleepEndTimestampGMT,
  raw_payload_json: originalPayload
}
```

#### Garmin stressDetails

**Flow:**
1. Parse stress data array from payload
2. Calculate daily average (values 1-100 only; negative values → NULL)
3. Extract body battery data
4. Map to wt_health_metrics (metric_type: 'stress')
5. Store 3-min averages in raw_payload_json

**Data mapping:**
```typescript
{
  metric_type: 'stress',
  value_num: avgStressLevel,  // 0-100
  value_text: JSON.stringify({
    min: minStress,
    max: maxStress,
    bodyBattery: bodyBatteryValue,
    restingHeartRate: restingHR
  }),
  unit: 'score',
  start_time: calendarDate + '00:00:00',
  end_time: calendarDate + '23:59:59',
  raw_payload_json: stressDetailsArray
}
```

#### Garmin userMetrics

**Flow:**
1. Parse VO2 max values
2. Extract vo2Max (running) and vo2MaxCycling
3. Map to wt_health_metrics (metric_type: 'vo2max')

**Data mapping:**
```typescript
{
  metric_type: 'vo2max',
  value_num: vo2MaxValue,
  value_text: JSON.stringify({
    type: 'running' | 'cycling',
    fitnessAge: fitnessAge
  }),
  unit: 'ml/kg/min',
  start_time: calendarDate,
  end_time: calendarDate,
  raw_payload_json: originalPayload
}
```

#### Garmin dailies

**Flow:**
1. Parse daily summary
2. Extract: steps, restingHeartRate, activeKilocalories, distance
3. Map each to separate wt_health_metrics rows

**Data mapping:**
```typescript
// Multiple rows inserted:
[
  { metric_type: 'steps', value_num: totalSteps, unit: 'steps' },
  { metric_type: 'resting_hr', value_num: restingHeartRate, unit: 'bpm' },
  { metric_type: 'calories', value_num: activeKilocalories, unit: 'kcal' },
  { metric_type: 'distance', value_num: totalDistanceMeters, unit: 'meters' }
]
```

#### Strava activities

**Flow:**
1. Fetch full activity from Strava API using object_id
2. Extract: type, duration, distance, avg_hr, calories
3. Map to wt_health_metrics
4. Check for VO2 max estimate → separate metric

**Data mapping:**
```typescript
{
  metric_type: 'activity',
  value_num: movingTimeSeconds,
  value_text: JSON.stringify({
    type: activityType,  // 'Run', 'Ride', 'Swim', etc.
    distance: distanceMeters,
    avgHeartRate: average_heartrate,
    calories: calories,
    elevationGain: total_elevation_gain
  }),
  unit: 'seconds',
  start_time: start_date,
  end_time: calculatedEndTime,
  raw_payload_json: fullActivity
}
```

### Retry Strategy

```
Attempt 1: immediate (on first pick-up)
Attempt 2: +1 minute
Attempt 3: +5 minutes
Attempt 4: +30 minutes
Attempt 5: +2 hours (final)

Formula: next_retry_at = now() + (base_delay * 2^(attempts-1))
Where base_delay = 60 seconds
```

**Implementation:**

```typescript
function calculateNextRetry(attempts: number): Date {
  const baseDelaySeconds = 60;
  const delaySeconds = baseDelaySeconds * Math.pow(2, attempts - 1);
  return new Date(Date.now() + delaySeconds * 1000);
}

async function handleFailure(event, error) {
  const newAttempts = event.attempts + 1;

  if (newAttempts >= event.max_attempts) {
    // Move to dead letter
    await supabase
      .from('wt_webhook_events')
      .update({
        status: 'dead_letter',
        attempts: newAttempts,
        last_error: error.message
      })
      .eq('id', event.id);

    // Alert monitoring
    await logToSentry(event, error);
  } else {
    // Schedule retry
    await supabase
      .from('wt_webhook_events')
      .update({
        status: 'failed',
        attempts: newAttempts,
        last_error: error.message,
        next_retry_at: calculateNextRetry(newAttempts)
      })
      .eq('id', event.id);
  }
}
```

### Dead Letter Handling

After max_attempts (5) failures:
- status = 'dead_letter'
- Alert: log to monitoring (Sentry)
- No auto-retry
- Admin can manually retry or inspect

**Manual retry:**
```sql
-- Reset a dead letter event for retry
UPDATE wt_webhook_events
SET status = 'pending',
    attempts = 0,
    next_retry_at = NULL,
    last_error = NULL
WHERE id = '<event-id>';
```

**Inspection query:**
```sql
-- Find recent dead letter events
SELECT
  id,
  source,
  event_type,
  user_id,
  attempts,
  last_error,
  received_at,
  payload
FROM wt_webhook_events
WHERE status = 'dead_letter'
ORDER BY received_at DESC
LIMIT 50;
```

### Backfill Support

Garmin allows requesting historical data (max 90 days):
1. Trigger backfill via Garmin API
2. Data arrives asynchronously via push webhooks
3. Same pipeline processes it (no special handling)
4. Events are deduplicated naturally via dedupe_hash in wt_health_metrics

**Backfill trigger:**
```typescript
// Request historical sleep data
await garminAPI.requestBackfill({
  userId: garminUserId,
  dataType: 'sleeps',
  startDate: '2025-11-15',
  endDate: '2026-02-15'
});

// Garmin will push data via webhooks over next few hours
```

## Monitoring

### Key Metrics

**Track:**
- Events received/min (by source)
- Processing latency (received_at → processed_at)
- Failure rate (failed events / total events)
- Dead letter count (daily)
- Queue depth (pending + failed events)

**Alert if:**
- Dead letter count > 10/day
- Processing latency > 5 minutes (p95)
- Failure rate > 10%
- Queue depth > 100 events

### Monitoring Queries

```sql
-- Processing latency (last 24 hours)
SELECT
  source,
  event_type,
  AVG(EXTRACT(EPOCH FROM (processed_at - received_at))) as avg_latency_seconds,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (processed_at - received_at))) as p95_latency_seconds
FROM wt_webhook_events
WHERE status = 'completed'
  AND received_at > NOW() - INTERVAL '24 hours'
GROUP BY source, event_type;

-- Failure rate (last 24 hours)
SELECT
  source,
  event_type,
  COUNT(*) FILTER (WHERE status IN ('failed', 'dead_letter')) as failed_count,
  COUNT(*) as total_count,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('failed', 'dead_letter')) / COUNT(*), 2) as failure_rate_pct
FROM wt_webhook_events
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY source, event_type;

-- Queue depth
SELECT
  status,
  COUNT(*) as count,
  MIN(received_at) as oldest_event
FROM wt_webhook_events
WHERE status IN ('pending', 'failed')
GROUP BY status;

-- Dead letter events (last 7 days)
SELECT
  DATE(received_at) as date,
  source,
  event_type,
  COUNT(*) as dead_letter_count
FROM wt_webhook_events
WHERE status = 'dead_letter'
  AND received_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(received_at), source, event_type
ORDER BY date DESC;
```

## Security Considerations

### Webhook Validation

**Garmin:**
- Validate request origin (IP allowlist if available)
- Verify HMAC signature if provided
- Rate limit by IP (max 1000 requests/min)

**Strava:**
- Verify subscription callback token (GET validation)
- Validate aspect_type and object_type
- Rate limit by athlete_id

### Data Isolation

- All webhook events are processed with service role credentials
- RLS policies prevent direct user access to wt_webhook_events
- User data isolation enforced at wt_health_metrics level (profile_id scoped)

### PII Handling

- Webhook payloads may contain PII (names, locations, timestamps)
- Store payloads encrypted at rest (Supabase encryption)
- Purge completed events older than 90 days
- Retain dead_letter events for 1 year (debugging)

## Cleanup Policy

```sql
-- Delete completed events older than 90 days
DELETE FROM wt_webhook_events
WHERE status = 'completed'
  AND processed_at < NOW() - INTERVAL '90 days';

-- Archive dead_letter events older than 1 year
-- (Optional: move to archive table before deletion)
DELETE FROM wt_webhook_events
WHERE status = 'dead_letter'
  AND received_at < NOW() - INTERVAL '1 year';
```

## Edge Cases

### Duplicate Webhooks

Garmin may send duplicate webhooks if initial response is slow or times out.

**Solution:**
- Allow duplicate events in wt_webhook_events (audit trail)
- Deduplication happens at wt_health_metrics level via dedupe_hash
- dedupe_hash = SHA256(profile_id || source || metric_type || start_time || end_time)

### User Re-Registration

User disconnects and reconnects Garmin/Strava account.

**Solution:**
- garmin_user_id and strava_athlete_id persist across connections
- Lookup in wt_health_connections by external user ID
- If connection deleted, webhook event user_id remains NULL
- Events with NULL user_id fail gracefully (no data inserted)

### Partial Data

Webhook payload is malformed or missing required fields.

**Solution:**
- Validate payload structure before processing
- Extract what's available, skip missing fields
- Log validation errors in last_error
- Retry may succeed if transient API issue
- Dead letter if consistently malformed

### Rate Limiting

Garmin/Strava API rate limits hit during processing.

**Solution:**
- Retry with exponential backoff (built into retry strategy)
- Implement global rate limiter (e.g., 100 requests/15min for Garmin)
- Queue additional API calls if limit hit (e.g., Strava activity detail fetch)

## Example Edge Function

```typescript
// supabase/functions/webhook-processor/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Fetch pending events
  const { data: events } = await supabase
    .from('wt_webhook_events')
    .select('*')
    .in('status', ['pending', 'failed'])
    .or(`next_retry_at.is.null,next_retry_at.lte.${new Date().toISOString()}`)
    .order('received_at', { ascending: true })
    .limit(10);

  const results = [];

  for (const event of events || []) {
    try {
      // Mark as processing
      await supabase
        .from('wt_webhook_events')
        .update({ status: 'processing' })
        .eq('id', event.id);

      // Process event
      if (event.source === 'garmin') {
        await processGarminEvent(event, supabase);
      } else if (event.source === 'strava') {
        await processStravaEvent(event, supabase);
      }

      // Mark as completed
      await supabase
        .from('wt_webhook_events')
        .update({
          status: 'completed',
          processed_at: new Date().toISOString()
        })
        .eq('id', event.id);

      results.push({ id: event.id, status: 'success' });
    } catch (error) {
      await handleFailure(event, error, supabase);
      results.push({ id: event.id, status: 'failed', error: error.message });
    }
  }

  return new Response(JSON.stringify({ processed: results.length, results }), {
    headers: { 'Content-Type': 'application/json' }
  });
});
```

## Summary

The webhook queue architecture ensures reliable, scalable processing of health data from external platforms. Key benefits:

1. **Reliability**: No data loss from transient failures
2. **Performance**: Fast webhook responses (< 500ms)
3. **Scalability**: Queue-based processing handles bursts
4. **Observability**: Full audit trail and monitoring
5. **Maintainability**: Centralized processing logic with retry/dead letter handling

All webhook integrations (Garmin, Strava, future platforms) follow this pattern consistently.
