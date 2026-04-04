import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export function createSupabaseClient(req: Request) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // For user-scoped operations, use the user's JWT
  const authHeader = req.headers.get('Authorization')

  return {
    // Admin client (bypasses RLS)
    adminClient: createClient(supabaseUrl, supabaseServiceKey),
    // User client (respects RLS) — uses anon key so PostgREST enforces RLS.
    // The user's JWT in the Authorization header determines which rows are visible.
    userClient: createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader || '' },
      },
    }),
  }
}
