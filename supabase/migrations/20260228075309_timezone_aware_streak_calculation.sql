
-- Update the 1-param overload (used in achievements)
CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE;
  has_usage BOOLEAN;
  latest_date DATE;
  user_tz TEXT;
  user_today DATE;
BEGIN
  -- Look up the user's timezone, fall back to UTC
  SELECT COALESCE(NULLIF(timezone, ''), 'UTC') INTO user_tz
  FROM public.users
  WHERE id = p_user_id;

  IF user_tz IS NULL THEN
    user_tz := 'UTC';
  END IF;

  -- Compute "today" in the user's local timezone
  user_today := (NOW() AT TIME ZONE user_tz)::date;

  -- Find the user's most recent usage date
  SELECT MAX(date) INTO latest_date
  FROM public.daily_usage
  WHERE user_id = p_user_id;

  -- No usage at all
  IF latest_date IS NULL THEN
    RETURN 0;
  END IF;

  -- 1-day grace: user has until end of today to push, so yesterday's push keeps streak alive
  IF latest_date < user_today - 1 THEN
    RETURN 0;
  END IF;

  -- Count consecutive days backward from latest date
  current_date_check := latest_date;
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
$function$;

-- Update the 2-param overload (used in layout/profile)
CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id uuid, p_freeze_days integer DEFAULT 0)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE;
  has_usage BOOLEAN;
  latest_date DATE;
  user_tz TEXT;
  user_today DATE;
  grace INTEGER;
BEGIN
  -- Look up the user's timezone, fall back to UTC
  SELECT COALESCE(NULLIF(timezone, ''), 'UTC') INTO user_tz
  FROM public.users
  WHERE id = p_user_id;

  IF user_tz IS NULL THEN
    user_tz := 'UTC';
  END IF;

  -- Compute "today" in the user's local timezone
  user_today := (NOW() AT TIME ZONE user_tz)::date;

  -- 1-day grace (can still push today) + freeze days
  grace := 1 + p_freeze_days;

  SELECT MAX(date) INTO latest_date
  FROM public.daily_usage
  WHERE user_id = p_user_id;

  IF latest_date IS NULL THEN
    RETURN 0;
  END IF;

  IF latest_date < user_today - grace THEN
    RETURN 0;
  END IF;

  current_date_check := latest_date;
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
$function$;
;
