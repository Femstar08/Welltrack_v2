-- RPC function to delete all user data across wt_* tables.
-- Called from the Flutter app when user requests account deletion.
-- Uses SECURITY DEFINER to bypass column-level REVOKEs.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_ids uuid[];
BEGIN
  -- Get all profile IDs for this user
  SELECT array_agg(id) INTO v_profile_ids
  FROM public.wt_profiles
  WHERE user_id = v_user_id;

  IF v_profile_ids IS NULL THEN
    -- No profiles found, just clean up wt_users
    DELETE FROM public.wt_users WHERE id = v_user_id;
    RETURN;
  END IF;

  -- Delete all profile-scoped data (CASCADE handles most via FK)
  DELETE FROM public.wt_health_metrics WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_recovery_scores WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_training_loads WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_daily_checkins WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_daily_plans WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_meal_plans WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_meals WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_recipes WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_pantry_items WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_shopping_lists WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_goals WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_workouts WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_workout_logs WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_supplements WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_supplement_logs WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_reminders WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_habit_streaks WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_habit_logs WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_bloodwork_results WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_health_connections WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_webhook_events WHERE user_id = v_user_id;
  DELETE FROM public.wt_baselines WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_insights WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_forecasts WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_profile_modules WHERE profile_id = ANY(v_profile_ids);
  DELETE FROM public.wt_ai_usage WHERE profile_id = ANY(v_profile_ids);

  -- Delete profiles
  DELETE FROM public.wt_profiles WHERE user_id = v_user_id;

  -- Delete user record
  DELETE FROM public.wt_users WHERE id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_data() TO authenticated;
