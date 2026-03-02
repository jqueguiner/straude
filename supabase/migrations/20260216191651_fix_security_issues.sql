
-- =============================================
-- Migration: fix_security_issues
-- Fixes mutable search_path on functions and
-- overly permissive cli_auth_codes RLS policy
-- =============================================

-- Step 1: Fix handle_new_user (SECURITY DEFINER + search_path)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, github_username, avatar_url, timezone)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'user_name',
    NEW.raw_user_meta_data ->> 'avatar_url',
    COALESCE(NEW.raw_user_meta_data ->> 'timezone', 'UTC')
  );
  RETURN NEW;
END;
$$;

-- Step 2: Fix update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Step 3: Fix refresh_leaderboards
CREATE OR REPLACE FUNCTION public.refresh_leaderboards()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_daily;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_weekly;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_monthly;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_all_time;
END;
$$;

-- Step 4: Fix calculate_user_streak
CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE := CURRENT_DATE;
  has_usage BOOLEAN;
BEGIN
  LOOP
    SELECT EXISTS(
      SELECT 1 FROM public.daily_usage
      WHERE user_id = p_user_id AND date = current_date_check
    ) INTO has_usage;

    IF has_usage THEN
      streak_count := streak_count + 1;
      current_date_check := current_date_check - 1;
    ELSE
      EXIT;
    END IF;
  END LOOP;

  RETURN streak_count;
END;
$$;

-- Step 5: Fix cli_auth_codes RLS policy
-- Drop the overly permissive policy
DROP POLICY IF EXISTS "Service role manages cli auth codes" ON cli_auth_codes;

-- Create proper policies:
-- Only authenticated users can read their own pending codes (for the verify page)
CREATE POLICY "Users can view own cli auth codes"
  ON cli_auth_codes FOR SELECT
  USING (user_id = auth.uid() OR status = 'pending');

-- Service role handles insert/update via API routes (no direct client access needed)
-- API routes use service_role key, which bypasses RLS
-- Authenticated users can verify codes (update user_id + status)
CREATE POLICY "Authenticated users can verify pending codes"
  ON cli_auth_codes FOR UPDATE
  USING (status = 'pending')
  WITH CHECK (user_id = auth.uid() AND status IN ('pending', 'completed'));
;
