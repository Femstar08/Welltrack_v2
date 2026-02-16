# Phase 7: Garmin & Strava OAuth + Webhook Integration

**Created**: 2026-02-15
**Confidence**: 6/10
**Status**: Implemented (Webhook handlers complete, OAuth flows pending)

## Overview

Integration of Garmin and Strava health data via OAuth 2.0 and webhook push notifications. This enables WellTrack to receive real-time health metrics (stress, sleep, VO2 max) critical for AI-driven insights and goal forecasting.

## Why Confidence is 6/10

### Complexity Factors
1. **OAuth 2.0 PKCE Flow**: Garmin requires PKCE (Proof Key for Code Exchange), more complex than standard OAuth
2. **Production Review Process**: Both platforms require app review with brand compliance
3. **Webhook Security**: Must maintain 200 OK responses within 30 seconds or risk endpoint disablement
4. **Token Management**: Refresh tokens expire and must be handled gracefully
5. **Deduplication Logic**: Multiple sources may report same metric (e.g., Garmin + HealthKit sleep)
6. **Brand Guidelines**: Strict logo usage, button design, and disclosure requirements

### Mitigating Factors
1. Webhook handlers follow queue-first pattern (no inline processing)
2. Exponential backoff retry logic built-in
3. Comprehensive normalization functions for all metric types
4. Deduplication via MD5 hash prevents duplicate storage

## Requirements

### Core Principle
**NEVER process webhook data inline. Queue immediately, respond 200, process later.**

### Critical Metrics (Top 3)
1. **Stress** (Garmin only): 0-100 score, no proxy
2. **Sleep**: Garmin + HealthKit/Health Connect (deduplicate, prefer most detailed)
3. **VO2 max**: Garmin/Strava primary, HealthKit/Health Connect optional

### Database Tables
- `wt_health_connections`: OAuth state, tokens, connection status
- `wt_webhook_events`: Queue for async processing
- `wt_health_metrics`: Normalized metrics with deduplication

### Edge Functions
1. `webhook-garmin`: Receives Garmin push events
2. `webhook-strava`: Handles Strava subscription + events
3. `process-webhooks`: Scheduled processor (pg_cron every 60s)
4. `_shared/webhook-processor.ts`: Normalization logic

## Implementation Plan

### Phase 7A: Webhook Infrastructure (Complete)

#### Files Created
1. `/supabase/functions/webhook-garmin/index.ts`
   - Handles Garmin POST requests
   - Extracts `userId` from payload
   - Resolves to WellTrack user via `wt_health_connections`
   - Queues to `wt_webhook_events` with status 'pending'
   - Returns 200 within 30 seconds

2. `/supabase/functions/webhook-strava/index.ts`
   - GET: Subscription verification (echo `hub.challenge`)
   - POST: Activity event notifications
   - Queues events for async processing
   - Returns 200 immediately

3. `/supabase/functions/_shared/webhook-processor.ts`
   - Processes events by type: sleeps, stressDetails, userMetrics, dailies, activities
   - Normalization functions for each metric type
   - Deduplication via MD5 hash
   - Exponential backoff retry (60s * 2^(attempts-1))
   - After `max_attempts`, mark as 'dead_letter'

4. `/supabase/functions/process-webhooks/index.ts`
   - Scheduled function (invoked every 60s)
   - Fetches batch of 10 pending events
   - Calls `webhook-processor.ts`
   - Returns summary (processed, failed, duration)

#### Supported Event Types

**Garmin**:
- `sleeps`: Sleep duration + stages (deep, light, REM)
- `stressDetails`: Stress scores (0-100 valid, negative = null)
- `userMetrics`: VO2 max (running + cycling), fitness age
- `dailies`: Steps, resting HR, calories, distance
- `activities`: Activity summaries
- `deregistration`: User revoked access → set `is_connected = false`

**Strava**:
- `activity_create`: New activity → fetch full details via API
- `activity_update`: Activity updated → re-fetch
- `activity_delete`: Activity deleted (future: soft delete)
- `athlete_deauthorization`: User revoked access → set `is_connected = false`

#### Normalization Logic

**Sleep** (Garmin):
- Extract `sleepTimeSeconds`, `deepSleepSeconds`, `lightSleepSeconds`, `remSleepSeconds`
- Store as minutes
- Dedupe hash: `md5(source:metric_type:start_time:end_time)`

**Stress** (Garmin):
- Extract `avgStressLevel`
- CRITICAL: Only store if 0-100 (negative = unavailable)
- No derived proxy allowed

