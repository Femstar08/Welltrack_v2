import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export function createSupabaseClient(req: Request) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // For user-scoped operations, use the user's JWT
  const authHeader = req.headers.get('Authorization')

  return {
    // Admin client (bypasses RLS)
    adminClient: createClient(supabaseUrl, supabaseServiceKey),
    // User client (respects RLS)
    userClient: createClient(supabaseUrl, supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader || '' },
      },
    }),
  }
}
