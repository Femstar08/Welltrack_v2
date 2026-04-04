/**
 * OAuth Token Refresh Utilities
 *
 * Provides token refresh for Garmin and Strava integrations.
 * Called by webhook-processor when an existing access token has expired
 * before making upstream API calls.
 *
 * Both functions return a normalised TokenResult so callers never need
 * to know provider-specific field names.
 */

export interface TokenResult {
  accessToken: string
  refreshToken: string
  expiresAt: string // ISO-8601 UTC
}

// ---------------------------------------------------------------------------
// Garmin
// ---------------------------------------------------------------------------

/**
 * Refresh a Garmin OAuth 2.0 access token.
 *
 * Garmin uses the standard OAuth 2.0 refresh-token grant against
 * https://diauth.garmin.com/di-oauth2-service/oauth/token (per PKCE spec).
 *
 * Required env vars:
 *   GARMIN_CLIENT_ID
 *   GARMIN_CLIENT_SECRET
 */
export async function refreshGarminToken(refreshToken: string): Promise<TokenResult> {
  const clientId = Deno.env.get('GARMIN_CLIENT_ID')
  const clientSecret = Deno.env.get('GARMIN_CLIENT_SECRET')

  if (!clientId || !clientSecret) {
    throw new Error('[Token Refresh] GARMIN_CLIENT_ID or GARMIN_CLIENT_SECRET not configured')
  }

  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
    client_id: clientId,
    client_secret: clientSecret,
  })

  const response = await fetch('https://diauth.garmin.com/di-oauth2-service/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error('[Token Refresh] Garmin token refresh failed:', response.status, errorText)
    throw new Error(`Garmin token refresh failed with status ${response.status}`)
  }

  const data = await response.json()

  // Garmin returns expires_in (seconds from now)
  const expiresAt = new Date(Date.now() + (data.expires_in ?? 3600) * 1000).toISOString()

  console.log('[Token Refresh] Garmin token refreshed successfully')

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? refreshToken, // Garmin may or may not rotate refresh token
    expiresAt,
  }
}

// ---------------------------------------------------------------------------
// Strava
// ---------------------------------------------------------------------------

/**
 * Refresh a Strava OAuth 2.0 access token.
 *
 * Strava always rotates both access and refresh tokens on each refresh call.
 * Callers MUST persist the new refresh token or the next refresh will fail.
 *
 * Required env vars:
 *   STRAVA_CLIENT_ID
 *   STRAVA_CLIENT_SECRET
 */
export async function refreshStravaToken(refreshToken: string): Promise<TokenResult> {
  const clientId = Deno.env.get('STRAVA_CLIENT_ID')
  const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET')

  if (!clientId || !clientSecret) {
    throw new Error('[Token Refresh] STRAVA_CLIENT_ID or STRAVA_CLIENT_SECRET not configured')
  }

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  })

  const response = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error('[Token Refresh] Strava token refresh failed:', response.status, errorText)
    throw new Error(`Strava token refresh failed with status ${response.status}`)
  }

  const data = await response.json()

  // Strava returns expires_at as a UNIX timestamp
  const expiresAt = new Date((data.expires_at ?? Math.floor(Date.now() / 1000) + 3600) * 1000).toISOString()

  console.log('[Token Refresh] Strava token refreshed successfully')

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token, // Strava ALWAYS rotates — never fall back to old token
    expiresAt,
  }
}