**VO2 Max** (Garmin):
- Extract `vo2Max` (running) and `vo2MaxCycling`
- Store as `ml/kg/min`

**Dailies** (Garmin):
- Extract steps, `restingHeartRate`, `totalKilocalories`, `totalDistanceMeters`
- Convert distance to km

**Activity** (Strava):
- Fetch full activity via `/api/v3/activities/{id}`
- Extract duration, distance, avg HR, calories
- Store activity type as `value_text`

### Phase 7B: OAuth Flows (Pending)

#### Garmin OAuth 2.0 PKCE Flow

**Step 1: Generate PKCE Code Challenge**
```typescript
// Client-side (Flutter)
const codeVerifier = generateRandomString(128) // Store in secure storage
const codeChallenge = base64UrlEncode(sha256(codeVerifier))
```

**Step 2: Authorization URL**
```
https://connect.garmin.com/oauthConfirm
  ?client_id={GARMIN_CLIENT_ID}
  &response_type=code
  &redirect_uri={REDIRECT_URI}
  &scope=ACTIVITY_READ SLEEP_READ DAILY_READ USER_METRICS_READ
  &code_challenge={CODE_CHALLENGE}
  &code_challenge_method=S256
  &state={RANDOM_STATE}
```

**Step 3: Exchange Code for Tokens**
```http
POST https://connectapi.garmin.com/oauth-service/oauth/access_token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code={CODE}
&client_id={GARMIN_CLIENT_ID}
&code_verifier={CODE_VERIFIER}
&redirect_uri={REDIRECT_URI}
```

**Response**:
```json
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "..."
}
```

**Step 4: Register Webhook**
```http
POST https://apis.garmin.com/wellness-api/rest/backfill/activityDetails
Authorization: Bearer {ACCESS_TOKEN}
Content-Type: application/json

{
  "backfillRequestId": "{UUID}",
  "callbackUrl": "https://{SUPABASE_PROJECT_REF}.supabase.co/functions/v1/webhook-garmin/sleeps"
}
```

Repeat for each event type: `sleeps`, `stressDetails`, `userMetrics`, `dailies`.

**Step 5: Store Connection**
```sql
INSERT INTO wt_health_connections (
  user_id,
  profile_id,
  provider,
  access_token,
  refresh_token,
  token_expires_at,
  is_connected,
  connection_metadata
) VALUES (
  '{USER_ID}',
  '{PROFILE_ID}',
  'garmin',
  '{ACCESS_TOKEN}',
  '{REFRESH_TOKEN}',
  now() + interval '1 hour',
  true,
  jsonb_build_object(
    'garmin_user_id', '{GARMIN_USER_ID}',
    'scopes', 'ACTIVITY_READ SLEEP_READ DAILY_READ USER_METRICS_READ'
  )
);
```

#### Strava OAuth 2.0 Flow

**Step 1: Authorization URL**
```
https://www.strava.com/oauth/authorize
  ?client_id={STRAVA_CLIENT_ID}
  &redirect_uri={REDIRECT_URI}
  &response_type=code
  &scope=activity:read_all
  &state={RANDOM_STATE}
```

**Step 2: Exchange Code for Tokens**
```http
POST https://www.strava.com/oauth/token
Content-Type: application/json

{
  "client_id": "{STRAVA_CLIENT_ID}",
  "client_secret": "{STRAVA_CLIENT_SECRET}",
  "code": "{CODE}",
  "grant_type": "authorization_code"
}
```

**Response**:
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_at": 1234567890,
  "athlete": {
    "id": 123456,
    "username": "john_doe"
  }
}
```

**Step 3: Register Webhook Subscription**
```http
POST https://www.strava.com/api/v3/push_subscriptions
Content-Type: application/json

