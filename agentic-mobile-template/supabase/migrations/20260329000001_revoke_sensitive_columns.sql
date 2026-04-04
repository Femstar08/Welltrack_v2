-- Migration: Revoke column-level UPDATE on sensitive wt_users columns
-- Security fix: prevents authenticated users from self-upgrading plan_tier
-- or bypassing onboarding via direct Supabase REST API calls.
--
-- Only the service role (Edge Functions, triggers) can modify these columns.
-- The existing row-level UPDATE policy remains intact for other columns.
-- ============================================================================

-- Revoke UPDATE on plan_tier — tier changes must go through server-side
-- payment verification (Edge Function with receipt validation).
REVOKE UPDATE (plan_tier) ON public.wt_users FROM authenticated;

-- Revoke UPDATE on onboarding_completed — must only be set via the
-- mark_onboarding_complete() RPC function below.
REVOKE UPDATE (onboarding_completed) ON public.wt_users FROM authenticated;

-- RPC function to mark onboarding complete for the calling user.
-- Uses SECURITY DEFINER to bypass the column-level REVOKE.
-- Validates that a wt_profiles record exists before setting the flag.
CREATE OR REPLACE FUNCTION public.mark_onboarding_complete()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only mark complete if a profile actually exists for this user
  IF EXISTS (SELECT 1 FROM public.wt_profiles WHERE user_id = auth.uid()) THEN
    UPDATE public.wt_users
    SET onboarding_completed = true, updated_at = now()
    WHERE id = auth.uid();
  ELSE
    RAISE EXCEPTION 'Cannot complete onboarding: no profile found for user';
  END IF;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.mark_onboarding_complete() TO authenticated;

-- Verify: after this migration, an authenticated user calling
--   supabase.from('wt_users').update({'plan_tier': 'pro'}).eq('id', userId)
-- will receive a permission denied error from PostgREST.
-- But supabase.rpc('mark_onboarding_complete') will work if they have a profile.
