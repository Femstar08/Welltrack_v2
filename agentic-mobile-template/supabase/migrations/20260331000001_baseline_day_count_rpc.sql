-- RPC function to count distinct days with health data for a profile.
-- Replaces the client-side unbounded SELECT that fetched ALL rows.
-- Scoped to last 60 days for performance.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_baseline_day_count(p_profile_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(DISTINCT DATE(start_time))::integer
  FROM public.wt_health_metrics
  WHERE profile_id = p_profile_id
    AND start_time >= (now() - interval '60 days');
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_baseline_day_count(uuid) TO authenticated;