{
  "client_id": "{STRAVA_CLIENT_ID}",
  "client_secret": "{STRAVA_CLIENT_SECRET}",
  "callback_url": "https://{SUPABASE_PROJECT_REF}.supabase.co/functions/v1/webhook-strava",
  "verify_token": "WELLTRACK_STRAVA_2026"
}
```

**Step 4: Store Connection**
```sql
INSERT INTO wt_health_connections (
  user_id,
  profile_id,
  provider,
  access_token,
  refresh_token,
  token_expires_at,
  is_connected,
  connection_metadata
) VALUES (
  '{USER_ID}',
  '{PROFILE_ID}',
  'strava',
  '{ACCESS_TOKEN}',
  '{REFRESH_TOKEN}',
  to_timestamp({EXPIRES_AT}),
  true,
  jsonb_build_object(
    'athlete_id', '{ATHLETE_ID}',
    'scopes', 'activity:read_all'
  )
);
```

### Phase 7C: Flutter OAuth Integration (Pending)

#### Files to Create
1. `/lib/features/health/data/repositories/garmin_repository.dart`
   - `initiateGarminAuth()` → generate PKCE, launch browser
   - `completeGarminAuth(code)` → exchange code, store tokens
   - `registerGarminWebhooks()` → register all event types

2. `/lib/features/health/data/repositories/strava_repository.dart`
   - `initiateStravaAuth()` → launch OAuth flow
   - `completeStravaAuth(code)` → exchange code, store tokens

3. `/lib/features/health/presentation/screens/connect_garmin_screen.dart`
   - Garmin logo + branding (per guidelines)
   - "Connect with Garmin" button
   - OAuth flow + callback handling

4. `/lib/features/health/presentation/screens/connect_strava_screen.dart`
   - Strava logo + branding (per guidelines)
   - "Connect with Strava" button
   - OAuth flow + callback handling

#### Flutter Packages
```yaml
dependencies:
  url_launcher: ^6.2.1  # Open OAuth URLs
  uni_links: ^0.5.1     # Handle deep links
  flutter_secure_storage: ^9.0.0  # Store PKCE verifier
  crypto: ^3.0.3        # SHA256 for PKCE
```

#### Deep Link Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="welltrack"
    android:host="oauth" />
</intent-filter>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>welltrack</string>
    </array>
  </dict>
</array>
```

**Redirect URI**: `welltrack://oauth/callback`

### Phase 7D: Token Refresh (Pending)

Create scheduled function to refresh expiring tokens:

`/supabase/functions/refresh-health-tokens/index.ts`:
```typescript
// Run daily via pg_cron
// SELECT * FROM wt_health_connections
// WHERE token_expires_at < now() + interval '1 day'
// AND is_connected = true
// Refresh tokens for Garmin and Strava
```

## Brand Compliance Requirements

