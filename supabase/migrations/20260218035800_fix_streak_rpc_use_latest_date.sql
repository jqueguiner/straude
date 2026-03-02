CREATE OR REPLACE FUNCTION public.calculate_user_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $$
DECLARE
  streak_count INTEGER := 0;
  current_date_check DATE;
  has_usage BOOLEAN;
  latest_date DATE;
BEGIN
  -- Find the user's most recent usage date
  SELECT MAX(date) INTO latest_date
  FROM public.daily_usage
  WHERE user_id = p_user_id;

  -- No usage at all
  IF latest_date IS NULL THEN
    RETURN 0;
  END IF;

  -- If latest usage is more than 2 days old, streak is broken.
  -- 2-day grace covers all timezone offsets (UTC-12 to UTC+14).
  IF latest_date < CURRENT_DATE - 2 THEN
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
$$;;