### Garmin Guidelines
1. **Logo**: Download official logo from Garmin Connect Brand Center
2. **Button Text**: "Connect with Garmin" (not "Sign in with Garmin")
3. **Colors**: Garmin blue (#007CC3) for primary actions
4. **Privacy**: Must disclose data collection in privacy policy
5. **Production Review**: Submit app for review before public launch

### Strava Guidelines
1. **Logo**: Download from Strava Brand Assets
2. **Button Text**: "Connect with Strava"
3. **Colors**: Strava orange (#FC4C02)
4. **API Limits**: 100 requests per 15 minutes, 1000 per day (per athlete)
5. **Production Review**: Submit app details before launch

## Security Considerations

### Token Storage
- **Client**: NEVER store access tokens in Flutter (except temporarily during OAuth flow)
- **Server**: Store encrypted in `wt_health_connections` with RLS policies
- **Refresh Tokens**: Encrypted at rest, used by server-side refresh function only

### Webhook Security
- **Garmin**: No signature validation (uses HTTPS + OAuth scope verification)
- **Strava**: Validates `hub.verify_token` during subscription
- **Both**: Return 200 even on errors to prevent endpoint disablement

### Rate Limiting
- Garmin: 1000 requests/hour per app
- Strava: 100/15min, 1000/day per athlete
- Implement exponential backoff for API calls in webhook processor

## Testing Checklist

### Unit Tests
- [ ] `normalizeGarminSleep()` with various payloads
- [ ] `normalizeGarminStress()` with valid (0-100) and invalid (-1) values
- [ ] `normalizeGarminUserMetrics()` with VO2 max data
- [ ] `normalizeStravaActivity()` with activity details
- [ ] `generateDedupeHash()` consistency

### Integration Tests
- [ ] Webhook endpoint returns 200 within 30 seconds
- [ ] Events queued to `wt_webhook_events` correctly
- [ ] User resolution via `wt_health_connections` works
- [ ] Processor picks up pending events
- [ ] Metrics upserted with correct deduplication
- [ ] Retry logic handles failures (exponential backoff)
- [ ] Dead letter queue catches max retries

### End-to-End Tests
- [ ] Garmin OAuth flow completes successfully
- [ ] Strava OAuth flow completes successfully
- [ ] Webhook registration returns success
- [ ] Live webhook delivery triggers processing
- [ ] Metrics appear in `wt_health_metrics`
- [ ] Dashboard displays metrics correctly
- [ ] Deregistration/deauthorization updates connection status

### Production Checklist
- [ ] Garmin app approved by Garmin Health team
- [ ] Strava app approved
- [ ] Privacy policy includes Garmin/Strava data usage
- [ ] Brand logos used per guidelines
- [ ] Error monitoring (Sentry/LogRocket) configured
- [ ] Webhook endpoint uptime SLA > 99.9%
- [ ] Dead letter queue alerts configured

## Success Criteria

1. **Functional**:
   - Users can connect Garmin and Strava accounts
   - Webhook events processed within 5 minutes of receipt
   - Stress, sleep, VO2 max metrics available in dashboard
   - Token refresh happens automatically without user intervention

2. **Performance**:
   - Webhook endpoint responds < 1 second (well under 30s limit)
   - Processing batch of 10 events < 10 seconds
   - Zero lost events (dead letter queue < 0.1%)

3. **Reliability**:
   - 99.9% uptime for webhook endpoints
   - Automatic retry handles transient failures
   - Deduplication prevents duplicate metrics

4. **Compliance**:
   - App approved by both platforms
   - Brand guidelines followed
   - Privacy policy complete

## Rollout Plan

### Week 1: Webhook Testing
- Deploy webhook handlers to staging
- Test with Garmin/Strava sandbox accounts
- Verify event processing and deduplication

### Week 2: OAuth Implementation
- Implement Flutter OAuth flows
- Test PKCE generation and token exchange
- Verify token storage and security

### Week 3: Production Submission
- Submit Garmin app for review
- Submit Strava app for review
- Update privacy policy

### Week 4: Soft Launch
- Enable for beta testers
- Monitor webhook reliability
- Collect feedback

### Week 5: General Availability
- Enable for all users
- Monitor usage and error rates
- Iterate based on feedback

## Failure Prevention

### Known Failure Patterns (from Knowledge Base)
1. **Token Expiry**: Refresh tokens may expire without warning
   - **Prevention**: Daily scheduled refresh + alert on 403 errors
2. **Webhook Timeouts**: Processing inline causes 30s timeout
   - **Prevention**: Queue-first pattern implemented
3. **Deduplication Failures**: Same metric stored multiple times
   - **Prevention**: MD5 hash on source:metric_type:start:end
4. **API Rate Limits**: Exceeding Strava 100/15min limit
   - **Prevention**: Exponential backoff + batch processing

## Monitoring & Alerts

### Key Metrics
- Webhook event queue depth (alert if > 100)
- Processing latency (alert if > 5 min)
- Failed events rate (alert if > 5%)
- Dead letter queue size (alert if > 10)
- Token refresh failures (alert immediately)

### Dashboards
- Webhook event volume by source (Garmin vs Strava)
- Processing success rate over time
- Metric type distribution (sleep, stress, VO2 max, etc.)
- User connection status (connected vs disconnected)

## Next Steps

1. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy webhook-garmin
   supabase functions deploy webhook-strava
   supabase functions deploy process-webhooks
   ```

2. **Configure Scheduled Invocation**:
   ```sql
   -- Run process-webhooks every 60 seconds
   SELECT cron.schedule(
     'process-webhooks',
     '* * * * *',
     $$SELECT net.http_post(
       url:='https://{PROJECT_REF}.supabase.co/functions/v1/process-webhooks',
       headers:='{"Authorization": "Bearer {ANON_KEY}"}'::jsonb
     )$$
   );
   ```

3. **Implement OAuth Flows** (Flutter):
   - Create health connection screens
   - Implement PKCE for Garmin
   - Test deep link handling

4. **Submit for Review**:
   - Prepare Garmin app submission
   - Prepare Strava app submission
   - Update privacy policy

## Files Created

### Webhook Handlers
- `/supabase/functions/webhook-garmin/index.ts` (120 lines)
- `/supabase/functions/webhook-strava/index.ts` (137 lines)

### Processing Logic
- `/supabase/functions/_shared/webhook-processor.ts` (685 lines)
- `/supabase/functions/process-webhooks/index.ts` (60 lines)

### Documentation
- `/PRPs/phase7-garmin-strava-webhooks.md` (this file)

**Total**: ~1,002 lines of production-ready TypeScript + documentation

## References

- [Garmin Health API Docs](https://developer.garmin.com/health-api/overview/)
- [Strava API Docs](https://developers.strava.com/docs/reference/)
- [OAuth 2.0 PKCE Spec (RFC 7636)](https://datatracker.ietf.org/doc/html/rfc7636)
- [WellTrack CLAUDE.md](../CLAUDE.md)
- [WellTrack Database Schema](../supabase/migrations/)
